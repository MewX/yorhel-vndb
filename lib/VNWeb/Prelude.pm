# Importing this module is equivalent to:
#
#  use v5.26;
#  use warnings;
#  use utf8;
#
#  use TUWF ':html5_', 'mkclass', 'xml_string';
#  use Exporter 'import';
#  use Time::HiRes 'time';
#  use List::Util 'min', 'max', 'sum';
#  use POSIX 'ceil', 'floor';
#
#  use VNDBUtil;
#  use VNDB::BBCode;
#  use VNDB::Types;
#  use VNDB::Config;
#  use VNDB::Func qw/fmtdate fmtage fmtvote fmtspoil fmtmedia minage query_encode lang_attr/;
#  use VNDB::ExtLinks;
#  use VNWeb::Auth;
#  use VNWeb::HTML;
#  use VNWeb::DB;
#  use VNWeb::Validation;
#  use VNWeb::Elm;
#
# + A few other handy tools.
#
# WARNING: This should not be used from the above modules.
package VNWeb::Prelude;

use strict;
use warnings;
use feature ':5.26';
use utf8;
use VNWeb::Elm;
use VNWeb::Auth;
use TUWF;
use JSON::XS;


sub import {
    my $c = caller;

    strict->import;
    warnings->import;
    feature->import(':5.26');
    utf8->import;

    die $@ if !eval <<"    EOM;";
    package $c;

    use TUWF ':html5_', 'mkclass', 'xml_string';
    use Exporter 'import';
    use Time::HiRes 'time';
    use List::Util 'min', 'max', 'sum';
    use POSIX 'ceil', 'floor';

    use VNDBUtil;
    use VNDB::BBCode;
    use VNDB::Types;
    use VNDB::Config;
    use VNDB::Func qw/fmtdate fmtage fmtvote fmtspoil fmtmedia minage query_encode lang_attr/;
    use VNDB::ExtLinks;
    use VNWeb::Auth;
    use VNWeb::HTML;
    use VNWeb::DB;
    use VNWeb::Validation;
    use VNWeb::Elm;
    1;
    EOM;

    no strict 'refs';
    *{$c.'::RE'} = *RE;
    *{$c.'::in'} = \&in;
}


# Regular expressions for use in path registration
my $num = qr{[1-9][0-9]{0,8}};
my $id = qr{(?<id>$num)};
my $rev = qr{(?:\.(?<rev>$num))};
our %RE = (
    num  => qr{(?<num>$num)},
    uid  => qr{u$id},
    vid  => qr{v$id},
    rid  => qr{r$id},
    sid  => qr{s$id},
    cid  => qr{c$id},
    pid  => qr{p$id},
    iid  => qr{i$id},
    did  => qr{d$id},
    tid  => qr{t$id},
    gid  => qr{g$id},
    vrev => qr{v$id$rev?},
    rrev => qr{r$id$rev?},
    prev => qr{p$id$rev?},
    srev => qr{s$id$rev?},
    crev => qr{c$id$rev?},
    drev => qr{d$id$rev?},
    postid => qr{t$id\.(?<num>$num)},
);


# Simple "is this element in the array?" function, using 'eq' to test equality.
# Supports both an @array and \@array.
# Usage:
#
#   my $contains_hi = in 'hi', qw/ a b hi c /; # true
#
sub in {
    my($q, @a) = @_;
    $_ eq $q && return 1 for map ref $_ eq 'ARRAY' ? @$_ : ($_), @a;
    0
}

1;
