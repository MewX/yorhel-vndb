package VN3::Char::Edit;

use VN3::Prelude;
use VN3::ElmGen;


my $FORM = {
    alias       => { required => 0, default => '', maxlength => 500 },
    desc        => { required => 0, default => '', maxlength => 5000 },
    hidden      => { anybool => 1 },
    locked      => { anybool => 1 },
    original    => { required => 0, default => '', maxlength => 200 },
    name        => { maxlength => 200 },
    b_day       => { uint => 1, range => [ 0, 31 ] },
    b_month     => { uint => 1, range => [ 0, 12 ] },
    s_waist     => { uint => 1, range => [ 0, 99999 ] },
    s_bust      => { uint => 1, range => [ 0, 99999 ] },
    s_hip       => { uint => 1, range => [ 0, 99999 ] },
    height      => { uint => 1, range => [ 0, 99999 ] },
    weight      => { uint => 1, range => [ 0, 99999 ], required => 0 },
    gender      => { gender => 1 },
    bloodt      => { blood_type => 1 },
    image       => { required => 0, default => 0, id => 1 }, # X
    main        => { id => 1, required => 0 }, # X
    main_spoil  => { spoiler => 1 },
    main_name   => { _when => 'out' },
    main_is     => { _when => 'out', anybool => 1 }, # If true, this character is already a "main" character for other character(s)
    traits      => { maxlength => 200, sort_keys => 'tid', aoh => {
        tid       => { id => 1 }, # X
        spoil     => { spoiler => 1 },
        group     => { _when => 'out' },
        name      => { _when => 'out' },
    } },
    vns         => { maxlength => 50, sort_keys => ['vid', 'rid'], aoh => {
        vid       => { id => 1 }, # X
        rid       => { id => 1, required => 0 }, # X
        role      => { char_role => 1 },
        spoil     => { spoiler => 1 },
        title     => { _when => 'out' },
    } },

    vnrels      => { _when => 'out', aoh => {
        id        => { id => 1 },
        releases  => { aoh => {
            id      => { id => 1 },
            title   => { },
            lang    => { type => 'array', values => {} },
        } }
    } },

    id          => { _when => 'out', required => 0, id => 1 },
    authmod     => { _when => 'out', anybool => 1 },
    editsum     => { _when => 'in out', editsum => 1 },
};

my $FORM_OUT = form_compile out => $FORM;
my $FORM_IN  = form_compile in  => $FORM;
my $FORM_CMP = form_compile cmp => $FORM;

elm_form CharEdit => $FORM_OUT, $FORM_IN;


sub vnrels {
    my @vns = @_;
    my $v = [ map +{ id => $_ }, @vns ];
    enrich_list releases => id => vid => sub {
        sql q{SELECT rv.vid, r.id, r.title FROM releases r JOIN releases_vn rv ON rv.id = r.id WHERE NOT r.hidden AND rv.vid IN}, $_[0], q{ORDER BY r.id}
    }, $v;
    enrich_list1 lang => id => id => sub { sql 'SELECT id, lang FROM releases_lang WHERE id IN', $_[0], 'ORDER BY id, lang' }, map $_->{releases}, @$v;
    $v
}


TUWF::get qr{/$CREV_RE/(?<type>edit|copy)} => sub {
    my $c = entry c => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    return tuwf->resDenied if !can_edit c => $c;
    my $copy = tuwf->capture('type') eq 'copy';

    $c->{main_name} = $c->{main} ? tuwf->dbVali('SELECT name FROM chars WHERE id =', \$c->{main}) : '';
    $c->{main_is} = !$copy && tuwf->dbVali('SELECT 1 FROM chars WHERE main =', \$c->{id})||0;

    enrich tid => q{SELECT t.id AS tid, t.name, g.name AS group, g.order FROM traits t JOIN traits g ON g.id = t.group WHERE t.id IN} => $c->{traits};
    $c->{traits} = [ sort { $a->{order} <=> $b->{order} || $a->{name} cmp $b->{name} } @{$c->{traits}} ];

    enrich vid => q{SELECT id AS vid, title FROM vn WHERE id IN} => $c->{vns};
    $c->{vns} = [ sort { $a->{vid} <=> $b->{vid} } @{$c->{vns}} ];

    my %vids = map +($_->{vid}, 1), @{$c->{vns}};
    $c->{vnrels} = vnrels keys %vids;

    $c->{authmod} = auth->permDbmod;
    $c->{editsum} = $copy ? "Copied from c$c->{id}.$c->{chrev}" : $c->{chrev} == $c->{maxrev} ? '' : "Reverted to revision c$c->{id}.$c->{chrev}";

    my $title = sprintf '%s %s', $copy ? 'Copy' : 'Edit', $c->{name};
    Framework index => 0, title => $title,
    top => sub {
        Div class => 'col-md', sub {
            EntryEdit c => $c;
            Div class => 'detail-page-title', sub {
                Txt $title;
                Debug $c;
            };
        };
    }, sub {
        FullPageForm module => 'CharEdit.Main', schema => $FORM_OUT, data => { %$c, $copy ? (id => undef) : () }, sections => [
            general => 'General info',
            traits  => 'Traits',
            vns     => 'Visual novels',
        ];
    };
};


TUWF::get qr{/$VID_RE/addchar}, sub {
    return tuwf->resDenied if !auth->permEdit;

    my $vn = tuwf->dbRowi('SELECT id, title FROM vn WHERE NOT hidden AND id =', \tuwf->capture('id'));
    return tuwf->resNotFound if !$vn->{id};

    my $data = {
        vns => [ { vid => $vn->{id}, rid => undef, role => 'primary', spoil => 0, title => $vn->{title} } ],
        vnrels => vnrels $vn->{id}
    };

    Framework index => 0, title => "Add a new character to $vn->{title}", narrow => 1, sub {
        FullPageForm module => 'CharEdit.New', schema => $FORM_OUT, data => $data, sections => [
            general   => 'General info',
            format    => 'Format',
            relations => 'Relations'
        ];
    };
};


json_api qr{/(?:$CID_RE/edit|c/add)}, $FORM_IN, sub {
    my $data = shift;
    my $new = !tuwf->capture('id');
    my $c = $new ? { id => 0 } : entry c => tuwf->capture('id') or return tuwf->resNotFound;

    return tuwf->resJSON({Unauth => 1}) if !can_edit c => $c;

    if(!auth->permDbmod) {
        $data->{hidden} = $c->{hidden}||0;
        $data->{locked} = $c->{locked}||0;
    }
    $data->{main} = undef if $data->{hidden};
    $data->{main_spoil} = 0 if !$data->{main};

    die "Image not found" if $data->{image} && !-e tuwf->imgpath(ch => $data->{image});
    if($data->{main}) {
        die "Relation with self" if $data->{main} == $c->{id};
        die "Invalid main" if !tuwf->dbVali('SELECT 1 FROM chars WHERE main IS NULL AND id =', \$data->{main});
        die "Main set when self is main" if $c->{id} && tuwf->dbVali('SELECT 1 FROM chars WHERE main =', \$c->{id});
    }
    validate_dbid 'SELECT id FROM traits WHERE id IN', map $_->{tid}, @{$data->{traits}};
    validate_dbid 'SELECT id FROM vn WHERE id IN', map $_->{vid}, @{$data->{vns}};
    for (grep $_->{rid}, @{$data->{vns}}) {
        die "Invalid release $_->{rid}" if !tuwf->dbVali('SELECT 1 FROM releases_vn WHERE', { id => $_->{rid}, vid => $_->{vid} });
    }

    $data->{desc} = bb_subst_links $data->{desc};

    return tuwf->resJSON({Unchanged => 1}) if !$new && !form_changed $FORM_CMP, $data, $c;

    my($id,undef,$rev) = update_entry c => $c->{id}, $data;
    tuwf->resJSON({Changed => [$id, $rev]});
};

1;
