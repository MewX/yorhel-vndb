package VNWeb::Releases::Edit;

use VNWeb::Prelude;


my $FORM = {
    id         => { _when => 'cmp in out', required => 0, id => 1 },
    title      => { _when => 'cmp in out new', maxlength => 250 },
    original   => { _when => 'cmp in out new', required => 0, default => '', maxlength => 250 },
    rtype      => { _when => 'cmp in out', enum => \%RELEASE_TYPE },
    patch      => { _when => 'cmp in out', anybool => 1 },
    freeware   => { _when => 'cmp in out', anybool => 1 },
    doujin     => { _when => 'cmp in out', anybool => 1 },
    lang       => { _when => 'cmp in out', aoh => { lang => { enum => \%LANGUAGE } } },
    platforms  => { _when => 'cmp in out', aoh => { platform => { enum => \%PLATFORM } } },
    media      => { _when => 'cmp in out', aoh => {
        medium    => { enum => \%MEDIUM },
        qty       => { uint => 1, range => [0,20] },
    } },
    gtin       => { _when => 'cmp in out', gtin => 1 },
    catalog    => { _when => 'cmp in out', required => 0, default => '', maxlength => 50 },
    released   => { _when => 'cmp in out', min => 1, rdate => 1 },
    minage     => { _when => 'cmp in out', int => 1, enum => \%AGE_RATING },
    uncensored => { _when => 'cmp in out', anybool => 1 },
    resolution => { _when => 'cmp in out', enum => \%RESOLUTION },
    voiced     => { _when => 'cmp in out', uint => 1, enum => \%VOICED },
    ani_story  => { _when => 'cmp in out', uint => 1, enum => \%ANIMATED },
    ani_ero    => { _when => 'cmp in out', uint => 1, enum => \%ANIMATED },
    website    => { _when => 'cmp in out', required => 0, default => '', weburl => 1 },
    engine     => { _when => 'cmp in out', required => 0, default => '', maxlength => 50 },
    extlinks   => { _when => 'cmp in out', validate_extlinks('r')->%* },
    notes      => { _when => 'cmp in out', required => 0, default => '', maxlength => 10240 },
    vn         => { _when => 'cmp in out new', sort_keys => 'vid', aoh => {
        vid    => { id => 1 },
        title  => { _when => 'out new' },
    } },
    producers  => { _when => 'cmp in out', sort_keys => 'pid', aoh => {
        pid       => { id => 1 },
        developer => { anybool => 1 },
        publisher => { anybool => 1 },
        name      => { _when => 'out' },
    } },
    hidden     => { _when => 'cmp in out', anybool => 1 },
    locked     => { _when => 'cmp in out', anybool => 1 },

    engines    => { _when => 'out new', aoh => {
        engine => {},
        count  => { uint => 1 },
    } },
    authmod    => { _when => 'out', anybool => 1 },
    editsum    => { _when => 'in out', editsum => 1 },
};

my $FORM_OUT = form_compile out => $FORM;
my $FORM_IN  = form_compile in  => $FORM;
my $FORM_NEW = form_compile new => $FORM;
my $FORM_CMP = form_compile cmp => $FORM;

sub to_extlinks { $_[0]{extlinks} = { map +($_, delete $_[0]{$_}), grep /^l_/, keys $_[0]->%* } }

sub engines {
    tuwf->dbAlli(q{
         SELECT engine, count(*) AS count FROM releases WHERE NOT hidden AND engine <> ''
          GROUP BY engine ORDER BY count(*) DESC, engine
    })
}

TUWF::get qr{/$RE{rrev}/(?<action>edit|copy)} => sub {
    my $e = db_entry r => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    my $copy = tuwf->capture('action') eq 'copy';
    return tuwf->resDenied if !can_edit r => $copy ? {} : $e;

    $e->{rtype} = delete $e->{type};
    $e->{authmod} = auth->permDbmod;
    $e->{editsum} = $copy ? "Copied from r$e->{id}.$e->{chrev}" : $e->{chrev} == $e->{maxrev} ? '' : "Reverted to revision r$e->{id}.$e->{chrev}";

    $e->{engines} = engines;
    to_extlinks $e;

    enrich_merge vid => 'SELECT id AS vid, title FROM vn WHERE id IN', $e->{vn};
    enrich_merge pid => 'SELECT id AS pid, name FROM producers WHERE id IN', $e->{producers};

    my $title = ($copy ? 'Copy ' : 'Edit ').$e->{title};
    framework_ title => $title, type => 'r', dbobj => $e, tab => tuwf->capture('action'),
    sub {
        editmsg_ r => $e, $title, $copy;
        elm_ 'ReleaseEdit.Main' => $FORM_OUT, $copy ? {%$e, id=>undef} : $e;
    };
};


TUWF::get qr{/$RE{vid}/add}, sub {
    return tuwf->resDenied if !can_edit r => undef;
    my $v = tuwf->dbRowi('SELECT id, title, original FROM vn WHERE id =', \tuwf->capture('id'));
    return tuwf->resNotFound if !$v->{id};

    my $delrel = tuwf->dbAlli('SELECT r.id, r.title, r.original FROM releases r JOIN releases_vn rv ON rv.id = r.id WHERE r.hidden AND rv.vid =', \$v->{id}, 'ORDER BY id');
    enrich_flatten languages => id => id => 'SELECT id, lang FROM releases_lang WHERE id IN', $delrel;

    framework_ title => "Add release to $v->{title}",
    sub {
        editmsg_ r => undef, "Add release to $v->{title}";

        div_ class => 'mainbox', sub {
            h1_ 'Deleted releases';
            div_ class => 'warning', sub {
                p_ q{This visual novel has releases that have been deleted
                    before. Please review this list to make sure you're not
                    adding a release that has already been deleted.};
                br_;
                ul_ sub {
                    li_ sub {
                        txt_ '['.join(',', $_->{languages}->@*)."] r$_->{id}:";
                        a_ href => "/r$_->{id}", title => $_->{original}||$_->{title}, $_->{title};
                    } for @$delrel;
                }
            }
        } if @$delrel;

        elm_ 'ReleaseEdit.New' => $FORM_NEW, {
            title    => $v->{title},
            original => $v->{original},
            engines  => engines(),
            authmod  => auth->permDbmod(),
            vn       => [{vid => $v->{id}, title => $v->{title}}],
        };
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
    $data->{doujin} = $data->{voiced} = $data->{ani_story} = $data->{ani_ero} = 0 if $data->{patch};
    $data->{resolution} = 'unknown' if $data->{patch};
    $data->{uncensored} = 0 if $data->{minage} != 18;
    $_->{qty} = $MEDIUM{$_->{medium}}{qty} ? $_->{qty}||1 : 0 for $data->{media}->@*;
    $data->{notes} = bb_subst_links $data->{notes};
    die "No VNs selected" if !$data->{vn}->@*;

    to_extlinks $e;
    $e->{rtype} = delete $e->{type};

    return elm_Unchanged if !$new && !form_changed $FORM_CMP, $data, $e;

    $data->{$_} = $data->{extlinks}{$_} for $data->{extlinks}->%*;
    delete $data->{extlinks};
    $data->{type} = delete $data->{rtype};

    my($id,undef,$rev) = db_edit r => $e->{id}, $data;
    elm_Redirect "/r$id.$rev";
}, New => $FORM_NEW;


1;
