package VNDB::ExtLinks;

use v5.26;
use warnings;
use VNDB::Config;
use Exporter 'import';

our @EXPORT = ('enrich_extlinks', 'revision_extlinks');


# column name in wikidata table => \%info
# info keys:
#   type       SQL type, used by Multi to generate the proper SQL
#   property   Wikidata Property ID, used by Multi
#   label      How the link is displayed on the website
#   fmt        How to generate the url (printf-style string or subroutine returning the full URL)
our %WIKIDATA = (
    enwiki             => { type => 'text',       property => undef,   label => 'Wikipedia (en)', fmt => sub { sprintf 'https://en.wikipedia.org/wiki/%s', (shift =~ s/ /_/rg) =~ s/\?/%3f/rg } },
    jawiki             => { type => 'text',       property => undef,   label => 'Wikipedia (ja)', fmt => sub { sprintf 'https://ja.wikipedia.org/wiki/%s', (shift =~ s/ /_/rg) =~ s/\?/%3f/rg } },
    website            => { type => 'text[]',     property => 'P856',  label => undef,            fmt => undef },
    vndb               => { type => 'text[]',     property => 'P3180', label => undef,            fmt => undef },
    mobygames          => { type => 'text[]',     property => 'P1933', label => 'MobyGames',      fmt => 'https://www.mobygames.com/game/%s' },
    mobygames_company  => { type => 'text[]',     property => 'P4773', label => 'MobyGames',      fmt => 'https://www.mobygames.com/company/%s' },
    gamefaqs_game      => { type => 'integer[]',  property => 'P4769', label => 'GameFAQs',       fmt => 'https://gamefaqs.gamespot.com/-/%s-' },
    gamefaqs_company   => { type => 'integer[]',  property => 'P6182', label => 'GameFAQs',       fmt => 'https://gamefaqs.gamespot.com/company/%s-' },
    anidb_anime        => { type => 'integer[]',  property => 'P5646', label => undef,            fmt => undef },
    anidb_person       => { type => 'integer[]',  property => 'P5649', label => 'AniDB',          fmt => 'https://anidb.net/cr%s' },
    ann_anime          => { type => 'integer[]',  property => 'P1985', label => undef,            fmt => undef },
    ann_manga          => { type => 'integer[]',  property => 'P1984', label => undef,            fmt => undef },
    musicbrainz_artist => { type => 'uuid[]',     property => 'P434',  label => 'MusicBrainz',    fmt => 'https://musicbrainz.org/artist/%s' },
    twitter            => { type => 'text[]',     property => 'P2002', label => 'Twitter',        fmt => 'https://twitter.com/%s' },
    vgmdb_product      => { type => 'integer[]',  property => 'P5659', label => 'VGMdb',          fmt => 'https://vgmdb.net/product/%s' },
    vgmdb_artist       => { type => 'integer[]',  property => 'P3435', label => 'VGMdb',          fmt => 'https://vgmdb.net/artist/%s' },
    discogs_artist     => { type => 'integer[]',  property => 'P1953', label => 'Discogs',        fmt => 'https://www.discogs.com/artist/%s' },
    acdb_char          => { type => 'integer[]',  property => 'P7013', label => undef,            fmt => undef },
    acdb_source        => { type => 'integer[]',  property => 'P7017', label => 'ACDB',           fmt => 'https://www.animecharactersdatabase.com/source.php?id=%s' },
    indiedb_game       => { type => 'text[]',     property => 'P6717', label => 'IndieDB',        fmt => 'https://www.indiedb.com/games/%s' },
    howlongtobeat      => { type => 'integer[]',  property => 'P2816', label => 'HowLongToBeat',  fmt => 'http://howlongtobeat.com/game.php?id=%s' },
    crunchyroll        => { type => 'text[]',     property => 'P4110', label => undef,            fmt => undef },
    igdb_game          => { type => 'text[]',     property => 'P5794', label => 'IGDB',           fmt => 'https://www.igdb.com/games/%s' },
    giantbomb          => { type => 'text[]',     property => 'P5247', label => undef,            fmt => undef },
    pcgamingwiki       => { type => 'text[]',     property => 'P6337', label => undef,            fmt => undef },
    steam              => { type => 'integer[]',  property => 'P1733', label => undef,            fmt => undef },
    gog                => { type => 'text[]',     property => 'P2725', label => 'GOG',            fmt => 'https://www.gog.com/game/%s' },
    pixiv_user         => { type => 'integer[]',  property => 'P5435', label => 'Pixiv',          fmt => 'https://www.pixiv.net/member.php?id=%d' },
    doujinshi_author   => { type => 'integer[]',  property => 'P7511', label => 'Doujinshi.org',  fmt => 'https://www.doujinshi.org/browse/author/%d/' },
);


# dbentry_type => column name => \%info
# info keys:
#   label     Name of the link
#   fmt       How to generate a url (basic version, printf-style only)
#   fmt2      How to generate a better url
#             (printf-style string or subroutine, given a hashref of the DB entry and returning a new 'fmt' string)
#             ("better" meaning proper store section, affiliate link)
our %LINKS = (
    v => {
        l_renai    => { label => 'Renai.us',         fmt => 'https://renai.us/game/%s' },
        l_wikidata => { label => 'Wikidata',         fmt => 'https://www.wikidata.org/wiki/Q%d' },
        # deprecated
        l_wp       => { label => 'Wikipedia',        fmt => 'https://en.wikipedia.org/wiki/%s' },
        l_encubed  => { label => 'Novelnews',        fmt => 'http://novelnews.net/tag/%s/' },
    },
    r => {
        website    => { label => 'Official website', fmt => '%s' },
        l_egs      => { label => 'ErogameScape',     fmt => 'https://erogamescape.dyndns.org/~ap2/ero/toukei_kaiseki/game.php?game=%d' },
        l_erotrail => { label => 'ErogeTrailers',    fmt => 'http://erogetrailers.com/soft/%d' },
        l_steam    => { label => 'Steam',            fmt => 'https://store.steampowered.com/app/%d/' },
        l_dlsite   => { label => 'DLsite (jpn)',     fmt => 'https://www.dlsite.com/home/work/=/product_id/%s.html'
                      , fmt2 => sub { sprintf config->{dlsite_url}, shift->{l_dlsite_shop}||'home' } },
        l_dlsiteen => { label => 'DLsite (eng)',     fmt => 'https://www.dlsite.com/home/eng/=/product_id/%s.html'
                      , fmt2 => sub { sprintf config->{dlsite_url}, shift->{l_dlsiteen_shop}||'eng' } },
        l_gog      => { label => 'GOG',              fmt => 'https://www.gog.com/game/%s' },
        l_itch     => { label => 'Itch.io',          fmt => 'https://%s' },
        l_denpa    => { label => 'Denpasoft',        fmt => 'https://denpasoft.com/products/%s', fmt2 => config->{denpa_url} },
        l_jlist    => { label => 'J-List',           fmt => 'https://www.jlist.com/%s', fmt2 => sub { config->{ shift->{l_jlist_jbox} ? 'jbox_url' : 'jlist_url' } } },
        l_jastusa  => { label => 'JAST USA',         fmt => 'https://jastusa.com/%s' },
        l_gyutto   => { label => 'Gyutto',           fmt => 'https://gyutto.com/i/item%d' },
        l_digiket  => { label => 'Digiket',          fmt => 'https://www.digiket.com/work/show/_data/ID=ITM%07d/' },
        l_melon    => { label => 'Melonbooks',       fmt => 'https://www.melonbooks.com/index.php?main_page=product_info&products_id=IT%010d' },
        l_mg       => { label => 'MangaGamer',       fmt => 'https://www.mangagamer.com/r18/detail.php?product_code=%d'
                      , fmt2 => sub { config->{ !defined($_[0]{l_mg_r18}) || $_[0]{l_mg_r18} ? 'mg_r18_url' : 'mg_main_url' } } },
        l_getchu   => { label => 'Getchu',           fmt => 'http://www.getchu.com/soft.phtml?id=%d' },
        l_getchudl => { label => 'DL.Getchu',        fmt => 'http://dl.getchu.com/i/item%d' },
        l_dmm      => { label => 'DMM',              fmt => 'https://%s' },
    },
    s => {
        l_site     => { label => 'Official website', fmt => '%s' },
        l_wikidata => { label => 'Wikidata',         fmt => 'https://www.wikidata.org/wiki/Q%d' },
        l_twitter  => { label => 'Twitter',          fmt => 'https://twitter.com/%s' },
        l_anidb    => { label => 'AniDB',            fmt => 'https://anidb.net/cr%s' },
        l_pixiv    => { label => 'Pixiv',            fmt => 'https://www.pixiv.net/member.php?id=%d' },
        # deprecated
        l_wp       => { label => 'Wikipedia',        fmt => 'https://en.wikipedia.org/wiki/%s' },
    },
    p => {
        website    => { label => 'Official website', fmt => '%s' },
        l_wikidata => { label => 'Wikidata',         fmt => 'https://www.wikidata.org/wiki/Q%d' },
        # deprecated
        l_wp       => { label => 'Wikipedia',        fmt => 'https://en.wikipedia.org/wiki/%s' },
    },
);


# Fetch a list of links to display at the given database entries, adds the
# following field to each object:
#
#   extlinks => [
#     [ $title, $url, $price ],
#     ..
#   ]
#
# (It also adds a few other fields in some cases, but you can ignore those)
sub enrich_extlinks {
    my($type, @obj) = @_;
    @obj = map ref $_ eq 'ARRAY' ? @$_ : ($_), @obj;

    my $l = $LINKS{$type} || die "DB entry type $type has no links";

    my @w_ids = grep $_, map $_->{l_wikidata}, @obj;
    my $w = @w_ids ? { map +($_->{id}, $_), $TUWF::OBJ->dbAlli('SELECT * FROM wikidata WHERE id IN', \@w_ids)->@* } : {};

    # Fetch shop info for releases
    if($type eq 'r') {
        VNWeb::DB::enrich_merge(id => q{
            SELECT r.id
                 ,       smg.price AS l_mg_price,       smg.r18 AS l_mg_r18
                 ,    sdenpa.price AS l_denpa_price
                 ,    sjlist.price AS l_jlist_price,    sjlist.jbox AS l_jlist_jbox
                 ,   sdlsite.price AS l_dlsite_price,   sdlsite.shop AS l_dlsite_shop
                 , sdlsiteen.price AS l_dlsiteen_price, sdlsiteen.shop AS l_dlsiteen_shop
              FROM releases r
              LEFT JOIN shop_denpa  sdenpa    ON    sdenpa.id = r.l_denpa    AND    sdenpa.lastfetch IS NOT NULL AND    sdenpa.deadsince IS NULL
              LEFT JOIN shop_dlsite sdlsite   ON   sdlsite.id = r.l_dlsite   AND   sdlsite.lastfetch IS NOT NULL AND   sdlsite.deadsince IS NULL
              LEFT JOIN shop_dlsite sdlsiteen ON sdlsiteen.id = r.l_dlsiteen AND sdlsiteen.lastfetch IS NOT NULL AND sdlsiteen.deadsince IS NULL
              LEFT JOIN shop_jlist  sjlist    ON    sjlist.id = r.l_jlist    AND    sjlist.lastfetch IS NOT NULL AND    sjlist.deadsince IS NULL
              LEFT JOIN shop_mg     smg       ON       smg.id = r.l_mg       AND       smg.lastfetch IS NOT NULL AND       smg.deadsince IS NULL
              WHERE r.id IN},
              grep $_->{l_mg}||$_->{l_denpa}||$_->{l_jlist}||$_->{l_dlsite}||$_->{l_dlsiteen}, @obj
        );
        VNWeb::DB::enrich(l_playasia => gtin => gtin =>
            "SELECT gtin, price, url FROM shop_playasia WHERE price <> '' AND gtin IN",
            grep $_->{gtin}, @obj
        );
    }

    for my $obj (@obj) {
        my @links;
        my sub w {
            return if !$obj->{l_wikidata};
            my($v, $fmt, $label) = ($w->{$obj->{l_wikidata}}{$_[0]}, @{$WIKIDATA{$_[0]}}{'fmt', 'label'});
            push @links, map [ $label, ref $fmt ? $fmt->($_) : sprintf $fmt, $_ ], ref $v ? @$v : $v ? $v : ()
        }
        my sub l {
            my($f, $price) = @_;
            my($v, $fmt, $fmt2, $label) = ($obj->{$f}, @{$l->{$f}}{'fmt', 'fmt2', 'label'});
            push @links, map [ $label, sprintf(ref $fmt2 ? $fmt2->($obj) : $fmt2 || $fmt, $_), $price ], ref $v ? @$v : $v ? $v : ()
        }

        l 'l_site';
        l 'website';
        w 'enwiki';
        w 'jawiki';
        l 'l_wikidata';

        # VN links
        if($type eq 'v') {
            w 'mobygames';
            w 'gamefaqs_game';
            w 'vgmdb_product';
            w 'acdb_source';
            w 'indiedb_game';
            w 'howlongtobeat';
            w 'igdb_game';
            l 'l_renai';
            push @links, [ 'VNStat', sprintf 'https://vnstat.net/novel/%d', $obj->{id} ] if $obj->{c_votecount}>=20;
        }

        # Release links
        if($type eq 'r') {
            l 'l_egs';
            l 'l_erotrail';
            l 'l_steam';
            push @links, [ 'SteamDB', sprintf 'https://steamdb.info/app/%d/info', $obj->{l_steam} ] if $obj->{l_steam};
            l 'l_dlsite', $obj->{l_dlsite_price};
            l 'l_dlsiteen', $obj->{l_dlsiteen_price};
            l 'l_gog';
            l 'l_itch';
            l 'l_denpa', $obj->{l_denpa_price};
            l 'l_jlist', $obj->{l_jlist_price};
            l 'l_jastusa';
            l 'l_gyutto';
            l 'l_digiket';
            l 'l_melon';
            l 'l_mg', $obj->{l_mg_price};
            l 'l_getchu';
            l 'l_getchudl';
            l 'l_dmm';
            push @links, map [ 'PlayAsia', $_->{url}, $_->{price} ], @{$obj->{l_playasia}} if $obj->{l_playasia};
        }

        # Staff links
        if($type eq 's') {
            l 'l_twitter'; w 'twitter'      if !$obj->{l_twitter};
            l 'l_anidb';   w 'anidb_person' if !$obj->{l_anidb};
            l 'l_pixiv';   w 'pixiv_user'   if !$obj->{l_pixiv};
            w 'musicbrainz_artist';
            w 'vgmdb_artist';
            w 'discogs_artist';
            w 'doujinshi_author';
        }

        # Producer links
        if($type eq 'p') {
            w 'twitter';
            w 'mobygames_company';
            w 'gamefaqs_company';
            w 'doujinshi_author';
            push @links, [ 'VNStat', sprintf 'https://vnstat.net/developer/%d', $obj->{id} ];
        }

        $obj->{extlinks} = \@links
    }
}


# Returns a list of @fields for use in VNWeb::HTML::revision_()
sub revision_extlinks {
    my($type) = @_;
    map {
        my($f, $p) = ($_, $LINKS{$type}{$_});
        [ $f, $p->{label}, fmt => sub { TUWF::XML::a_ href => sprintf($p->{fmt}, $_), $_; }, empty => 0 ]
    } sort keys $LINKS{$type}->%*
}


1;