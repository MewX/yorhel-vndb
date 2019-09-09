#!/usr/bin/perl

package VNDB;

use strict;
use warnings;
use Cwd 'abs_path';
eval { require CSS::Minifier::XS };

our($ROOT, %S);
BEGIN { ($ROOT = abs_path $0) =~ s{/util/skingen\.pl$}{}; }

use lib "$ROOT/lib";
use SkinFile;

require $ROOT.'/data/global.pl';


my $iconcss = do {
  open my $F, '<', "$ROOT/data/icons/icons.css" or die $!;
  local $/=undef;
  <$F>;
};


sub imgsize {
  open my $IMG, '<', $_[0] or die $!;
  sysread $IMG, my $buf, 1024 or die $!;
  $buf =~ /\xFF\xC0...(....)/s ? unpack('nn', $1) : $buf =~ /IHDR(.{8})/s ? unpack('NN', $1) : die;
}


sub rdcolor {
  length $_[0] == 4 ? map hex($_)/15,  $_[0] =~ /#(.)(.)(.)/ : #RGB
  length $_[0] == 7 ? map hex($_)/255, $_[0] =~ /#(..)(..)(..)/ : #RRGGBB
  length $_[0] == 9 ? map hex($_)/255, $_[0] =~ /#(..)(..)(..)(..)/ : #RRGGBBAA
  die;
}


sub blend {
  my($f, $b) = @_;
  my @f = rdcolor $f;
  my @b = rdcolor $b;
  $f[3] //= 1;
  sprintf '#%02x%02x%02x',
    ($f[0] * $f[3] + $b[0] * (1 - $f[3]))*255,
    ($f[1] * $f[3] + $b[1] * (1 - $f[3]))*255,
    ($f[2] * $f[3] + $b[2] * (1 - $f[3]))*255;
}


sub writeskin { # $name
  my $name = shift;
  my $skin = SkinFile->new("$ROOT/static/s", $name);
  my %o = map +($_ => $skin->get($_)), $skin->get;
  $o{iconcss} = $iconcss;

  # get the right top image
  if($o{imgrighttop}) {
    my $path = "/s/$name/$o{imgrighttop}";
    my($h, $w) = imgsize "$ROOT/static$path";
    $o{_bgright} = sprintf 'background: url(%s?%s) no-repeat; width: %dpx; height: %dpx', $path, $S{version}, $w, $h;
  } else {
    $o{_bgright} = 'display: none';
  }

  # body background
  if($o{imglefttop}) {
    $o{_bodybg} = sprintf 'background: %s url(/s/%s/%s?%s) no-repeat', $o{bodybg}, $name, $o{imglefttop}, $S{version};
  } else {
    $o{_bodybg} = sprintf 'background-color: %s', $o{bodybg};
  }

  # boxbg blended with bodybg
  $o{_blendbg} = blend $o{boxbg}, $o{bodybg};

  # version
  $o{version} = $S{version};

  # write the CSS
  open my $CSS, '<', "$ROOT/data/style.css" or die $!;
  my $css = join '', <$CSS>;
  close $CSS;
  $css =~ s/\$$_\$/$o{$_}/g for (keys %o);

  my $f = "$ROOT/static/s/$name/style.css";
  open my $SKIN, '>', "$f~" or die $!;
  print $SKIN $CSS::Minifier::XS::VERSION ? CSS::Minifier::XS::minify($css) : $css;
  close $SKIN;

  rename "$f~", $f;

  if($VNDB::SKINGEN{gzip}) {
    `$VNDB::SKINGEN{gzip} -c '$f' >'$f.gz~'`;
    rename "$f.gz~", "$f.gz";
  }
}


if(@ARGV) {
  writeskin($_) for (@ARGV);
} else {
  writeskin($_) for (SkinFile->new("$ROOT/static/s")->list);
}


