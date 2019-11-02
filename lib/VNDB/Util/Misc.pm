
package VNDB::Util::Misc;

use strict;
use warnings;
use Exporter 'import';
use TUWF ':html';
use VNDB::Func;
use VNDB::Types;
use VNDB::BBCode;

our @EXPORT = qw|filFetchDB filCompat bbSubstLinks entryLinks|;


our %filfields = (
  vn      => [qw|date_before date_after released length hasani hasshot tag_inc tag_exc taginc tagexc tagspoil lang olang plat staff_inc staff_exc ul_notblack ul_onwish ul_voted ul_onlist|],
  release => [qw|type patch freeware doujin uncensored date_before date_after released minage lang olang resolution plat prod_inc prod_exc med voiced ani_story ani_ero engine|],
  char    => [qw|gender bloodt bust_min bust_max waist_min waist_max hip_min hip_max height_min height_max va_inc va_exc weight_min weight_max cup_min cup_max trait_inc trait_exc tagspoil role|],
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
        (keys %RESOLUTION)[$_] || 'unknown'
      } else { $_ }
    } ref $fil->{resolution} ? @{$fil->{resolution}} : $fil->{resolution} ];
  }

  $mod;
}



sub bbSubstLinks {
  shift; bb_subst_links @_;
}



# Returns an arrayref of links, each link being [$title, $url, $price]
sub entryLinks {
  my($self, $type, $obj) = @_;
  my $w = $obj->{l_wikidata} ? $self->dbWikidata($obj->{l_wikidata}) : {};

  my @links;
  my $lnk = sub {
    my($v, $title, $url, $xform, $price) = @_;
    push @links, map [ $title, sprintf($url, $xform ? $xform->($_) : $_), $price ], ref $v ? @$v : $v ? ($v) : ();
  };

  $lnk->($obj->{l_site},      'Official website',  '%s'); # (staff) Homepage always comes first
  $lnk->($obj->{website},     'Official website',  '%s'); # (producers, releases)
  $lnk->($w->{enwiki},        'Wikipedia (en)',    'https://en.wikipedia.org/wiki/%s', sub { (shift =~ s/ /_/rg) =~ s/\?/%3f/rg });
  $lnk->($w->{jawiki},        'Wikipedia (ja)',    'https://ja.wikipedia.org/wiki/%s', sub { (shift =~ s/ /_/rg) =~ s/\?/%3f/rg });
  $lnk->($obj->{l_wikidata},  'Wikidata',          'https://www.wikidata.org/wiki/Q%d');

  # Not everything in the wikidata table is actually used, only those links that
  # seem to be directly mappings (i.e. not displaying anime links on VN pages).

  # VN links
  if($type eq 'v') {
    $lnk->($w->{mobygames},     'MobyGames',      'https://www.mobygames.com/game/%s');
    $lnk->($w->{gamefaqs_game}, 'GameFAQs',       'https://gamefaqs.gamespot.com/-/%s-');
    $lnk->($w->{vgmdb_product}, 'VGMdb',          'https://vgmdb.net/product/%s');
    $lnk->($w->{acdb_source},   'ACDB',           'https://www.animecharactersdatabase.com/source.php?id=%s');
    $lnk->($w->{indiedb_game},  'IndieDB',        'https://www.indiedb.com/games/%s');
    $lnk->($w->{howlongtobeat}, 'HowLongToBeat',  'http://howlongtobeat.com/game.php?id=%s');
    $lnk->($w->{igdb_game},     'IGDB',           'https://www.igdb.com/games/%s');
    $lnk->($obj->{l_renai},     'Renai.us',       'https://renai.us/game/%s');
    push @links, [ 'VNStat', sprintf 'https://vnstat.net/novel/%d', $obj->{id} ] if $obj->{c_votecount}>=20;
  }

  # Release links
  if($type eq 'r') {
    $lnk->($obj->{l_egs},      'ErogameScape', 'https://erogamescape.dyndns.org/~ap2/ero/toukei_kaiseki/game.php?game=%d');
    $lnk->($obj->{l_erotrail}, 'ErogeTrailers','http://erogetrailers.com/soft/%d');
    $lnk->($obj->{l_steam},    'Steam',       'https://store.steampowered.com/app/%d/');
    $lnk->($obj->{l_steam},    'SteamDB',     'https://steamdb.info/app/%d/info');
    $lnk->($obj->{l_dlsite},   'DLsite (jpn)',sprintf($self->{dlsite_url}, $obj->{l_dlsite_shop}||'home'), undef, $obj->{l_dlsite_price});
    $lnk->($obj->{l_dlsiteen}, 'DLsite (eng)',sprintf($self->{dlsite_url}, $obj->{l_dlsiteen_shop}||'eng'), undef, $obj->{l_dlsiteen_price});
    $lnk->($obj->{l_gog},      'GOG',         'https://www.gog.com/game/%s');
    $lnk->($obj->{l_itch},     'Itch.io',     'https://%s');
    $lnk->($obj->{l_denpa},    'Denpasoft',   $self->{denpa_url}, undef, $obj->{l_denpa_price});
    $lnk->($obj->{l_jlist},    $obj->{l_jlist_jbox} ? 'JBOX' : 'J-List', $self->{ $obj->{l_jlist_jbox} ? 'jbox_url' : 'jlist_url' }, undef, $obj->{l_jlist_price});
    $lnk->($obj->{l_jastusa},  'JAST USA',    'https://jastusa.com/%s');
    $lnk->($obj->{l_gyutto},   'Gyutto',      'https://gyutto.com/i/item%d');
    $lnk->($obj->{l_digiket},  'Digiket',     'https://www.digiket.com/work/show/_data/ID=ITM%07d/');
    $lnk->($obj->{l_melon},    'Melonbooks',  'https://www.melonbooks.com/index.php?main_page=product_info&products_id=IT%010d');
    $lnk->($obj->{l_mg},       'MangaGamer',  !defined($obj->{l_mg_r18}) || $obj->{l_mg_r18} ? $self->{mg_r18_url} : $self->{mg_main_url}, undef, $obj->{l_mg_price});
    $lnk->($obj->{l_getchu},   'Getchu',      'http://www.getchu.com/soft.phtml?id=%d');
    $lnk->($obj->{l_getchudl}, 'DL.Getchu',   'http://dl.getchu.com/i/item%d');
    $lnk->($obj->{l_dmm},      'DMM',         'https://%s');
    push @links, map [ 'PlayAsia', $_->{url}, $_->{price} ], @{$obj->{l_playasia}} if $obj->{l_playasia};
  }

  # Staff links
  if($type eq 's') {
    $lnk->($obj->{l_twitter},        'Twitter',      'https://twitter.com/%s');
    $lnk->($w->{twitter},            'Twitter',      'https://twitter.com/%s') if !$obj->{l_twitter};
    $lnk->($obj->{l_anidb},          'AniDB',        'https://anidb.net/cr%s');
    $lnk->($w->{anidb_person},       'AniDB',        'https://anidb.net/cr%s') if !$obj->{l_anidb};
    $lnk->($obj->{l_pixiv},          'Pixiv',        'https://www.pixiv.net/member.php?id=%d');
    $lnk->($w->{pixiv_user},         'Pixiv',        'https://www.pixiv.net/member.php?id=%d') if !$obj->{l_pixiv};
    $lnk->($w->{musicbrainz_artist}, 'MusicBrainz',  'https://musicbrainz.org/artist/%s');
    $lnk->($w->{vgmdb_artist},       'VGMdb',        'https://vgmdb.net/artist/%s');
    $lnk->($w->{discogs_artist},     'Discogs',      'https://www.discogs.com/artist/%s');
  }

  # Producer links
  if($type eq 'p') {
    $lnk->($w->{twitter},           'Twitter',   'https://twitter.com/%s');
    $lnk->($w->{mobygames_company}, 'MobyGames', 'https://www.mobygames.com/company/%s');
    $lnk->($w->{gamefaqs_company},  'GameFAQs',  'https://gamefaqs.gamespot.com/company/%s-');
    push @links, [ 'VNStat', sprintf 'https://vnstat.net/developer/%d', $obj->{id} ];
  }

  \@links
}

1;

