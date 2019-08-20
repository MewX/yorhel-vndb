# This package provides a 'tuwf->auth' method and a useful object for dealing
# with VNDB sessions. Usage:
#
#   use VN3::Auth;
#
#   if(auth) {
#     ..user is logged in
#   }
#   ..or:
#   if(tuwf->auth) { .. }
#
#   my $success = auth->login($user, $pass);
#   auth->logout;
#
#   my $uid = auth->uid;
#   my $username = auth->username;
#   my $wants_spoilers = auth->pref('spoilers');
#   ..etc
#
#   die "You're not allowed to post!" if !tuwf->auth->permBoard;
#
package VN3::Auth;

use strict;
use warnings;
use TUWF;
use Exporter 'import';

use Digest::SHA qw|sha1 sha1_hex|;
use Crypt::URandom 'urandom';
use Crypt::ScryptKDF 'scrypt_raw';
use Encode 'encode_utf8';

use VN3::DB;
use VNDBUtil 'norm_ip';

our @EXPORT = ('auth');
sub auth { tuwf->{auth} }


TUWF::hook before => sub {
    my $cookie = tuwf->reqCookie('auth')||'';
    my($uid, $token_e) = $cookie =~ /^([a-fA-F0-9]{40})\.?(\d+)$/ ? ($2, sha1_hex pack 'H*', $1) : (0, '');

    tuwf->{auth} = __PACKAGE__->new();
    tuwf->{auth}->_load_session($uid, $token_e);
    1;
};


TUWF::hook after => sub { tuwf->{auth} = __PACKAGE__->new() };


# log user IDs (necessary for determining performance issues, user preferences
# have a lot of influence in this)
TUWF::set log_format => sub {
    my(undef, $uri, $msg) = @_;
    sprintf "[%s] %s %s: %s\n", scalar localtime(), $uri, auth ? auth->uid : '-', $msg;
};



use overload bool => sub { defined shift->{uid} };

sub uid      { shift->{uid} }
sub username { shift->{username} }
sub perm     { shift->{perm}||0 }
sub token    { shift->{token} }



# The 'perm' field is a bit field, with the following bits.
# The 'usermod' flag is hardcoded in sql/func.sql for the user_* functions.
# Flag 8 was used for 'staffedit', but is now free for re-use.
my %perms = qw{
    board        1
    boardmod     2
    edit         4
    tag         16
    dbmod       32
    tagmod      64
    usermod    128
    affiliate  256
};

sub defaultPerms { $perms{board} + $perms{edit} + $perms{tag} }
sub allPerms     { my $i = 0; $i |= $_ for values %perms; $i }
sub listPerms    { \%perms }


# Create a read-only accessor to check if the current user is authorized to
# perform a particular action.
for my $perm (keys %perms) {
    no strict 'refs';
    *{ "perm".ucfirst($perm) } = sub { (shift->perm() & $perms{$perm}) > 0 }
}


sub _randomascii {
    return join '', map chr($_%92+33), unpack 'C*', urandom shift;
}


# Prepares a plaintext password for database storage
# Arguments: pass, optionally: salt, N, r, p
# Returns: hashed password (hex coded)
sub _preparepass {
    my($self, $pass, $salt, $N, $r, $p) = @_;
    ($N, $r, $p) = @{$self->{scrypt_args}} if !$N;
    $salt ||= urandom(8);
    unpack 'H*', pack 'NCCa8a*', $N, $r, $p, $salt, scrypt_raw(encode_utf8($pass), $self->{scrypt_salt} . $salt, $N, $r, $p, 32);
}


# Hash a password with the same scrypt parameters as the users' current password.
sub _encpass {
    my($self, $uid, $pass) = @_;

    my $args = tuwf->dbVali('SELECT user_getscryptargs(id) FROM users WHERE id =', \$uid);
    return undef if !$args || length($args) != 14;

    my($N, $r, $p, $salt) = unpack 'NCCa8', $args;
    $self->_preparepass($pass, $salt, $N, $r, $p);
}


# Arguments: self, uid, encpass
# Returns: 0 on error, 1 on success
sub _create_session {
    my($self, $uid, $encpass) = @_;

    my $token = urandom 20;
    my $token_db = sha1_hex $token;
    return 0 if !tuwf->dbVali('SELECT ',
        sql_func(user_login => \$uid, sql_fromhex($encpass), sql_fromhex $token_db)
    );

    tuwf->resCookie(auth => unpack('H*', $token).'.'.$uid, httponly => 1, expires => time + 31536000);
    $self->_load_session($uid, $token_db);
    return 1;
}


sub _load_session {
    my($self, $uid, $token_db) = @_;

    my $user = {};
    my %pref = ();
    if($uid) {
        my $loggedin = sql_func(user_isloggedin => 'id', sql_fromhex($token_db));
        $user = tuwf->dbRowi(
            'SELECT id, username, perm, ', sql_totime($loggedin), ' AS lastused',
            'FROM users WHERE id = ', \$uid, 'AND', $loggedin, 'IS NOT NULL'
        );

        # update the sessions.lastused column if lastused < now()-'6 hours'
        tuwf->dbExeci('SELECT', sql_func user_update_lastused => \$user->{id}, sql_fromhex $token_db)
            if $user->{id} && $user->{lastused} < time()-6*3600;
    }

    # Drop the cookie if it's not valid
  	tuwf->resCookie(auth => undef) if !$user->{id} && tuwf->reqCookie('auth');

    $self->{uid}      = $user->{id};
    $self->{username} = $user->{username};
    $self->{perm}     = $user->{perm}||0;
    $self->{token}    = $token_db;
    delete $self->{pref};
}


sub new {
    bless {
        scrypt_salt => 'random string',
        scrypt_args => [ 65536, 8, 1 ],
        %{ tuwf->conf->{auth}||{} }
    }, shift;
}


# Returns 1 on success, 0 on failure
sub login {
    my($self, $user, $pass) = @_;
    return 0 if $self->uid || !$user || !$pass;

    my $uid = tuwf->dbVali('SELECT id FROM users WHERE username =', \$user);
    return 0 if !$uid;
    my $encpass = $self->_encpass($uid, $pass);
    return 0 if !$encpass;
    $self->_create_session($uid, $encpass);
}


sub logout {
    my $self = shift;
    return if !$self->uid;
    tuwf->dbExeci('SELECT', sql_func user_logout => \$self->uid, sql_fromhex $self->{token});
    $self->_load_session();
}


# Replaces the user's password with a random token that can be used to reset
# the password. Returns ($uid, $token) if the email address is found in the DB,
# () otherwise.
sub resetpass {
    my(undef, $mail) = @_;
    my $token = unpack 'H*', urandom(20);
    my $id = tuwf->dbVali(
        select => sql_func(user_resetpass => \$mail, sql_fromhex sha1_hex lc $token)
    );
    return $id ? ($id, $token) : ();
}


# Checks if the password reset token is valid
sub isvalidtoken {
    my(undef, $uid, $token) = @_;
    tuwf->dbVali(
        select => sql_func(user_isvalidtoken => \$uid, sql_fromhex sha1_hex lc $token)
    );
}


# Change the users' password, drop all existing sessions and create a new session.
# Requires either the current password or a reset token.
sub setpass {
    my($self, $uid, $token, $oldpass, $newpass) = @_;

    my $code = $token
        ? sha1_hex lc $token
        : $self->_encpass($uid, $oldpass);
    return if !$code;

    my $encpass = $self->_preparepass($newpass);
    return if !tuwf->dbVali(
        select => sql_func user_setpass => \$uid, sql_fromhex($code), sql_fromhex($encpass)
    );
    $self->_create_session($uid, $encpass);
}


# Generate an CSRF token for this user, also works for anonymous users (albeit
# less secure). The key is only valid for the current hour, tokens for previous
# hours can be generated by passing a negative $hour_offset.
sub csrftoken {
    my($self, $hour_offset) = @_;
    sha1_hex sprintf '%s%s%d',
        $self->{csrf_key} || 'csrf-token',      # Server secret
        $self->{token} || norm_ip(tuwf->reqIP), # User secret
        (time/3600)+($hour_offset||0);          # Time limitation
}


# Returns 1 if the given CSRF token is still valid (meaning: created for this
# user within the past 3 hours), 0 otherwise.
sub csrfcheck {
    my($self, $token) = @_;
    return 1 if $self->csrftoken( 0) eq $token;
    return 1 if $self->csrftoken(-1) eq $token;
    return 1 if $self->csrftoken(-2) eq $token;
    return 0;
}


# Returns a value from 'users_prefs' for the current user. Lazily loads all
# preferences to speed of subsequent calls.
sub pref {
    my($self, $key) = @_;
    return undef if !$self->uid;

    $self->{pref} ||= { map +($_->{key}, $_->{value}), @{ tuwf->dbAlli(
        'SELECT key, value FROM users_prefs WHERE uid =', \$self->uid
    ) } };
    $self->{pref}{$key};
}


sub prefSet {
    my($self, $key, $value, $uid) = @_;
    $uid //= $self->uid;
    if($value) {
        tuwf->dbExeci(
            'INSERT INTO users_prefs', { uid => $uid, key => $key, value => $value },
            'ON CONFLICT (uid,key) DO UPDATE SET', { value => $value }
        );
    } else {
        tuwf->dbExeci('DELETE FROM users_prefs WHERE', { uid => $uid, key => $key });
    }
}


1;