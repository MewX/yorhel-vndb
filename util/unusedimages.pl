#!/usr/bin/perl

# This script finds all unused and unreferenced images in static/ and outputs a
# shell script to remove them.
#
# Use with care!

use strict;
use warnings;
use DBI;
use File::Find;
use Cwd 'abs_path';

my $ROOT;
BEGIN { ($ROOT = abs_path $0) =~ s{/util/unusedimages\.pl$}{}; }

my $db = DBI->connect('dbi:Pg:dbname=vndb', 'vndb', undef, { RaiseError => 1 });

my(%scr, %cv, %ch);
my $count = 0;

my $fnmatch = qr{/(cv|ch|sf|st)/[0-9][0-9]/([0-9]+)\.jpg};
my %dir = (cv => \%cv, ch => \%ch, sf => \%scr, st => \%scr);

sub cleandb {
  my $cnt = $db->do(q{
    DELETE FROM screenshots s
     WHERE NOT EXISTS(SELECT 1 FROM vn_screenshots_hist WHERE scr = s.id)
       AND NOT EXISTS(SELECT 1 FROM vn_screenshots WHERE scr = s.id)
  });
  print "# Deleted unreferenced screenshots: $cnt\n";
}

sub addtxt {
  my $t = shift;
  while($t =~ m{$fnmatch}g) {
    $dir{$1}{$2} = 1;
    $count++;
  }
}

sub addtxtsql {
  my($name, $query) = @_;
  $count = 0;
  my $st = $db->prepare($query);
  $st->execute();
  while((my $txt = $st->fetch())) {
    addtxt $txt->[0];
  }
  print "# References in $name... $count\n";
}

sub addnumsql {
  my($name, $tbl, $query) = @_;
  $count = 0;
  my $st = $db->prepare($query);
  $st->execute();
  while((my $num = $st->fetch())) {
    $tbl->{$num->[0]} = 1;
    $count++;
  }
  print "# Items in $name... $count\n";
}

sub adddoc {
  $count = 0;
  for my $fn (glob("$ROOT/data/docs/*")) {
    local $/=undef;
    open my $F, $fn or die "Can't open $fn: $!\n";
    addtxt scalar <$F>;
  }
  print "# Referencs in the docs: $count\n";
}

sub findunused {
  my $size = 0;
  $count = 0;
  find {
    no_chdir => 1,
    wanted => sub {
      return if $File::Find::name !~ /($fnmatch)$/;
      if(!$dir{$2}{$3}) {
        my $s = (-s $File::Find::name) / 1024;
        $size += $s;
        $count++;
        printf "rm '%s' # %d KiB, https://s.vndb.org%s\n", $File::Find::name, $s, $1
      }
    }
  }, "$ROOT/static";
  printf "# Deleted %d files, saved %d KiB\n", $count, $size;
}


cleandb;
adddoc;
addtxtsql 'VN descriptions',        'SELECT "desc" FROM vn        UNION ALL SELECT "desc" FROM vn_hist';
addtxtsql 'Character descriptions', 'SELECT "desc" FROM chars     UNION ALL SELECT "desc" FROM chars_hist';
addtxtsql 'Producer descriptions',  'SELECT "desc" FROM producers UNION ALL SELECT "desc" FROM producers_hist';
addtxtsql 'Release descriptions',   'SELECT notes  FROM releases  UNION ALL SELECT notes  FROM releases_hist';
addtxtsql 'Staff descriptions',     'SELECT "desc" FROM staff     UNION ALL SELECT "desc" FROM staff_hist';
addtxtsql 'Tag descriptions',       'SELECT description FROM tags';
addtxtsql 'Trait descriptions',     'SELECT description FROM traits';
addtxtsql 'Change summaries',       'SELECT comments FROM changes';
addtxtsql 'Posts',                  'SELECT msg FROM threads_posts';
addnumsql 'Screenshots', \%scr,     'SELECT id FROM screenshots';
addnumsql 'VN images', \%cv,        'SELECT image FROM vn    UNION ALL SELECT image from vn_hist';
addnumsql 'Character images', \%ch, 'SELECT image FROM chars UNION ALL SELECT image from chars_hist';
findunused;
