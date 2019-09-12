
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
  board_edit_time => 7*24*3600,
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

