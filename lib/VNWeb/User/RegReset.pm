# User registration and password reset. These functions share some common code.
package VNWeb::User::RegReset;

use VNWeb::Prelude;


# Generate some Elm code for the HTML5 validations, the Send and Recv types
# aren't used, they're simple enough to maintain manually.
elm_form RegReset => undef, form_compile(in => {
    email    => { email => 1 },
    password => { password => 1 },
    username => { username => 1 },
    vns      => { uint => 1 },
});


TUWF::get '/u/newpass' => sub {
    return tuwf->resRedirect('/', 'temp') if auth;
    framework_ title => 'Password reset', index => 0, sub {
        elm_ 'User.PassReset';
    };
};


json_api '/u/newpass', {
    email => { email => 1 },
}, sub {
    my $data = shift;

    my($id, $token) = auth->resetpass($data->{email});
    return elm_BadEmail if !$id;

    my $name = tuwf->dbVali('SELECT username FROM users WHERE id =', \$id);
    my $body = sprintf
         "Hello %s,"
        ."\n\n"
        ."Your VNDB.org login has been disabled, you can now set a new password by following the link below:"
        ."\n\n"
        ."%s"
        ."\n\n"
        ."Now don't forget your password again! :-)"
        ."\n\n"
        ."vndb.org",
        $name, tuwf->reqBaseURI()."/u$id/setpass/$token";

    tuwf->mail($body,
      To => $data->{email},
      From => 'VNDB <noreply@vndb.org>',
      Subject => "Password reset for $name",
    );
    elm_Success
};


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
    die "Invalid reset token" if !auth->setpass($id, $token, undef, $data->{password});
    tuwf->dbExeci('UPDATE users SET email_confirmed = true WHERE id =', \$id);
    elm_Success
};


TUWF::get '/u/register', sub {
    return tuwf->resRedirect('/', 'temp') if auth;
    framework_ title => 'Register', index => 0, sub {
        elm_ 'User.Register';
    };
};


json_api '/u/register', {
    username => { username => 1 },
    email    => { email => 1 },
    vns      => { int => 1 },
}, sub {
    my $data = shift;

    my $num = tuwf->dbVali("SELECT count FROM stats_cache WHERE section = 'vn'");
    return elm_Bot         if $data->{vns} < $num*0.995 || $data->{vns} > $num*1.005;
    return elm_Taken       if tuwf->dbVali('SELECT 1 FROM users WHERE username =', \$data->{username});
    return elm_DoubleEmail if tuwf->dbVali(select => sql_func user_emailexists => \$data->{email});

    my $ip = tuwf->reqIP;
    return elm_DoubleIP if tuwf->dbVali(
        q{SELECT 1 FROM users WHERE registered >= NOW()-'1 day'::interval AND ip <<},
        $ip =~ /:/ ? \"$ip/48" : \"$ip/30"
    );

    my $id = tuwf->dbVali('INSERT INTO users', {
        username => $data->{username},
        mail     => $data->{email},
        ip       => $ip,
    }, 'RETURNING id');
    my(undef, $token) = auth->resetpass($data->{email});

    my $body = sprintf
         "Hello %s,"
        ."\n\n"
        ."Someone has registered an account on VNDB.org with your email address. To confirm your registration, follow the link below."
        ."\n\n"
        ."%s"
        ."\n\n"
        ."If you don't remember creating an account on VNDB.org recently, please ignore this e-mail."
        ."\n\n"
        ."vndb.org",
        $data->{username}, tuwf->reqBaseURI()."/u$id/setpass/$token";

    tuwf->mail($body,
        To => $data->{email},
        From => 'VNDB <noreply@vndb.org>',
        Subject => "Confirm registration for $data->{username}",
    );
    elm_Success
};

1;
