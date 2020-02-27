package VNWeb::Releases::Edit;

use VNWeb::Prelude;


my $FORM = {
    id         => { required => 0, id => 1 },
    title      => { maxlength => 250 },
    original   => { required => 0, default => '', maxlength => 250 },
    rtype      => { enum => \%RELEASE_TYPE },
    patch      => { anybool => 1 },
    freeware   => { anybool => 1 },
    doujin     => { anybool => 1 },
    lang       => { aoh => { lang => { enum => \%LANGUAGE } } },
    platforms  => { aoh => { platform => { enum => \%PLATFORM } } },
    media      => { aoh => {
        medium    => { enum => \%MEDIUM },
        qty       => { uint => 1, range => [0,20] },
    } },
    gtin       => { gtin => 1 },
    catalog    => { required => 0, default => '', maxlength => 50 },
    released   => { rdate => 1 },
    minage     => { int => 1, enum => \%AGE_RATING },
    uncensored => { anybool => 1 },
    resolution => { enum => \%RESOLUTION },
    voiced     => { uint => 1, enum => \%VOICED },
    ani_story  => { uint => 1, enum => \%ANIMATED },
    ani_ero    => { uint => 1, enum => \%ANIMATED },
    website    => { required => 0, default => '', weburl => 1 },
    engine     => { required => 0, default => '', maxlength => 50 },
    extlinks   => validate_extlinks('r'),
    hidden     => { anybool => 1 },
    locked     => { anybool => 1 },

    engines    => { _when => 'out', aoh => {
        engine => {},
        count  => { uint => 1 },
    } },
    authmod    => { _when => 'out', anybool => 1 },
    editsum    => { _when => 'in out', editsum => 1 },
};

my $FORM_OUT = form_compile out => $FORM;
my $FORM_IN  = form_compile in  => $FORM;
my $FORM_CMP = form_compile cmp => $FORM;

sub to_extlinks { $_[0]{extlinks} = { map +($_, delete $_[0]{$_}), grep /^l_/, keys $_[0]->%* } }

TUWF::get qr{/$RE{rrev}/(?<action>edit|copy)} => sub {
    my $e = db_entry r => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    my $copy = tuwf->capture('action') eq 'copy';
    return tuwf->resDenied if !can_edit r => $copy ? {} : $e;

    $e->{rtype} = delete $e->{type};
    $e->{authmod} = auth->permDbmod;
    $e->{editsum} = $e->{chrev} == $e->{maxrev} ? '' : "Reverted to revision r$e->{id}.$e->{chrev}";

    $e->{engines} = tuwf->dbAlli(q{
         SELECT engine, count(*) AS count FROM releases WHERE NOT hidden AND engine <> ''
          GROUP BY engine ORDER BY count(*) DESC, engine
    });
    to_extlinks $e;

    my $title = ($copy ? 'Copy ' : 'Edit ').$e->{title};
    framework_ title => $title, type => 'r', dbobj => $e, tab => tuwf->capture('action'),
    sub {
        editmsg_ r => $e, $title, $copy;
        elm_ 'ReleaseEdit.Main' => $FORM_OUT, $copy ? {%$e, id=>undef} : $e;
    };
};


TUWF::get qr{/$RE{vid}/add}, sub {
    return tuwf->resDenied if !can_edit r => undef;
    # TODO: Auto-fill some fields
    framework_ title => 'Add release',
    sub {
        editmsg_ r => undef, 'Add release';
        elm_ 'ReleaseEdit.New';
    };
};


elm_api ReleaseEdit => $FORM_OUT, $FORM_IN, sub {
    my $data = shift;
    my $new = !$data->{id};
    my $e = $new ? { id => 0 } : db_entry r => $data->{id} or return tuwf->resNotFound;
    return elm_Unauth if !can_edit r => $e;

    if(!auth->permDbmod) {
        $data->{hidden} = $e->{hidden}||0;
        $data->{locked} = $e->{locked}||0;
    }
    $_->{qty} = $MEDIUM{$_->{medium}}{qty} ? $_->{qty}||1 : 0 for $data->{media}->@*;

    to_extlinks $e;
    $e->{rtype} = delete $e->{type};

    return elm_Unchanged if !$new && !form_changed $FORM_CMP, $data, $e;

    $data->{$_} = $data->{extlinks}{$_} for $data->{extlinks}->%*;
    delete $data->{extlinks};
    $data->{type} = delete $data->{rtype};

    my($id,undef,$rev) = db_edit r => $e->{id}, $data;
    elm_Redirect "/r$id.$rev";
};


1;
