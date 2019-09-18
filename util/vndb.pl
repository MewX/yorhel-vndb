#!/usr/bin/perl

use v5.24;
use warnings;
use Cwd 'abs_path';
use TUWF ':html_';

$|=1; # Disable buffering on STDOUT, otherwise vndb-dev-server.pl won't pick up our readyness notification.

my $ROOT;
BEGIN { ($ROOT = abs_path $0) =~ s{/util/vndb\.pl$}{}; }

use lib $ROOT.'/lib';
use SkinFile;
use VNDB::Config;
use VNWeb::HTML ();


# load the skins
my $skin = SkinFile->new("$ROOT/static/s");
tuwf->{skins} = { map +($_ => [ $skin->get($_, 'name'), $skin->get($_, 'userid') ]), $skin->list };

# Some global variables
tuwf->{scr_size}     = [ 136, 102 ]; # w*h of screenshot thumbnails
tuwf->{ch_size}      = [ 256, 300 ]; # max. w*h of char images
tuwf->{cv_size}      = [ 256, 400 ]; # max. w*h of cover images
tuwf->{permissions}  = {qw| board 1  boardmod 2  edit 4  tag 16  dbmod 32  tagmod 64  usermod 128 |};
tuwf->{default_perm} = 1+4+16; # Keep synchronised with the default value of users.perm
tuwf->{$_} = config->{$_} for keys %{ config() };

TUWF::set %{ config->{tuwf} };


TUWF::hook before => sub {
    # If we're running standalone, serve www/ and static/ too.
    if(tuwf->{_TUWF}{http}) {
        if(tuwf->resFile("$ROOT/www", tuwf->reqPath) || tuwf->resFile("$ROOT/static", tuwf->reqPath)) {
            tuwf->resHeader('Cache-Control' => 'max-age=31536000');
            tuwf->done;
        }
    }

    # load some stats (used for about all pageviews, anyway)
    tuwf->{stats} = tuwf->dbStats;
};


TUWF::set error_404_handler => sub {
    tuwf->resStatus(404);
    VNWeb::HTML::framework_ title => 'Page Not Found', noindex => 1, sub {
        div_ class => 'mainbox', sub {
            h1_ 'Page not found';
            div_ class => 'warning', sub {
                h2_ 'Oops!';
                p_;
                txt_ 'It seems the page you were looking for does not exist,';
                br_;
                txt_ 'you may want to try using the menu on your left to find what you are looking for.';
            }
        }
    }
};


TUWF::load_recursive('VNDB::Util', 'VNDB::DB', 'VNDB::Handler', 'VNWeb');
TUWF::run();
