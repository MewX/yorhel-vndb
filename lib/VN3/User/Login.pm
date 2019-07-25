package VN3::User::Login;

use VN3::Prelude;

# TODO: Redirect to a password change form when a user logs in with an insecure password.

TUWF::get '/u/login' => sub {
    return tuwf->resRedirect('/', 'temp') if auth;
    Framework title => 'Login', center => 1, sub {
        Div 'data-elm-module' => 'User.Login', '';
    };
};


json_api '/u/login', {
    username => { username => 1 },
    password => { password => 1 }
}, sub {
    my $data = shift;

    my $conf = tuwf->conf->{login_throttle} || [ 24*3600/10, 24*3600 ];
    my $ip = norm_ip tuwf->reqIP;

    my $tm = tuwf->dbVali(
        'SELECT', sql_totime('greatest(timeout, now())'), 'FROM login_throttle WHERE ip =', \$ip
    ) || time;

    my $status
        = $tm-time() > $conf->[1] ? 'Throttled'
        : auth->login($data->{username}, $data->{password}) ? 'Success'
        : 'BadLogin';

    # Failed login, update throttle.
    if($status eq 'BadLogin') {
        my $upd = {
            ip      => \$ip,
            timeout => sql_fromtime $tm+$conf->[0]
        };
        tuwf->dbExeci('INSERT INTO login_throttle', $upd, 'ON CONFLICT (ip) DO UPDATE SET', $upd);
    }

    tuwf->resJSON({$status => 1});
};


TUWF::get qr{/$UID_RE/logout}, sub {
    return tuwf->resNotFound if !auth || auth->uid != tuwf->capture('id');
    auth->logout;
    tuwf->resRedirect('/', 'temp');
};

1;
