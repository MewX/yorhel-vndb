#!/usr/bin/perl

use v5.26;
use warnings;
use DBI;
use Image::Magick;

my $db = DBI->connect('dbi:Pg:dbname=vndb', 'vndb', undef, { RaiseError => 1, AutoCommit => 0 });

my $upd = $db->prepare('UPDATE images SET width = ?, height = ? WHERE id = ?::image_id');

for my $id ($db->selectcol_arrayref('SELECT id FROM images WHERE width IS NULL')->@*) {
    my($t,$n) = $id =~ /\(([a-z]+),([0-9]+)\)/;
    my $f = sprintf 'static/%s/%02d/%d.jpg', $t, $n%100, $n;
    my $im = Image::Magick->new;
    my $e = $im->Read($f);
    warn "$f: $e\n" if $e;
    $upd->execute($im->Get('width'), $im->Get('height'), $id) if !$e;
}

# A few images have been permanently deleted, that's alright, not being used anyway.
$db->do('UPDATE images SET width = 0, height = 0 WHERE width IS NULL');

$db->do('ALTER TABLE images ALTER COLUMN width SET NOT NULL');
$db->do('ALTER TABLE images ALTER COLUMN height SET NOT NULL');
$db->commit;
