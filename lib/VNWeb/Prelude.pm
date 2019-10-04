# Importing this module is equivalent to:
#
#  use v5.26;
#  use warnings;
#  use utf8;
#
#  use TUWF ':html5_', 'mkclass';
#  use Exporter 'import';
#  use Time::HiRes 'time';
#  use List::Util 'min', 'max', 'sum';
#
#  use VNDBUtil;
#  use VNDB::BBCode;
#  use VNDB::Types;
#  use VNDB::Config;
#  use VNDB::Func 'fmtdate', 'fmtvote';
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

    use TUWF ':html5_', 'mkclass';
    use Exporter 'import';
    use Time::HiRes 'time';
    use List::Util 'min', 'max', 'sum';

    use VNDBUtil;
    use VNDB::BBCode;
    use VNDB::Types;
    use VNDB::Config;
    use VNDB::Func 'fmtdate', 'fmtvote';
    use VNWeb::Auth;
    use VNWeb::HTML;
    use VNWeb::DB;
    use VNWeb::Validation;
    use VNWeb::Elm;
    1;
    EOM;

    no strict 'refs';
    *{$c.'::RE'} = *RE;
    *{$c.'::json_api'} = \&json_api;
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
sub json_api {
    my($path, $keys, $sub) = @_;

    my $schema = ref $keys eq 'HASH' ? tuwf->compile({ type => 'hash', keys => $keys }) : $keys;

    TUWF::post $path => sub {
        if(!auth->csrfcheck(tuwf->reqHeader('X-CSRF-Token')||'')) {
            warn "Invalid CSRF token in request\n";
            return elm_CSRF;
        }

        my $data = tuwf->validate(json => $schema);
        if(!$data) {
            warn "JSON validation failed\ninput: " . JSON::XS->new->allow_nonref->pretty->canonical->encode(tuwf->reqJSON) . "\nerror: " . JSON::XS->new->encode($data->err) . "\n";
            return elm_Invalid;
        }

        $sub->($data->data);
        warn "Non-JSON response to a json_api request, is this intended?\n" if tuwf->resHeader('Content-Type') !~ /^application\/json/;
    };
}

1;
