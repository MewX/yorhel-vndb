package VNWeb::ULists::Elm;

use VNWeb::Prelude;
use VNWeb::ULists::Lib;


# Should be called after any change to the ulist_* tables.
# (Normally I'd do this with triggers, but that seemed like a more complex and less efficient solution in this case)
sub updcache {
    tuwf->dbExeci(SELECT => sql_func update_users_ulist_stats => \shift);
}


our $LABELS = form_compile any => {
    uid => { id => 1 },
    labels => { aoh => {
        id      => { int => 1 },
        label   => { maxlength => 50 },
        private => { anybool => 1 },
        count   => { uint => 1 },
        delete  => { required => 0, default => undef, uint => 1, range => [1, 3] }, # 1=keep vns, 2=delete when no other label, 3=delete all
    } }
};

elm_api UListManageLabels => undef, $LABELS, sub {
    my($uid, $labels) = ($_[0]{uid}, $_[0]{labels});
    return elm_Unauth if !ulists_own $uid;

    # Insert new labels
    my @new = grep $_->{id} < 0 && !$_->{delete}, @$labels;
    # Subquery to get the lowest unused id
    my $newid = sql '(
        SELECT min(x.n)
         FROM generate_series(10,
                greatest((SELECT max(id)+1 from ulist_labels ul WHERE ul.uid =', \$uid, '), 10)
              ) x(n)
        WHERE NOT EXISTS(SELECT 1 FROM ulist_labels ul WHERE ul.uid =', \$uid, 'AND ul.id = x.n)
    )';
    tuwf->dbExeci('INSERT INTO ulist_labels', { id => $newid, uid => $uid, label => $_->{label}, private => $_->{private} }) for @new;

    # Update private flag
    tuwf->dbExeci(
        'UPDATE ulist_labels SET private =', \$_->{private},
         'WHERE uid =', \$uid, 'AND id =', \$_->{id}, 'AND private <>', \$_->{private}
    ) for grep $_->{id} > 0 && !$_->{delete}, @$labels;

    # Update label
    tuwf->dbExeci(
        'UPDATE ulist_labels SET label =', \$_->{label},
         'WHERE uid =', \$uid, 'AND id =', \$_->{id}, 'AND label <>', \$_->{label}
    ) for grep $_->{id} >= 10 && !$_->{delete}, @$labels;

    # Delete labels
    my @delete = grep $_->{id} >= 10 && $_->{delete}, @$labels;
    my @delete_lblonly = map $_->{id}, grep $_->{delete} == 1, @delete;
    my @delete_empty   = map $_->{id}, grep $_->{delete} == 2, @delete;
    my @delete_all     = map $_->{id}, grep $_->{delete} == 3, @delete;

    # delete vns with: (a label in option 3) OR ((a label in option 2) AND (no labels other than in option 1 or 2))
    my @where =
        @delete_all ? sql('vid IN(SELECT vid FROM ulist_vns_labels WHERE uid =', \$uid, 'AND lbl IN', \@delete_all, ')') : (),
        @delete_empty ? sql(
                'vid IN(SELECT vid FROM ulist_vns_labels WHERE uid =', \$uid, 'AND lbl IN', \@delete_empty, ')',
            'AND NOT EXISTS(SELECT 1 FROM ulist_vns_labels WHERE uid =', \$uid, 'AND lbl NOT IN(', [ @delete_lblonly, @delete_empty ], '))'
        ) : ();
    tuwf->dbExeci('DELETE FROM ulist_vns WHERE uid =', \$uid, 'AND (', sql_or(@where), ')') if @where;

    # (This will also delete all relevant vn<->label rows from ulist_vns_labels)
    tuwf->dbExeci('DELETE FROM ulist_labels WHERE uid =', \$uid, 'AND id IN', [ map $_->{id}, @delete ]) if @delete;

    updcache $uid;
    elm_Success
};




our $VNVOTE = form_compile any => {
    uid  => { id => 1 },
    vid  => { id => 1 },
    vote => { vnvote => 1 },
};

elm_api UListVoteEdit => undef, $VNVOTE, sub {
    my($data) = @_;
    return elm_Unauth if !ulists_own $data->{uid};
    tuwf->dbExeci(
        'INSERT INTO ulist_vns', { %$data, vote_date => sql $data->{vote} ? 'NOW()' : 'NULL' },
            'ON CONFLICT (uid, vid) DO UPDATE
            SET', { %$data,
                lastmod   => sql('NOW()'),
                vote_date => sql $data->{vote} ? 'CASE WHEN ulist_vns.vote IS NULL THEN NOW() ELSE ulist_vns.vote_date END' : 'NULL'
            }
    );
    updcache $data->{uid};
    elm_Success
};




my $VNLABELS = {
    uid      => { id => 1 },
    vid      => { id => 1 },
    label    => { _when => 'in', id => 1 },
    applied  => { _when => 'in', anybool => 1 },
    labels   => { _when => 'out', aoh => { id => { int => 1 }, label => {}, private => { anybool => 1 } } },
    selected => { _when => 'out', type => 'array', values => { id => 1 } },
};

our $VNLABELS_OUT = form_compile out => $VNLABELS;
my  $VNLABELS_IN  = form_compile in  => $VNLABELS;

elm_api UListLabelEdit => $VNLABELS_OUT, $VNLABELS_IN, sub {
    my($data) = @_;
    return elm_Unauth if !ulists_own $data->{uid};
    die "Attempt to set vote label" if $data->{label} == 7;

    tuwf->dbExeci('INSERT INTO ulist_vns', {uid => $data->{uid}, vid => $data->{vid}}, 'ON CONFLICT (uid, vid) DO NOTHING');
    tuwf->dbExeci(
        'DELETE FROM ulist_vns_labels
          WHERE uid =', \$data->{uid}, 'AND vid =', \$data->{vid}, 'AND lbl =', \$data->{label}
    ) if !$data->{applied};
    tuwf->dbExeci(
        'INSERT INTO ulist_vns_labels', { uid => $data->{uid}, vid => $data->{vid}, lbl => $data->{label} },
        'ON CONFLICT (uid, vid, lbl) DO NOTHING'
    ) if $data->{applied};
    tuwf->dbExeci('UPDATE ulist_vns SET lastmod = NOW() WHERE uid =', \$data->{uid}, 'AND vid =', \$data->{vid});

    updcache $data->{uid};
    elm_Success
};




our $VNDATE = form_compile any => {
    uid   => { id => 1 },
    vid   => { id => 1 },
    date  => { required => 0, default => '', regex => qr/^(?:19[7-9][0-9]|20[0-9][0-9])-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])$/ }, # 1970 - 2099 for sanity
    start => { anybool => 1 }, # Field selection, started/finished
};

elm_api UListDateEdit => undef, $VNDATE, sub {
    my($data) = @_;
    return elm_Unauth if !ulists_own $data->{uid};
    tuwf->dbExeci(
        'UPDATE ulist_vns SET lastmod = NOW(), ', $data->{start} ? 'started' : 'finished', '=', \($data->{date}||undef),
         'WHERE uid =', \$data->{uid}, 'AND vid =', \$data->{vid}
    );
    updcache $data->{uid};
    elm_Success
};




our $VNOPT = form_compile any => {
    own   => { anybool => 1 },
    uid   => { id => 1 },
    vid   => { id => 1 },
    notes => {},
    rels  => $VNWeb::Elm::apis{Releases}[0],
    relstatus => { type => 'array', values => { uint => 1 } }, # List of release statuses, same order as rels
};


our $VNPAGE = form_compile any => {
    uid      => { id => 1 },
    vid      => { id => 1 },
    onlist   => { anybool => 1 },
    canvote  => { anybool => 1 },
    vote     => { vnvote => 1 },
    notes    => { required => 0, default => '' },
    review   => { required => 0, vndbid => 'w' },
    canreview=> { anybool => 1 },
    labels   => { aoh => { id => { int => 1 }, label => {}, private => { anybool => 1 } } },
    selected => { type => 'array', values => { id => 1 } },
};


# UListVNNotes module is abused for the UList.Opts and UList.VNPage flag definition
elm_api UListVNNotes => $VNOPT, {
    uid   => { id => 1 },
    vid   => { id => 1 },
    notes => { required => 0, default => '', maxlength => 2000 },
}, sub {
    my($data) = @_;
    return elm_Unauth if !ulists_own $data->{uid};
    tuwf->dbExeci(
        'INSERT INTO ulist_vns', \%$data, 'ON CONFLICT (uid, vid) DO UPDATE SET', { %$data, lastmod => sql('NOW()') }
    );
    # Doesn't need `updcache()`
    elm_Success
}, VNPage => $VNPAGE;




elm_api UListDel => undef, {
    uid => { id => 1 },
    vid => { id => 1 },
}, sub {
    my($data) = @_;
    return elm_Unauth if !ulists_own $data->{uid};
    tuwf->dbExeci('DELETE FROM ulist_vns WHERE uid =', \$data->{uid}, 'AND vid =', \$data->{vid});
    updcache $data->{uid};
    elm_Success
};




# Adds the release when not in the list.
# $RLIST_STATUS is also referenced from VNWeb::Releases::Page.
our $RLIST_STATUS = form_compile any => {
    uid => { id => 1 },
    rid => { id => 1 },
    status => { required => 0, uint => 1, enum => \%RLIST_STATUS }, # undef meaning delete
    empty => { required => 0, default => '' }, # An 'out' field
};
elm_api UListRStatus => undef, $RLIST_STATUS, sub {
    my($data) = @_;
    delete $data->{empty};
    return elm_Unauth if !ulists_own $data->{uid};
    if(!defined $data->{status}) {
        tuwf->dbExeci('DELETE FROM rlists WHERE uid =', \$data->{uid}, 'AND rid =', \$data->{rid})
    } else {
        tuwf->dbExeci('INSERT INTO rlists', $data, 'ON CONFLICT (uid, rid) DO UPDATE SET status =', \$data->{status})
    }
    # Doesn't need `updcache()`
    elm_Success
};




our %SAVED_OPTS = (
    # Labels
    l   => { onerror => [], type => 'array', scalar => 1, values => { int => 1 } },
    mul => { anybool => 1 },
    # Sort column & order
    s   => { onerror => 'title', enum => [qw[ title label vote voted added modified started finished rel rating ]] },
    o   => { onerror => 'a', enum => ['a', 'd'] },
    # Visible columns
    c   => { onerror => [], type => 'array', scalar => 1, values => { enum => [qw[ label vote voted added modified started finished rel rating ]] } },
);

my $SAVED_OPTS = {
    uid   => { id => 1 },
    opts  => { type => 'hash', keys => \%SAVED_OPTS },
    field => { _when => 'in', enum => [qw/ vnlist votes wish /] },
};

my  $SAVED_OPTS_IN  = form_compile in  => $SAVED_OPTS;
our $SAVED_OPTS_OUT = form_compile out => $SAVED_OPTS;

elm_api UListSaveDefault => $SAVED_OPTS_OUT, $SAVED_OPTS_IN, sub {
    my($data) = @_;
    return elm_Unauth if !ulists_own $data->{uid};
    tuwf->dbExeci('UPDATE users SET ulist_'.$data->{field}, '=', \JSON::XS->new->encode($data->{opts}), 'WHERE id =', \$data->{uid});
    elm_Success
};

1;
