# Listings and formatting functions for various data types in the database.

package VN3::Types;

use strict;
use warnings;
use utf8;
use Tie::IxHash;
use TUWF ':Html5';
use POSIX 'strftime', 'ceil';
use Exporter 'import';
use VNDB::Types;

our @EXPORT = qw/
    $UID_RE $VID_RE $RID_RE $SID_RE $CID_RE $PID_RE $IID_RE $DOC_RE
    $VREV_RE $RREV_RE $PREV_RE $SREV_RE $CREV_RE $DREV_RE
    Lang
    Platform
    %MEDIA media_display
    ReleaseDate
    @VN_LENGTHS vn_length_time vn_length_display
    char_roles char_role_display
    vote_display vote_string
    date_display
    vn_relation_reverse vn_relation_display
    producer_relation_reverse producer_relation_display
    spoil_display
    release_types
    @MINAGE minage_display minage_display_full
    %RESOLUTIONS resolution_display_full
    @VOICED
    @ANIMATED
    gender_display gender_icon
    blood_type_display
/;


# Regular expressions for use in path registration
my $num = qr{[1-9][0-9]{0,6}};
our $UID_RE = qr{u(?<id>$num)};
our $VID_RE = qr{v(?<id>$num)};
our $RID_RE = qr{r(?<id>$num)};
our $SID_RE = qr{s(?<id>$num)};
our $CID_RE = qr{c(?<id>$num)};
our $PID_RE = qr{p(?<id>$num)};
our $IID_RE = qr{i(?<id>$num)};
our $DOC_RE = qr{d(?<id>$num)};
our $VREV_RE = qr{$VID_RE(?:\.(?<rev>$num))?};
our $RREV_RE = qr{$RID_RE(?:\.(?<rev>$num))?};
our $PREV_RE = qr{$PID_RE(?:\.(?<rev>$num))?};
our $SREV_RE = qr{$SID_RE(?:\.(?<rev>$num))?};
our $CREV_RE = qr{$CID_RE(?:\.(?<rev>$num))?};
our $DREV_RE = qr{$DOC_RE(?:\.(?<rev>$num))?};


sub Lang {
    Span class => 'lang-badge', uc $_[0];
}



sub Platform {
    # TODO: Icons
    Img class => 'svg-icon', src => tuwf->conf->{url_static}.'/v3/windows.svg', title => $PLATFORM{$_[0]};
}



# The 'unk' medium is reserved for "unknown" in release filters.
our %MEDIA;
tie %MEDIA, 'Tie::IxHash',
    cd  => { qty => 1, single => 'CD',                    plural => 'CDs',                   },
    dvd => { qty => 1, single => 'DVD',                   plural => 'DVDs',                  },
    gdr => { qty => 1, single => 'GD-ROM',                plural => 'GD-ROMs',               },
    blr => { qty => 1, single => 'Blu-ray disc',          plural => 'Blu-ray discs',         },
    flp => { qty => 1, single => 'Floppy',                plural => 'Floppies',              },
    mrt => { qty => 1, single => 'Cartridge',             plural => 'Cartridges',            },
    mem => { qty => 1, single => 'Memory card',           plural => 'Memory cards',          },
    umd => { qty => 1, single => 'UMD',                   plural => 'UMDs',                  },
    nod => { qty => 1, single => 'Nintendo Optical Disc', plural => 'Nintendo Optical Discs' },
    in  => { qty => 0, single => 'Internet download',     plural => '',                      },
    otc => { qty => 0, single => 'Other',                 plural => '',                      };

sub media_display {
    my($media, $qty) = @_;
    my $med = $MEDIA{$media};
    return $med->{single} if !$med->{qty};
    sprintf '%d %s', $qty, $qty == 1 ? $med->{single} : $med->{plural};
}




sub ReleaseDate {
    my $date = sprintf '%08d', shift||0;
    my $future = $date > strftime '%Y%m%d', gmtime;
    my($y, $m, $d) = ($1, $2, $3) if $date =~ /^([0-9]{4})([0-9]{2})([0-9]{2})$/;

    my $str = $y ==  0 ? 'unknown' : $y == 9999 ? 'TBA' :
              $m == 99 ? sprintf('%04d', $y) :
              $d == 99 ? sprintf('%04d-%02d', $y, $m) :
                         sprintf('%04d-%02d-%02d', $y, $m, $d);

    Txt $str if !$future;
    B class => 'future', $str if $future;
}



our @VN_LENGTHS = (
    # name          time             examples
    [ 'Unknown',    '',              ''                                                  ],
    [ 'Very short', '< 2 hours',     'OMGWTFOTL, Jouka no Monshou, The world to reverse' ],
    [ 'Short',      '2 - 10 hours',  'Narcissu, Saya no Uta, Planetarian'                ],
    [ 'Medium',     '10 - 30 hours', 'Yume Miru Kusuri, Cross†Channel, Crescendo'        ],
    [ 'Long',       '30 - 50 hours', 'Tsukihime, Ever17, Demonbane'                      ],
    [ 'Very long',  '> 50 hours',    'Clannad, Umineko, Fate/Stay Night'                 ],
);

sub vn_length_time {
    my $l = $VN_LENGTHS[$_[0]];
    $l->[1] || $l->[0];
}

sub vn_length_display {
    my $l = $VN_LENGTHS[$_[0]];
    $l->[0].($l->[1] ? " ($l->[1])" : '')
}



sub char_role_display {
    my($role, $num) = @_;
    $CHAR_ROLE{$role}{!$num || $num == 1 ? 'txt' : 'plural'};
}



sub vote_display {
    !$_[0] ? '-' : $_[0] % 10 == 0 ? $_[0]/10 : sprintf '%.1f', $_[0]/10;
}

sub vote_string {
    ['worst ever',
     'awful',
     'bad',
     'weak',
     'so-so',
     'decent',
     'good',
     'very good',
     'excellent',
     'masterpiece']->[ceil(shift()/10)-2];
}



sub date_display {
    strftime '%Y-%m-%d', gmtime $_[0];
}



sub vn_relation_reverse { $VN_RELATION{$_[0]}{reverse} }
sub vn_relation_display { $VN_RELATION{$_[0]}{txt} }



sub producer_relation_reverse { $PRODUCER_RELATION{$_[0]}{reverse} }
sub producer_relation_display { $PRODUCER_RELATION{$_[0]}{txt} }



sub spoil_display {
    ['No spoilers'
    ,'Minor spoilers'
    ,'Spoil me!']->[$_[0]];
}



my @RELEASE_TYPES = qw/complete partial trial/;

sub release_types { @RELEASE_TYPES }



# XXX: Apparently, unknown is stored in the DB as -1 rather than NULL, even
# though the column is marked as nullable; probably needs some fixing for
# consistency.
our @MINAGE = (0, 6..18);
my %MINAGE_EX = (
     0 => 'CERO A',
    12 => 'CERO B',
    15 => 'CERO C',
    17 => 'CERO D',
    18 => 'CERO Z',
);

sub minage_display { !defined $_[0] || $_[0] < 0 ? 'Unknown' : !$_[0] ? 'All ages' : sprintf '%d+', $_[0] }

sub minage_display_full { my $e = $MINAGE_EX{$_[0]||''}; minage_display($_[0]).($e ? " (e.g. $e)" : '') };



our %RESOLUTIONS;
tie %RESOLUTIONS, 'Tie::IxHash',
    # DB             # Display       # Category
    unknown     => [ 'Unknown / console / handheld', '' ],
    nonstandard => [ 'Non-standard', '' ],
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
    '1920x1080' => [ '1920x1080',    'widescreen' ];

sub resolution_display_full { my $e = $RESOLUTIONS{$_[0]}; ($e->[1] ? ucfirst "$e->[1]: " : '').$e->[0] }



our @VOICED = ('Unknown', 'Not voiced', 'Only ero scenes voiced', 'Partially voiced', 'Fully voiced');

our @ANIMATED = ('Unknown', 'No animations', 'Simple animations', 'Some fully animated scenes', 'All scenes fully animated');



sub gender_display { $GENDER{$_[0]} }
sub gender_icon { +{qw/m ♂ f ♀ mf ♂♀/}->{$_[0]}||'' }



sub blood_type_display { $BLOOD_TYPE{$_[0]} }


1;
