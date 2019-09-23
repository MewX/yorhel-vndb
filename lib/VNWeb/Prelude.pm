# Importing this module is equivalent to:
#
#  use v5.26;
#  use warnings;
#  use utf8;
#
#  use TUWF ':html5_', 'mkclass';
#  use Exporter 'import';
#  use Time::HiRes 'time';
#
#  use VNDBUtil;
#  use VNDB::Types;
#  use VNDB::Config;
#  use VNWeb::Auth;
#  use VNWeb::HTML;
#  use VNWeb::DB;
#
# WARNING: This should not be used from the above modules.
package VNWeb::Prelude;

use strict;
use warnings;
use feature ':5.26';
use utf8;

sub import {
    my $c = caller;

    strict->import;
    warnings->import;
    feature->import(':5.26');
    utf8->import;

    die $@ if !eval <<"    EOM;";
    package $c;

    use TUWF ':html5_', 'mkclass';
    use Exporter 'import';
    use Time::HiRes 'time';

    use VNDBUtil;
    use VNDB::Types;
    use VNDB::Config;
    use VNWeb::Auth;
    use VNWeb::HTML;
    use VNWeb::DB;
    1;
    EOM;

    no strict 'refs';
    *{$c.'::RE'} = *RE;
}


# Regular expressions for use in path registration
my $num = qr{[1-9][0-9]{0,6}};
my $id = qr{(?<id>$num)};
my $rev = qr{(?:\.(?<rev>$num))};
our %RE = (
    uid  => qr{u$id},
    vid  => qr{v$id},
    rid  => qr{r$id},
    sid  => qr{s$id},
    cid  => qr{c$id},
    pid  => qr{p$id},
    iid  => qr{i$id},
    did  => qr{d$id},
    vrev => qr{v$id$rev?},
    rrev => qr{r$id$rev?},
    prev => qr{p$id$rev?},
    srev => qr{s$id$rev?},
    crev => qr{c$id$rev?},
    drev => qr{d$id$rev?},
);

1;
