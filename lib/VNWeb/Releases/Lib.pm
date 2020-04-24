package VNWeb::Releases::Lib;

use VNWeb::Prelude;
use Exporter 'import';

our @EXPORT = qw/release_extlinks_/;


# Generate the html for an 'external links' dropdown, assumes enrich_extlinks() has already been called on this object.
sub release_extlinks_ {
    my($r, $id) = @_;
    return if !$r->{extlinks}->@*;
    my $has_dd = $r->{extlinks}->@* > ($r->{website} ? 1 : 0);
    my sub icon_ {
        a_ href => $r->{website}||'#', sub {
            txt_ scalar $r->{extlinks}->@* if $has_dd;
            abbr_ class => 'icons external', title => 'External link', '';
        }
    }
    elm_ ReleaseExtLinks => undef, [ ''.($id||$r->{id}), $r->{extlinks} ], \&icon_ if $has_dd;
    icon_ if !$has_dd;
}

1;
