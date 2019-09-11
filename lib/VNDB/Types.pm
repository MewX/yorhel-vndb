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



# SQL: ENUM credit_type
hash CREDIT_TYPE =>
    scenario   => 'Scenario',
    chardesign => 'Character design',
    art        => 'Artist',
    music      => 'Composer',
    songs      => 'Vocals',
    director   => 'Director',
    staff      => 'Staff';
