package VN3::DB;

use v5.10;
use strict;
use warnings;
use TUWF;
use SQL::Interp ':all';
use Carp 'carp';
use base 'Exporter';

our @EXPORT = qw/
    sql
    sql_join sql_comma sql_and sql_array sql_func sql_fromhex sql_tohex sql_fromtime sql_totime
    enrich enrich_list enrich_list1
    entry update_entry
/;



# Test for potential SQL injection and warn about it. This will cause some
# false positives.
# The heuristic is pretty simple: Just check if there's an integer in the SQL
# statement. SQL injection through strings is likely to be caught much earlier,
# since that will generate a syntax error if the string is not properly escaped
# (and who'd put effort into escaping strings when placeholders are easier?).
sub interp_warn {
    my @r = sql_interp @_;
    carp "Possible SQL injection in '$r[0]'" if tuwf->debug && $r[0] =~ /[2-9]/; # 0 and 1 aren't interesting, "SELECT 1" is a common pattern and so is "x > 0"
    return @r;
}


# SQL::Interp wrappers around TUWF's db* methods.  These do not work with
# sql_type(). Proper integration should probably be added directly to TUWF.
sub TUWF::Object::dbExeci { shift->dbExec(interp_warn @_) }
sub TUWF::Object::dbVali  { shift->dbVal (interp_warn @_) }
sub TUWF::Object::dbRowi  { shift->dbRow (interp_warn @_) }
sub TUWF::Object::dbAlli  { shift->dbAll (interp_warn @_) }
sub TUWF::Object::dbPagei { shift->dbPage(shift, interp_warn @_) }

# Ugly workaround to ensure that db* method failures are reported at the actual caller.
$Carp::Internal{ (__PACKAGE__) }++;



# sql_* are macros for SQL::Interp use

# join(), but for sql objects.
sub sql_join {
    my $sep = shift;
    my @args = map +($sep, $_), @_;
    shift @args;
    return @args;
}

# Join multiple arguments together with a comma, for use in a SELECT or IN
# clause or function arguments.
sub sql_comma { sql_join ',', @_ }

sub sql_and   { sql_join 'AND', map sql('(', $_, ')'), @_ }

# Construct a PostgreSQL array type from the function arguments.
sub sql_array { 'ARRAY[', sql_join(',', map \$_, @_), ']' }

# Call an SQL function
sub sql_func {
    my($funcname, @args) = @_;
    sql $funcname, '(', sql_comma(@args), ')';
}

# Convert a Perl hex value into Postgres bytea
sub sql_fromhex($) {
    sql_func decode => \$_[0], "'hex'";
}

# Convert a Postgres bytea into a Perl hex value
sub sql_tohex($) {
    sql_func encode => $_[0], "'hex'";
}

# Convert a Perl time value (UNIX timestamp) into a Postgres timestamp
sub sql_fromtime($) {
    sql_func to_timestamp => \$_[0];
}

# Convert a Postgres timestamp into a Perl time value
sub sql_totime($) {
    sql "extract('epoch' from ", $_[0], ')';
}



# Helper function for the enrich functions below.
sub _enrich {
    my($merge, $key, $sql, @array) = @_;

    # 'flatten' the given array, so that you can also give arrayrefs as argument
    @array = map +(ref $_ eq 'ARRAY' ? @$_ : $_), @array;

    # Create a list of unique identifiers to fetch, do nothing if there's nothing to fetch
    my %ids = map +($_->{$key},1), @array;
    return if !keys %ids;

    # Fetch the data
    $sql = ref $sql eq 'CODE' ? $sql->([keys %ids]) : sql $sql, [keys %ids];
    my $data = tuwf->dbAlli($sql);

    # And merge
    $merge->($data, \@array);
}


# This function is slightly magical: It is used to fetch information from the
# database and add it to an existing data structure. Usage:
#
#   enrich $key, $sql, $object1, $object2, [$more_objects], ..;
#
# Where each $object is an hashref that will be modified in-place. $key is the
# name of a key that should be present in each $object, and indicates the value
# that should be used as database identifier to fetch more information. $sql is
# the SQL query that is used to fetch more information for each identifier. If
# $sql is a subroutine, then it is given an arrayref of keys (to be used in an
# WHERE x IN() clause), and should return a sql() query.  If $sql is a string
# or sql() query itself, then the arrayref of keys is appended to it.  The
# generated SQL query should return a column named $key, so that the other
# columns can be merged back into the $objects.
sub enrich {
    my($key, $sql, @array) = @_;
    _enrich sub {
        my($data, $array) = @_;
        my %ids = map +(delete($_->{$key}), $_), @$data;
        # Copy the key to a temp variable to prevent stringifycation of integer keys
        %$_ = (%$_, %{$ids{ (my $v = $_->{$key}) }}) for @$array;
    }, $key, $sql, @array;
}


# Similar to enrich(), but instead of requiring a one-to-one mapping between
# $object->{$key} and the row returned by $sql, this function allows multiple
# rows to be returned by $sql. $object->{$key} is compared with $merge_col
# returned by the SQL query, the rows are stored as an arrayref in
# $object->{$name}.
sub enrich_list {
    my($name, $key, $merge_col, $sql, @array) = @_;
    _enrich sub {
        my($data, $array) = @_;
        my %ids = ();
        push @{$ids{ delete $_->{$merge_col} }}, $_ for @$data;
        $_->{$name} = $ids{ (my $v = $_->{$key}) }||[] for @$array;
    }, $key, $sql, @array;
}


# Similar to enrich_list(), instead of returning each row as a hash, each row
# is taken to be a single value.
sub enrich_list1 {
    my($name, $key, $merge_col, $sql, @array) = @_;
    _enrich sub {
        my($data, $array) = @_;
        my %ids = ();
        push @{$ids{ delete $_->{$merge_col} }}, values %$_ for @$data;
        $_->{$name} = $ids{ (my $v = $_->{$key}) }||[] for @$array;
    }, $key, $sql, @array;
}




# Database entry API: Intended to provide a low-level read/write interface for
# versioned database entires. The same data structure is used for reading and
# updating entries, and should support easy diffing/comparison.
# Probably not very convenient for general querying & searching, but we'll see.

my %entry_prefixes = (qw{
    c chars
    d docs
    p producers
    r releases
    s staff
    v vn
});

# Reads the database schema and creates a hash of
#   'table' => [versioned item-specific columns]
# for a particular entry prefix, where each column is a hash.
#
# These functions assume a specific table layout for versioned database
# entries, as documented in util/sql/schema.sql.
sub _entry_tables {
    my $prefix = shift;
    my $tables = tuwf->dbh->column_info(undef, undef, "$prefix%_hist", undef)->fetchall_arrayref({});
    my %tables;
    for (@$tables) {
        (my $t = $_->{TABLE_NAME}) =~ s/_hist$//;
        next if $_->{COLUMN_NAME} eq 'chid';
        push @{$tables{$t}}, {
            name => $_->{pg_column},        # Raw name, as it appears in the data structure
            type => $_->{TYPE_NAME},        # Postgres type name
            sql_ref  => $_->{COLUMN_NAME},  # SQL to refer to this column
            sql_read => $_->{COLUMN_NAME},  # SQL to read this column (could be used to transform the data to something perl likes)
            sql_write => sub { \$_[0] },    # SQL to convert Perl data into something that can be assigned to the column
        };
    }
    \%tables;
}


sub _entry_type {
    # Store the cached result of _entry_tables() for each entry type
    state $types = {
        map +($_, _entry_tables $entry_prefixes{$_}),
        keys %entry_prefixes
    };
    $types->{ shift() };
}


# Returns everything for a specific entry ID. The top-level hash also includes
# the following keys:
#
#   id, chid, rev, maxrev, hidden, locked, entry_hidden, entry_locked
#
# (Ordering of arrays is unspecified)
sub entry {
    my($type, $id, $rev) = @_;

    my $prefix = $entry_prefixes{$type}||die;
    my $t = _entry_type $type;

    my $maxrev = tuwf->dbVali('SELECT MAX(rev) FROM changes WHERE type =', \$type, ' AND itemid =', \$id);
    return undef if !$maxrev;
    $rev ||= $maxrev;
    my $entry = tuwf->dbRowi(q{
        SELECT itemid AS id, id AS chid, rev AS chrev, ihid AS hidden, ilock AS locked
          FROM changes
         WHERE}, { type => $type, itemid => $id, rev => $rev }
    );
    return undef if !$entry->{id};
    $entry->{maxrev} = $maxrev;

    if($maxrev == $rev) {
        $entry->{entry_hidden} = $entry->{hidden};
        $entry->{entry_locked} = $entry->{locked};
    } else {
        enrich id => "SELECT id, hidden AS entry_hidden, locked AS entry_locked FROM $prefix WHERE id IN", $entry;
    }

    enrich chid => sql(
        SELECT => sql_comma(chid => map $_->{sql_read}, @{$t->{$prefix}}),
        FROM => "${prefix}_hist",
        'WHERE chid IN'
    ), $entry;

    for my $tbl (grep /^${prefix}_/, keys %$t) {
        (my $name = $tbl) =~ s/^${prefix}_//;
        $entry->{$name} = tuwf->dbAlli(
            SELECT => sql_comma(map $_->{sql_read}, @{$t->{$tbl}}),
            FROM => "${tbl}_hist",
            WHERE => { chid => $entry->{chid} });
    }
    $entry
}


# Update or create an entry, usage:
#   ($id, $chid, $rev) = update_entry $type, $id, $data, $uid;
#
# $id should be undef to create a new entry.
# $uid should be undef to use the currently logged in user.
# $data should have the same format as returned by entry(), but instead with
# the following additional keys in the top-level hash:
#
#   hidden, locked, editsum
sub update_entry {
    my($type, $id, $data, $uid) = @_;
    $id ||= undef;

    my $prefix = $entry_prefixes{$type}||die;
    my $t = _entry_type $type;

    tuwf->dbExeci("SELECT edit_${type}_init(", \$id, ', (SELECT MAX(rev) FROM changes WHERE type = ', \$type, ' AND itemid = ', \$id, '))');
    tuwf->dbExeci('UPDATE edit_revision SET', {
        requester => $uid // scalar VN3::Auth::auth()->uid(),
        ip        => scalar tuwf->reqIP(),
        comments  => $data->{editsum},
        ihid      => $data->{hidden},
        ilock     => $data->{locked},
    });

    tuwf->dbExeci("UPDATE edit_${prefix} SET ",
        sql_comma(map sql($_->{sql_ref}, ' = ', $_->{sql_write}->($data->{$_->{name}})), @{$t->{$prefix}}));

    for my $tbl (grep /^${prefix}_/, keys %$t) {
        (my $name = $tbl) =~ s/^${prefix}_//;

        my @rows = map {
            my $d = $_;
            sql '(', sql_comma(map $_->{sql_write}->($d->{$_->{name}}), @{$t->{$tbl}}), ')'
        } @{$data->{$name}};

        tuwf->dbExeci("DELETE FROM edit_${tbl}");
        tuwf->dbExeci("INSERT INTO edit_${tbl} ",
            '(', sql_comma(map $_->{sql_ref}, @{$t->{$tbl}}), ')',
            ' VALUES ', sql_comma(@rows)
        ) if @rows;
    }

    my $r = tuwf->dbRow("SELECT * FROM edit_${type}_commit()");
    ($r->{itemid}, $r->{chid}, $r->{rev})
}

1;
