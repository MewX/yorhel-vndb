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

my $count = 0;
my $fnmatch = '/(cv|ch|sf|st)/[0-9][0-9]/([1-9][0-9]{0,6})\.jpg';

my(%scr, %cv, %ch);
my %dir = (cv => \%cv, ch => \%ch, sf => \%scr, st => \%scr);


sub cleandb {
    # Delete all images from the `images` table that are not referenced from
    # *anywhere* in the database, including old revisions and links found in
    # comments, descriptions and docs.
    # The 30 (100, in the case of screenshots) most recently uploaded images of
    # each type are also kept because there's a good chance they will get
    # referenced from somewhere, soon.
    my $cnt = $db->do(q{
      DELETE FROM images WHERE id IN(
        SELECT id FROM images EXCEPT
         WHERE id NOT IN(SELECT id FROM images WHERE id BETWEEN vndbid('ch',1) AND vndbid_max('ch') ORDER BY id DESC LIMIT  30)
           AND id NOT IN(SELECT id FROM images WHERE id BETWEEN vndbid('cv',1) AND vndbid_max('cv') ORDER BY id DESC LIMIT  30)
           AND id NOT IN(SELECT id FROM images WHERE id BETWEEN vndbid('sf',1) AND vndbid_max('sf') ORDER BY id DESC LIMIT 100)
        SELECT * FROM (
                SELECT scr   FROM vn_screenshots
          UNION SELECT scr   FROM vn_screenshots_hist
          UNION SELECT image FROM vn           WHERE image IS NOT NULL
          UNION SELECT image FROM vn_hist      WHERE image IS NOT NULL
          UNION SELECT image FROM chars        WHERE image IS NOT NULL
          UNION SELECT image FROM chars_hist   WHERE image IS NOT NULL
          UNION (
            SELECT vndbid(case when img[1] = 'st' then 'sf' else img[1] end, img[2]::int)
              FROM (      SELECT content FROM docs
                UNION ALL SELECT content FROM docs_hist
                UNION ALL SELECT "desc" FROM vn
                UNION ALL SELECT "desc" FROM vn_hist
                UNION ALL SELECT "desc" FROM chars
                UNION ALL SELECT "desc" FROM chars_hist
                UNION ALL SELECT "desc" FROM producers
                UNION ALL SELECT "desc" FROM producers_hist
                UNION ALL SELECT notes  FROM releases
                UNION ALL SELECT notes  FROM releases_hist
                UNION ALL SELECT "desc" FROM staff
                UNION ALL SELECT "desc" FROM staff_hist
                UNION ALL SELECT description FROM tags
                UNION ALL SELECT description FROM traits
                UNION ALL SELECT comments FROM changes
                UNION ALL SELECT msg FROM threads_posts
              ) x(text), regexp_matches(text, '}.$fnmatch.q{', 'g') as y(img)
          )
        ) x
      )
    });
    print "# Deleted unreferenced images: $cnt\n";
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
addimagessql;
findunused;
