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
#  use VN3::ElmGen;
#
# WARNING: This should not be used from the above modules.
#
# This module also exports a few utility functions for writing URI handlers.
package VN3::Prelude;

use strict;
use warnings;
use utf8;
use feature ':5.10';
use TUWF;
use VN3::Auth;
use VN3::ElmGen;

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
    use VN3::ElmGen;
    1;
    EOM;

    no strict 'refs';
    *{$c.'::json_api'} = \&json_api;
}



# Easy wrapper to create a simple API that accepts JSON data on POST requests.
# The CSRF token and the input data are validated before the subroutine is
# called.
#
# Usage:
#
#   json_api '/some/url', {
#       username => { maxlength => 10 },
#   }, sub {
#       my $validated_data = shift;
#   };
my $elm_Invalid = elm_api 'Invalid', {};
sub json_api {
    my($path, $keys, $sub) = @_;

    my $schema = ref $keys eq 'HASH' ? tuwf->compile({ type => 'hash', keys => $keys }) : $keys;

    TUWF::post $path => sub {
        if(!auth->csrfcheck(tuwf->reqHeader('X-CSRF-Token')||'')) {
            warn "Invalid CSRF token in request\n";
            $elm_CSRF->();
            return;
        }

        my $data = tuwf->validate(json => $schema);
        if(!$data) {
            warn "JSON validation failed\ninput: " . JSON::XS->new->allow_nonref->pretty->canonical->encode(tuwf->reqJSON) . "\nerror: " . JSON::XS->new->encode($data->err) . "\n";
            $elm_Invalid->($data->err);
            return;
        }

        $sub->($data->data);
        warn "Non-JSON response to a json_api request, is this intended?\n" if tuwf->resHeader('Content-Type') !~ /^application\/json/;
    };
}

1;
