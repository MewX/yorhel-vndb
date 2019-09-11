package VNDB::Types;

use v5.12;
no strict 'refs';
use warnings;
use Exporter 'import';
use Tie::IxHash;

our @EXPORT;

sub hash {
    my $name = shift;
    tie $name->%*, 'Tie::IxHash', @_;
    push @EXPORT, "%$name";
}

sub array {
    my $name = shift;
    $name->@* = @_;
    push @EXPORT, "\@$name";
}

sub fun($&) {
    my($name, $code) = @_;
    *$name = $code;
    push @EXPORT, $name;
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
    he => 'Hebrew',
    hr => 'Croatian',
    hu => 'Hungarian',
    id => 'Indonesian',
    it => 'Italian',
    ja => 'Japanese',
    ko => 'Korean',
    nl => 'Dutch',
    no => 'Norwegian',
    pl => 'Polish',
    'pt-br' => 'Portuguese (Brazil)',
    'pt-pt' => 'Portuguese (Portugal)',
    ro => 'Romanian',
    ru => 'Russian',
    sk => 'Slovak',
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
    ipa => { reverse => 'imp', txt => 'Parent brand '   };



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
    0 => { txt => 'Unknown',    time => '',              example => ''                                                  },
    1 => { txt => 'Very short', time => '< 2 hours',     example => 'OMGWTFOTL, Jouka no Monshou, The world to reverse' },
    2 => { txt => 'Short',      time => '2 - 10 hours',  example => 'Narcissu, Saya no Uta, Planetarian'                },
    3 => { txt => 'Medium',     time => '10 - 30 hours', example => 'Yume Miru Kusuri, Cross†Channel, Crescendo'        },
    4 => { txt => 'Long',       time => '30 - 50 hours', example => 'Tsukihime, Ever17, Demonbane'                      },
    5 => { txt => 'Very long',  time => '> 50 hours',    example => 'Clannad, Umineko, Fate/Stay Night'                 };



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



# SQL: ENUM blood_type
hash BLOOD_TYPE =>
    unknown => 'Unknown',
    o       => 'O',
    a       => 'A',
    b       => 'B',
    ab      => 'AB';

# SQL: ENUM blood_type
hash GENDER =>
    unknown => 'Unknown or N/A',
    m       => 'Male',
    f       => 'Female',
    b       => 'Both';

# SQL: ENUM char_role
hash CHAR_ROLE =>
    main    => { txt => 'Protagonist',         plural => 'Protagonists'       },
    primary => { txt => 'Main character',      plural => 'Main characters'    },
    side    => { txt => 'Side character',      plural => 'Side characters'    },
    appears => { txt => 'Makes an appearance', plural => 'Make an appearance' };
