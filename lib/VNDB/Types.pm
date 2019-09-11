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



# SQL: ENUM credit_type
hash CREDIT_TYPE =>
    scenario   => 'Scenario',
    chardesign => 'Character design',
    art        => 'Artist',
    music      => 'Composer',
    songs      => 'Vocals',
    director   => 'Director',
    staff      => 'Staff';
