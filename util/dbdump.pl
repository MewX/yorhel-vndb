#!/usr/bin/perl
my $HELP=<<_;
Usage:

util/dbdump.pl export-db output.tar.zst

  Write a full database export as a .tar.zst

  The uncompressed directory is written to "output.tar.zst_dir"

util/dbdump.pl export-img output.tar.zst

  Write an export of all referenced images to a .tar.zst

util/dbdump.pl export-votes output.gz
util/dbdump.pl export-tags output.gz
util/dbdump.pl export-traits output.gz
_

# TODO:
# - Import
# - Consolidate with devdump.pl?

use strict;
use warnings;
use autodie;
use DBI;
use DBD::Pg;
use File::Copy 'cp';

use Cwd 'abs_path';
our $ROOT;
BEGIN { ($ROOT = abs_path $0) =~ s{/util/dbdump\.pl$}{}; }

use lib "$ROOT/lib";
use VNDBSchema;


# Tables and columns to export.
#
# Tables are exported with an explicit ORDER BY to make them more deterministic
# and avoid potentially leaking information about internal state (such as when
# a user last updated their account).
my %tables = (
    anime               => { where => 'id IN(SELECT va.aid FROM vn_anime va JOIN vn v ON v.id = va.id WHERE NOT v.hidden)' },
    chars               => { where => 'NOT hidden' },
    chars_traits        => { where => 'id IN(SELECT id FROM chars WHERE NOT hidden) AND tid IN(SELECT id FROM traits WHERE state = 2)' },
    chars_vns           => { where => 'id IN(SELECT id FROM chars WHERE NOT hidden)'
                                .' AND vid IN(SELECT id FROM vn WHERE NOT hidden)'
                                .' AND rid IN(SELECT id FROM releases WHERE NOT hidden)'
                           , order => 'id, vid, rid' },
    docs                => { where => 'NOT hidden' },
    producers           => { where => 'NOT hidden' },
    producers_relations => { where => 'id IN(SELECT id FROM producers WHERE NOT hidden)' },
    releases            => { where => 'NOT hidden' },
    releases_lang       => { where => 'id IN(SELECT id FROM releases WHERE NOT hidden)' },
    releases_media      => { where => 'id IN(SELECT id FROM releases WHERE NOT hidden)' },
    releases_platforms  => { where => 'id IN(SELECT id FROM releases WHERE NOT hidden)' },
    releases_producers  => { where => 'id IN(SELECT id FROM releases WHERE NOT hidden) AND pid IN(SELECT id FROM producers WHERE NOT hidden)' },
    releases_vn         => { where => 'id IN(SELECT id FROM releases WHERE NOT hidden) AND vid IN(SELECT id FROM vn WHERE NOT hidden)' },
    rlists              => { where => 'uid NOT IN(SELECT uid FROM users_prefs WHERE key = \'hide_list\') AND rid IN(SELECT id FROM releases WHERE NOT hidden)' },
    screenshots         => { where => 'id IN(SELECT scr FROM vn_screenshots vs JOIN vn v ON v.id = vs.id WHERE NOT v.hidden)' },
    staff               => { where => 'NOT hidden' },
    staff_alias         => { where => 'id IN(SELECT id FROM staff WHERE NOT hidden)' },
    tags                => { where => 'state = 2' },
    tags_aliases        => { where => 'tag IN(SELECT id FROM tags WHERE state = 2)' },
    tags_parents        => { where => 'tag IN(SELECT id FROM tags WHERE state = 2)' },
    tags_vn             => { where => 'tag IN(SELECT id FROM tags WHERE state = 2) AND vid IN(SELECT id FROM vn WHERE NOT hidden)' },
    traits              => { where => 'state = 2' },
    traits_parents      => { where => 'trait IN(SELECT id FROM traits WHERE state = 2)' },
                           # Only include users that are relevant for this dump.
                           # (The 'DISTINCT' isn't necessary, but does make the query faster)
                           # (Users with their votes ignored are still included. W/e)
    users               => { where => q{
                                (     id NOT IN(SELECT DISTINCT uid FROM users_prefs WHERE key = 'hide_list')
                                  AND id IN(SELECT DISTINCT uid FROM rlists
                                      UNION SELECT DISTINCT uid FROM wlists
                                      UNION SELECT DISTINCT uid FROM vnlists
                                      UNION SELECT DISTINCT uid FROM votes)
                                ) OR id IN(SELECT DISTINCT uid FROM tags_vn)
                           } },
    vn                  => { where => 'NOT hidden' },
    vn_anime            => { where => 'id IN(SELECT id FROM vn WHERE NOT hidden)' },
    vn_relations        => { where => 'id IN(SELECT id FROM vn WHERE NOT hidden)' },
    vn_screenshots      => { where => 'id IN(SELECT id FROM vn WHERE NOT hidden)' },
    vn_seiyuu           => { where => 'id IN(SELECT id FROM vn WHERE NOT hidden)'
                                .' AND aid IN(SELECT sa.aid FROM staff_alias sa JOIN staff s ON s.id = sa.id WHERE NOT s.hidden)'
                                .' AND cid IN(SELECT id FROM chars WHERE NOT hidden)' },
    vn_staff            => { where => 'id IN(SELECT id FROM vn WHERE NOT hidden) AND aid IN(SELECT sa.aid FROM staff_alias sa JOIN staff s ON s.id = sa.id WHERE NOT s.hidden)' },
    vnlists             => { where => 'uid NOT IN(SELECT uid FROM users_prefs WHERE key = \'hide_list\') AND vid IN(SELECT id FROM vn WHERE NOT hidden)' },
    votes               => { where => 'uid NOT IN(SELECT uid FROM users_prefs WHERE key = \'hide_list\')'
                                .' AND uid NOT IN(SELECT id FROM users WHERE ign_votes)'
                                .' AND vid IN(SELECT id FROM vn WHERE NOT hidden)' },
    wlists              => { where => 'uid NOT IN(SELECT uid FROM users_prefs WHERE key = \'hide_list\') AND vid IN(SELECT id FROM vn WHERE NOT hidden)' },
);

my @tables = map +{ name => $_, %{$tables{$_}} }, sort keys %tables;
my $schema = VNDBSchema::schema("$ROOT/util/sql/schema.sql");
my $types = VNDBSchema::types("$ROOT/util/sql/all.sql");
my $references = VNDBSchema::references("$ROOT/util/sql/tableattrs.sql");

my $db = DBI->connect('dbi:Pg:dbname=vndb', 'vndb', undef, { RaiseError => 1 });
$db->do('SET TIME ZONE +0');


sub export_timestamp {
    my $dest = shift;
    open my $F, '>', $dest;
    printf $F "%s\n", $db->selectrow_array('SELECT date_trunc(\'second\', NOW())');
}


sub export_table {
    my($dest, $table) = @_;

    my $schema = $schema->{$table->{name}};
    my @cols = grep $_->{pub}, @{$schema->{cols}};
    die "No columns to export for table '$table->{name}'\n" if !@cols;;

    #print "# Dumping $table->{name}\n";
    my $fn = "$dest/$table->{name}";

    # Truncate all timestamptz columns to a day, to avoid leaking privacy-sensitive info.
    my $cols = join ', ', map $_->{type} eq 'timestamptz' ? "date_trunc('day', \"$_->{name}\")" : qq{"$_->{name}"}, @cols;
    my $where = $table->{where} ? "WHERE $table->{where}" : '';
    my $order = $schema->{primary} ? join ', ', map "\"$_\"", @{$schema->{primary}} : $table->{order};
    die "Table '$table->{name}' is missing an ORDER BY clause\n" if !$order;

    $db->do(qq{COPY (SELECT $cols FROM "$table->{name}" $where ORDER BY $order) TO STDOUT});
    open my $F, '>:utf8', $fn;
    my $v;
    print $F $v while($db->pg_getcopydata($v) >= 0);
    close $F;

    open $F, '>', "$fn.header";
    print $F join "\t", map $_->{name}, @cols;
    print $F "\n";
    close $F;
}


sub export_import_script {
    my $dest = shift;
    open my $F, '>', $dest;
    print $F <<'    _' =~ s/^    //mgr;
    -- This script will create the necessary tables and import all data into an
    -- existing PostgreSQL database.
    --
    -- Usage:
    --   Run a 'CREATE DATABASE $database' somewhere.
    --   psql -U $user $database -f import.sql
    --
    -- The imported database does not include any indices, other than primary keys.
    -- You may want to create some indices by hand to speed up complex queries.

    -- Uncomment to import the schema and data into a separate namespace:
    --CREATE SCHEMA vndb;
    --SET search_path TO vndb;
    _

    print $F "\n\n";
    my %types = map +($_->{type}, 1), grep $_->{pub}, map @{$schema->{$_->{name}}{cols}}, @tables;
    print $F "$types->{$_}{decl}\n" for (sort grep $types->{$_}, keys %types);

    for my $table (@tables) {
        my $schema = $schema->{$table->{name}};
        print $F "\n";
        print $F "CREATE TABLE \"$table->{name}\" (\n";
        print $F join ",\n", map "  $_->{decl}" =~ s/" serial/" integer/ir, grep $_->{pub}, @{$schema->{cols}};
        print $F ",\n  PRIMARY KEY(".join(', ', map "\"$_\"", @{$schema->{primary}}).")" if $schema->{primary};
        print $F "\n);\n";
    }

    print $F "\n\n";
    print $F "-- You can comment out tables you don't need, to speed up the import and save some disk space.\n";
    print $F "\\copy $_->{name} from 'db/$_->{name}'\n" for @tables;

    print $F "\n\n";
    print $F "-- These are included to verify the internal consistency of the dump, you can safely comment out this part.\n";
    for my $ref (@$references) {
        next if !$tables{$ref->{from_table}} || !$tables{$ref->{to_table}};
        my %pub = map +($_->{name}, 1), grep $_->{pub}, @{$schema->{$ref->{from_table}}{cols}};
        next if grep !$pub{$_}, @{$ref->{from_cols}};
        print $F "$ref->{decl}\n";
    }
}


sub export_db {
    my $dest = shift;

    my @static = qw{
        LICENSE-CC-BY-NC-SA.txt
        LICENSE-DBCL.txt
        LICENSE-ODBL.txt
        README.txt
    };

    # This will die if it already exists, which is good because we want to write to a new empty dir.
    mkdir "${dest}_dir";
    mkdir "${dest}_dir/db";

    cp "$ROOT/util/dump/$_", "${dest}_dir/$_" for @static;

    export_timestamp "${dest}_dir/TIMESTAMP";
    export_table "${dest}_dir/db", $_ for @tables;
    export_import_script "${dest}_dir/import.sql";

    #print "# Compressing\n";
    `tar -cf "$dest" -I 'zstd -7' --sort=name -C "${dest}_dir" @static import.sql TIMESTAMP db`
}


# XXX: This does not include images that are linked from descriptions; May want to borrow from util/unusedimages.pl to find those.
sub export_img {
    my $dest = shift;

    mkdir "${dest}_dir";
    cp "$ROOT/util/dump/LICENSE-ODBL.txt", "${dest}_dir/LICENSE-ODBL.txt";
    cp "$ROOT/util/dump/README-img.txt", "${dest}_dir/README.txt";
    export_timestamp "${dest}_dir/TIMESTAMP";

    open my $F, '>', "${dest}_files";

    printf $F "static/sf/%1\$02d/%2\$d.jpg\nstatic/st/%1\$02d/%2\$d.jpg\n", $_->[0]%100, $_->[0]
        for $db->selectall_array("SELECT id FROM screenshots WHERE $tables{screenshots}{where} ORDER BY id");

    printf $F "static/cv/%02d/%d.jpg\n", $_->[0]%100, $_->[0]
        for $db->selectall_array("SELECT image FROM vn WHERE image <> 0 AND $tables{vn}{where} ORDER BY image");

    printf $F "static/ch/%02d/%d.jpg\n", $_->[0]%100, $_->[0]
        for $db->selectall_array("SELECT image FROM chars WHERE image <> 0 AND $tables{chars}{where} ORDER BY image");

    close $F;
    undef $db;

    `tar -cf "$dest" -I 'zstd -5' \\
        --verbatim-files-from --files-from "${dest}_files" \\
        -C "${dest}_dir" LICENSE-ODBL.txt README.txt TIMESTAMP`;

    unlink "${dest}_files";
    unlink "${dest}_dir/LICENSE-ODBL.txt";
    unlink "${dest}_dir/README.txt";
    unlink "${dest}_dir/TIMESTAMP";
    rmdir "${dest}_dir";
}


sub export_votes {
    my $dest = shift;
    require PerlIO::gzip;

    open my $F, '>:gzip:utf8', $dest;
    $db->do(q{COPY (
        SELECT vv.vid||' '||vv.uid||' '||vv.vote||' '||to_char(vv.date, 'YYYY-MM-DD')
          FROM votes vv
          JOIN users u ON u.id = vv.uid
          JOIN vn v ON v.id = vv.vid
         WHERE NOT v.hidden
           AND NOT u.ign_votes
           AND NOT EXISTS(SELECT 1 FROM users_prefs up WHERE up.uid = u.id AND key = 'hide_list')
         ORDER BY vv.vid, vv.uid
       ) TO STDOUT
    });
    my $v;
    print $F $v while($db->pg_getcopydata($v) >= 0);
}


sub export_tags {
    my $dest = shift;
    require JSON::XS;
    require PerlIO::gzip;

    my $lst = $db->selectall_arrayref(q{
        SELECT id, name, description, searchable, applicable, c_items AS vns, cat,
          (SELECT string_agg(alias,'$$$-$$$') FROM tags_aliases where tag = id) AS aliases,
          (SELECT string_agg(parent::text, ',') FROM tags_parents WHERE tag = id) AS parents
        FROM tags WHERE state = 2 ORDER BY id
    }, { Slice => {} });
    for(@$lst) {
      $_->{id} *= 1;
      $_->{meta} = !$_->{searchable} ? JSON::XS::true() : JSON::XS::false(); # For backwards compat
      $_->{searchable} = $_->{searchable} ? JSON::XS::true() : JSON::XS::false();
      $_->{applicable} = $_->{applicable} ? JSON::XS::true() : JSON::XS::false();
      $_->{vns} *= 1;
      $_->{aliases} = [ split /\$\$\$-\$\$\$/, ($_->{aliases}||'') ];
      $_->{parents} = [ map $_*1, split /,/, ($_->{parents}||'') ];
    }

    open my $F, '>:gzip:utf8', $dest;
    print $F JSON::XS->new->canonical->encode($lst);
}


sub export_traits {
    my $dest = shift;
    require JSON::XS;
    require PerlIO::gzip;

    my $lst = $db->selectall_arrayref(q{
        SELECT id, name, alias AS aliases, description, searchable, applicable, c_items AS chars,
               (SELECT string_agg(parent::text, ',') FROM traits_parents WHERE trait = id) AS parents
        FROM traits WHERE state = 2 ORDER BY id
    }, { Slice => {} });
    for(@$lst) {
      $_->{id} *= 1;
      $_->{meta} = $_->{searchable} ? JSON::XS::true() : JSON::XS::false(); # For backwards compat
      $_->{searchable} = $_->{searchable} ? JSON::XS::true() : JSON::XS::false();
      $_->{applicable} = $_->{applicable} ? JSON::XS::true() : JSON::XS::false();
      $_->{chars} *= 1;
      $_->{aliases} = [ split /\r?\n/, ($_->{aliases}||'') ];
      $_->{parents} = [ map $_*1, split /,/, ($_->{parents}||'') ];
    }

    open my $F, '>:gzip:utf8', $dest;
    print $F JSON::XS->new->canonical->encode($lst);
}


if($ARGV[0] && $ARGV[0] eq 'export-db' && $ARGV[1]) {
    export_db $ARGV[1];
} elsif($ARGV[0] && $ARGV[0] eq 'export-img' && $ARGV[1]) {
    export_img $ARGV[1];
} elsif($ARGV[0] && $ARGV[0] eq 'export-votes' && $ARGV[1]) {
    export_votes $ARGV[1];
} elsif($ARGV[0] && $ARGV[0] eq 'export-tags' && $ARGV[1]) {
    export_tags $ARGV[1];
} elsif($ARGV[0] && $ARGV[0] eq 'export-traits' && $ARGV[1]) {
    export_traits $ARGV[1];
} else {
    print $HELP;
}
