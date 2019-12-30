package VNWeb::User::Edit;

use VNWeb::Prelude;


my $FORM = form_compile in => {
    username  => { username => 1 },
    email     => { email => 1 },
    perm      => { uint => 1, func => sub { ($_[0] & ~auth->allPerms) == 0 } },
    ign_votes => { anybool => 1 },
    show_nsfw => { anybool => 1 },
    traits_sexual => { anybool => 1 },
    tags_all  => { anybool => 1 },
    tags_cont => { anybool => 1 },
    tags_ero  => { anybool => 1 },
    tags_tech => { anybool => 1 },
    spoilers  => { uint => 1, range => [ 0, 2 ] },
    skin      => { enum => tuwf->{skins} },
    customcss => { required => 0, default => '', maxlength => 2000 },

    nodistract_can     => { anybool => 1 },
    nodistract_noads   => { anybool => 1 },
    nodistract_nofancy => { anybool => 1 },
    support_can     => { anybool => 1 },
    support_enabled => { anybool => 1 },
    uniname_can     => { anybool => 1 },
    uniname         => { required => 0, default => '', regex => qr/^.{2,15}$/ }, # Use regex to check length, HTML5 `maxlength` attribute counts UTF-16 code units...
    pubskin_can     => { anybool => 1 },
    pubskin_enabled => { anybool => 1 },

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


sub _getmail {
    my $uid = shift;
    tuwf->dbVali(select => sql_func user_getmail => \$uid, \auth->uid, sql_fromhex auth->token);
}

TUWF::get qr{/$RE{uid}/edit}, sub {
    my $u = tuwf->dbRowi(q{
        SELECT id, username, perm, ign_votes, show_nsfw, traits_sexual
             , tags_all, tags_cont, tags_ero, tags_tech, spoilers, skin, customcss
             , nodistract_can, nodistract_noads, nodistract_nofancy, support_can, support_enabled, uniname_can, uniname, pubskin_can, pubskin_enabled
          FROM users WHERE id =}, \tuwf->capture('id')
    );

    return tuwf->resNotFound if !$u->{id} || !can_edit u => $u;

    $u->{email} = _getmail $u->{id};
    $u->{authmod} = auth->permUsermod;
    $u->{password} = undef;
    $u->{skin} ||= config->{skin_default};

    # Let's not disclose this (though it's not hard to find out through other means)
    if(!auth->permUsermod) {
        $u->{ign_votes} = 0;
        $u->{perm} = auth->defaultPerms;
    }

    my $title = $u->{id} == auth->uid ? 'My Account' : "Edit $u->{username}";
    framework_ title => $title, type => 'u', dbobj => $u, tab => 'edit',
    sub {
        elm_ 'User.Edit', $FORM, $u;
    };
};


json_api qr{/u/edit\.json}, $FORM, sub {
    my $data = shift;

    my $username = tuwf->dbVali('SELECT username FROM users WHERE id =', \$data->{id});
    return tuwf->resNotFound if !$username;
    return elm_Unauth if !can_edit u => $data;

    return elm_Taken if $data->{uniname}
        && tuwf->dbVali('SELECT 1 FROM users WHERE id <>', \$data->{id}, 'AND username =', \lc($data->{uniname}));

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

    my $ret = \&elm_Success;

    my $oldmail = _getmail $data->{id};
    if($data->{email} ne $oldmail) {
        if(auth->permUsermod) {
            tuwf->dbExeci(select => sql_func user_admin_setmail => \$data->{id}, \auth->uid, sql_fromhex(auth->token), \$data->{email});
        } else {
            return elm_DoubleEmail if tuwf->dbVali(select => sql_func user_emailexists => \$data->{email}, \$data->{id});
            my $token = auth->setmail_token($data->{email});
            my $body = sprintf
                "Hello %s,"
                ."\n\n"
                ."To confirm that you want to change the email address associated with your VNDB.org account from %s to %s, click the link below:"
                ."\n\n"
                ."%s"
                ."\n\n"
                ."vndb.org",
                $username, $oldmail, $data->{email}, tuwf->reqBaseURI()."/u$data->{id}/setmail/$token";

            tuwf->mail($body,
                To => $data->{email},
                From => 'VNDB <noreply@vndb.org>',
                Subject => "Confirm e-mail change for $username",
            );
            $ret = \&elm_MailChange;
        }
    }

    $data->{skin} = '' if $data->{skin} eq config->{skin_default};
    $data->{uniname} = '' if $data->{uniname} eq $data->{username};
    tuwf->dbExeci('UPDATE users SET', { %{$data}{qw/
            show_nsfw traits_sexual tags_all tags_cont tags_ero tags_tech spoilers skin customcss
            nodistract_noads nodistract_nofancy support_enabled uniname pubskin_enabled
        /} },
        'WHERE id =', \$data->{id}
    );

    $ret->();
};


TUWF::get qr{/$RE{uid}/setmail/(?<token>[a-f0-9]{40})}, sub {
    my $success = auth->setmail_confirm(tuwf->capture('id'), tuwf->capture('token'));
    my $title = $success ? 'E-mail confirmed' : 'Error confirming email';
    framework_ title => $title, sub {
        div_ class => 'mainbox', sub {
            h1_ $title;
            div_ class => $success ? 'notice' : 'warning', sub {
                p_ "Your e-mail address has been updated!" if $success;
                p_ "Invalid or expired confirmation link." if !$success;
            };
        };
    };
};

1;
