package VNWeb::User::Edit;

use VNWeb::Prelude;


my $FORM = form_compile in => {
    username  => { username => 1 },
    email     => { email => 1 },
    perm      => { uint => 1, func => sub { ($_[0] & ~auth->allPerms) == 0 } },
    ign_votes => { anybool => 1 },
    hide_list => { anybool => 1 },
    show_nsfw => { anybool => 1 },
    traits_sexual => { anybool => 1 },
    tags_all  => { anybool => 1 },
    tags_cont => { anybool => 1 },
    tags_ero  => { anybool => 1 },
    tags_tech => { anybool => 1 },
    spoilers  => { uint => 1, range => [ 0, 2 ] },
    skin      => { enum => tuwf->{skins} },
    customcss => { required => 0, default => '', maxlength => 2000 },

    password  => { _when => 'in', required => 0, type => 'hash', keys => {
        old   => { password => 1 },
        new   => { password => 1 }
    } },

    id        => { uint => 1 },
    # This is technically only used for Perl->Elm data, but also received from
    # Elm in order to make the Send and Recv types equivalent.
    authmod   => { anybool => 1 },
};

# Some validations in this form are also used by other User.* Elm modules.
elm_form UserEdit => undef, $FORM;


TUWF::get qr{/$RE{uid}/edit}, sub {
    my $u = tuwf->dbRowi('SELECT id, username, perm, ign_votes FROM users WHERE id =', \tuwf->capture('id'));

    return tuwf->resNotFound if !can_edit u => $u;

    $u->{email} = tuwf->dbVali(select => sql_func user_getmail => \$u->{id}, \auth->uid, sql_fromhex auth->token);
    $u->{authmod} = auth->permUsermod;
    $u->{password} = undef;

    # Let's not disclose this (though it's not hard to find out through other means)
    if(!auth->permUsermod) {
        $u->{ign_votes} = 0;
        $u->{perm} = auth->defaultPerms;
    }

    my $prefs = { map +($_->{key}, $_->{value}), @{ tuwf->dbAlli('SELECT key, value FROM users_prefs WHERE uid =', \$u->{id}) }};
    $u->{$_} = $prefs->{$_}||'' for qw/hide_list show_nsfw traits_sexual tags_all spoilers skin customcss/;
    $u->{spoilers} ||= 0;
    $u->{skin} ||= config->{skin_default};
    $u->{"tags_$_"} = (($prefs->{tags_cat}||'cont,tech') =~ /$_/) for qw/cont ero tech/;

    my $title = $u->{id} == auth->uid ? 'My Account' : "Edit $u->{username}";
    framework_ title => $title, index => 0, type => 'u', dbobj => $u, tab => 'edit',
    sub {
        elm_ 'User.Edit', $FORM, $u;
    };
};


json_api qr{/u/edit}, $FORM, sub {
    my $data = shift;

    return elm_Unauth if !can_edit u => $data;

    if(auth->permUsermod) {
        tuwf->dbExeci(update => users => set => {
            username  => $data->{username},
            ign_votes => $data->{ign_votes},
            email_confirmed => 1,
        }, where => { id => $data->{id} });
        tuwf->dbExeci(select => sql_func user_setperm => \$data->{id}, \auth->uid, sql_fromhex(auth->token), \$data->{perm});
    }

    if($data->{password}) {
        return elm_InsecurePass if is_insecurepass $data->{password}{new};

        if(auth->uid == $data->{id}) {
            return elm_BadCurPass if !auth->setpass($data->{id}, undef, $data->{password}{old}, $data->{password}{new});
        } else {
            tuwf->dbExeci(select => sql_func user_admin_setpass => \$data->{id}, \auth->uid,
                sql_fromhex(auth->token), sql_fromhex auth->_preparepass($data->{password}{new})
            );
        }
    }

    tuwf->dbExeci(select => sql_func user_setmail => \$data->{id}, \auth->uid, sql_fromhex(auth->token), \$data->{email});

    $data->{skin} = '' if $data->{skin} eq config->{skin_default};
    auth->prefSet($_, $data->{$_}, $data->{id}) for qw/hide_list show_nsfw traits_sexual tags_all spoilers skin customcss/;
    auth->prefSet(tags_cat => join(',', map $data->{"tags_$_"} ? $_ : (), qw/cont ero tech/), $data->{id});

    elm_Success
};

1;
