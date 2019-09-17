# Listings and formatting functions for various data types in the database.

package VN3::Types;

use strict;
use warnings;
use utf8;
use TUWF ':Html5';
use POSIX 'strftime', 'ceil';
use Exporter 'import';
use VNDB::Types;

our @EXPORT = qw/
    $UID_RE $VID_RE $RID_RE $SID_RE $CID_RE $PID_RE $IID_RE $DOC_RE
    $VREV_RE $RREV_RE $PREV_RE $SREV_RE $CREV_RE $DREV_RE
    Lang
    Platform
    media_display
    ReleaseDate
    vn_length_time vn_length_display
    char_roles char_role_display
    vote_display vote_string
    date_display
    vn_relation_reverse vn_relation_display
    producer_relation_reverse producer_relation_display
    spoil_display
    release_types
    minage_display minage_display_full
    resolution_display_full
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


sub media_display {
    my($media, $qty) = @_;
    my $med = $MEDIUM{$media};
    return $med->{txt} if !$med->{qty};
    sprintf '%d %s', $qty, $qty == 1 ? $med->{txt} : $med->{plural};
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


sub vn_length_time {
    my $l = $VN_LENGTH{$_[0]};
    $l->{time} || $l->{txt};
}

sub vn_length_display {
    my $l = $VN_LENGTH{$_[0]};
    $l->{txt}.($l->{time} ? " ($l->{time})" : '')
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



sub release_types { keys %RELEASE_TYPE }


sub minage_display { $AGE_RATING{$_[0]}{txt} }
sub minage_display_full { my $e = $AGE_RATING{$_[0]}; $e->{txt}.($e->{ex} ? " (e.g. $e->{ex})" : '') };



sub resolution_display_full { my $e = $RESOLUTION{$_[0]}; ($e->{cat} ? ucfirst "$e->{cat}: " : '').$e->{txt} }


sub gender_display { $GENDER{$_[0]} }
sub gender_icon { +{qw/m ♂ f ♀ mf ♂♀/}->{$_[0]}||'' }



sub blood_type_display { $BLOOD_TYPE{$_[0]} }


1;
