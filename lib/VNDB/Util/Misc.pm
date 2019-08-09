
package VNDB::Util::Misc;

use strict;
use warnings;
use Exporter 'import';
use TUWF ':html';
use VNDB::Func;
use VNDB::BBCode ();

our @EXPORT = qw|filFetchDB filCompat bbSubstLinks entryLinks|;


our %filfields = (
  vn      => [qw|date_before date_after released length hasani hasshot tag_inc tag_exc taginc tagexc tagspoil lang olang plat staff_inc staff_exc ul_notblack ul_onwish ul_voted ul_onlist|],
  release => [qw|type patch freeware doujin uncensored date_before date_after released minage lang olang resolution plat prod_inc prod_exc med voiced ani_story ani_ero engine|],
  char    => [qw|gender bloodt bust_min bust_max waist_min waist_max hip_min hip_max height_min height_max va_inc va_exc weight_min weight_max trait_inc trait_exc tagspoil role|],
  staff   => [qw|gender role truename lang|],
);


# Arguments:
#   type ('vn', 'release' or 'char'),
#   filter overwrite (string or undef),
#     when defined, these filters will be used instead of the preferences,
#     must point to a variable, will be modified in-place with the actually used filters
#   options to pass to db*Get() before the filters (hashref or undef)
#     these options can be overwritten by the filters or the next option
#   options to pass to db*Get() after the filters (hashref or undef)
#     these options overwrite all other options (pre-options and filters)

sub filFetchDB {
  my($self, $type, $overwrite, $pre, $post) = @_;
  $pre = {} if !$pre;
  $post = {} if !$post;
  my $dbfunc = $self->can($type eq 'vn' ? 'dbVNGet' : $type eq 'release' ? 'dbReleaseGet' : $type eq 'char' ? 'dbCharGet' : 'dbStaffGet');
  my $prefname = 'filter_'.$type;
  my $pref = $self->authPref($prefname);

  my $filters = fil_parse $overwrite // $pref, @{$filfields{$type}};

  # compatibility
  my $compat = $self->filCompat($type, $filters);
  $self->authPref($prefname => fil_serialize $filters) if $compat && !defined $overwrite;

  # write the definite filter string in $overwrite
  $_[2] = fil_serialize({map +(
    exists($post->{$_})    ? ($_ => $post->{$_})    :
    exists($filters->{$_}) ? ($_ => $filters->{$_}) :
    exists($pre->{$_})     ? ($_ => $pre->{$_})     : (),
  ), @{$filfields{$type}}}) if defined $overwrite;

  return $dbfunc->($self, %$pre, %$filters, %$post) if defined $overwrite or !keys %$filters;;

  # since incorrect filters can throw a database error, we have to special-case
  # filters that originate from a preference setting, so that in case these are
  # the cause of an error, they are removed. Not doing this will result in VNDB
  # throwing 500's even for non-browse pages. We have to do some low-level
  # PostgreSQL stuff with savepoints to ensure that an error won't affect our
  # existing transaction.
  my $dbh = $self->dbh;
  $dbh->pg_savepoint('filter');
  my($r, $np);
  my $OK = eval {
    ($r, $np) = $dbfunc->($self, %$pre, %$filters, %$post);
    1;
  };
  $dbh->pg_rollback_to('filter') if !$OK;
  $dbh->pg_release('filter');

  # error occured, let's try again without filters. if that succeeds we know
  # it's the fault of the filter preference, and we should remove it.
  if(!$OK) {
    ($r, $np) = $dbfunc->($self, %$pre, %$post);
    # if we're here, it means the previous function didn't die() (duh!)
    $self->authPref($prefname => '');
    warn sprintf "Reset filter preference for userid %d. Old: %s\n", $self->authInfo->{id}||0, $pref;
  }
  return wantarray ? ($r, $np) : $r;
}


# Compatibility with old filters. Modifies the filter in-place and returns the number of changes made.
sub filCompat {
  my($self, $type, $fil) = @_;
  my $mod = 0;

  # older tag specification (by name rather than ID)
  if($type eq 'vn' && ($fil->{taginc} || $fil->{tagexc})) {
    my $tagfind = sub {
      return map {
        my $i = $self->dbTagGet(name => $_)->[0];
        $i && $i->{searchable} ? $i->{id} : ();
      } grep $_, ref $_[0] ? @{$_[0]} : ($_[0]||'')
    };
    $fil->{tag_inc} //= [ $tagfind->(delete $fil->{taginc}) ] if $fil->{taginc};
    $fil->{tag_exc} //= [ $tagfind->(delete $fil->{tagexc}) ] if $fil->{tagexc};
    $mod++;
  }

  if($type eq 'release' && $fil->{resolution}) {
    $fil->{resolution} = [ map {
      if(/^[0-9]+$/) {
        $mod++;
        (keys %{$self->{resolutions}})[$_] || 'unknown'
      } else { $_ }
    } ref $fil->{resolution} ? @{$fil->{resolution}} : $fil->{resolution} ];
  }

  $mod;
}



sub bbSubstLinks {
  my ($self, $msg) = @_;

  # Parse a message and create an index of links to resolve
  my %lookup;
  VNDB::BBCode::parse $msg, sub {
    my($code, $tag) = @_;
    $lookup{$1}{$2} = 1 if $tag eq 'dblink' && $code =~ /^(.)(\d+)/;
    1;
  };
  return $msg unless %lookup;

  # Now resolve the links
  my %links;
  my @opt = (results => 50);

  if ($lookup{v}) {
    $links{"v$_->{id}"} = $_->{title} for (@{$self->dbVNGet(id => [keys %{$lookup{v}}], @opt)});
  }
  if ($lookup{c}) {
    $links{"c$_->{id}"} = $_->{name} for (@{$self->dbCharGet(id => [keys %{$lookup{c}}], @opt)});
  }
  if ($lookup{p}) {
    $links{"p$_->{id}"} = $_->{name} for (@{$self->dbProducerGet(id => [keys %{$lookup{p}}], @opt)});
  }
  if ($lookup{g}) {
    $links{"g$_->{id}"} = $_->{name} for (@{$self->dbTagGet(id => [keys %{$lookup{g}}], @opt)});
  }
  if ($lookup{i}) {
    $links{"i$_->{id}"} = $_->{name} for (@{$self->dbTraitGet(id => [keys %{$lookup{i}}], @opt)});
  }
  if ($lookup{s}) {
    $links{"s$_->{id}"} = $_->{name} for (@{$self->dbStaffGet(id => [keys %{$lookup{s}}], @opt)});
  }
  return $msg unless %links;

  # Now substitute
  my $result = '';
  VNDB::BBCode::parse $msg, sub {
    my($code, $tag) = @_;
    $result .= $tag eq 'dblink' && $links{$code}
      ? sprintf '[url=/%s]%s[/url]', $code, $links{$code}
      : $code;
    1;
  };
  return $result;
}


# Returns an arrayref of links, each link being [$title, $url]
sub entryLinks {
  my($self, $type, $obj) = @_;
  my $w = $obj->{l_wikidata} ? $self->dbWikidata($obj->{l_wikidata}) : {};

  # Not everything in the wikidata table is actually used, only those links that
  # seem to be directly mappings (i.e. not displaying anime links on VN pages).
  my @links = (
    $w->{enwiki}            ? [ 'Wikipedia (en)', 'https://en.wikipedia.org/wiki/%s', $w->{enwiki} =~ s/ /_/rg ] : (),
    $w->{jawiki}            ? [ 'Wikipedia (ja)', 'https://ja.wikipedia.org/wiki/%s', $w->{jawiki} =~ s/ /_/rg ] : (),
    $obj->{l_wikidata}      ? [ 'Wikidata',       'https://www.wikidata.org/wiki/Q%d', $obj->{l_wikidata} ] : (),

    # VN links
    $type eq 'v' ? (
      $w->{mobygames}         ? [ 'MobyGames',      'https://www.mobygames.com/game/%s', $w->{mobygames} ] : (),
      $w->{gamefaqs_game}     ? [ 'GameFAQs',       'https://gamefaqs.gamespot.com/-/%s-', $w->{gamefaqs_game} ] : (),
      $w->{vgmdb_product}     ? [ 'VGMdb',          'https://vgmdb.net/product/%s', $w->{vgmdb_product} ] : (),
      $w->{acdb_source}       ? [ 'ACDB',           'https://www.animecharactersdatabase.com/source.php?id=%s', $w->{acdb_source} ] : (),
      $w->{indiedb_game}      ? [ 'IndieDB',        'https://www.indiedb.com/games/%s', $w->{indiedb_game} ] : (),
      $w->{howlongtobeat}     ? [ 'HowLongToBeat',  'http://howlongtobeat.com/game.php?id=%s', $w->{howlongtobeat} ] : (),
      $obj->{l_renai}         ? [ 'Renai.us',       'https://renai.us/game/%s', $obj->{l_renai} ] : (),
      $obj->{c_votecount}>=20 ? [ 'VNStat',         'https://vnstat.net/novel/%d', $obj->{id} ] : (),
      #$obj->{l_wp}             ? [ 'Wikipedia', 'http://en.wikipedia.org/wiki/%s', $obj->{l_wp} ] : (), # Superseded by l_wikidata
      #$obj->{l_encubed}        ? [ 'Encubed',   'http://novelnews.net/tag/%s/', $obj->{l_encubed} ] : (), # Seems dead
    ) : (),

    # Staff links
    $type eq 's' ? (
      $obj->{l_site} ?    [ 'Official page', $obj->{l_site} ] : (),
      $obj->{l_twitter} ? [ 'Twitter',       'https://twitter.com/%s', $obj->{l_twitter} ] : (),
      $obj->{l_anidb} ?   [ 'AniDB',         'https://anidb.net/cr%s', $obj->{l_anidb}   ] : (),

      !$obj->{l_anidb}   && $w->{anidb_person} ? [ 'AniDB',   'https://anidb,net/cr%s', $w->{anidb_person} ] : (),
      !$obj->{l_twitter} && $w->{twitter}      ? [ 'Twitter', 'https://twitter.com/%s', $w->{twitter} ] : (),
      $w->{musicbrainz_artist} ? [ 'MusicBrainz',    'https://musicbrainz.org/artist/%s', $w->{musicbrainz_artist} ] : (),
      $w->{vgmdb_artist}       ? [ 'VGMdb',          'https://vgmdb.net/artist/%s', $w->{vgmdb_artist} ] : (),
      $w->{discogs_artist}     ? [ 'Discogs',        'https://www.discogs.com/artist/%s', $w->{discogs_artist} ] : (),

      #$s->{l_wp} ?      [ 'Wikipedia',    "https://en.wikipedia.org/wiki/$s->{l_wp}" ] : (), # Superseded by l_wikidata
    ) : (),

    # Producer links
    $type eq 'p' ? (
      $obj->{website}         ? [ 'Homepage',   $obj->{website} ] : (),
      $w->{mobygames_company} ? [ 'MobyGames', 'https://www.mobygames.com/company/%s', $w->{mobygames_company} ] : (),
      $w->{gamefaqs_company}  ? [ 'GameFAQs',  'https://gamefaqs.gamespot.com/company/%s-', $w->{gamefaqs_company} ] : (),
                                [ 'VNStat',    'https://vnstat.net/developer/%d', $obj->{id} ],

      #$obj->{l_wp} ?      [ 'Wikipedia',    "https://en.wikipedia.org/wiki/$obj->{l_wp}" ] : (), # Superseded by l_wikidata
    ) : (),
  );

  [ map [ $_->[0], $_->[2] ? sprintf $_->[1], $_->[2] : $_->[1] ], @links ];
}

1;

