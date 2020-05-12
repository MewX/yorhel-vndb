package VNWeb::Chars::Edit;

use VNWeb::Prelude;


my $FORM = {
    id         => { required => 0, id => 1 },
    name       => { maxlength => 200 },
    original   => { required => 0, default => '', maxlength => 200 },
    alias      => { required => 0, default => '', maxlength => 500 },
    desc       => { required => 0, default => '', maxlength => 5000 },
    gender     => { default => 'unknown', enum => \%GENDER },
    b_month    => { required => 0, default => 0, uint => 1, range => [ 0, 12 ] },
    b_day      => { required => 0, default => 0, uint => 1, range => [ 0, 31 ] },
    age        => { required => 0, uint => 1, range => [ 0, 32767 ] },
    s_bust     => { required => 0, uint => 1, range => [ 0, 32767 ], default => 0 },
    s_waist    => { required => 0, uint => 1, range => [ 0, 32767 ], default => 0 },
    s_hip      => { required => 0, uint => 1, range => [ 0, 32767 ], default => 0 },
    height     => { required => 0, uint => 1, range => [ 0, 32767 ], default => 0 },
    weight     => { required => 0, uint => 1, range => [ 0, 32767 ] },
    bloodt     => { default => 'unknown', enum => \%BLOOD_TYPE },
    cup_size   => { required => 0, default => '', enum => \%CUP_SIZE },
    main       => { required => 0, id => 1 },
    main_ref   => { _when => 'out', anybool => 1 },
    main_name  => { _when => 'out', default => '' },
    image      => { required => 0, regex => qr/ch[1-9][0-9]{0,6}/ },
    hidden     => { anybool => 1 },
    locked     => { anybool => 1 },

    authmod    => { _when => 'out', anybool => 1 },
    editsum    => { _when => 'in out', editsum => 1 },
};

my $FORM_OUT = form_compile out => $FORM;
my $FORM_IN  = form_compile in  => $FORM;
my $FORM_CMP = form_compile cmp => $FORM;


TUWF::get qr{/$RE{crev}/edit} => sub {
    my $e = db_entry c => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    return tuwf->resDenied if !can_edit c => $e;

    $e->{main_name} = $e->{main} ? tuwf->dbVali('SELECT name FROM chars WHERE id =', \$e->{main}) : '';
    $e->{main_ref} = tuwf->dbVali('SELECT 1 FROM chars WHERE main =', \$e->{id})||0;

    $e->{authmod} = auth->permDbmod;
    $e->{editsum} = $e->{chrev} == $e->{maxrev} ? '' : "Reverted to revision c$e->{id}.$e->{chrev}";

    framework_ title => "Edit $e->{name}", type => 'c', dbobj => $e, tab => 'edit',
    sub {
        editmsg_ c => $e, "Edit $e->{name}";
        elm_ CharEdit => $FORM_OUT, $e;
    };
};


# XXX: Require VN
# TODO: Copy.
TUWF::get qr{/c/new}, sub {
    return tuwf->resDenied if !can_edit c => undef;
    framework_ title => 'Add character',
    sub {
        editmsg_ c => undef, 'Add character';
        elm_ CharEdit => $FORM_OUT, {
            elm_empty($FORM_OUT)->%*,
        };
    };
};


elm_api CharEdit => $FORM_OUT, $FORM_IN, sub {
    my $data = shift;
    my $new = !$data->{id};
    my $e = $new ? { id => 0 } : db_entry c => $data->{id} or return tuwf->resNotFound;
    return elm_Unauth if !can_edit c => $e;

    if(!auth->permDbmod) {
        $data->{hidden} = $e->{hidden}||0;
        $data->{locked} = $e->{locked}||0;
    }
    $data->{desc} = bb_subst_links $data->{desc};
    $data->{b_day} = 0 if !$data->{b_month};

    $data->{main} = undef if $data->{hidden};
    die "Attempt to set main to self" if $data->{main} && $data->{main} == $e->{id};
    die "Attempt to set main while this character is already referenced." if $data->{main} && tuwf->dbVali('SELECT 1 AS ref FROM chars WHERE main =', \$e->{id});
    # It's possible that the referenced character has been deleted since it was added as main, so don't die() on this one, just unset main.
    $data->{main} = undef if $data->{main} && !tuwf->dbVali('SELECT 1 FROM chars WHERE NOT hidden AND main IS NULL AND id =', \$data->{main});

    return elm_Unchanged if !$new && !form_changed $FORM_CMP, $data, $e;
    my($id,undef,$rev) = db_edit c => $e->{id}, $data;
    elm_Redirect "/c$id.$rev";
};

1;
