package Multi::JList;

use strict;
use warnings;
use Multi::Core;
use AnyEvent::HTTP;
use VNDB::Config;


my %C = (
  jbox  => 'https://www.jbox.com/',
  jlist => 'https://www.jlist.com/',
  clean_timeout => 48*3600,
  check_timeout => 10*60, # Minimum time between fetches.
);


sub run {
  shift;
  $C{ua} = sprintf 'VNDB.org Affiliate Crawler (Multi v%s; contact@vndb.org)', config->{version};
  %C = (%C, @_);

  push_watcher schedule 0, $C{clean_timeout}, sub {
    pg_cmd 'DELETE FROM shop_jlist WHERE id NOT IN(SELECT l_jlist FROM releases WHERE NOT hidden)';
  };
  push_watcher schedule 0, $C{check_timeout}, sub {
    pg_cmd q{
      INSERT INTO shop_jlist (id)
      SELECT DISTINCT l_jlist
        FROM releases
       WHERE NOT hidden AND l_jlist <> ''
         AND NOT EXISTS(SELECT 1 FROM shop_jlist WHERE id = l_jlist)
    }, [], \&sync
  }
}


sub trysite {
  my($jbox, $id) = @_;
  my $ts = AE::now;
  my $url = ($jbox eq 't' ? $C{jbox} : $C{jlist}).$id;
  http_get $url, headers => {'User-Agent' => $C{ua} }, timeout => 60,
    sub { data($jbox, AE::now-$ts, $id, @_) };
}


sub data {
  my($jbox, $time, $id, $body, $hdr) = @_;
  my $prefix = sprintf '[%.1fs] %s', $time, $id;
  return AE::log warn => "$prefix ERROR: $hdr->{Status} $hdr->{Reason}" if $hdr->{Status} !~ /^2/ && $hdr->{Status} ne '404';
  return AE::log warn => "$prefix ERROR: Blocked by StackPath" if $body =~ /StackPath/;

  my $found = $hdr->{Status} ne '404' && $body =~ /fancybox mainProductImage/;
  my $outofstock = $body =~ /<div class="statusBox-detail">[\s\r\n]*Out of stock[\s\r\n]*<\/div>/im;
  my $price = $body =~ /<span class="price"(?: id="product-price-\d+")?>\s*\$(\d+\.\d+)(?:\/\$\d+\.\d+)?\s*<\/span>/ ? sprintf('US$ %.2f', $1) : '';

  return AE::log warn => "$prefix Product found, but no price" if !$price && $found && !$outofstock;

  # Out of stock? Update database.
  if($outofstock) {
    pg_cmd q{UPDATE shop_jlist SET deadsince = NULL, jbox = $2, price = '', lastfetch = NOW() WHERE id = $1}, [ $id, $jbox ];
    AE::log debug => "$prefix is out of stock on jbox=$jbox";

  # We have a price? Update database.
  } elsif($price) {
    pg_cmd q{UPDATE shop_jlist SET deadsince = NULL, jbox = $2, price = $3, lastfetch = NOW() WHERE id = $1}, [ $id, $jbox, $price ];
    AE::log debug => "$prefix for $price on jbox=$jbox";

  # No price or stock info? Try J-List
  } elsif($jbox eq 't') {
    trysite 'f', $id;

  # Nothing at all? Update database.
  } else {
    pg_cmd q{UPDATE shop_jlist SET deadsince = coalesce(deadsince, NOW()), lastfetch = NOW() WHERE id = $1}, [ $id ];
    AE::log info => "$prefix not found on either JBOX or J-List.";
  }
}


sub sync {
  pg_cmd 'SELECT id FROM shop_jlist ORDER BY lastfetch ASC NULLS FIRST LIMIT 1', [], sub {
    my($res, $time) = @_;
    return if pg_expect $res, 1 or !$res->nRows;
    trysite 't', $res->value(0,0);
  };
}
