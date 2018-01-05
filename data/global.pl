
package VNDB;

use utf8;
use strict;
use warnings;
use Tie::IxHash;

our $ROOT;

# Convenient wrapper to create an ordered hash
sub ordhash { my %x; tie %x, 'Tie::IxHash', @_; \%x }


# options for TUWF
our %O = (
  db_login  => [ 'dbi:Pg:dbname=vndb', 'vndb_site', 'passwd' ],
  debug     => 1,
  logfile   => $ROOT.'/data/log/vndb.log',
  cookie_prefix   => 'vndb_',
  cookie_defaults => {
    domain => '.vndb.org',
    path   => '/',
  },
);


# VNDB-specific options (object_data)
our %S;
%S = (%S,
  version         => `cd $ROOT; git describe` =~ /^(.+)$/ && $1,
  url             => 'http://vndb.org',   # Only used by Multi, web pages infer their own address
  url_static      => 'http://s.vndb.org',
  skin_default    => 'angel',
  placeholder_img => 'http://s.vndb.org/s/angel/bg.jpg', # Used in the og:image meta tag
  form_salt       => 'a-private-string-here',
  scrypt_args     => [ 65536, 8, 1 ], # N, r, p
  scrypt_salt     => 'another-random-string',
  regen_static    => 0,
  source_url      => 'http://git.blicky.net/vndb.git/?h=master',
  admin_email     => 'contact@vndb.org',
  login_throttle  => [ 24*3600/10, 24*3600 ], # interval between attempts, max burst (10 a day)
  scr_size        => [ 136, 102 ], # w*h of screenshot thumbnails
  ch_size         => [ 256, 300 ], # max. w*h of char images
  cv_size         => [ 256, 400 ], # max. w*h of cover images
                     # bit flags (Flag 8 was used for staffedit, now free to re-use)
                     # The 'usermod' flag is hardcoded in sql/func.sql for user_* functions.
  permissions     => {qw| board 1  boardmod 2  edit 4  tag 16  dbmod 32  tagmod 64  usermod 128  affiliate 256 |},
  default_perm    => 1+4+16, # Keep synchronised with the default value of users.perm
  default_tags_cat=> 'cont,tech',
  languages       => ordhash(grep !/^ *$/, split /[\s\r\n]*([^ ]+) +(.+)/, q{
    ar Arabic
    bg Bulgarian
    ca Catalan
    cs Czech
    da Danish
    de German
    en English
    es Spanish
    fi Finnish
    fr French
    he Hebrew
    hr Croatian
    hu Hungarian
    id Indonesian
    it Italian
    ja Japanese
    ko Korean
    nl Dutch
    no Norwegian
    pl Polish
    pt-br Portuguese (Brazil)
    pt-pt Portuguese (Portugal)
    ro Romanian
    ru Russian
    sk Slovak
    sv Swedish
    ta Tagalog
    th Thai
    tr Turkish
    uk Ukrainian
    vi Vietnamese
    zh Chinese
  }),
  producer_types  => ordhash(
    co => 'Company',
    in => 'Individual',
    ng => 'Amateur group',
  ),
  # Some discussion board properties are hardcoded, e.g.:
  # - number of rows to show on /t
  # - whether it needs mod access
  # - whether it needs to be linked to a DB item.
  discussion_boards => ordhash(
    an => 'Announcements',
    db => 'VNDB discussions',
    ge => 'General discussions',
    v  => 'Visual novels',
    p  => 'Producers',
    u  => 'Users',
  ),
  vn_lengths => [
    # name          time             examples
    [ 'Unknown',    '',              ''                                                  ],
    [ 'Very short', '< 2 hours',     'OMGWTFOTL, Jouka no Monshou, The world to reverse' ],
    [ 'Short',      '2 - 10 hours',  'Narcissu, Saya no Uta, Planetarian'                ],
    [ 'Medium',     '10 - 30 hours', 'Yume Miru Kusuri, Cross†Channel, Crescendo'        ],
    [ 'Long',       '30 - 50 hours', 'Tsukihime, Ever17, Demonbane'                      ],
    [ 'Very long',  '> 50 hours',    'Clannad, Umineko, Fate/Stay Night'                 ],
  ],
  anime_types => {
    tv  => 'TV Series',
    ova => 'OVA',
    mov => 'Movie',
    oth => 'Other',
    web => 'Web',
    spe => 'TV Special',
    mv  => 'Music Video',
  },
  board_edit_time => 7*24*3600,
  vn_relations => ordhash(
  # id   => [ reverse, txt ]
    seq  => [ 'preq', 'Sequel'              ],
    preq => [ 'seq',  'Prequel'             ],
    set  => [ 'set',  'Same setting'        ],
    alt  => [ 'alt',  'Alternative version' ],
    char => [ 'char', 'Shares characters'   ],
    side => [ 'par',  'Side story'          ],
    par  => [ 'side', 'Parent story'        ],
    ser  => [ 'ser',  'Same series'         ],
    fan  => [ 'orig', 'Fandisc'             ],
    orig => [ 'fan',  'Original game'       ],
  ),
  prod_relations  => ordhash(
    'old' => [ 'new', 'Formerly'        ],
    'new' => [ 'old', 'Succeeded by'    ],
    'spa' => [ 'ori', 'Spawned'         ],
    'ori' => [ 'spa', 'Originated from' ],
    'sub' => [ 'par', 'Subsidiary'      ],
    'par' => [ 'sub', 'Parent producer' ],
    'imp' => [ 'ipa', 'Imprint'         ],
    'ipa' => [ 'imp', 'Parent brand '   ],
  ),
  age_ratings     => [-1, 0, 6..18],
  release_types   => [qw|complete partial trial|],
  # The 'unk' platform and medium are reserved for "unknown".
  platforms       => ordhash(grep !/^ *$/, split /[\s\r\n]*([^ ]+) +(.+)/, q{
    win Windows
    dos DOS
    lin Linux
    mac Mac OS
    ios Apple iProduct
    and Android
    dvd DVD Player
    bdp Blu-ray Player
    fmt FM Towns
    gba Game Boy Advance
    gbc Game Boy Color
    msx MSX
    nds Nintendo DS
    nes Famicom
    p88 PC-88
    p98 PC-98
    pce PC Engine
    pcf PC-FX
    psp PlayStation Portable
    ps1 PlayStation 1
    ps2 PlayStation 2
    ps3 PlayStation 3
    ps4 PlayStation 4
    psv PlayStation Vita
    drc Dreamcast
    sat Sega Saturn
    sfc Super Nintendo
    swi Nintendo Switch
    wii Nintendo Wii
    wiu Nintendo Wii U
    n3d Nintendo 3DS
    x68 X68000
    xb1 Xbox
    xb3 Xbox 360
    xbo Xbox One
    web Website
    oth Other
  }),
  media           => ordhash(
   #DB     qty  txt                      plural (if qty)           icon
    cd  => [ 1, 'CD',                    'CDs',                    'disk'     ],
    dvd => [ 1, 'DVD',                   'DVDs',                   'disk'     ],
    gdr => [ 1, 'GD-ROM',                'GD-ROMs',                'disk'     ],
    blr => [ 1, 'Blu-ray disc',          'Blu-ray discs',          'disk'     ],
    flp => [ 1, 'Floppy',                'Floppies',               'cartridge'],
    mrt => [ 1, 'Cartridge',             'Cartridges',             'cartridge'],
    mem => [ 1, 'Memory card',           'Memory cards',           'cartridge'],
    umd => [ 1, 'UMD',                   'UMDs',                   'cartridge'],
    nod => [ 1, 'Nintendo Optical Disc', 'Nintendo Optical Discs', 'disk'     ],
    in  => [ 0, 'Internet download',     '',                       'download' ],
    otc => [ 0, 'Other',                 '',                       'cartridge'],
  ),
  resolutions     => [
    [ 'Unknown / console / handheld', '' ], # hardcoded to 0 in many places
    [ 'Non-standard', '' ],                 # hardcoded to 1 in VNPage.pm
    [ '640x480',      '4:3' ],
    [ '800x600',      '4:3' ],
    [ '1024x768',     '4:3' ],
    [ '1280x960',     '4:3' ],
    [ '1600x1200',    '4:3' ],
    [ '640x400',      'widescreen' ],
    [ '960x600',      'widescreen' ],
    [ '1024x576',     'widescreen' ],
    [ '1024x600',     'widescreen' ],
    [ '1024x640',     'widescreen' ],
    [ '1280x720',     'widescreen' ],
    [ '1280x800',     'widescreen' ],
    [ '1366x768',     'widescreen' ],
    [ '1920x1080',    'widescreen' ],
  ],
  tag_categories  => ordhash(
    cont => 'Content',
    ero  => 'Sexual content',
    tech => 'Technical',
  ),
  animated              => [ 'Unknown', 'No animations',      'Simple animations',     'Some fully animated scenes', 'All scenes fully animated' ],
  icons_story_animated  => [ 'unknown', 'story_not_animated', 'story_simple_animated', 'story_some_fully_animated',  'story_all_fully_animated'  ],
  icons_ero_animated    => [ 'unknown', 'ero_not_animated',   'ero_simple_animated',   'ero_some_fully_animated',    'ero_all_fully_animated'    ],
  voiced          => [ 'Unknown', 'Not voiced', 'Only ero scenes voiced', 'Partially voiced', 'Fully voiced' ],
  icons_voiced    => [ 'unknown', 'not_voiced', 'ero_voiced',             'partially_voiced', 'fully_voiced' ],
  wishlist_status => [ 'high', 'medium', 'low', 'blacklist' ],
  rlist_status    => [ 'Unknown', 'Pending', 'Obtained', 'On loan', 'Deleted' ], # 0 = hardcoded "unknown", 2 = hardcoded 'OK'
  vnlist_status   => [ 'Unknown', 'Playing', 'Finished', 'Stalled', 'Dropped' ],
  blood_types     => ordhash(qw{unknown Unknown o O a A b B ab AB}),
  genders         => ordhash(unknown => 'Unknown or N/A', qw{m Male  f Female  b Both}),
  char_roles      => ordhash(
    main    => [ 'Protagonist',         'Protagonists' ],
    primary => [ 'Main character',      'Main characters' ],
    side    => [ 'Side character',      'Side characters' ],
    appears => [ 'Makes an appearance', 'Make an appearance' ],
  ),
  atom_feeds => { # num_entries, title, id
    announcements => [ 10, 'VNDB Site Announcements', '/t/an' ],
    changes       => [ 25, 'VNDB Recent Changes', '/hist' ],
    posts         => [ 25, 'VNDB Recent Posts', '/t' ],
  },
  staff_roles     => ordhash(
    scenario   => 'Scenario',
    chardesign => 'Character design',
    art        => 'Artist',
    music      => 'Composer',
    songs      => 'Vocals',
    director   => 'Director',
    staff      => 'Staff',
  ),
  poll_options    => 20, # max number of options in discussion board polls
);


# Multi-specific options (Multi also uses some options in %S and %O)
our %M = (
  log_dir   => $ROOT.'/data/log',
  log_level => 'trace',
  modules   => {
    #API         => {},  # disabled by default, not really needed
    #APIDump     => {},
    Feed        => {},
    RG          => {},
    #Anime       => {},  # disabled by default, requires AniDB username/pass
    Maintenance => {},
    #IRC         => {},  # disabled by default, no need to run an IRC bot when debugging
  },
);


# Options for jsgen.pl
our %JSGEN = (
  compress => undef,
  gzip => undef,
);


# Options for spritegen.pl
our %SPRITEGEN = (
  slow => 0,
  crush => undef,
);

# Options for skingen.pl
our %SKINGEN = (
  gzip => undef,
);


# allow the settings to be overwritten in config.pl
require $ROOT.'/data/config.pl' if -f $ROOT.'/data/config.pl';

1;

