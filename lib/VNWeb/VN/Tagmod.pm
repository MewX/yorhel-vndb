package VNWeb::VN::Tagmod;

use VNWeb::Prelude;
use VNWeb::Tags::Lib;


my $FORM = {
    id    => { id => 1 },
    title => { _when => 'out' },
    tags  => { aoh => {
        id        => { id => 1 },
        vote      => { int => 1, enum => [ -3..3 ] },
        spoil     => { required => 0, uint => 1, enum => [ 0..2 ] },
        overrule  => { anybool => 1 },
        cat       => { _when => 'out' },
        name      => { _when => 'out' },
        rating    => { _when => 'out', num => 1 },
        count     => { _when => 'out', uint => 1 },
        spoiler   => { _when => 'out', num => 1 },
        overruled => { _when => 'out', anybool => 1 },
    } },
    mod   => { _when => 'out', anybool => 1 },
};

my $FORM_IN  = form_compile in  => $FORM;
my $FORM_OUT = form_compile out => $FORM;

elm_api Tagmod => $FORM_OUT, $FORM_IN, sub {
    my($id, $tags) = $_[0]->@{'id', 'tags'};
    return elm_Unauth if !auth->permTag;

    $tags = [ grep $_->{vote}, @$tags ];
    $_->{overrule} = 0 for auth->permTagmod ? () : @$tags;

    # Weed out invalid/deleted/non-applicable tags
    enrich_merge id => 'SELECT id, 1 as exists FROM tags WHERE state <> 1 AND applicable AND id IN', $tags;
    $tags = [ grep $_->{exists}, @$tags ];

    # Find out if any of these tags are being overruled
    enrich_merge id => sub { sql 'SELECT tag AS id, bool_or(ignore) as overruled FROM tags_vn WHERE vid =', \$id, 'AND tag IN', $_, 'GROUP BY tag' }, $tags;

    # Delete tag votes not in $tags
    tuwf->dbExeci('DELETE FROM tags_vn WHERE uid =', \auth->uid, 'AND vid =', \$id, @$tags ? ('AND tag NOT IN', [ map $_->{id}, @$tags ]) : ());

    # Add & update tags
    for(@$tags) {
        my $row = { uid => auth->uid, vid => $id, tag => $_->{id}, vote => $_->{vote}, spoiler => $_->{spoil}, ignore => ($_->{overruled} && !$_->{overrule})?1:0 };
        tuwf->dbExeci('INSERT INTO tags_vn', $row, 'ON CONFLICT (uid, vid, tag) DO UPDATE SET', $row);
        tuwf->dbExeci('UPDATE tags_vn SET ignore = TRUE WHERE uid <>', \auth->uid, 'AND vid =', \$id, 'AND tag =', \$_->{id}) if $_->{overrule};
    }

    # Make sure to reset the ignore flag when a moderator removes an overruled vote.
    # (i.e. look for tags where *all* votes are on ignore)
    tuwf->dbExeci('UPDATE tags_vn tv SET ignore = FALSE WHERE NOT EXISTS(SELECT 1 FROM tags_vn tvi WHERE tvi.tag = tv.tag AND tvi.vid = tv.vid AND NOT tvi.ignore) AND vid =', \$id) if auth->permTagmod;

    tuwf->dbExeci(select => sql_func tag_vn_calc => \$id);
    elm_Success
};


TUWF::get qr{/$RE{vid}/tagmod}, sub {
    my $v = tuwf->dbRowi('SELECT id, title, hidden AS entry_hidden, locked AS entry_locked FROM vn WHERE id =', \tuwf->capture('id'));
    return tuwf->resNotFound if !$v->{id} || (!auth->permDbmod && $v->{entry_hidden});
    return tuwf->resDenied if !auth->permTag;

    my $tags = tuwf->dbAlli('
        SELECT t.id, t.name, t.cat, count(*) as count
             , avg(CASE WHEN tv.ignore THEN NULL ELSE tv.vote END) as rating
             , coalesce(avg(CASE WHEN tv.ignore THEN NULL ELSE tv.spoiler END), t.defaultspoil) as spoiler
             , bool_or(tv.ignore) as overruled
          FROM tags t
          JOIN tags_vn tv ON tv.tag = t.id
         WHERE tv.vid =', \$v->{id}, '
         GROUP BY t.id, t.name, t.cat
         ORDER BY t.name'
    );
    enrich_merge id => sub { sql 'SELECT tag AS id, vote, spoiler AS spoil, ignore FROM tags_vn WHERE', { uid => auth->uid, vid => $v->{id} } }, $tags;

    for(@$tags) {
        $_->{vote} //= 0;
        $_->{spoil} //= undef;
        $_->{overrule} = $_->{vote} && !$_->{ignore} && $_->{overruled};
    }

    framework_ title => "Edit tags for $v->{title}", type => 'v', dbobj => $v, tab => 'tagmod', sub {
        elm_ 'Tagmod' => $FORM_OUT, { id => $v->{id}, title => $v->{title}, tags => $tags, mod => auth->permTagmod };
    };
};

1;
