package VN3::Release::Edit;

use VN3::Prelude;

my $FORM = {
    hidden      => { anybool => 1 },
    locked      => { anybool => 1 },
    title       => { maxlength => 250 },
    original    => { required => 0, default => '', maxlength => 250 },
    rtype       => { enum => [ release_types ] }, # This is 'type' in the database, but renamed for Elm compat
    patch       => { anybool => 1 },
    freeware    => { anybool => 1 },
    doujin      => { anybool => 1 },
    lang        => { minlength => 1, sort_keys => 'lang', aoh => { lang => { language => 1 } } },
    gtin        => { gtin => 1 },
    catalog     => { required => 0, default => '', maxlength => 50 },
    website     => { required => 0, default => '', weburl => 1 },
    released    => { rdate => 1, min => 1 },
    minage      => { required => 0, minage => 1 },
    uncensored  => { anybool => 1 },
    notes       => { required => 0, default => '', maxlength => 10240 },
    resolution  => { resolution => 1 },
    voiced      => { voiced => 1 },
    ani_story   => { animated => 1 },
    ani_ero     => { animated => 1 },
    platforms   => { sort_keys => 'platform', aoh => { platform => { platform => 1 } } },
    media       => { sort_keys => ['media', 'qty'], aoh => {
        medium    => { medium => 1 },
        qty       => { uint => 1, range => [0,20] },
    } },
    vn          => { length => [1,50], sort_keys => 'vid', aoh => {
        vid       => { id => 1 }, # X
        title     => { _when => 'out' },
    } },
    producers   => { maxlength => 50, sort_keys => 'pid', aoh => {
        pid       => { id => 1 }, # X
        developer => { anybool => 1 },
        publisher => { anybool => 1 },
        name      => { _when => 'out' },
    } },

    id          => { _when => 'out', required => 0, id => 1 },
    authmod     => { _when => 'out', anybool => 1 },
    editsum     => { _when => 'in out', editsum => 1 },
};

my $FORM_OUT = form_compile out => $FORM;
my $FORM_IN  = form_compile in  => $FORM;
my $FORM_CMP = form_compile cmp => $FORM;

elm_form RelEdit => $FORM_OUT, $FORM_IN;

TUWF::get qr{/$RREV_RE/(?<type>edit|copy)}, sub {
    my $r = entry r => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    return tuwf->resDenied if !can_edit r => $r;
    my $copy = tuwf->capture('type') eq 'copy';

    enrich vid => q{SELECT id AS vid, title FROM vn WHERE id IN} => $r->{vn};
    enrich pid => q{SELECT id AS pid, name  FROM producers WHERE id IN} => $r->{producers};

    $r->{rtype} = delete $r->{type};
    $r->{authmod} = auth->permDbmod;
    $r->{editsum} = $copy ? "Copied from r$r->{id}.$r->{chrev}" : $r->{chrev} == $r->{maxrev} ? '' : "Reverted to revision r$r->{id}.$r->{chrev}";

    my $title = sprintf '%s %s', $copy ? 'Copy' : 'Edit', $r->{title};
    Framework title => $title,
    top => sub {
        Div class => 'col-md', sub {
            EntryEdit r => $r;
            Div class => 'detail-page-title', sub {
                Txt $title;
                Debug $r;
            };
        };
    }, sub {
        FullPageForm module => 'RelEdit.Main', schema => $FORM_OUT, data => { %$r, $copy ? (id => undef) : () }, sections => [
            general   => 'General info',
            format    => 'Format',
            relations => 'Relations'
        ];
    };
};


TUWF::get qr{/$VID_RE/add}, sub {
    return tuwf->resDenied if !auth->permEdit;

    my $vn = tuwf->dbRowi('SELECT id, title, original FROM vn WHERE NOT hidden AND id =', \tuwf->capture('id'));
    return tuwf->resNotFound if !$vn->{id};

    Framework index => 0, title => "Add a new release to $vn->{title}", narrow => 1, sub {
        FullPageForm module => 'RelEdit.New', data => $vn, sections => [
            general   => 'General info',
            format    => 'Format',
            relations => 'Relations'
        ];
    };
};


json_api qr{/(?:$RID_RE/edit|r/add)}, $FORM_IN, sub {
    my $data = shift;
    my $new = !tuwf->capture('id');
    my $rel = $new ? { id => 0 } : entry r => tuwf->capture('id') or return tuwf->resNotFound;

    return $elm_Unauth->() if !can_edit r => $rel;

    if(!auth->permDbmod) {
        $data->{hidden} = $rel->{hidden}||0;
        $data->{locked} = $rel->{locked}||0;
    }
    $data->{doujin} = $data->{voiced} = $data->{ani_story} = $data->{ani_ero} = 0 if $data->{patch};
    $data->{resolution} = 'unknown' if $data->{patch};
    $data->{uncensored} = 0 if !$data->{minage} || $data->{minage} != 18;
    $_->{qty} = $MEDIUM{$_->{medium}}{qty} ? $_->{qty}||1 : 0 for @{$data->{media}};

    validate_dbid 'SELECT id FROM vn WHERE id IN', map $_->{vid}, @{$data->{vn}};
    validate_dbid 'SELECT id FROM producers WHERE id IN', map $_->{pid}, @{$data->{producers}};

    $data->{notes} = bb_subst_links $data->{notes};

    $rel->{rtype} = delete $rel->{type};
    return $elm_Unchanged() if !$new && !form_changed $FORM_CMP, $data, $rel;
    $data->{type} = delete $data->{rtype};

    my($id,undef,$rev) = update_entry r => $rel->{id}, $data;
    $elm_Changed->($id, $rev);
};

1;
