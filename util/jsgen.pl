#!/usr/bin/perl

package VNDB;

use strict;
use warnings;
use Encode 'encode_utf8';
use Cwd 'abs_path';
use JSON::XS;

our($ROOT, %S, %O);
BEGIN { ($ROOT = abs_path $0) =~ s{/util/jsgen\.pl$}{}; }
require $ROOT.'/data/global.pl';

use lib "$ROOT/lib";
use VNDB::Types;


# screen resolution information, suitable for usage in filFSelect()
sub resolutions {
  my $cat = '';
  my @r;
  my $push = \@r;
  for my $i (keys %{$S{resolutions}}) {
    my $r = $S{resolutions}{$i};
    if($cat ne $r->[1]) {
      push @r, [$r->[1]];
      $cat = $r->[1];
      $push = $r[$#r];
    }
    push @$push, [$i, $r->[0]];
  }
  \@r
}


sub vars {
  my %vars = (
    rlist_status  => $S{rlist_status},
    cookie_prefix => $O{cookie_prefix},
    age_ratings   => [ map [ $_, $_ == -1 ? 'Unknown' : $_ == 0 ? 'All ages' : "$_+" ], @{$S{age_ratings}} ],
    languages     => [ map [ $_, $LANGUAGE{$_} ], keys %LANGUAGE ],
    platforms     => [ map [ $_, $PLATFORM{$_} ], keys %PLATFORM ],
    char_roles    => [ map [ $_, $S{char_roles}{$_}[0] ], keys %{$S{char_roles}} ],
    media         => [ map [ $_, $S{media}{$_}[1], $S{media}{$_}[0] ], keys %{$S{media}} ],
    release_types => [ map [ $_, ucfirst $_ ], @{$S{release_types}} ],
    animated      => [ map [ $_, $S{animated}[$_] ], 0..$#{$S{animated}} ],
    voiced        => [ map [ $_, $S{voiced}[$_] ], 0..$#{$S{voiced}} ],
    vn_lengths    => [ map [ $_, $S{vn_lengths}[$_][0] ], 0..$#{$S{vn_lengths}} ],
    blood_types   => [ map [ $_, $S{blood_types}{$_} ], keys %{$S{blood_types}} ],
    genders       => [ map [ $_, $S{genders}{$_} ], keys %{$S{genders}} ],
    credit_type   => [ map [ $_, $CREDIT_TYPE{$_} ], keys %CREDIT_TYPE ],
    resolutions   => scalar resolutions(),
  );
  JSON::XS->new->encode(\%vars);
}


# Reads main.js and any included files.
sub readjs {
  my $f = shift || 'main.js';
  open my $JS, '<:utf8', "$ROOT/data/js/$f" or die $!;
  local $/ = undef;
  local $_ = <$JS>;
  close $JS;
  s{^//include (.+)$}{'(function(){'.readjs($1).'})();'}meg;
  $_;
}


sub save {
  my($f, $body) = @_;
  open my $F, '>', "$f~" or die $!;
  print $F encode_utf8($body);
  close $F;
  rename "$f~", $f or die $!;
}


my $js = readjs;
$js =~ s{/\*VARS\*/}{vars()}eg;
save "$ROOT/static/f/vndb.js", $js;
