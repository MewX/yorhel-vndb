#!/usr/bin/perl

# This script generates the devdump.tar.gz
# See https://vndb.org/d8#3 for info.

use strict;
use warnings;
use autodie;
use DBI;
use DBD::Pg;
use Cwd 'abs_path';

my $ROOT;
BEGIN { ($ROOT = abs_path $0) =~ s{/util/devdump\.pl$}{}; }

use lib $ROOT.'/lib';

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
my $images = $db->selectcol_arrayref(q{
         SELECT image FROM chars_hist          ch JOIN changes c ON c.id = ch.chid WHERE c.type = 'c' AND c.itemid IN(}.join(',',@$characters).qq{) AND ch.image IS NOT NULL
   UNION SELECT image FROM vn_hist             vh JOIN changes c ON c.id = vh.chid WHERE c.type = 'v' AND c.itemid IN($vids) AND vh.image IS NOT NULL
   UNION SELECT scr   FROM vn_screenshots_hist vs JOIN changes c ON c.id = vs.chid WHERE c.type = 'v' AND c.itemid IN($vids)
});


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

    print "-- This file replaces 'sql/all.sql'.\n";
    print "\\set ON_ERROR_STOP 1\n";
    print "\\i sql/schema.sql\n";
    print "\\i sql/data.sql\n";
    print "\\i sql/func.sql\n";
    print "\\i sql/editfunc.sql\n";

    # Copy over all sequence values
    my @seq = sort @{ $db->selectcol_arrayref(
        "SELECT oid::regclass::text FROM pg_class WHERE relkind = 'S' AND relnamespace = 'public'::regnamespace"
    ) };
    printf "SELECT setval('%s', %d);\n", $_, $db->selectrow_array('SELECT nextval(?)', {}, $_) for @seq;

    # A few pre-defined users
    # This password is 'hunter2' with the default salt
    my $pass = '000100000801ec4185fed438752d6b3b968e2b2cd045f70005cb7e10cafdbb694a82246bd34a065b6e977e0c3dcc';
    printf "INSERT INTO users (id, username, mail, perm_usermod, passwd, email_confirmed) VALUES (%d, '%s', '%s', %d, decode('%s', 'hex'), true);\n", @$_, $pass for(
        [ 2, 'admin', 'admin@vndb.org', 'true' ],
        [ 3, 'user1', 'user1@vndb.org', 'false'],
        [ 4, 'user2', 'user2@vndb.org', 'false'],
        [ 5, 'user3', 'user3@vndb.org', 'false'],
        [ 6, 'user4', 'user4@vndb.org', 'false'],
        [ 7, 'user5', 'user5@vndb.org', 'false'],
        [ 8, 'user6', 'user6@vndb.org', 'false'],
        [ 9, 'user7', 'user7@vndb.org', 'false'],
    );
    print "SELECT ulist_labels_create(id) FROM users;\n";

    # Tags & traits
    copy tags => undef, {addedby => 'user'};
    copy 'tags_aliases';
    copy 'tags_parents';
    copy traits => undef, {addedby => 'user'};
    copy 'traits_parents';

    # Wikidata (TODO: This could be a lot more selective)
    copy 'wikidata';

    # Image metadata
    my $image_ids = join ',', map "'$_'", @$images;
    copy images => "SELECT * FROM images WHERE id IN($image_ids)";
    copy image_votes => "SELECT DISTINCT ON (id,uid%10) * FROM image_votes WHERE id IN($image_ids)", { uid => 'user' };

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
    copy_entry p => [qw/producers/], $producers;

    # Characters
    copy_entry c => [qw/chars chars_traits chars_vns/], $characters;

    # Visual novels
    copy anime       => "SELECT DISTINCT a.* FROM anime a JOIN vn_anime_hist v ON v.aid = a.id JOIN changes c ON c.id = v.chid WHERE c.type = 'v' AND c.itemid IN($vids)";
    copy_entry v     => [qw/vn vn_anime vn_seiyuu vn_staff vn_relations vn_screenshots/], \@vids;

    # VN-related niceties
    copy tags_vn     => "SELECT DISTINCT ON (tag,vid,uid%10) * FROM tags_vn WHERE vid IN($vids)", {uid => 'user'};
    copy quotes      => "SELECT * FROM quotes WHERE vid IN($vids)";
    my $votes = "SELECT vid, uid%8+2 AS uid, (percentile_cont((uid%8+1)::float/9) WITHIN GROUP (ORDER BY vote))::smallint AS vote, MIN(vote_date) AS vote_date"
               ."  FROM ulist_vns WHERE vid IN($vids) AND vote IS NOT NULL GROUP BY vid, uid%8";
    copy ulist_vns   => $votes, {uid => 'user'};
    copy ulist_vns_labels => "SELECT vid, uid, 7 AS lbl FROM ($votes) x", {uid => 'user'};

    # Releases
    copy_entry r => [qw/releases releases_lang releases_media releases_platforms releases_producers releases_vn/], $releases;

    print "\\i sql/tableattrs.sql\n";
    print "\\i sql/triggers.sql\n";

    # Update some caches
    print "SELECT tag_vn_calc(NULL);\n";
    print "SELECT traits_chars_calc(NULL);\n";
    print "SELECT update_vncache(id) FROM vn;\n";
    print "SELECT update_stats_cache_full();\n";
    print "SELECT update_vnvotestats();\n";
    print "SELECT update_users_ulist_stats(NULL);\n";
    print "SELECT update_images_cache(NULL);\n";
    print "UPDATE users u SET c_tags = (SELECT COUNT(*) FROM tags_vn v WHERE v.uid = u.id);\n";
    print "UPDATE users u SET c_changes = (SELECT COUNT(*) FROM changes c WHERE c.requester = u.id);\n";

    print "\\set ON_ERROR_STOP 0\n";
    print "\\i sql/perms.sql\n";

    select STDOUT;
    close $OUT;
}




# Now figure out which images we need, and throw everything in a tarball
sub img { sprintf 'static/%s/%02d/%d.jpg', $_[0], $_[1]%100, $_[1] }
my @imgpaths = sort map { my($t,$id) = /([a-z]+)([0-9]+)/; (img($t, $id), $t eq 'sf' ? img('st', $id) : ()) } @$images;

system("tar -czf devdump.tar.gz dump.sql ".join ' ', @imgpaths);
unlink 'dump.sql';
