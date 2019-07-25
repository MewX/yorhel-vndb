# User registration and password reset. These functions share some common code.
package VN3::User::RegReset;

use VN3::Prelude;


TUWF::get '/u/newpass' => sub {
    return tuwf->resRedirect('/', 'temp') if auth;
    Framework title => 'Password reset', center => 1, sub {
        Div 'data-elm-module' => 'User.PassReset', '';
    };
};


json_api '/u/newpass', {
    email => { email => 1 },
}, sub {
    my $data = shift;

    my($id, $token) = auth->resetpass($data->{email});
    return tuwf->resJSON({BadEmail => 1}) if !$id;

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
    tuwf->resJSON({Success => 1});
};


my $reset_url = qr{/$UID_RE/setpass/(?<token>[a-f0-9]{40})};

TUWF::get $reset_url, sub {
    return tuwf->resRedirect('/', 'temp') if auth;

    my $id = tuwf->capture('id');
    my $token = tuwf->capture('token');
    my $name = tuwf->dbVali('SELECT username FROM users WHERE id =', \$id);

    return tuwf->resNotFound if !$name || !auth->isvalidtoken($id, $token);

    Framework title => 'Set password', center => 1, sub {
        Div 'data-elm-module' => 'User.PassSet', 'data-elm-flags' => '"'.tuwf->reqPath().'"', '';
    };
};


json_api $reset_url, {
   pass => { password => 1 },
}, sub {
    my $data = shift;
    my $id = tuwf->capture('id');
    my $token = tuwf->capture('token');

    return tuwf->resJSON({BadPass => 1}) if tuwf->isUnsafePass($data->{pass});
    die "Invalid reset token" if !auth->setpass($id, $token, undef, $data->{pass});
    tuwf->dbExeci('UPDATE users SET email_confirmed = true WHERE id =', \$id);
    tuwf->resJSON({Success => 1});
};


TUWF::get '/u/register', sub {
    return tuwf->resRedirect('/', 'temp') if auth;
    Framework title => 'Register', center => 1, sub {
        Div 'data-elm-module' => 'User.Register', '';
    };
};


json_api '/u/register', {
    username => { username => 1 },
    email    => { email => 1 },
    vns      => { int => 1 },
}, sub {
    my $data = shift;

    my $num = tuwf->dbVali("SELECT count FROM stats_cache WHERE section = 'vn'");
    return tuwf->resJSON({Bot => 1})
        if $data->{vns} < $num*0.995 || $data->{vns} > $num*1.005;
    return tuwf->resJSON({Taken => 1})
        if tuwf->dbVali('SELECT 1 FROM users WHERE username =', \$data->{username});
    return tuwf->resJSON({DoubleEmail => 1})
        if tuwf->dbVali(select => sql_func user_emailexists => \$data->{email});

    my $ip = tuwf->reqIP;
    return tuwf->resJSON({DoubleIP => 1}) if tuwf->dbVali(
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
    tuwf->resJSON({Success => 1});
};

1;
