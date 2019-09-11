
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
                     # bit flags (Flag 8 was used for staffedit and 256 for affiliates, now free to re-use)
                     # The 'usermod' flag is hardcoded in sql/func.sql for user_* functions.
  permissions     => {qw| board 1  boardmod 2  edit 4  tag 16  dbmod 32  tagmod 64  usermod 128 |},
  default_perm    => 1+4+16, # Keep synchronised with the default value of users.perm
  default_tags_cat=> 'cont,tech',
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
  board_edit_time => 7*24*3600,
  age_ratings     => [-1, 0, 6..18],
  release_types   => [qw|complete partial trial|],
  media           => ordhash(
   #DB     qty  txt                      plural (if qty)           icon
    cd  => [ 1, 'CD',                    'CDs',                    'disk'     ],
    dvd => [ 1, 'DVD',                   'DVDs',                   'disk'     ],
    gdr => [ 1, 'GD-ROM',                'GD-ROMs',                'disk'     ],
    blr => [ 1, 'Blu-ray disc',          'Blu-ray discs',          'disk'     ],
    flp => [ 1, 'Floppy',                'Floppies',               'cartridge'],
    mrt => [ 1, 'Cartridge',             'Cartridges',             'cartridge'],
    mem => [ 1, 'Memory card',           'Memory cards',           'cartridge'],
    umd => [ 1, 'UMD',                   'UMDs',                   'disk'     ],
    nod => [ 1, 'Nintendo Optical Disc', 'Nintendo Optical Discs', 'disk'     ],
    in  => [ 0, 'Internet download',     '',                       'download' ],
    otc => [ 0, 'Other',                 '',                       'cartridge'],
  ),
  resolutions     => ordhash(
    unknown     => [ 'Unknown / console / handheld', '' ], # hardcoded in many places
    nonstandard => [ 'Non-standard', '' ],                 # hardcoded in VNPage.pm
    '640x480'   => [ '640x480',      '4:3' ],
    '800x600'   => [ '800x600',      '4:3' ],
    '1024x768'  => [ '1024x768',     '4:3' ],
    '1280x960'  => [ '1280x960',     '4:3' ],
    '1600x1200' => [ '1600x1200',    '4:3' ],
    '640x400'   => [ '640x400',      'widescreen' ],
    '960x600'   => [ '960x600',      'widescreen' ],
    '960x640'   => [ '960x640',      'widescreen' ],
    '1024x576'  => [ '1024x576',     'widescreen' ],
    '1024x600'  => [ '1024x600',     'widescreen' ],
    '1024x640'  => [ '1024x640',     'widescreen' ],
    '1280x720'  => [ '1280x720',     'widescreen' ],
    '1280x800'  => [ '1280x800',     'widescreen' ],
    '1366x768'  => [ '1366x768',     'widescreen' ],
    '1600x900'  => [ '1600x900',     'widescreen' ],
    '1920x1080' => [ '1920x1080',    'widescreen' ],
  ),
  animated              => [ 'Unknown', 'No animations',      'Simple animations',     'Some fully animated scenes', 'All scenes fully animated' ],
  icons_story_animated  => [ 'unknown', 'story_not_animated', 'story_simple_animated', 'story_some_fully_animated',  'story_all_fully_animated'  ],
  icons_ero_animated    => [ 'unknown', 'ero_not_animated',   'ero_simple_animated',   'ero_some_fully_animated',    'ero_all_fully_animated'    ],
  voiced          => [ 'Unknown', 'Not voiced', 'Only ero scenes voiced', 'Partially voiced', 'Fully voiced' ],
  icons_voiced    => [ 'unknown', 'not_voiced', 'ero_voiced',             'partially_voiced', 'fully_voiced' ],
  atom_feeds => { # num_entries, title, id
    announcements => [ 10, 'VNDB Site Announcements', '/t/an' ],
    changes       => [ 25, 'VNDB Recent Changes', '/hist' ],
    posts         => [ 25, 'VNDB Recent Posts', '/t' ],
  },
  poll_options    => 20, # max number of options in discussion board polls
  engines => [ grep $_, split /\s*\n\s*/, q{
    BGI/Ethornell
    CatSystem2
    codeX RScript
    EntisGLS
    Ikura GDL
    KiriKiri
    Majiro
    NScripter
    QLIE
    RPG Maker
    RealLive
    Ren'Py
    Shiina Rio
    Unity
    YU-RIS
  }],
  dlsite_url   => 'https://www.dlsite.com/%s/work/=/product_id/%%s.html',
  denpa_url    => 'https://denpasoft.com/products/%s',
  jlist_url    => 'https://www.jlist.com/%s',
  jbox_url     => 'https://www.jbox.com/%s',
  mg_r18_url   => 'https://www.mangagamer.com/r18/detail.php?product_code=%d',
  mg_main_url  => 'https://www.mangagamer.com/detail.php?product_code=%d',
);


# Multi-specific options (Multi also uses some options in %S and %O)
our %M = (
  log_dir   => $ROOT.'/data/log',
  log_level => 'trace',
  modules   => {
    #API         => {},  # disabled by default, not really needed
    Feed        => {},
    RG          => {},
    #Anime       => {},  # disabled by default, requires AniDB username/pass
    Maintenance => {},
    #IRC         => {},  # disabled by default, no need to run an IRC bot when debugging
    #Wikidata    => {},  # disabled by default, no need to bother the Wikidata API when debugging
    #JList       => {},
    #MG          => {},
    #Denpa       => { api => '', user => '', pass => '' },
  },
);


# allow the settings to be overwritten in config.pl
require $ROOT.'/data/config.pl' if -f $ROOT.'/data/config.pl';

1;

