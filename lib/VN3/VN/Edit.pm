package VN3::VN::Edit;

use VN3::Prelude;
use VN3::VN::Lib;


my $FORM = {
    alias       => { required => 0, default => '', maxlength => 500 },
    anime       => { maxlength => 50, sort_keys => 'aid', aoh =>{
        aid       => { id => 1 }
    } },
    desc        => { required => 0, default => '', maxlength => 10240 },
    image       => { required => 0, default => 0, id => 1 }, # X
    img_nsfw    => { anybool => 1 },
    hidden      => { anybool => 1 },
    l_encubed   => { required => 0, default => '', maxlength => 100 },
    l_renai     => { required => 0, default => '', maxlength => 100 },
    l_wp        => { required => 0, default => '', maxlength => 150 },
    length      => { vn_length => 1 },
    locked      => { anybool => 1 },
    original    => { required => 0, default => '', maxlength => 250 },
    relations   => { maxlength => 50, sort_keys => 'vid', aoh => {
        vid       => { id => 1 }, # X
        relation  => { vn_relation => 1 },
        official  => { anybool => 1 },
        title     => { _when => 'out' },
    } },
    screenshots =>  { maxlength => 10, sort_keys => 'scr', aoh => {
        scr       => { id => 1 }, # X
        rid       => { id => 1 }, # X
        nsfw      => { anybool => 1 },
        width     => { _when => 'out', uint => 1 },
        height    => { _when => 'out', uint => 1 },
    } },
    seiyuu      => { sort_keys => ['aid','cid'], aoh => {
        aid       => { id => 1 }, # X
        cid       => { id => 1 }, # X
        note      => { required => 0, default => '', maxlength => 250 },
        id        => { _when => 'out', id => 1 },
        name      => { _when => 'out' },
    } },
    staff       => { sort_keys => ['aid','role'], aoh => {
        aid       => { id => 1 }, # X
        role      => { staff_role => 1 },
        note      => { required => 0, default => '', maxlength => 250 },
        id        => { _when => 'out', id => 1 },
        name      => { _when => 'out' },
    } },
    title       => { maxlength => 250 },

    id          => { _when => 'out', required => 0, id => 1 },
    authmod     => { _when => 'out', anybool => 1 },
    editsum     => { _when => 'in out', editsum => 1 },
    chars       => { _when => 'out', aoh => {
        id        => { id => 1 },
        name      => {},
    } },
    releases    => { _when => 'out', aoh => {
        id        => { id => 1 },
        title     => {},
        original  => {},
        display   => {},
        resolution=> {},
    } },
};

our $FORM_OUT = form_compile out => $FORM;
our $FORM_IN  = form_compile in  => $FORM;
our $FORM_CMP = form_compile cmp => $FORM;



TUWF::get qr{/$VREV_RE/edit} => sub {
    my $vn = entry v => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    return tuwf->resDenied if !can_edit v => $vn;

    enrich aid => q{SELECT id, aid, name FROM staff_alias WHERE aid IN} => $vn->{staff}, $vn->{seiyuu};
    enrich vid => q{SELECT id AS vid, title FROM vn WHERE id IN} => $vn->{relations};
    enrich scr => q{SELECT id AS scr, width, height FROM screenshots WHERE id IN}, $vn->{screenshots};
    $vn->{chars} = tuwf->dbAlli('SELECT id, name FROM chars c WHERE id IN(SELECT id FROM chars_vns WHERE vid =', \$vn->{id}, ') ORDER BY name');

    $vn->{releases} = tuwf->dbAlli('SELECT id, title, original, resolution FROM releases WHERE id IN(SELECT id FROM releases_vn WHERE vid =', \$vn->{id}, ') ORDER BY id');
    enrich_list1 lang => id => id => q{SELECT id, lang FROM releases_lang WHERE id IN}, $vn->{releases};
    $_->{display} = sprintf '[%s] %s (r%d)', join(',', @{ delete $_->{lang} }), $_->{title}, $_->{id} for @{$vn->{releases}};

    $vn->{authmod} = auth->permDbmod;
    $vn->{editsum} = $vn->{chrev} == $vn->{maxrev} ? '' : "Reverted to revision v$vn->{id}.$vn->{chrev}";

    Framework index => 0, title => "Edit $vn->{title}",
    top => sub {
        Div class => 'col-md', sub {
            EntryEdit v => $vn;
            Div class => 'detail-page-title', sub {
                Txt $vn->{title};
                Debug $vn;
            };
            TopNav edit => $vn;
        };
    }, sub {
        FullPageForm module => 'VNEdit.Main', data => $vn, schema => $FORM_OUT, sections => [
            general     => 'General info',
            staff       => 'Staff',
            cast        => 'Cast',
            relations   => 'Relations',
            screenshots => 'Screenshots',
        ];
    };
};


TUWF::get '/v/add', sub {
    return tuwf->resDenied if !auth->permEdit;
    Framework index => 0, title => 'Add a new visual novel', narrow => 1, sub {
        Div class => 'row', sub {
            Div class => 'col-md col-md--1', sub { Div 'data-elm-module' => 'VNEdit.New', '' };
        };
    };
};


json_api qr{/(?:$VID_RE/edit|v/add)}, $FORM_IN, sub {
    my $data = shift;
    my $new = !tuwf->capture('id');
    my $vn = $new ? { id => 0 } : entry v => tuwf->capture('id') or return tuwf->resNotFound;

    return tuwf->resJSON({Unauth => 1}) if !can_edit v => $vn;

    if(!auth->permDbmod) {
        $data->{hidden} = $vn->{hidden}||0;
        $data->{locked} = $vn->{locked}||0;
    }

    # Elm doesn't actually verify this one
    die "Image not found" if $data->{image} && !-e tuwf->imgpath(cv => $data->{image});

    die "Relation with self" if grep $_->{vid} == $vn->{id}, @{$data->{relations}};
    validate_dbid 'SELECT id FROM vn WHERE id IN', map $_->{vid}, @{$data->{relations}};
    validate_dbid 'SELECT id FROM screenshots WHERE id IN', map $_->{scr}, @{$data->{screenshots}};
    validate_dbid sql('SELECT DISTINCT id FROM releases_vn WHERE vid =', \$vn->{id}, ' AND id IN'), map $_->{rid}, @{$data->{screenshots}};
    validate_dbid 'SELECT aid FROM staff_alias WHERE aid IN', map $_->{aid}, @{$data->{seiyuu}}, @{$data->{staff}};
    validate_dbid sql('SELECT DISTINCT id FROM chars_vns WHERE vid =', \$vn->{id}, ' AND id IN'), map $_->{cid}, @{$data->{seiyuu}};

    $data->{desc} = bb_subst_links $data->{desc};
    return tuwf->resJSON({Unchanged => 1}) if !$new && !form_changed $FORM_CMP, $data, $vn;

    my($id,undef,$rev) = update_entry v => $vn->{id}, $data;

    update_reverse($id, $rev, $vn, $data);

    tuwf->resJSON({Changed => [$id, $rev]});
};


sub update_reverse {
    my($id, $rev, $old, $new) = @_;

    my %old = map +($_->{vid}, $_), $old->{relations} ? @{$old->{relations}} : ();
    my %new = map +($_->{vid}, $_), @{$new->{relations}};

    # Updates to be performed, vid => { vid => x, relation => y, official => z } or undef if the relation should be removed.
    my %upd;

    for my $i (keys %old, keys %new) {
        if($old{$i} && !$new{$i}) {
            $upd{$i} = undef;
        } elsif(!$old{$i} || $old{$i}{relation} ne $new{$i}{relation} || !$old{$i}{official} != !$new{$i}{official}) {
            $upd{$i} = {
                vid => $id,
                relation => vn_relation_reverse($new{$i}{relation}),
                official => $new{$i}{official}
            };
        }
    }

    for my $i (keys %upd) {
        my $v = entry v => $i;
        $v->{relations} = [
            $upd{$i} ? $upd{$i} : (),
            grep $_->{vid} != $id, @{$v->{relations}}
        ];
        $v->{editsum} = "Reverse relation update caused by revision v$id.$rev";
        update_entry v => $i, $v, 1;
    }
}

1;
