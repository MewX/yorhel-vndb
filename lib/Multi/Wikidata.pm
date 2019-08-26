
#
#  Multi::Wikidata  -  Fetches information from wikidata
#

package Multi::Wikidata;

use strict;
use warnings;
use Multi::Core;
use JSON::XS 'decode_json';
use AnyEvent::HTTP;


my %C = (
  check_timeout  => 30, # Check & fetch for entries to update every 30 seconds
  fetch_number   => 50, # Number of entries to fetch in a single API call
  fetch_interval => 24*3600, # Minimum delay between updates of a single entry
  api_endpoint => 'https://www.wikidata.org/w/api.php',
);


sub run {
  shift;
  $C{ua} = "VNDB.org Crawler (Multi v$VNDB::S{version}; contact\@vndb.org)";
  %C = (%C, @_);

  push_watcher schedule 0, $C{check_timeout}, \&fetch;
}


sub fetch {
  pg_cmd q{
    SELECT id
      FROM wikidata
     WHERE id IN(
              SELECT l_wikidata FROM producers WHERE l_wikidata IS NOT NULL AND NOT hidden
        UNION SELECT l_wikidata FROM staff     WHERE l_wikidata IS NOT NULL AND NOT hidden
        UNION SELECT l_wikidata FROM vn        WHERE l_wikidata IS NOT NULL AND NOT hidden)
       AND (lastfetch IS NULL OR lastfetch < date_trunc('hour', now()-($1 * '1 second'::interval)))
     ORDER BY lastfetch NULLS FIRST
     LIMIT $2
  }, [ $C{fetch_interval}, $C{fetch_number} ], sub {
    my($res) = @_;
    return if pg_expect $res, 1 or !$res->nRows;
    my @ids = map $res->value($_,0), 0..($res->nRows-1);

    my $ids_q = join '|', map "Q$_", @ids;
    my $ts = AE::now;
    http_get "$C{api_endpoint}?action=wbgetentities&format=json&props=sitelinks|claims&sitefilter=enwiki|jawiki&ids=$ids_q",
      'User-Agent' => $C{ua},
      timeout => 60,
      sub { process(\@ids, $ids_q, $ts, @_) }
  }
}


my %props = (
  P856  => [ 'website',            'text'    ],
  P3180 => [ 'vndb',               'text'    ],
  P1933 => [ 'mobygames',          'text'    ],
  P4773 => [ 'mobygames_company',  'text'    ],
  P4769 => [ 'gamefaqs_game',      'integer' ],
  P6182 => [ 'gamefaqs_company',   'integer' ],
  P5646 => [ 'anidb_anime',        'integer' ],
  P5649 => [ 'anidb_person',       'integer' ],
  P1985 => [ 'ann_anime',          'integer' ],
  P1984 => [ 'ann_manga',          'integer' ],
  P434  => [ 'musicbrainz_artist', 'uuid'    ],
  P2002 => [ 'twitter',            'text'    ],
  P5659 => [ 'vgmdb_product',      'integer' ],
  P3435 => [ 'vgmdb_artist',       'integer' ],
  P1953 => [ 'discogs_artist',     'integer' ],
  P7013 => [ 'acdb_char',          'integer' ],
  P7017 => [ 'acdb_source',        'integer' ],
  P6717 => [ 'indiedb_game',       'text'    ],
  P2816 => [ 'howlongtobeat',      'integer' ],
);


sub process {
  my($ids, $ids_q, $ts, $body, $hdr) = @_;

  # Just update lastfetch even if we have some kind of error further on. This
  # makes sure we at least don't get into an error loop on the same entry.
  my $n = 1;
  my $ids_where = join ',', map sprintf('$%d', $n++), @$ids;
  pg_cmd "UPDATE wikidata SET lastfetch = NOW() WHERE id IN($ids_where)", $ids;

  return AE::log warn => "$ids_q Http error: $hdr->{Status} $hdr->{Reason}"
    if $hdr->{Status} !~ /^2/;

  my $data = eval { decode_json $body };
  return AE::log warn => "$ids_q Error decoding JSON: $@" if !$data;

  save($_, $ts, $data->{entities}{"Q$_"}) for @$ids;
}


sub save {
  my($id, $ts, $data) = @_;

  my @set = (     'enwiki = $2',                     'jawiki = $3');
  my @val = ($id, $data->{sitelinks}{enwiki}{title}, $data->{sitelinks}{jawiki}{title});

  for my $p (sort keys %props) {
    my @v;
    for (@{$data->{claims}{$p}}) {
      my $v = $_->{mainsnak}{datavalue}{value};
      if(ref $v) {
        AE::log warn => "Q$id has a non-scalar value for '$p'";
      } elsif($_->{qualifiers}{P582}) {
        AE::log info => "Q$id excluding property '$p' because it has an 'end time'";
      } elsif(defined $v) {
        push @val, $v;
        push @v, sprintf '$%d::%s', scalar @val, $props{$p}[1];
      }
    }

    push @set, @v
      ? sprintf '%s = ARRAY[%s]', $props{$p}[0], join ',', @v
      : "$props{$p}[0] = NULL";
  }

  my $set = join ', ', @set;

  pg_cmd "UPDATE wikidata SET $set WHERE id = \$1", \@val;
  AE::log info => sprintf "Q%d in %.1fs with %d vals", $id, AE::now()-$ts, -1+scalar grep defined($_), @val;
}

1;
