package VNWeb::User::Login;

use VNWeb::Prelude;


my $LOGIN = form_compile in => {
    username => { username => 1 },
    password => { password => 1 }
};

elm_form UserLogin => $LOGIN, $LOGIN;


TUWF::get '/u/login' => sub {
    return tuwf->resRedirect('/', 'temp') if auth;

    my $ref = tuwf->reqGet('ref');
    $ref = '/' if !$ref || $ref !~ /^\//;

    framework_ title => 'Login', index => 0, sub {
        elm_ 'User.Login' => tuwf->compile({}), $ref;
    };
};


json_api '/u/login', $LOGIN, sub {
    my $data = shift;

    my $ip = norm_ip tuwf->reqIP;
    my $tm = tuwf->dbVali(
        'SELECT', sql_totime('greatest(timeout, now())'), 'FROM login_throttle WHERE ip =', \$ip
    ) || time;
    return elm_LoginThrottle if $tm-time() > config->{login_throttle}[1];

    my $insecure = is_insecurepass $data->{password};
    return $insecure ? elm_InsecurePass : elm_Success
        if auth->login($data->{username}, $data->{password}, $insecure);

    # Failed login, update throttle.
    my $upd = {
        ip      => \$ip,
        timeout => sql_fromtime $tm + config->{login_throttle}[0]
    };
    tuwf->dbExeci('INSERT INTO login_throttle', $upd, 'ON CONFLICT (ip) DO UPDATE SET', $upd);
    elm_BadLogin
};


json_api '/u/changepass', {
    username => { username => 1 },
    oldpass  => { password => 1 },
    newpass  => { password => 1 },
}, sub {
    my $data = shift;
    my $uid = tuwf->dbVali('SELECT id FROM users WHERE username =', \$data->{username});
    die if !$uid;
    return elm_InsecurePass if is_insecurepass $data->{newpass};
    die if !auth->setpass($uid, undef, $data->{oldpass}, $data->{newpass}); # oldpass should already have been verified.
    elm_Success
};


TUWF::post qr{/$RE{uid}/logout}, sub {
    return tuwf->resNotFound if !auth || auth->uid != tuwf->capture('id') || (tuwf->reqPost('csrf')||'') ne auth->csrftoken;
    auth->logout;
    tuwf->resRedirect('/', 'post');
};

1;
