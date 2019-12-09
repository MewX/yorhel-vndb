
package VNDB::DB::Discussions;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw|dbThreadGet dbPostGet|;


# Options: id, type, iid, results, page, what, asuser, notusers, search, sort, reverse
# What: boards, boardtitles, firstpost, lastpost, poll
# Sort: id lastpost
sub dbThreadGet {
  my($self, %o) = @_;
  $o{results} ||= 50;
  $o{page} ||= 1;
  $o{what} ||= '';

  my @where = (
    $o{id} ? (
      't.id = ?' => $o{id}
    ) : (
      'NOT t.hidden' => 0,
      q{(NOT t.private OR EXISTS(SELECT 1 FROM threads_boards WHERE tid = t.id AND type = 'u' AND iid = ?))} => $o{asuser}
    ),
    $o{type} && !$o{iid} ? (
      'EXISTS(SELECT 1 FROM threads_boards WHERE tid = t.id AND type IN(!l))' => [ ref $o{type} ? $o{type} : [ $o{type} ] ] ) : (),
    $o{type} && $o{iid} ? (
      'tb.type = ?' => $o{type}, 'tb.iid = ?' => $o{iid} ) : (),
    $o{notusers} ? (
      'NOT EXISTS(SELECT 1 FROM threads_boards WHERE type = \'u\' AND tid = t.id)' => 1) : (),
  );

  if($o{search}) {
    for (split /[ -,._]/, $o{search}) {
      s/%//g;
      push @where, 't.title ilike ?', "%$_%" if length($_) > 0;
    }
  }

  my @select = (
    qw|t.id t.title t.count t.locked t.hidden t.private|, 't.poll_question IS NOT NULL AS haspoll',
    $o{what} =~ /lastpost/  ? (q|EXTRACT('epoch' from tpl.date) AS lastpost_date|, VNWeb::DB::sql_user('ul', 'lastpost_')) : (),
    $o{what} =~ /poll/      ? (qw|t.poll_question t.poll_max_options t.poll_preview t.poll_recast|) : (),
  );

  my @join = (
    $o{what} =~ /lastpost/ ? (
      'JOIN threads_posts tpl ON tpl.tid = t.id AND tpl.num = t.count',
      'JOIN users ul ON ul.id = tpl.uid'
    ) : (),
    $o{type} && $o{iid} ?
      'JOIN threads_boards tb ON tb.tid = t.id' : (),
  );

  my $order = sprintf {
    id       => 't.id %s',
    lastpost => 'tpl.date %s',
  }->{ $o{sort}||'id' }, $o{reverse} ? 'DESC' : 'ASC';

  my($r, $np) = $self->dbPage(\%o, q|
    SELECT !s
      FROM threads t
      !s
      !W
      ORDER BY !s|,
    join(', ', @select), join(' ', @join), \@where, $order
  );

  if($o{what} =~ /(boards|boardtitles|poll)/ && $#$r >= 0) {
    my %r = map {
      $r->[$_]{boards} = [];
      $r->[$_]{poll_options} = [];
      ($r->[$_]{id}, $_)
    } 0..$#$r;

    if($o{what} =~ /boards/) {
      push(@{$r->[$r{$_->{tid}}]{boards}}, [ $_->{type}, $_->{iid} ]) for (@{$self->dbAll(q|
        SELECT tid, type, iid
          FROM threads_boards
          WHERE tid IN(!l)|,
        [ keys %r ]
      )});
    }

    if($o{what} =~ /poll/) {
      push(@{$r->[$r{$_->{tid}}]{poll_options}}, [ $_->{id}, $_->{option} ]) for (@{$self->dbAll(q|
        SELECT tid, id, option
          FROM threads_poll_options
          WHERE tid IN(!l)|,
        [ keys %r ]
      )});
    }

    if($o{what} =~ /firstpost/) {
      do { my $idx = $r{ delete $_->{tid} }; $r->[$idx] = { $r->[$idx]->%*, %$_ } } for (@{$self->dbAll(q|
        SELECT tpf.tid, EXTRACT('epoch' from tpf.date) AS firstpost_date, !s
          FROM threads_posts tpf
          JOIN users uf ON tpf.uid = uf.id
          WHERE tpf.num = 1 AND tpf.tid IN(!l)|,
         VNWeb::DB::sql_user('uf', 'firstpost_'), [ keys %r ]
      )});
    }

    if($o{what} =~ /boardtitles/) {
      push(@{$r->[$r{$_->{tid}}]{boards}}, $_) for (@{$self->dbAll(q|
        SELECT tb.tid, tb.type, tb.iid, COALESCE(u.username, v.title, p.name) AS title, COALESCE(u.username, v.original, p.original) AS original
          FROM threads_boards tb
          LEFT JOIN vn v ON tb.type = 'v' AND v.id = tb.iid
          LEFT JOIN producers p ON tb.type = 'p' AND p.id = tb.iid
          LEFT JOIN users u ON tb.type = 'u' AND u.id = tb.iid
          WHERE tb.tid IN(!l)|,
        [ keys %r ]
      )});
    }
  }

  return wantarray ? ($r, $np) : $r;
}


# Options: tid, num, what, uid, mindate, hide, search, type, page, results, sort, reverse
# what: user thread
sub dbPostGet {
  my($self, %o) = @_;
  $o{results} ||= 50;
  $o{page} ||= 1;
  $o{what} ||= '';

  my %where = (
    $o{tid} ? (
      'tp.tid = ?' => $o{tid} ) : (),
    $o{num} ? (
      'tp.num = ?' => $o{num} ) : (),
    $o{uid} ? (
      'tp.uid = ?' => $o{uid} ) : (),
    $o{mindate} ? (
      'tp.date > to_timestamp(?)' => $o{mindate} ) : (),
    $o{hide} ? (
      'tp.hidden = FALSE' => 1 ) : (),
    $o{hide} && $o{what} =~ /thread/ ? (
      't.hidden = FALSE AND t.private = FALSE' => 1 ) : (),
    $o{type} ? (
      'tp.tid IN(SELECT tid FROM threads_boards WHERE type IN(!l))' => [ ref $o{type} ? $o{type} : [ $o{type} ] ] ) : (),
  );

  my @select = (
    qw|tp.tid tp.num tp.hidden|, q|extract('epoch' from tp.date) as date|, q|extract('epoch' from tp.edited) as edited|,
    $o{search} ? () : 'tp.msg',
    $o{what} =~ /user/ ? (VNWeb::DB::sql_user()) : (),
    $o{what} =~ /thread/ ? ('t.title', 't.hidden AS thread_hidden') : (),
  );
  my @join = (
    $o{what} =~ /user/ ? 'JOIN users u ON u.id = tp.uid' : (),
    $o{what} =~ /thread/ ? 'JOIN threads t ON t.id = tp.tid' : (),
  );

  my $order = sprintf {
    num  => 'tp.num %s',
    date => 'tp.date %s',
  }->{ $o{sort}||'num' }, $o{reverse} ? 'DESC' : 'ASC';

  my($r, $np) = $self->dbPage(\%o, q|
    SELECT !s
      FROM threads_posts tp
      !s
      !W
      ORDER BY !s|,
    join(', ', @select), join(' ', @join), \%where, $order
  );

  return wantarray ? ($r, $np) : $r;
}

1;
