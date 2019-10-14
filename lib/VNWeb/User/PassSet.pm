package VNWeb::User::PassSet;

use VNWeb::Prelude;


# Compatibility with old the URL format
TUWF::get qr{/$RE{uid}/setpass}, sub { tuwf->resRedirect(sprintf('/u%d/setpass/%s', tuwf->capture('id'), tuwf->reqGet('t')||''), 'temp') };


my $reset_url = qr{/$RE{uid}/setpass/(?<token>[a-f0-9]{40})};

TUWF::get $reset_url, sub {
    return tuwf->resRedirect('/', 'temp') if auth;

    my $id = tuwf->capture('id');
    my $token = tuwf->capture('token');
    my $name = tuwf->dbVali('SELECT username FROM users WHERE id =', \$id);

    return tuwf->resNotFound if !$name || !auth->isvalidtoken($id, $token);

    framework_ title => 'Set password', index => 0, sub {
        elm_ 'User.PassSet', tuwf->compile({}), tuwf->reqPath;
    };
};


json_api $reset_url, {
   password => { password => 1 },
}, sub {
    my $data = shift;
    my $id = tuwf->capture('id');
    my $token = tuwf->capture('token');

    return elm_InsecurePass if is_insecurepass($data->{password});
    # "CSRF" is kind of wrong here, but the message advices to reload the page,
    # which will give a 404, which should be a good enough indication that the
    # token has expired. This case won't happen often.
    return elm_CSRF if !auth->setpass($id, $token, undef, $data->{password});
    tuwf->dbExeci('UPDATE users SET email_confirmed = true WHERE id =', \$id);
    elm_Success
};

1;
