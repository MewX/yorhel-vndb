#!/usr/bin/perl

use v5.24;
use warnings;
use Cwd 'abs_path';
use TUWF ':html_';
use Time::HiRes 'time';

$|=1; # Disable buffering on STDOUT, otherwise vndb-dev-server.pl won't pick up our readyness notification.

my $ROOT;
BEGIN { ($ROOT = abs_path $0) =~ s{/util/vndb\.pl$}{}; }

use lib $ROOT.'/lib';
use SkinFile;
use VNDB::Func ();
use VNDB::Config;
use VNWeb::Auth;
use VNWeb::HTML ();
use VNWeb::Validation ();


# load the skins
my $skin = SkinFile->new("$ROOT/static/s");
tuwf->{skins} = { map +($_ => [ $skin->get($_, 'name'), $skin->get($_, 'userid') ]), $skin->list };

# Some global variables
tuwf->{scr_size}     = [ 136, 102 ]; # w*h of screenshot thumbnails
tuwf->{ch_size}      = [ 256, 300 ]; # max. w*h of char images
tuwf->{cv_size}      = [ 256, 400 ]; # max. w*h of cover images
tuwf->{$_} = config->{$_} for keys %{ config() };

TUWF::set %{ config->{tuwf} };

# Signal to VNWeb::Elm whether it should generate the Elm files.
# Should be done before loading any more modules.
tuwf->{elmgen} = $ARGV[0] && $ARGV[0] eq 'elmgen';


sub _path {
    my($t, $id) = $_[1] =~ /([a-z]+)([0-9]+)/;
    $t = 'st' if $t eq 'sf' && $_[2];
    sprintf '%s/%s/%02d/%d.jpg', $_[0], $t, $id%100, $id;
}

# tuwf->imgpath($image_id, $thumb)
sub TUWF::Object::imgpath { _path "$ROOT/static", $_[1], $_[2] }

# tuwf->imgurl($image_id, $thumb)
sub TUWF::Object::imgurl { _path $_[0]{url_static}, $_[1], $_[2] }

# tuwf->samesite() - returns true if this request originated from the same site, i.e. not an external referer.
sub TUWF::Object::samesite { !!tuwf->reqCookie('samesite') }


TUWF::hook before => sub {
    # If we're running standalone, serve www/ and static/ too.
    if(tuwf->{_TUWF}{http}) {
        if(tuwf->resFile("$ROOT/www", tuwf->reqPath) || tuwf->resFile("$ROOT/static", tuwf->reqPath)) {
            tuwf->resHeader('Cache-Control' => 'max-age=31536000');
            tuwf->done;
        }
    }

    # Use a 'SameSite=Strict' cookie to determine whether this page was loaded from internal or external.
    # Ought to be more reliable than checking the Referer header, but it's unfortunately a bit uglier.
    tuwf->resCookie(samesite => 1, httponly => 1, samesite => 'Strict') if !tuwf->samesite;

    tuwf->req->{trace_start} = time if config->{trace_log};
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


sub TUWF::Object::resDenied {
    tuwf->resStatus(403);
    VNWeb::HTML::framework_ title => 'Access Denied', noindex => 1, sub {
        div_ class => 'mainbox', sub {
            h1_ 'Access Denied';
            div_ class => 'warning', sub {
                if(!auth) {
                    h2_ 'You need to be logged in to perform this action.';
                    p_ sub {
                        txt_ 'Please ';
                        a_ href => '/u/login', 'login';
                        txt_ ' or ';
                        a_ href => '/u/register', 'create an account';
                        txt_ " if you don't have one yet.";
                    }
                } else {
                    h2_ 'You are not allowed to perform this action.';
                    p_ 'You do not have the proper rights to perform the action you wanted to perform.';
                }
            }
        }
    }
}


# Intercept TUWF::any() and TUWF::register() to figure out which module is processing the request.
if(config->{trace_log}) {
    my sub wrap {
        my $f = shift;
        sub {
            my $i = 0;
            my $loc = ['',0];
            while(my($pack, undef, $line) = caller($i++)) {
                if($pack !~ '^(?:main|TUWF|VNWeb::Elm)') {
                    $loc = [$pack,$line];
                    last;
                }
            }
            my sub subwrap { my $sub = shift; sub { tuwf->req->{trace_loc} = $loc; $sub->(@_) } }
            $f->(map ref($_) eq 'CODE' ? subwrap($_) : $_, @_)
        }
    }
    no warnings 'redefine';
    my $x = \&TUWF::register; *TUWF::register = wrap($x);# sub { $x->(map ref($_) eq 'CODE' ? wrap($_) : $_, @_) };
    my $y = \&TUWF::any;      *TUWF::any      = wrap($y);# sub { $y->(map ref($_) eq 'CODE' ? wrap($_) : $_, @_) };
}

TUWF::load_recursive('VNDB::Util', 'VNDB::DB', 'VNDB::Handler');
TUWF::set import_modules => 0;
TUWF::load_recursive('VNWeb');

TUWF::hook after => sub {
    return if rand() > config->{trace_log} || !tuwf->req->{trace_start};
    my $sqlt = List::Util::sum(map $_->[2], tuwf->{_TUWF}{DB}{queries}->@*);
    my %elm = map +($_->[0], 1), tuwf->req->{pagevars}{elm}->@*;
    tuwf->dbExeci('INSERT INTO trace_log', {
        method    => tuwf->reqMethod(),
        path      => tuwf->reqPath(),
        query     => tuwf->reqQuery(),
        module    => tuwf->req->{trace_loc}[0],
        line      => tuwf->req->{trace_loc}[1],
        sql_num   => scalar grep($_->[0] ne 'ping/rollback' && $_->[0] ne 'commit', tuwf->{_TUWF}{DB}{queries}->@*),
        sql_time  => $sqlt,
        perl_time => time() - tuwf->req->{trace_start},
        loggedin  => auth?1:0,
        elm_mods  => '{'.join(',', sort keys %elm).'}'
    });
} if config->{trace_log};

TUWF::run if !tuwf->{elmgen};
