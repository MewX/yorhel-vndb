package VNWeb::Releases::Lib;

use VNWeb::Prelude;
use Exporter 'import';

our @EXPORT = qw/release_extlinks_/;


# Generate the html for an 'external links' dropdown, assumes enrich_extlinks() has already been called on this object.
sub release_extlinks_ {
    my($r, $id) = @_;
    return if !$r->{extlinks}->@*;

    if($r->{extlinks}->@* == 1 && $r->{website}) {
        a_ href => $r->{website}, sub {
            abbr_ class => 'icons external', title => 'Official website', '';
        };
        return
    }

    div_ class => 'elm_dd_noarrow elm_dd_hover elm_dd_left elm_dd_relextlink', sub {
        div_ class => 'elm_dd', sub {
            a_ href => $r->{website}||'#', sub {
                txt_ scalar $r->{extlinks}->@*;
                abbr_ class => 'icons external', title => 'External link', '';
            };
            div_ sub {
                ul_ sub {
                    li_ sub {
                        a_ href => $_->[1], sub {
                            span_ $_->[2] if length $_->[2];
                            txt_ $_->[0];
                        }
                    } for $r->{extlinks}->@*;
                }
            }
        }
    }
}

1;
