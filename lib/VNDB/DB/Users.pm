
package VNDB::DB::Users;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw|
  dbUserGet dbUserDel
  dbNotifyGet dbNotifyMarkRead dbNotifyRemove
  dbThrottleGet dbThrottleSet
|;


# %options->{ username session uid ip registered search results page what sort reverse notperm }
# what: extended
# sort: username registered votes changes tags
sub dbUserGet {
  my $s = shift;
  my %o = (
    page => 1,
    results => 10,
    what => '',
    sort => '',
    @_
  );

  my $token = unpack 'H*', $o{session}||'';
  $o{search} =~ s/%// if $o{search};
  my %where = (
    $o{username} ? (
      'username = ?' => $o{username} ) : (),
    $o{firstchar} ? (
      'SUBSTRING(username from 1 for 1) = ?' => $o{firstchar} ) : (),
    !$o{firstchar} && defined $o{firstchar} ? (
      'ASCII(username) < 97 OR ASCII(username) > 122' => 1 ) : (),
    $o{uid} && !ref($o{uid}) ? (
      'id = ?' => $o{uid} ) : (),
    $o{uid} && ref($o{uid}) ? (
      'id IN(!l)' => [ $o{uid} ]) : (),
    !$o{uid} && !$o{username} ? (
      'id > 0' => 1 ) : (),
    $o{ip} ? (
      'ip !s ?' => [ $o{ip} =~ /\// ? '<<' : '=', $o{ip} ] ) : (),
    $o{registered} ? (
      'registered > to_timestamp(?)' => $o{registered} ) : (),
    $o{search} ? (
      'username ILIKE ?' => "%$o{search}%") : (),
    $token ? (
      q|user_isloggedin(id, decode(?, 'hex')) IS NOT NULL| => $token ) : (),
    $o{notperm} ? (
      'perm & ~(?::smallint) > 0' => $o{notperm} ) : (),
  );

  my @select = (
    qw|id username c_votes c_changes c_tags hide_list|,
    VNWeb::DB::sql_user(), # XXX: This duplicates id and username, but updating all the code isn't going to be easy
    q|extract('epoch' from registered) as registered|,
    $o{what} =~ /extended/ ? qw|perm ign_votes| : (), # mail
    $token ? qq|extract('epoch' from user_isloggedin(id, decode('$token', 'hex'))) as session_lastused| : (),
  );

  my $order = sprintf {
    id => 'u.id %s',
    username => 'u.username %s',
    registered => 'u.registered %s',
    votes => 'u.hide_list, u.c_votes %s',
    changes => 'u.c_changes %s',
    tags => 'u.c_tags %s',
  }->{ $o{sort}||'username' }, $o{reverse} ? 'DESC' : 'ASC';

  my($r, $np) = $s->dbPage(\%o, q|
    SELECT !s
      FROM users u
      !W
      ORDER BY !s|,
    join(', ', @select), \%where, $order
  );

  return wantarray ? ($r, $np) : $r;
}



# uid
sub dbUserDel {
  $_[0]->dbExec(q|DELETE FROM users WHERE id = ?|, $_[1]);
}


# %options->{ uid id what results page reverse }
# what: titles
sub dbNotifyGet {
  my($s, %o) = @_;
  $o{what} ||= '';
  $o{results} ||= 10;
  $o{page} ||= 1;

  my %where = (
    'n.uid = ?' => $o{uid},
    $o{id} ? (
      'n.id = ?' => $o{id} ) : (),
    defined($o{read}) ? (
      'n.read !s' => $o{read} ? 'IS NOT NULL' : 'IS NULL' ) : (),
  );

  my @join = (
    $o{what} =~ /titles/ ? 'LEFT JOIN users u ON n.c_byuser = u.id' : (),
  );

  my @select = (
    qw|n.id n.ntype n.ltype n.iid n.subid|,
    q|extract('epoch' from n.date) as date|,
    q|extract('epoch' from n.read) as read|,
    $o{what} =~ /titles/ ? ('n.c_title', VNWeb::DB::sql_user()) : (),
  );

  my($r, $np) = $s->dbPage(\%o, q|
    SELECT !s
      FROM notifications n
      !s
      !W
      ORDER BY n.id !s
  |, join(', ', @select), join(' ', @join), \%where, $o{reverse} ? 'DESC' : 'ASC');
  return wantarray ? ($r, $np) : $r;
}


# ids
sub dbNotifyMarkRead {
  my $s = shift;
  $s->dbExec('UPDATE notifications SET read = NOW() WHERE id IN(!l)', \@_);
}


# ids
sub dbNotifyRemove {
  my $s = shift;
  $s->dbExec('DELETE FROM notifications WHERE id IN(!l)', \@_);
}


# ip
sub dbThrottleGet {
  my $s = shift;
  my $t = $s->dbRow("SELECT extract('epoch' from timeout) as timeout FROM login_throttle WHERE ip = ?", shift)->{timeout};
  return $t && $t >= time ? $t : time;
}

# ip, timeout
sub dbThrottleSet {
  my($s, $ip, $timeout) = @_;
  !$timeout ? $s->dbExec('DELETE FROM login_throttle WHERE ip = ?', $ip)
   : $s->dbExec('UPDATE login_throttle SET timeout = to_timestamp(?) WHERE ip = ?', $timeout, $ip)
  || $s->dbExec('INSERT INTO login_throttle (ip, timeout) VALUES (?, to_timestamp(?))', $ip, $timeout);
}

1;

