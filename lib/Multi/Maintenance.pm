
#
#  Multi::Maintenance  -  General maintenance functions
#

package Multi::Maintenance;

use strict;
use warnings;
use Multi::Core;
use PerlIO::gzip;
use VNDBUtil 'normalize_titles';
use VNDB::Config;


my $monthly;


sub run {
  push_watcher schedule 12*3600, 24*3600, \&daily;
  push_watcher schedule 0, 3600, \&vnsearch_check;
  push_watcher pg->listen(vnsearch => on_notify => \&vnsearch_check);
  set_monthly();
}


sub unload {
  undef $monthly;
}


sub set_monthly {
  # Calculate the UNIX timestamp of 12:00 GMT of the first day of the next month.
  # We do this by simply incrementing the timestamp with one day and checking gmtime()
  # for a month change. This might not be very reliable, but should be enough for
  # our purposes.
  my $nextday = int((time+3)/86400+1)*86400 + 12*3600;
  my $thismonth = (gmtime)[5]*100+(gmtime)[4]; # year*100 + month, for easy comparing
  $nextday += 86400 while (gmtime $nextday)[5]*100+(gmtime $nextday)[4] <= $thismonth;
  $monthly = AE::timer $nextday-time(), 0, \&monthly;
}


sub log_res {
  my($id, $res, $time) = @_;
  return if pg_expect $res, undef, $id;
  AE::log info => sprintf 'Finished %s in %.3fs (%d rows)', $id, $time, $res->cmdRows;
}


#
#  D A I L Y   J O B S
#


my %dailies = (
  # takes about 50ms to 500ms to complete, depending on how many releases have been released within the past 5 days
  vncache_inc => q|
    SELECT update_vncache(id)
      FROM (
        SELECT DISTINCT rv.vid
          FROM releases r
          JOIN releases_vn rv ON rv.id = r.id
         WHERE r.released  > TO_CHAR(NOW() - '5 days'::interval, 'YYYYMMDD')::integer
           AND r.released <= TO_CHAR(NOW(), 'YYYYMMDD')::integer
      ) AS r(id)|,

  # takes about 15 seconds max, still OK
  tagcache => 'SELECT tag_vn_calc(NULL)',

  # takes about 25 seconds, OK
  traitcache => 'SELECT traits_chars_calc(NULL)',

  # takes about 4 seconds, OK
  vnstats => 'SELECT update_vnvotestats()',

  # takes a few seconds, need more data and measurements. This query /should/ not be necessary.
  imagecache => 'SELECT update_images_cache(NULL)',

  # should be pretty fast
  cleangraphs => q|
    DELETE FROM relgraphs vg
     WHERE NOT EXISTS(SELECT 1 FROM vn WHERE rgraph = vg.id)
       AND NOT EXISTS(SELECT 1 FROM producers WHERE rgraph = vg.id)|,

  cleansessions      => q|DELETE FROM sessions       WHERE expires    < NOW()|,
  cleannotifications => q|DELETE FROM notifications  WHERE read       < NOW()-'1 month'::interval|,
  cleannotifications2=> q|DELETE FROM notifications  WHERE id IN (
    SELECT id FROM (SELECT id, row_number() OVER (PARTITION BY uid ORDER BY id DESC) > 500 from notifications) AS x(id,del) WHERE x.del)|,
  rmunconfirmusers   => q|DELETE FROM users          WHERE registered < NOW()-'1 week'::interval AND NOT email_confirmed|,
  cleanthrottle      => q|DELETE FROM login_throttle WHERE timeout    < NOW()|,
);


sub run_daily {
  my($d, $sub) = @_;
  pg_cmd $dailies{$d}, undef, sub {
    log_res $d, @_;
    $sub->() if $sub;
  };
}


sub daily {
  my @l = sort keys %dailies;
  my $s; $s = sub {
    run_daily shift(@l), $s if @l;
  };
  $s->();
}




#
#  M O N T H L Y   J O B S
#


my %monthlies = (
  # This only takes about 3 seconds to complete
  vncache_full => 'SELECT update_vncache(id) FROM vn',

  # This shouldn't really be necessary, the triggers in PgSQL should keep
  # these up-to-date nicely. But it takes less than a second, anyway.
  stats_cache  => 'SELECT update_stats_cache_full()',
);


sub logrotate {
  my $dir = sprintf '%s/old', config->{Multi}{Core}{log_dir};
  mkdir $dir if !-d $dir;

  for (glob sprintf '%s/*', config->{Multi}{Core}{log_dir}) {
    next if /^\./ || /~$/ || !-f;
    my $f = /([^\/]+)$/ ? $1 : $_;
    my $n = sprintf '%s/%s.%04d-%02d-%02d.gz', $dir, $f, (localtime)[5]+1900, (localtime)[4]+1, (localtime)[3];
    return if -f $n;
    open my $I, '<', sprintf '%s/%s', config->{Multi}{Core}{log_dir}, $f;
    open my $O, '>:gzip', $n;
    print $O $_ while <$I>;
    close $O;
    close $I;
    open $I, '>', sprintf '%s/%s', config->{Multi}{Core}{log_dir}, $f;
    close $I;
  }
  AE::log info => 'Logs rotated.';
}


sub run_monthly {
  my($d, $sub) = @_;
  pg_cmd $monthlies{$d}, undef, sub {
    log_res $d, @_;
    $sub->() if $sub;
  };
}


sub monthly {
  my @l = sort keys %monthlies;
  my $s; $s = sub {
    run_monthly shift(@l), $s if @l;
  };
  $s->();

  logrotate;
  set_monthly;
}



#
#  V N   S E A R C H   C A C H E
#


sub vnsearch_check {
  pg_cmd 'SELECT id FROM vn WHERE c_search IS NULL LIMIT 1', undef, sub {
    my $res = shift;
    return if pg_expect $res, 1 or !$res->rows;

    my $id = $res->value(0,0);
    pg_cmd q|SELECT title, original, alias FROM vn WHERE id = $1
       UNION SELECT r.title, r.original, NULL FROM releases r JOIN releases_vn rv ON rv.id = r.id WHERE rv.vid = $1 AND NOT r.hidden|,
       [ $id ], sub { vnsearch_update($id, @_) };
  };
}


sub vnsearch_update { # id, res, time
  my($id, $res, $time) = @_;
  return if pg_expect $res, 1;

  my $t = normalize_titles(grep length, map
    +($_->{title}, $_->{original}, split /[\n,]/, $_->{alias}||''),
    $res->rowsAsHashes
  );

  pg_cmd 'UPDATE vn SET c_search = $1 WHERE id = $2', [ $t, $id ], sub {
    my($res, $t2) = @_;
    return if pg_expect $res, 0;
    AE::log info => sprintf 'Updated search cache for v%d (%3dms SQL)', $id, ($time+$t2)*1000;
    vnsearch_check;
  };
}


1;
