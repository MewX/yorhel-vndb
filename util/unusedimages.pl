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
    DELETE FROM images WHERE id IN(
      SELECT id FROM images EXCEPT
      SELECT * FROM (
              SELECT scr   FROM vn_screenshots
        UNION SELECT scr   FROM vn_screenshots_hist
        UNION SELECT image FROM vn           WHERE image IS NOT NULL
        UNION SELECT image FROM vn_hist      WHERE image IS NOT NULL
        UNION SELECT image FROM chars        WHERE image IS NOT NULL
        UNION SELECT image FROM chars_hist   WHERE image IS NOT NULL
      ) x
    )
  });
  print "# Deleted unreferenced images: $cnt\n";
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

sub addimagessql {
  my $st = $db->prepare('SELECT vndbid_type(id), vndbid_num(id) FROM images');
  $st->execute();
  $count = 0;
  while((my $num = $st->fetch())) {
    $dir{$num->[0]}{$num->[1]} = 1;
    $count++;
  }
  print "# Items in `images'... $count\n";
};

sub findunused {
  my $size = 0;
  $count = 0;
  my $left = 0;
  find {
    no_chdir => 1,
    follow => 1,
    wanted => sub {
      return if -d "$File::Find::name";
      if($File::Find::name !~ /($fnmatch)$/) {
         print "# Unknown file: $File::Find::name\n";
         return;
      }
      if(!$dir{$2}{$3}) {
        my $s = (-s $File::Find::name) / 1024;
        $size += $s;
        $count++;
        printf "rm '%s' # %d KiB, https://s.vndb.org%s\n", $File::Find::name, $s, $1
      } else {
        $left++;
      }
    }
  }, "$ROOT/static/cv", "$ROOT/static/ch", "$ROOT/static/sf", "$ROOT/static/st";
  printf "# Deleted %d files, left %d files, saved %d KiB\n", $count, $left, $size;
}


cleandb;
addtxtsql 'Docs',                   'SELECT content FROM docs     UNION ALL SELECT content FROM docs_hist';
addtxtsql 'VN descriptions',        'SELECT "desc" FROM vn        UNION ALL SELECT "desc" FROM vn_hist';
addtxtsql 'Character descriptions', 'SELECT "desc" FROM chars     UNION ALL SELECT "desc" FROM chars_hist';
addtxtsql 'Producer descriptions',  'SELECT "desc" FROM producers UNION ALL SELECT "desc" FROM producers_hist';
addtxtsql 'Release descriptions',   'SELECT notes  FROM releases  UNION ALL SELECT notes  FROM releases_hist';
addtxtsql 'Staff descriptions',     'SELECT "desc" FROM staff     UNION ALL SELECT "desc" FROM staff_hist';
addtxtsql 'Tag descriptions',       'SELECT description FROM tags';
addtxtsql 'Trait descriptions',     'SELECT description FROM traits';
addtxtsql 'Change summaries',       'SELECT comments FROM changes';
addtxtsql 'Posts',                  'SELECT msg FROM threads_posts';
addimagessql;
findunused;
