
#
#  Multi::Feed  -  Generates and updates Atom feeds
#

package Multi::Feed;

use strict;
use warnings;
use TUWF::XML;
use Multi::Core;
use POSIX 'strftime';
use VNDB::BBCode;
use VNDB::Config;

my %stats; # key = feed, value = [ count, total, max ]


sub run {
  my $p = shift;
  my %o = (
    regenerate_interval => 600, # 10 min.
    stats_interval => 86400, # daily
    @_
  );
  push_watcher schedule 0, $o{regenerate_interval}, \&generate;
  push_watcher schedule 0, $o{stats_interval}, \&stats;
}


sub generate {
  # announcements
  pg_cmd q{
      SELECT '/'||t.id AS id, t.title, extract('epoch' from tp.date) AS published,
         extract('epoch' from tp.edited) AS updated, u.username, u.id AS uid, tp.msg AS summary
       FROM threads t
       JOIN threads_posts tp ON tp.tid = t.id AND tp.num = 1
       JOIN threads_boards tb ON tb.tid = t.id AND tb.type = 'an'
       LEFT JOIN users u ON u.id = tp.uid
      WHERE NOT t.hidden AND NOT t.private
      ORDER BY t.id DESC
      LIMIT $1},
    [10],
    sub { write_atom(announcements => '/t/an', 'VNDB Site Announcements', @_) };

  # changes
  pg_cmd q{
      SELECT '/'||c.type||COALESCE(v.id, r.id, p.id, ca.id, s.id, d.id)||'.'||c.rev AS id,
         COALESCE(v.title, r.title, p.name, ca.name, sa.name, d.title) AS title, extract('epoch' from c.added) AS updated,
         u.username, u.id AS uid, c.comments AS summary
      FROM changes c
       LEFT JOIN vn v ON c.type = 'v' AND c.itemid = v.id
       LEFT JOIN releases r ON c.type = 'r' AND c.itemid = r.id
       LEFT JOIN producers p ON c.type = 'p' AND c.itemid = p.id
       LEFT JOIN chars ca ON c.type = 'c' AND c.itemid = ca.id
       LEFT JOIN docs d ON c.type = 'd' AND c.itemid = d.id
       LEFT JOIN staff s ON c.type = 's' AND c.itemid = s.id
       LEFT JOIN staff_alias sa ON sa.id = s.id AND sa.aid = s.aid
       JOIN users u ON u.id = c.requester
      WHERE c.requester <> 1
      ORDER BY c.id DESC
      LIMIT $1},
    [25],
    sub { write_atom(changes => '/hist', 'VNDB Recent Changes', @_); };

  # posts
  pg_cmd q{
      SELECT '/'||t.id||'.'||tp.num AS id, t.title||' (#'||tp.num||')' AS title, extract('epoch' from tp.date) AS published,
         extract('epoch' from tp.edited) AS updated, u.username, u.id AS uid, tp.msg AS summary
       FROM threads_posts tp
       JOIN threads t ON t.id = tp.tid
       LEFT JOIN users u ON u.id = tp.uid
      WHERE NOT tp.hidden AND NOT t.hidden AND NOT t.private
      ORDER BY tp.date DESC
      LIMIT $1},
    [25],
    sub { write_atom(posts => '/t', 'VNDB Recent Posts', @_); };
}


sub write_atom {
  my($feed, $path, $title, $res, $sqltime) = @_;
  return if pg_expect $res, 1;

  my $start = AE::time;

  my @r = $res->rowsAsHashes;
  my $updated = 0;
  for(@r) {
    $updated = $_->{published} if $_->{published} && $_->{published} > $updated;
    $updated = $_->{updated} if $_->{updated} && $_->{updated} > $updated;
  }

  my $data;
  my $x = TUWF::XML->new(write => sub { $data .= shift }, pretty => 2);
  $x->xml();
  $x->tag(feed => xmlns => 'http://www.w3.org/2005/Atom', 'xml:lang' => 'en', 'xml:base' => config->{url}.'/');
  $x->tag(title => $title);
  $x->tag(updated => datetime($updated));
  $x->tag(id => config->{url}.$path);
  $x->tag(link => rel => 'self', type => 'application/atom+xml', href => config->{url}."/feeds/$feed.atom", undef);
  $x->tag(link => rel => 'alternate', type => 'text/html', href => config->{url}.$path, undef);

  for(@r) {
    $x->tag('entry');
    $x->tag(id => config->{url}.$_->{id});
    $x->tag(title => $_->{title});
    $x->tag(updated => datetime($_->{updated} || $_->{published}));
    $x->tag(published => datetime($_->{published})) if $_->{published};
    if($_->{username}) {
      $x->tag('author');
      $x->tag(name => $_->{username});
      $x->tag(uri => config->{url}.'/u'.$_->{uid}) if $_->{uid};
      $x->end;
    }
    $x->tag(link => rel => 'alternate', type => 'text/html', href => config->{url}.$_->{id}, undef);
    $x->tag('summary', type => 'html', bb2html $_->{summary}) if $_->{summary};
    $x->end('entry');
  }

  $x->end('feed');

  open my $f, '>:utf8', config->{root}."/www/feeds/$feed.atom" || die $!;
  print $f $data;
  close $f;

  AE::log debug => sprintf 'Wrote %16s.atom (%d entries, sql:%4dms, perl:%4dms)',
    $feed, scalar(@r), $sqltime*1000, (AE::time-$start)*1000;

  my $time = ((AE::time-$start)+$sqltime)*1000;
  $stats{$feed} = [ 0, 0, 0 ] if !$stats{$feed};
  $stats{$feed}[0]++;
  $stats{$feed}[1] += $time;
  $stats{$feed}[2] = $time if $stats{$feed}[2] < $time;
}


sub stats {
  for (keys %stats) {
    my $v = $stats{$_};
    next if !$v->[0];
    AE::log info => sprintf 'Stats summary for %16s.atom: total:%5dms, avg:%4dms, max:%4dms, size: %.1fkB',
      $_, $v->[1], $v->[1]/$v->[0], $v->[2], (-s config->{root}."/www/feeds/$_.atom")/1024;
  }
  %stats = ();
}


sub datetime {
  strftime('%Y-%m-%dT%H:%M:%SZ', gmtime shift);
}


1;

