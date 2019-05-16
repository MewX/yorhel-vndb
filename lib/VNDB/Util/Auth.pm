
package VNDB::Util::Auth;


use strict;
use warnings;
use Exporter 'import';
use Digest::SHA qw|sha1 sha1_hex|;
use Crypt::URandom 'urandom';
use Crypt::ScryptKDF 'scrypt_raw';
use Encode 'encode_utf8';
use TUWF ':html';
use VNDB::Func;


our @EXPORT = qw|
  authInit authLogin authLogout authInfo authCan authSetPass authAdminSetPass
  authResetPass authIsValidToken authGetCode authCheckCode authPref
|;


sub randomascii {
  return join '', map chr($_%92+33), unpack 'C*', urandom shift;
}


# Fetches and parses the auth cookie.
# Returns (uid, encrypted_token) on success, (0, '') on failure.
sub parsecookie {
  # Earlier versions of the auth cookie didn't have the dot separator, so that's optional.
  return ($_[0]->reqCookie('auth')||'') =~ /^([a-fA-F0-9]{40})\.?(\d+)$/ ? ($2, sha1 pack 'H*', $1) : (0, '');
}


# initializes authentication information and checks the vndb_auth cookie
sub authInit {
  my $self = shift;

  my($uid, $token_e) = parsecookie($self);
  $self->{_auth} = $uid && $self->dbUserGet(uid => $uid, session => $token_e, what => 'extended notifycount prefs')->[0];
  $self->{_auth}{token} = $token_e if $self->{_auth};

  # update the sessions.lastused column if lastused < now()-'6 hours'
  $self->dbUserUpdateLastUsed($uid, $token_e) if $self->{_auth} && $self->{_auth}{session_lastused} < time()-6*3600;

  # Drop the cookie if it's not valid
  $self->resCookie(auth => undef) if !$self->{_auth} && $self->reqCookie('auth');
}


# login, arguments: user, password, url-to-redirect-to-on-success
# returns 1 on success (redirected), 0 otherwise (no reply sent)
sub authLogin {
  my($self, $user, $pass, $to) = @_;

  return 0 if !$user || !$pass;

  my $d = $self->dbUserGet(username => $user, what => 'scryptargs extended prefs notifycount')->[0];
  return 0 if !$d->{id} || !$d->{scryptargs} || length($d->{scryptargs}) != 14;

  my($N, $r, $p, $salt) = unpack 'NCCa8', $d->{scryptargs};
  my $encpass = _preparepass($self, $pass, $salt, $N, $r, $p);

  return _createsession($self, $d->{id}, $encpass, $to);
}


# Prepares a plaintext password for database storage
# Arguments: pass, optionally: salt, N, r, p
# Returns: encrypted password (as a binary string)
sub _preparepass {
  my($self, $pass, $salt, $N, $r, $p) = @_;
  ($N, $r, $p) = @{$self->{scrypt_args}} if !$N;
  $salt ||= urandom(8);
  return pack 'NCCa8a*', $N, $r, $p, $salt, scrypt_raw(encode_utf8($pass), $self->{scrypt_salt} . $salt, $N, $r, $p, 32);
}


# self, uid, encpass, url-to-redirect-to
sub _createsession {
  my($self, $uid, $encpass, $url) = @_;

  my $token = urandom(20);
  my $token_e = sha1 $token;
  return 0 if !$self->dbUserLogin($uid, $encpass, $token_e);

  $self->resRedirect($url, 'post');
  $self->resCookie(auth => unpack('H*', $token).'.'.$uid, httponly => 1, expires => time + 31536000); # keep the cookie for 1 year
  return $token_e;
}


# clears authentication cookie and redirects to /
sub authLogout {
  my $self = shift;

  my($uid, $token_e) = parsecookie($self);
  $self->dbUserLogout($uid, $token_e) if $uid;

  $self->resRedirect('/', 'temp');
  $self->resCookie(auth => undef);
}


# Replaces the user's password with a random token that can be used to reset the password.
sub authResetPass {
  my $self = shift;
  my $mail = shift;
  my $token = unpack 'H*', urandom(20);
  my $id = $self->dbUserResetPass($mail, sha1(lc($token)));
  return $id ? ($id, $token) : ();
}


# uid, token
sub authIsValidToken {
  $_[0]->dbUserIsValidToken($_[1], sha1(lc($_[2])))
}


# uid, new_pass, url_to_redir_to, 'token'|'pass', $token_or_pass
# Changes the user's password, invalidates all existing sessions, creates a new
# session and redirects.
sub authSetPass {
  my($self, $uid, $pass, $redir, $oldtype, $oldpass) = @_;

  if($oldtype eq 'token') {
    $oldpass = sha1(lc($oldpass));

  } elsif($oldtype eq 'pass') {
    my $u = $self->dbUserGet(uid => $uid, what => 'scryptargs')->[0];
    return 0 if !$u->{id} || !$u->{scryptargs} || length($u->{scryptargs}) != 14;
    my($N, $r, $p, $salt) = unpack 'NCCa8', $u->{scryptargs};
    $oldpass = _preparepass($self, $oldpass, $salt, $N, $r, $p);
  }

  $pass = _preparepass($self, $pass);
  return 0 if !$self->dbUserSetPass($uid, $oldpass, $pass);
  return _createsession($self, $uid, $pass, $redir);
}


sub authAdminSetPass {
  my($self, $uid, $pass) = @_;
  $pass = _preparepass($self, $pass);
  $self->dbUserAdminSetPass($uid, $self->authInfo->{id}, $self->authInfo->{token}, $pass);
}


# returns a hashref with information about the current loggedin user
# the hash is identical to the hash returned by dbUserGet
# returns empty hash if no user is logged in.
sub authInfo {
  return shift->{_auth} || {};
}


# returns whether the currently loggedin or anonymous user can perform
# a certain action. Argument is the action name as defined in global.pl
sub authCan {
  my($self, $act) = @_;
  return $self->{_auth} ? $self->{_auth}{perm} & $self->{permissions}{$act} : 0;
}


# Generate a code to be used later on to validate that the form was indeed
# submitted from our site and by the same user/visitor. Not limited to
# logged-in users.
# Arguments:
#   form-id (string, can be empty, but makes the validation stronger)
#   time (optional, time() to encode in the code)
sub authGetCode {
  my $self = shift;
  my $id = shift;
  my $time = (shift || time)/3600; # accuracy of an hour
  my $uid = encode_utf8($self->{_auth} ? $self->{_auth}{id} : norm_ip($self->reqIP()));
  return lc substr sha1_hex($self->{form_salt} . $uid . encode_utf8($id||'') . pack('N', int $time)), 0, 16;
}


# Validates the correctness of the returned code, creates an error page and
# returns false if it's invalid, returns true otherwise. Codes are valid for at
# least two and at most three hours.
# Arguments:
#   [ form-id, [ code ] ]
# If the code is not given, uses the 'formcode' form parameter instead. If
# form-id is not given, the path of the current requests is used.
sub authCheckCode {
  my $self = shift;
  my $id = shift || $self->reqPath();
  my $code = shift || $self->reqParam('formcode');
  return _incorrectcode($self) if !$code || $code !~ qr/^[0-9a-f]{16}$/;
  my $time = time;
  return 1 if $self->authGetCode($id, $time) eq $code;
  return 1 if $self->authGetCode($id, $time-3600) eq $code;
  return 1 if $self->authGetCode($id, $time-2*3600) eq $code;
  return _incorrectcode($self);
}


sub _incorrectcode {
  my $self = shift;
  $self->resInit;
  $self->htmlHeader(title => 'Validation code expired', noindex => 1);

  div class => 'mainbox';
   h1 'Validation code expired';
   div class => 'warning';
    p 'Please hit the back-button of your browser, refresh the page and try again.';
   end;
  end;

  $self->htmlFooter;
  return 0;
}


sub authPref {
  my($self, $key, $val) = @_;
  my $nfo = $self->authInfo;
  return '' if !$nfo->{id};
  return $nfo->{prefs}{$key}||'' if @_ == 2;
  $nfo->{prefs}{$key} = $val;
  $self->dbUserPrefSet($nfo->{id}, $key, $val);
}

1;

