# Importing this module is equivalent to:
#
#  use strict;
#  use warnings;
#  use v5.10;
#  use utf8;
#
#  use TUWF ':Html5', 'mkclass';
#  use Exporter 'import';
#  use Time::HiRes 'time';
#
#  use VNDBUtil;
#  use VN3::HTML;
#  use VN3::Auth;
#  use VN3::DB;
#  use VN3::Types;
#  use VN3::Validation;
#  use VN3::BBCode;
#
# WARNING: This should not be used from the above modules.
package VN3::Prelude;

use strict;
use warnings;
use utf8;
use feature ':5.10';

sub import {
    my $c = caller;

    strict->import;
    warnings->import;
    feature->import(':5.10');
    utf8->import;

    die $@ if !eval <<"    EOM;";
    package $c;

    use TUWF ':Html5', 'mkclass';
    use Exporter 'import';
    use Time::HiRes 'time';

    use VNDBUtil;
    use VN3::HTML;
    use VN3::Auth;
    use VN3::DB;
    use VN3::Types;
    use VN3::Validation;
    use VN3::BBCode;
    1;
    EOM;
}

1;
