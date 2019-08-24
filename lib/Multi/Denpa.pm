package Multi::Denpa;

use strict;
use warnings;
use Multi::Core;
use AnyEvent::HTTP;
use JSON::XS 'decode_json';
use MIME::Base64 'encode_base64';


my %C = (
  api  => '',
  user => '',
  pass => '',
  check_timeout => 24*3600,
);


sub run {
  shift;
  $C{ua} = "VNDB.org Affiliate Crawler (Multi v$VNDB::S{version}; contact\@vndb.org)";
  %C = (%C, @_);

  push_watcher schedule 0, $C{check_timeout}, sub {
    pg_cmd 'DELETE FROM shop_denpa WHERE id NOT IN(SELECT l_denpa FROM releases WHERE NOT hidden)', [], sub {
      pg_cmd q{
        INSERT INTO shop_denpa (id)
        SELECT DISTINCT l_denpa
          FROM releases
         WHERE NOT hidden AND l_denpa <> ''
           AND NOT EXISTS(SELECT 1 FROM shop_denpa WHERE id = l_denpa)
      }, [], \&sync
    }
  }
}


sub sync {
  pg_cmd 'SELECT id FROM shop_denpa', [],
  sub {
    my($res, $time) = @_;
    return if pg_expect $res, 1 or !$res->nRows;

    my %handles = map +($res->value($_,0), 1), 0..($res->nRows-1);

    my $code = encode_base64("$C{user}:$C{pass}", '');
    http_get $C{api},
      headers => {'User-Agent' => $C{ua}, Authorization => "Basic $code"},
      timeout => 60,
      sub { data(\%handles, @_) };
  };
}


sub data {
  my($handles, $body, $hdr) = @_;

  return AE::log warn => "ERROR: $hdr->{Status} $hdr->{Reason}" if $hdr->{Status} !~ /^2/;
  my $data = eval { decode_json $body };
  if(!$data) {
    AE::log warn => "Error decoding JSON: $@";
    return;
  }
  AE::log warn => 'Close to result limit, may need to add pagination support' if @{$data->{products}} >= 240;

  my $db_count = keys %$handles;

  for my $prod (@{$data->{products}}) {
    next if !$prod->{published_at};

    if(!$handles->{$prod->{handle}}) {
      AE::log info => 'Handle not in vndb: https://denpasoft.com/products/%s', $prod->{handle};
      next;
    }
    my $price = 'US$ '.$prod->{variants}[0]{price};
    $price = 'free' if $price eq 'US$ 0.00';
    pg_cmd 'UPDATE shop_denpa SET found = TRUE, lastfetch = NOW(), sku = $2, price = $3 WHERE id = $1',
      [ $prod->{handle}, $prod->{variants}[0]{sku}, $price ];

    delete $handles->{$prod->{handle}};
  }

  pg_cmd 'UPDATE shop_denpa SET found = FALSE, lastfetch = NOW() WHERE id = $1', [$_]
    for (keys %$handles);

  AE::log info => "%d in shop, %d online, %d offline", scalar @{$data->{products}}, $db_count-scalar keys %$handles, scalar keys %$handles;
}
