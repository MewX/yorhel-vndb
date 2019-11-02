package VNDB::Types;

use v5.24;
no strict 'refs';
use warnings;
use Exporter 'import';

our @EXPORT;
sub hash {
    my $name = shift;
    tie $name->%*, 'VNDB::Types::Hash', @_;
    push @EXPORT, "%$name";
}



# SQL: ENUM language
hash LANGUAGE =>
    ar => 'Arabic',
    bg => 'Bulgarian',
    ca => 'Catalan',
    cs => 'Czech',
    da => 'Danish',
    de => 'German',
    el => 'Greek',
    en => 'English',
    eo => 'Esperanto',
    es => 'Spanish',
    fi => 'Finnish',
    fr => 'French',
    gd => 'Scottish Gaelic',
    he => 'Hebrew',
    hr => 'Croatian',
    hu => 'Hungarian',
    id => 'Indonesian',
    it => 'Italian',
    ja => 'Japanese',
    ko => 'Korean',
    mk => 'Macedonian',
    ms => 'Malay',
    lt => 'Lithuanian',
    lv => 'Latvian',
    nl => 'Dutch',
    no => 'Norwegian',
    pl => 'Polish',
    'pt-br' => 'Portuguese (Brazil)',
    'pt-pt' => 'Portuguese (Portugal)',
    ro => 'Romanian',
    ru => 'Russian',
    sk => 'Slovak',
    sl => 'Slovene',
    sv => 'Swedish',
    ta => 'Tagalog',
    th => 'Thai',
    tr => 'Turkish',
    uk => 'Ukrainian',
    vi => 'Vietnamese',
    zh => 'Chinese';



# SQL: ENUM platform
# The 'unk' platform is used to mean "Unknown" in various places (not in the DB).
hash PLATFORM =>
    win => 'Windows',
    dos => 'DOS',
    lin => 'Linux',
    mac => 'Mac OS',
    ios => 'Apple iProduct',
    and => 'Android',
    dvd => 'DVD Player',
    bdp => 'Blu-ray Player',
    fmt => 'FM Towns',
    gba => 'Game Boy Advance',
    gbc => 'Game Boy Color',
    msx => 'MSX',
    nds => 'Nintendo DS',
    nes => 'Famicom',
    p88 => 'PC-88',
    p98 => 'PC-98',
    pce => 'PC Engine',
    pcf => 'PC-FX',
    psp => 'PlayStation Portable',
    ps1 => 'PlayStation 1',
    ps2 => 'PlayStation 2',
    ps3 => 'PlayStation 3',
    ps4 => 'PlayStation 4',
    psv => 'PlayStation Vita',
    drc => 'Dreamcast',
    sat => 'Sega Saturn',
    sfc => 'Super Nintendo',
    swi => 'Nintendo Switch',
    wii => 'Nintendo Wii',
    wiu => 'Nintendo Wii U',
    n3d => 'Nintendo 3DS',
    x68 => 'X68000',
    xb1 => 'Xbox',
    xb3 => 'Xbox 360',
    xbo => 'Xbox One',
    web => 'Website',
    oth => 'Other';



# SQL: ENUM vn_relation
hash VN_RELATION =>
    seq  => { reverse => 'preq', txt => 'Sequel'              },
    preq => { reverse => 'seq',  txt => 'Prequel'             },
    set  => { reverse => 'set',  txt => 'Same setting'        },
    alt  => { reverse => 'alt',  txt => 'Alternative version' },
    char => { reverse => 'char', txt => 'Shares characters'   },
    side => { reverse => 'par',  txt => 'Side story'          },
    par  => { reverse => 'side', txt => 'Parent story'        },
    ser  => { reverse => 'ser',  txt => 'Same series'         },
    fan  => { reverse => 'orig', txt => 'Fandisc'             },
    orig => { reverse => 'fan',  txt => 'Original game'       };



# SQL: ENUM producer_relation
hash PRODUCER_RELATION =>
    old => { reverse => 'new', txt => 'Formerly'        },
    new => { reverse => 'old', txt => 'Succeeded by'    },
    spa => { reverse => 'ori', txt => 'Spawned'         },
    ori => { reverse => 'spa', txt => 'Originated from' },
    sub => { reverse => 'par', txt => 'Subsidiary'      },
    par => { reverse => 'sub', txt => 'Parent producer' },
    imp => { reverse => 'ipa', txt => 'Imprint'         },
    ipa => { reverse => 'imp', txt => 'Parent brand'    };



# SQL: ENUM producer_type
hash PRODUCER_TYPE =>
    co => 'Company',
    in => 'Individual',
    ng => 'Amateur group';



# SQL: ENUM credit_type
hash CREDIT_TYPE =>
    scenario   => 'Scenario',
    chardesign => 'Character design',
    art        => 'Artist',
    music      => 'Composer',
    songs      => 'Vocals',
    director   => 'Director',
    staff      => 'Staff';



hash VN_LENGTH =>
    0 => { txt => 'Unknown',    time => ''              },
    1 => { txt => 'Very short', time => '< 2 hours'     },
    2 => { txt => 'Short',      time => '2 - 10 hours'  },
    3 => { txt => 'Medium',     time => '10 - 30 hours' },
    4 => { txt => 'Long',       time => '30 - 50 hours' },
    5 => { txt => 'Very long',  time => '> 50 hours'    };



# SQL: ENUM anime_type
hash ANIME_TYPE => # anidb = what the UDP API returns, lowercased
    tv  => { txt => 'TV Series',    anidb => 'tv series'   },
    ova => { txt => 'OVA',          anidb => 'ova'         },
    mov => { txt => 'Movie',        anidb => 'movie'       },
    oth => { txt => 'Other',        anidb => 'other'       },
    web => { txt => 'Web',          anidb => 'web'         },
    spe => { txt => 'TV Special',   anidb => 'tv special'  },
    mv  => { txt => 'Music Video',  anidb => 'music video' };



# SQL: ENUM tag_category
hash TAG_CATEGORY =>
    cont => 'Content',
    ero  => 'Sexual content',
    tech => 'Technical';



hash ANIMATED =>
    0 => { txt => 'Unknown',                    story_icon => 'unknown',                   ero_icon => 'unknown'                 },
    1 => { txt => 'No animations',              story_icon => 'story_not_animated',        ero_icon => 'ero_not_animated'        },
    2 => { txt => 'Simple animations',          story_icon => 'story_simple_animated',     ero_icon => 'ero_simple_animated'     },
    3 => { txt => 'Some fully animated scenes', story_icon => 'story_some_fully_animated', ero_icon => 'ero_some_fully_animated' },
    4 => { txt => 'All scenes fully animated',  story_icon => 'story_all_fully_animated',  ero_icon => 'ero_all_fully_animated'  };



hash VOICED =>
    0 => { txt => 'Unknown',                 icon => 'unknown'          },
    1 => { txt => 'Not voiced',              icon => 'not_voiced'       },
    2 => { txt => 'Only ero scenes voiced',  icon => 'ero_voiced'       },
    3 => { txt => 'Partially voiced',        icon => 'partially_voiced' },
    4 => { txt => 'Fully voiced',            icon => 'fully_voiced'     };



# TODO: For some reason the minage column in SQL is nullable but still stores 'unknown' as -1.
# This should be cleaned up at some point.
hash AGE_RATING =>
    -1 => { txt => 'Unknown',  ex => '' },
     0 => { txt => 'All ages', ex => 'CERO A' },
     6 => { txt => '6+',       ex => '' },
     7 => { txt => '7+',       ex => '' },
     8 => { txt => '8+',       ex => '' },
     9 => { txt => '9+',       ex => '' },
    10 => { txt => '10+',      ex => '' },
    11 => { txt => '11+',      ex => '' },
    12 => { txt => '12+',      ex => 'CERO B' },
    13 => { txt => '13+',      ex => '' },
    14 => { txt => '14+',      ex => '' },
    15 => { txt => '15+',      ex => 'CERO C' },
    16 => { txt => '16+',      ex => '' },
    17 => { txt => '17+',      ex => 'CERO D' },
    18 => { txt => '18+',      ex => 'CERO Z' };



# SQL: ENUM medium
# The 'unk' medium is used in release filters to mean "unknown".
hash MEDIUM =>
    cd  => { qty => 1, txt => 'CD',                    plural => 'CDs',                    icon => 'disk'      },
    dvd => { qty => 1, txt => 'DVD',                   plural => 'DVDs',                   icon => 'disk'      },
    gdr => { qty => 1, txt => 'GD-ROM',                plural => 'GD-ROMs',                icon => 'disk'      },
    blr => { qty => 1, txt => 'Blu-ray disc',          plural => 'Blu-ray discs',          icon => 'disk'      },
    flp => { qty => 1, txt => 'Floppy',                plural => 'Floppies',               icon => 'cartridge' },
    mrt => { qty => 1, txt => 'Cartridge',             plural => 'Cartridges',             icon => 'cartridge' },
    mem => { qty => 1, txt => 'Memory card',           plural => 'Memory cards',           icon => 'cartridge' },
    umd => { qty => 1, txt => 'UMD',                   plural => 'UMDs',                   icon => 'disk'      },
    nod => { qty => 1, txt => 'Nintendo Optical Disc', plural => 'Nintendo Optical Discs', icon => 'disk'      },
    in  => { qty => 0, txt => 'Internet download',     plural => '',                       icon => 'download'  },
    otc => { qty => 0, txt => 'Other',                 plural => '',                       icon => 'cartridge' };



# SQL: ENUM resolution
hash RESOLUTION =>
    unknown     => { txt => 'Unknown / console / handheld', cat => '' }, # hardcoded in many places
    nonstandard => { txt => 'Non-standard', cat => ''                 }, # hardcoded in VNPage.pm
    '640x480'   => { txt => '640x480',      cat => '4:3'              },
    '800x600'   => { txt => '800x600',      cat => '4:3'              },
    '1024x768'  => { txt => '1024x768',     cat => '4:3'              },
    '1280x960'  => { txt => '1280x960',     cat => '4:3'              },
    '1600x1200' => { txt => '1600x1200',    cat => '4:3'              },
    '640x400'   => { txt => '640x400',      cat => 'widescreen'       },
    '960x600'   => { txt => '960x600',      cat => 'widescreen'       },
    '960x640'   => { txt => '960x640',      cat => 'widescreen'       },
    '1024x576'  => { txt => '1024x576',     cat => 'widescreen'       },
    '1024x600'  => { txt => '1024x600',     cat => 'widescreen'       },
    '1024x640'  => { txt => '1024x640',     cat => 'widescreen'       },
    '1280x720'  => { txt => '1280x720',     cat => 'widescreen'       },
    '1280x800'  => { txt => '1280x800',     cat => 'widescreen'       },
    '1366x768'  => { txt => '1366x768',     cat => 'widescreen'       },
    '1600x900'  => { txt => '1600x900',     cat => 'widescreen'       },
    '1920x1080' => { txt => '1920x1080',    cat => 'widescreen'       };



# SQL: ENUM release_type
hash RELEASE_TYPE =>
    complete => 'Complete',
    partial  => 'Partial',
    trial    => 'Trial';



hash WISHLIST_STATUS =>
    0 => 'High',
    1 => 'Medium',
    2 => 'Low',
    3 => 'Blacklist';



# 0 = hardcoded "unknown", 2 = hardcoded 'OK'
hash RLIST_STATUS =>
    0 => 'Unknown',
    1 => 'Pending',
    2 => 'Obtained',
    3 => 'On loan',
    4 => 'Deleted';



hash VNLIST_STATUS =>
    0 => 'Unknown',
    1 => 'Playing',
    2 => 'Finished',
    3 => 'Stalled',
    4 => 'Dropped';



# SQL: ENUM board_type
hash BOARD_TYPE =>
    an => { txt => 'Announcements',       post_perm => 'boardmod', index_rows =>  5, dbitem => 0 },
    db => { txt => 'VNDB discussions',    post_perm => 'board',    index_rows => 10, dbitem => 0 },
    ge => { txt => 'General discussions', post_perm => 'board',    index_rows => 10, dbitem => 0 },
    v  => { txt => 'Visual novels',       post_perm => 'board',    index_rows => 10, dbitem => 1 },
    p  => { txt => 'Producers',           post_perm => 'board',    index_rows =>  5, dbitem => 1 },
    u  => { txt => 'Users',               post_perm => 'board',    index_rows =>  5, dbitem => 1 };



# SQL: ENUM blood_type
hash BLOOD_TYPE =>
    unknown => 'Unknown',
    o       => 'O',
    a       => 'A',
    b       => 'B',
    ab      => 'AB';



# SQL: ENUM gender
hash GENDER =>
    unknown => 'Unknown or N/A',
    m       => 'Male',
    f       => 'Female',
    b       => 'Both';



# SQL: ENUM cup_size
hash CUP_SIZE =>
    ''  => 'Unknown or N/A',
    AAA => 'AAA',
    AA  => 'AA',
    map +($_,$_), 'A'..'Z';



# SQL: ENUM char_role
hash CHAR_ROLE =>
    main    => { txt => 'Protagonist',         plural => 'Protagonists'       },
    primary => { txt => 'Main character',      plural => 'Main characters'    },
    side    => { txt => 'Side character',      plural => 'Side characters'    },
    appears => { txt => 'Makes an appearance', plural => 'Make an appearance' };




# Concise implementation of an immutable hash that remembers key order.
package VNDB::Types::Hash;
use v5.24;
sub TIEHASH { shift; bless [ [ map $_[$_*2], 0..$#_/2 ], +{@_}, 0 ], __PACKAGE__ };
sub FETCH { $_[0][1]{$_[1]} }
sub EXISTS { exists $_[0][1]{$_[1]} }
sub FIRSTKEY { $_[0][2] = 0; &NEXTKEY }
sub NEXTKEY { $_[0][0][ $_[0][2]++ ] }
sub SCALAR { scalar $_[0][0]->@* }
1;
