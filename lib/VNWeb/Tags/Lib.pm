package VNWeb::Tags::Lib;

use VNWeb::Prelude;
use Exporter 'import';

our @EXPORT = qw/ tagscore_ /;

sub tagscore_ {
    my($s, $ign) = @_;
    div_ mkclass(tagscore => 1, negative => $s < 0, ignored => $ign), sub {
        span_ sprintf '%.1f', $s;
        div_ style => sprintf('width: %.0fpx', abs $s/3*30), '';
    };
}

1;
