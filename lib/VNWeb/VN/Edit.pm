package VNWeb::VN::Edit;

use VNWeb::Prelude;
use VNWeb::Images::Lib 'enrich_image';


my $FORM = {
    id         => { required => 0, id => 1 },
    title      => { maxlength => 250 },
    original   => { required => 0, default => '', maxlength => 250 },
    alias      => { required => 0, default => '', maxlength => 500 },
    desc       => { required => 0, default => '', maxlength => 10240 },
    length     => { uint => 1, enum => \%VN_LENGTH },
    l_wikidata => { required => 0, uint => 1, max => (1<<31)-1 },
    l_renai    => { required => 0, default => '', maxlength => 100 },
    anime      => { sort_keys => 'id', aoh => {
        aid      => { id => 1 },
        title    => { _when => 'out' },
        original => { _when => 'out', required => 0, default => '' },
    } },
    image      => { required => 0, vndbid => 'cv' },
    image_info => { _when => 'out', required => 0, type => 'hash', keys => $VNWeb::Elm::apis{ImageResult}[0]{aoh} },
    screenshots=> { sort_keys => 'scr', aoh => {
        scr      => { vndbid => 'sf' },
        rid      => { required => 0, id => 1 },
        info     => { _when => 'out', type => 'hash', keys => $VNWeb::Elm::apis{ImageResult}[0]{aoh} },
    } },
    hidden     => { anybool => 1 },
    locked     => { anybool => 1 },

    authmod    => { _when => 'out', anybool => 1 },
    editsum    => { _when => 'in out', editsum => 1 },
    releases   => { _when => 'out', $VNWeb::Elm::apis{Releases}[0]->%* },
};

my $FORM_OUT = form_compile out => $FORM;
my $FORM_IN  = form_compile in  => $FORM;
my $FORM_CMP = form_compile cmp => $FORM;


TUWF::get qr{/$RE{vrev}/edit} => sub {
    my $e = db_entry v => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    return tuwf->resDenied if !can_edit v => $e;

    $e->{image_sex} = $e->{image_vio} = undef;
    $e->{authmod} = auth->permDbmod;
    $e->{editsum} = $e->{chrev} == $e->{maxrev} ? '' : "Reverted to revision v$e->{id}.$e->{chrev}";

    if($e->{image}) {
        $e->{image_info} = { id => $e->{image} };
        enrich_image 0, [$e->{image_info}];
    } else {
        $e->{image_info} = undef;
    }
    $_->{info} = {id=>$_->{scr}} for $e->{screenshots}->@*;
    enrich_image 0, [map $_->{info}, $e->{screenshots}->@*];

    enrich_merge aid => 'SELECT id AS aid, title_romaji AS title, title_kanji AS original FROM anime WHERE id IN', $e->{anime};

    $e->{releases} = tuwf->dbAlli('
        SELECT rv.vid, r.id, r.title, r.original, r.released, r.type as rtype, r.reso_x, r.reso_y
          FROM releases r
          JOIN releases_vn rv ON rv.id = r.id
         WHERE NOT r.hidden AND rv.vid =', \$e->{id}, '
         ORDER BY r.released, r.title, r.id'
    );
    enrich_flatten lang => id => id => sub { sql('SELECT id, lang FROM releases_lang WHERE id IN', $_, 'ORDER BY lang') }, $e->{releases};
    enrich_flatten platforms => id => id => sub { sql('SELECT id, platform FROM releases_platforms WHERE id IN', $_, 'ORDER BY platform') }, $e->{releases};

    framework_ title => "Edit $e->{title}", type => 'v', dbobj => $e, tab => 'edit',
    sub {
        editmsg_ v => $e, "Edit $e->{title}";
        elm_ VNEdit => $FORM_OUT, $e;
    };
};


# TODO: Make this work
TUWF::get qr{/v/add}, sub {
    return tuwf->resDenied if !can_edit v => undef;

    my $e = elm_empty($FORM_OUT);

    framework_ title => 'Add visual novel',
    sub {
        editmsg_ v => undef, 'Add visual novel';
        elm_ VNEdit => $FORM_OUT, $e;
    };
};


elm_api VNEdit => $FORM_OUT, $FORM_IN, sub {
    my $data = shift;
    my $new = !$data->{id};
    my $e = $new ? { id => 0 } : db_entry v => $data->{id} or return tuwf->resNotFound;
    return elm_Unauth if !can_edit v => $e;

    if(!auth->permDbmod) {
        $data->{hidden} = $e->{hidden}||0;
        $data->{locked} = $e->{locked}||0;
    }
    $data->{desc} = bb_subst_links $data->{desc};

    validate_dbid 'SELECT id FROM anime WHERE id IN', map $_->{aid}, $data->{anime}->@*;
    validate_dbid 'SELECT id FROM images WHERE id IN', $data->{image} if $data->{image};
    validate_dbid 'SELECT id FROM images WHERE id IN', map $_->{scr}, $data->{screenshots}->@*;

    die "Screenshot without releases assigned" if grep !$_->{rid}, $data->{screenshots}->@*; # This is only the case for *very* old revisions, form disallows this now.
    # Allow linking to deleted or moved releases only if the previous revision also had that.
    # (The form really should encourage the user to fix that, but disallowing the edit seems a bit overkill)
    validate_dbid sub { '
        SELECT r.id FROM releases r JOIN releases_vn rv ON r.id = rv.id WHERE NOT r.hidden AND rv.vid =', \$e->{id}, ' AND r.id IN', $_, '
         UNION
        SELECT rid FROM vn_screenshots WHERE id =', \$e->{id}, 'AND rid IN', $_
    }, map $_->{rid}, $data->{screenshots}->@*;

    $data->{image_nsfw} = $e->{image_nsfw}||0;
    my %oldscr = map +($_->{scr}, $_->{nsfw}), @{ $e->{screenshots}||[] };
    $_->{nsfw} = $oldscr{$_->{scr}}||0 for $data->{screenshots}->@*;

    return elm_Unchanged if !$new && !form_changed $FORM_CMP, $data, $e;
    my($id,undef,$rev) = db_edit v => $e->{id}, $data;
    elm_Redirect "/v$id.$rev";
};

1;
