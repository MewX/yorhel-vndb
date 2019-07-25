#!/usr/bin/perl

use strict;
use warnings;
use TUWF;

use Cwd 'abs_path';
my $ROOT;
BEGIN { ($ROOT = abs_path $0) =~ s{/util/vndb3\.pl$}{}; }
use lib $ROOT.'/lib';

use PWLookup;

$|=1; # Disable buffering on STDOUT, otherwise vndb-dev-server.pl won't pick up our readyness notification.

my $conf = require $ROOT.'/data/config3.pl';

# Make the configuration available as tuwf->conf
sub TUWF::Object::conf { $conf }


# Make our root path available as tuwf->root
# Optionally accepts other path components to assemble a file path:
#   tuwf->root('static/sf/01/1.jpg')
sub TUWF::Object::root { shift; join '/', $ROOT, @_ }


# tuwf->imgpath(cg => $image_id)
sub TUWF::Object::imgpath {
    tuwf->root(static => $_[1] => sprintf '%02d/%d.jpg', $_[2]%100, $_[2]);
}


# tuwf->imgurl(cv => $image_id)
sub TUWF::Object::imgurl {
    sprintf '%s/%s/%02d/%d.jpg', $_[0]->conf->{url_static}, $_[1], $_[2]%100, $_[2];
}


# tuwf->resDenied
sub TUWF::Object::resDenied {
    TUWF::_very_simple_page(403, '403 - Permission Denied', 'You do not have the permission to access this page.');
}

# tuwf->isUnsafePass($pass)
sub TUWF::Object::isUnsafePass {
    $_[0]->conf->{password_db} && PWLookup::lookup($_[0]->conf->{password_db}, $_[1])
}


TUWF::set %{ $conf->{tuwf} || {} };

TUWF::set import_modules => 0;

# If we're running standalone, serve www/ and static/ too.
TUWF::hook before => sub {
    my $static = tuwf->{_TUWF}{http} &&
        (  tuwf->resFile(tuwf->root('www'),    tuwf->reqPath)
        || tuwf->resFile(tuwf->root('static'), tuwf->reqPath)
        );
    if($static) {
        tuwf->resHeader('Cache-Control' => 'max-age=31536000');
        tuwf->done;
    }
};


require VN3::Validation; # Load this early, to ensure the custom_validations are available
TUWF::load_recursive 'VN3';
TUWF::run;
