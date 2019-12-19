package Multi::Denpa;

use strict;
use warnings;
use Multi::Core;
use AnyEvent::HTTP;
use JSON::XS 'decode_json';
use MIME::Base64 'encode_base64';
use VNDB::Config;
use TUWF::Misc 'uri_escape';


my %C = (
  api  => '',
  user => '',
  pass => '',
  clean_timeout => 48*3600,
  check_timeout => 15*60,
);


sub run {
  shift;
  $C{ua} = sprintf 'VNDB.org Affiliate Crawler (Multi v%s; contact@vndb.org)', config->{version};
  %C = (%C, @_);

  push_watcher schedule 0, $C{clean_timeout}, sub {
    pg_cmd 'DELETE FROM shop_denpa WHERE id NOT IN(SELECT l_denpa FROM releases WHERE NOT hidden)';
  };
  push_watcher schedule 0, $C{check_timeout}, sub {
    pg_cmd q{
      INSERT INTO shop_denpa (id)
      SELECT DISTINCT l_denpa
        FROM releases
       WHERE NOT hidden AND l_denpa <> ''
         AND NOT EXISTS(SELECT 1 FROM shop_denpa WHERE id = l_denpa)
    }, [], \&sync
  }
}


sub data {
  my($time, $id, $body, $hdr) = @_;
  my $prefix = sprintf '[%.1fs] %s', $time, $id;
  return AE::log warn => "$prefix ERROR: $hdr->{Status} $hdr->{Reason}" if $hdr->{Status} !~ /^2/;

  my $data = eval { decode_json $body };
  if(!$data) {
    AE::log warn => "$prefix Error decoding JSON: $@";
    return;
  }

  my($prod) = $data->{products}->@*;

  if(!$prod || !$prod->{published_at}) {
    pg_cmd q{UPDATE shop_denpa SET deadsince = COALESCE(deadsince, NOW()), lastfetch = NOW() WHERE id = $1}, [ $id ];
    AE::log info => "$prefix not found.";

  } else {
    my $price = 'US$ '.$prod->{variants}[0]{price};
    $price = 'free' if $price eq 'US$ 0.00';
    pg_cmd 'UPDATE shop_denpa SET deadsince = NULL, lastfetch = NOW(), sku = $2, price = $3 WHERE id = $1',
      [ $prod->{handle}, $prod->{variants}[0]{sku}, $price ];
    AE::log debug => "$prefix for $price at $prod->{variants}[0]{sku}";
  }
}


sub sync {
  pg_cmd 'SELECT id FROM shop_denpa ORDER BY lastfetch ASC NULLS FIRST LIMIT 1', [], sub {
    my($res, $time) = @_;
    return if pg_expect $res, 1 or !$res->nRows;

    my $id = $res->value(0,0);
    my $ts = AE::now;
    my $code = encode_base64("$C{user}:$C{pass}", '');
    http_get $C{api}.'?handle='.uri_escape($id),
      headers => {'User-Agent' => $C{ua}, Authorization => "Basic $code"},
      timeout => 60,
      sub { data(AE::now-$ts, $id, @_) };
  };
}

1;
