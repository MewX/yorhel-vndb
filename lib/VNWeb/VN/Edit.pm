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
    hidden     => { anybool => 1 },
    locked     => { anybool => 1 },

    authmod    => { _when => 'out', anybool => 1 },
    editsum    => { _when => 'in out', editsum => 1 },
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

    enrich_merge aid => 'SELECT id AS aid, title_romaji AS title, title_kanji AS original FROM anime WHERE id IN', $e->{anime};

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

    return elm_Unchanged if !$new && !form_changed $FORM_CMP, $data, $e;
    my($id,undef,$rev) = db_edit v => $e->{id}, $data;
    elm_Redirect "/v$id.$rev";
};

1;
