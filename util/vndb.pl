#!/usr/bin/perl

use strict;
use warnings;
use Cwd 'abs_path';
use TUWF ':html';

$|=1; # Disable buffering on STDOUT, otherwise vndb-dev-server.pl won't pick up our readyness notification.

my $ROOT;
BEGIN { ($ROOT = abs_path $0) =~ s{/util/vndb\.pl$}{}; }

use lib $ROOT.'/lib';
use SkinFile;
use VNDB::Config;


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

TUWF::set(
  %{ config->{tuwf} },
  pre_request_handler => \&reqinit,
  error_404_handler => \&handle404,
  log_format => \&logformat,
);
TUWF::load_recursive('VNDB::Util', 'VNDB::DB', 'VNDB::Handler', 'VNWeb');
TUWF::run();


sub reqinit {
  my $self = shift;

  # If we're running standalone, serve www/ and static/ too.
  if($TUWF::OBJ->{_TUWF}{http}) {
    if($self->resFile("$ROOT/www", $self->reqPath) || $self->resFile("$ROOT/static", $self->reqPath)) {
      $self->resHeader('Cache-Control' => 'max-age=31536000');
      return 0;
    }
  }

  # check authentication cookies
  $self->authInit;

  # load some stats (used for about all pageviews, anyway)
  $self->{stats} = $self->dbStats;

  return 1;
}


sub handle404 {
  my $self = shift;
  $self->resStatus(404);
  $self->htmlHeader(title => 'Page Not Found');
  div class => 'mainbox';
   h1 'Page not found';
   div class => 'warning';
    h2 'Oops!';
    p;
     txt 'It seems the page you were looking for does not exist,';
     br;
     txt 'you may want to try using the menu on your left to find what you are looking for.';
    end;
   end;
  end;
  $self->htmlFooter;
}


# log user IDs (necessary for determining performance issues, user preferences
# have a lot of influence in this)
sub logformat {
  my($self, $uri, $msg) = @_;
  sprintf "[%s] %s %s: %s\n", scalar localtime(), $uri,
    $self->authInfo->{id} ? 'u'.$self->authInfo->{id} : '-', $msg;
}
