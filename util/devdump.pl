#!/usr/bin/perl

# This script generates the devdump.tar.gz
# See https://vndb.org/d8#3 for info.

use strict;
use warnings;
use autodie;
use DBI;
use DBD::Pg;

my $db = DBI->connect('dbi:Pg:dbname=vndb', 'vndb', undef, { RaiseError => 1 });



# Figure out which DB entries to export

my @vids = (3, 17, 97, 183, 264, 266, 384, 407, 1910, 2932, 5922, 6438, 9837);
my $vids = join ',', @vids;
my $staff = $db->selectcol_arrayref(
    "SELECT c2.itemid FROM vn_staff_hist  v JOIN changes c ON c.id = v.chid JOIN staff_alias_hist a ON a.aid = v.aid JOIN changes c2 ON c2.id = a.chid WHERE c.itemid IN($vids) "
   ."UNION "
   ."SELECT c2.itemid FROM vn_seiyuu_hist v JOIN changes c ON c.id = v.chid JOIN staff_alias_hist a ON a.aid = v.aid JOIN changes c2 ON c2.id = a.chid WHERE c.itemid IN($vids)"
);
my $releases = $db->selectcol_arrayref("SELECT DISTINCT c.itemid FROM releases_vn_hist v JOIN changes c ON c.id = v.chid WHERE v.vid IN($vids)");
my $producers = $db->selectcol_arrayref("SELECT pid FROM releases_producers_hist p JOIN changes c ON c.id = p.chid WHERE c.type = 'r' AND c.itemid IN(".join(',',@$releases).")");
my $characters = $db->selectcol_arrayref(
    "SELECT DISTINCT c.itemid FROM chars_vns_hist e JOIN changes c ON c.id = e.chid WHERE e.vid IN($vids) "
   ."UNION "
   ."SELECT DISTINCT h.main FROM chars_vns_hist e JOIN changes c ON c.id = e.chid JOIN chars_hist h ON h.chid = e.chid WHERE e.vid IN($vids) AND h.main IS NOT NULL"
);



# Helper function to copy a table or SQL statement. Can do modifications on a
# few columns (the $specials).
sub copy {
    my($dest, $sql, $specials) = @_;

    $sql ||= "SELECT * FROM $dest";
    $specials ||= {};

    my @cols = do {
        my $s = $db->prepare($sql);
        $s->execute();
        grep !($specials->{$_} && $specials->{$_} eq 'del'), @{$s->{NAME}}
    };

    printf "COPY %s (%s) FROM stdin;\n", $dest, join ', ', map "\"$_\"", @cols;

    $sql = "SELECT " . join(',', map {
        my $s = $specials->{$_} || '';
        if($s eq 'user') {
            qq{"$_" % 10 AS "$_"}
        } else {
            qq{"$_"}
        }
    } @cols) . " FROM ($sql) AS x";
    #warn $sql;
    $db->do("COPY ($sql) TO STDOUT");
    my $v;
    print $v while $db->pg_getcopydata($v) >= 0;
    print "\\.\n\n";
}



# Helper function to copy a full DB entry with history and all (doesn't handle references)
sub copy_entry {
    my($type, $tables, $ids) = @_;
    $ids = join ',', @$ids;
    copy changes => "SELECT * FROM changes WHERE type = '$type' AND itemid IN($ids)", {requester => 'user', ip => 'del'};
    for(@$tables) {
        my $add = '';
        $add = " AND vid IN($vids)" if /^releases_vn/ || /^vn_relations/ || /^chars_vns/;
        copy $_          => "SELECT *   FROM $_ WHERE id IN($ids) $add";
        copy "${_}_hist" => "SELECT x.* FROM ${_}_hist x JOIN changes c ON c.id = x.chid WHERE c.type = '$type' AND c.itemid IN($ids) $add";
    }
}


{
    open my $OUT, '>:utf8', 'dump.sql';
    select $OUT;

    # Header
    my @tables = grep !/^multi_/, sort @{ $db->selectcol_arrayref(
        "SELECT oid::regclass::text FROM pg_class WHERE relkind = 'r' AND relnamespace = 'public'::regnamespace"
    ) };
    print  "\\set ON_ERROR_STOP 1\n";
    print  "BEGIN;\n";
    printf "TRUNCATE TABLE %s CASCADE;\n", join ',', @tables;
    print  "SET CONSTRAINTS ALL DEFERRED;\n";
    printf "ALTER TABLE %s DISABLE TRIGGER USER;\n", $_ for @tables;

    # Copy over some required defaults
    open my $F, '<', 'util/sql/data.sql';
    print while <$F>;
    close $F;

    # Copy over all sequence values
    my @seq = sort @{ $db->selectcol_arrayref(
        "SELECT oid::regclass::text FROM pg_class WHERE relkind = 'S' AND relnamespace = 'public'::regnamespace"
    ) };
    printf "SELECT setval('%s', %d);\n", $_, $db->selectrow_array('SELECT nextval(?)', {}, $_) for @seq;

    # A few pre-defined users
    # This password is 'hunter2' with the default salt
    my $pass = '000100000801ec4185fed438752d6b3b968e2b2cd045f70005cb7e10cafdbb694a82246bd34a065b6e977e0c3dcc';
    printf "INSERT INTO users (id, username, mail, perm, passwd, email_confirmed) VALUES (%d, '%s', '%s', %d, decode('%s', 'hex'), true);\n", @$_, $pass for(
        [ 2, 'admin', 'admin@vndb.org', 503 ],
        [ 3, 'user1', 'user1@vndb.org', 21 ],
        [ 4, 'user2', 'user2@vndb.org', 21 ],
        [ 5, 'user3', 'user3@vndb.org', 21 ],
        [ 6, 'user4', 'user4@vndb.org', 21 ],
        [ 7, 'user5', 'user5@vndb.org', 21 ],
        [ 8, 'user6', 'user6@vndb.org', 21 ],
        [ 9, 'user7', 'user7@vndb.org', 21 ],
    );

    # Tags & traits
    copy tags => undef, {addedby => 'user'};
    copy 'tags_aliases';
    copy 'tags_parents';
    copy traits => undef, {addedby => 'user'};
    copy 'traits_parents';

    # Threads (announcements)
    my $threads = join ',', @{ $db->selectcol_arrayref("SELECT tid FROM threads_boards b WHERE b.type = 'an'") };
    copy threads        => "SELECT * FROM threads WHERE id IN($threads)";
    copy threads_boards => "SELECT * FROM threads_boards WHERE tid IN($threads)";
    copy threads_posts  => "SELECT * FROM threads_posts WHERE tid IN($threads)", { uid => 'user' };

    # Doc pages
    copy_entry d => ['docs'], $db->selectcol_arrayref('SELECT id FROM docs');

    # Staff
    copy_entry s => [qw/staff staff_alias/], $staff;

    # Producers (TODO: Relations)
    copy 'relgraphs', "SELECT DISTINCT ON (r.id) r.* FROM relgraphs r JOIN producers p ON p.rgraph = r.id WHERE p.id IN(".join(',', @$producers).")", {};
    copy_entry p => [qw/producers/], $producers;

    # Characters
    copy_entry c => [qw/chars chars_traits chars_vns/], $characters;

    # Visual novels
    copy screenshots => "SELECT DISTINCT s.* FROM screenshots s JOIN vn_screenshots_hist v ON v.scr = s.id JOIN changes c ON c.id = v.chid WHERE c.type = 'v' AND c.itemid IN($vids)";
    copy anime       => "SELECT DISTINCT a.* FROM anime a JOIN vn_anime_hist v ON v.aid = a.id JOIN changes c ON c.id = v.chid WHERE c.type = 'v' AND c.itemid IN($vids)";
    copy relgraphs   => "SELECT DISTINCT ON (r.id) r.* FROM relgraphs r JOIN vn v ON v.rgraph = r.id WHERE v.id IN($vids)", {};
    copy_entry v     => [qw/vn vn_anime vn_seiyuu vn_staff vn_relations vn_screenshots/], \@vids;

    # VN-related niceties
    copy tags_vn     => "SELECT DISTINCT ON (tag,vid,uid%10) * FROM tags_vn WHERE vid IN($vids)", {uid => 'user'};
    copy quotes      => "SELECT * FROM quotes WHERE vid IN($vids)";
    copy votes       => "SELECT vid, uid%8+2 AS uid, (percentile_cont((uid%8+1)::float/9) WITHIN GROUP (ORDER BY vote))::smallint AS vote, MIN(date) AS date FROM votes WHERE vid IN($vids) GROUP BY vid, uid%8", {uid => 'user'};

    # Releases
    copy_entry r => [qw/releases releases_lang releases_media releases_platforms releases_producers releases_vn/], $releases;

    # Caches
    print "SELECT tag_vn_calc();\n";
    print "SELECT traits_chars_calc();\n";
    print "SELECT update_vncache(id) FROM vn;\n";
    print "UPDATE users u SET c_votes = (SELECT COUNT(*) FROM votes v WHERE v.uid = u.id);\n";
    print "UPDATE users u SET c_tags = (SELECT COUNT(*) FROM tags_vn v WHERE v.uid = u.id);\n";
    print "UPDATE users u SET c_changes = (SELECT COUNT(*) FROM changes c WHERE c.requester = u.id);\n";
    # These were copied from Multi::Maintenance
    print "UPDATE stats_cache SET count = (SELECT COUNT(*) FROM users)-1 WHERE section = 'users';\n";
    print "UPDATE stats_cache SET count = (SELECT COUNT(*) FROM vn        WHERE hidden = FALSE) WHERE section = 'vn';\n";
    print "UPDATE stats_cache SET count = (SELECT COUNT(*) FROM releases  WHERE hidden = FALSE) WHERE section = 'releases';\n";
    print "UPDATE stats_cache SET count = (SELECT COUNT(*) FROM producers WHERE hidden = FALSE) WHERE section = 'producers';\n";
    print "UPDATE stats_cache SET count = (SELECT COUNT(*) FROM chars     WHERE hidden = FALSE) WHERE section = 'chars';\n";
    print "UPDATE stats_cache SET count = (SELECT COUNT(*) FROM staff     WHERE hidden = FALSE) WHERE section = 'staff';\n";
    print "UPDATE stats_cache SET count = (SELECT COUNT(*) FROM tags      WHERE state = 2)      WHERE section = 'tags';\n";
    print "UPDATE stats_cache SET count = (SELECT COUNT(*) FROM traits    WHERE state = 2)      WHERE section = 'traits';\n";
    print "UPDATE stats_cache SET count = (SELECT COUNT(*) FROM threads   WHERE hidden = FALSE) WHERE section = 'threads';\n";
    print "UPDATE stats_cache SET count = (SELECT COUNT(*) FROM threads_posts WHERE hidden = FALSE
            AND EXISTS(SELECT 1 FROM threads WHERE threads.id = tid AND threads.hidden = FALSE)) WHERE section = 'threads_posts';\n";
    # TODO: Something with the 'stats_cache' table. The vn.c_* stats are also inconsistent

    # Footer
    # Apparently we can't do an ALTER TABLE while the (deferred) foreign key checks
    # haven't been executed, so do a commit first.
    print "COMMIT;\n";
    printf "ALTER TABLE %s ENABLE TRIGGER USER;\n", $_ for @tables;

    select STDOUT;
    close $OUT;
}




# Now figure out which images we need, and throw everything in a tarball
sub imgs { map sprintf('static/%s/%02d/%d.jpg', $_[0], $_%100, $_), @{$_[1]} }

my $ch = $db->selectcol_arrayref("SELECT DISTINCT e.image FROM chars_hist          e JOIN changes c ON c.id = e.chid WHERE c.type = 'c' AND e.image <> 0 AND c.itemid IN(".join(',', @$characters).")");
my $cv = $db->selectcol_arrayref("SELECT DISTINCT e.image FROM vn_hist             e JOIN changes c ON c.id = e.chid WHERE c.type = 'v' AND e.image <> 0 AND c.itemid IN($vids)");
my $sf = $db->selectcol_arrayref("SELECT DISTINCT e.scr   FROM vn_screenshots_hist e JOIN changes c ON c.id = e.chid WHERE c.type = 'v' AND c.itemid IN($vids)");

system("tar -czf devdump.tar.gz dump.sql ".join ' ', imgs(ch => $ch), imgs(cv => $cv), imgs(sf => $sf), imgs(st => $sf));
unlink 'dump.sql';