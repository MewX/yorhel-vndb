package VNWeb::DB;

use v5.24;
use warnings;
use TUWF;
use SQL::Interp ':all';
use Carp 'carp';
use Exporter 'import';
use VNDB::Schema;

our @EXPORT = qw/
    sql
    sql_join sql_comma sql_and sql_or sql_array sql_func sql_fromhex sql_tohex sql_fromtime sql_totime sql_user
    enrich enrich_merge enrich_flatten
    db_entry db_edit
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
    sql @args[1..$#args];
}

# Join multiple arguments together with a comma, for use in a SELECT or IN
# clause or function arguments.
sub sql_comma { sql_join ',', @_ }

sub sql_and   { @_ ? sql_join 'AND', map sql('(', $_, ')'), @_ : sql '1=1' }
sub sql_or    { @_ ? sql_join 'OR',  map sql('(', $_, ')'), @_ : sql '1=0' }

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

# Returns a list of column names to fetch for displaying a username with HTML::user_().
# Arguments: Name of the 'users' table (default: 'u'), prefix for the fetched fields (default: 'user_').
# (This function returns a plain string so that old non-SQL-Interp functions can also use it)
sub sql_user {
    my $tbl = shift||'u';
    my $prefix = shift||'user_';
    join ', ',
       "$tbl.id              as ${prefix}id",
       "$tbl.username        as ${prefix}name",
       "$tbl.support_can     as ${prefix}support_can",
       "$tbl.support_enabled as ${prefix}support_enabled",
       "$tbl.uniname_can     as ${prefix}uniname_can",
       "$tbl.uniname         as ${prefix}uniname";
}




# The enrich*() functions are based on https://dev.yorhel.nl/doc/sqlobject
# See that article for general usage information, the following is purely
# reference documentation:
#
# enrich $name, $key, $merge_col, $sql, @objects;
#
#   Add a $name field each item in @objects,
#   Its value is a (possibly empty) array of hashes with data from $sql,
#
# enrich_flatten $name, $key, $merge_col, $sql, @objects;
#
#   Add a $name field each item in @objects,
#   Its value is a (possibly empty) array of values from a single column from $sql,
#
# enrich_merge $key, $sql, @objects;
#
#   Merge all columns returned by $sql into @objects;
#
#
# Arguments:
#
#   $key is the field in @objects used in the IN clause of $sql,
#
#   $merge_col is the column name returned by $sql and compared against the
#     values of the $key field.
#     (enrich_merge() requires that the column name is equivalent to $key)
#
#   $sql is the query to be executed, can be either:
#     - A string or sql() object, in which case it should end with ' IN' so
#       that the list of identifiers can be appended to it.
#     - A subroutine, in which case the array of identifiers is given as first
#       argument. The sub should return an sql() object.
#
#   @objects is a list or array of hashrefs to be enriched.


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


sub enrich {
    my($name, $key, $merge_col, $sql, @array) = @_;
    _enrich sub {
        my($data, $array) = @_;
        my %ids = ();
        push $ids{ delete $_->{$merge_col} }->@*, $_ for @$data;
        $_->{$name} = $ids{ $_->{$key} }||[] for @$array;
    }, $key, $sql, @array;
}


sub enrich_merge {
    my($key, $sql, @array) = @_;
    _enrich sub {
        my($data, $array) = @_;
        my %ids = map +(delete($_->{$key}), $_), @$data;
        %$_ = (%$_, $ids{ $_->{$key} }->%*) for @$array;
    }, $key, $sql, @array;
}


sub enrich_flatten {
    my($name, $key, $merge_col, $sql, @array) = @_;
    _enrich sub {
        my($data, $array) = @_;
        my %ids = ();
        push $ids{ delete $_->{$merge_col} }->@*, values %$_ for @$data;
        $_->{$name} = $ids{ $_->{$key} }||[] for @$array;
    }, $key, $sql, @array;
}



# Database entry API: Intended to provide a low-level read/write interface for
# versioned database entires. The same data structure is used for reading and
# updating entries, and should support easy diffing/comparison.
# Not very convenient for general querying & searching, those still need custom
# queries.


# Hash table, something like:
# {
#   v => {
#       prefix => 'vn',
#       base => { .. 'vn_hist' schema }
#       tables => {
#           anime => { .. 'vn_anime_hist' schema }
#       },
#   }, ..
# }
my $entry_types = do {
    my $schema = VNDB::Schema::schema;
    my %types = map +($_->{dbentry_type}, { prefix => $_->{name} }), grep $_->{dbentry_type}, values %$schema;
    for my $t (values %$schema) {
        my $n = $t->{name};
        my($type) = grep $n =~ s/^$_->{prefix}_//, values %types;
        next if !$type;
        $type->{base} = $t if $n eq 'hist';
        next if $n !~ s/_hist$//;
        $type->{tables}{$n} = $t;
    }
    \%types;
};


# Returns everything for a specific entry ID. The top-level hash also includes
# the following keys:
#
#   id, chid, rev, maxrev, hidden, locked, entry_hidden, entry_locked
#
# (Ordering of arrays is unspecified)
#
# TODO:
# - Use non _hist tables if $maxrev == $rev (should be faster)
# - Combine the enrich_merge() calls into a single query.
# - Fixed ordering of arrays (use primary keys)
sub db_entry {
    my($type, $id, $rev) = @_;
    my $t = $entry_types->{$type}||die;

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
        my $base = $t->{base}{name} =~ s/_hist$//r;
        enrich_merge id => "SELECT id, hidden AS entry_hidden, locked AS entry_locked FROM \"$base\" WHERE id IN", $entry;
    }

    enrich_merge chid => sql(
        SELECT => sql_comma(map "\"$_->{name}\"", $t->{base}{cols}->@*),
        FROM => "\"$t->{base}{name}\"",
        'WHERE chid IN'
    ), $entry;

    while(my($name, $tbl) = each $t->{tables}->%*) {
        $entry->{$name} = tuwf->dbAlli(
            SELECT => sql_comma(map "\"$_->{name}\"", grep $_->{name} ne 'chid', $tbl->{cols}->@*),
            FROM => "\"$tbl->{name}\"",
            WHERE => { chid => $entry->{chid} }
        );
    }
    $entry
}


# Edit or create an entry, usage:
#   ($id, $chid, $rev) = db_edit $type, $id, $data, $uid;
#
# $id should be undef to create a new entry.
# $uid should be undef to use the currently logged in user.
# $data should have the same format as returned by db_entry(), but instead with
# the following additional keys in the top-level hash:
#
#   hidden, locked, editsum
sub db_edit {
    my($type, $id, $data, $uid) = @_;
    $id ||= undef;
    my $t = $entry_types->{$type}||die;

    tuwf->dbExeci("SELECT edit_${type}_init(", \$id, ', (SELECT MAX(rev) FROM changes WHERE type = ', \$type, ' AND itemid = ', \$id, '))');
    tuwf->dbExeci('UPDATE edit_revision SET', {
        requester => $uid // scalar VNWeb::Auth::auth()->uid(),
        ip        => scalar tuwf->reqIP(),
        comments  => $data->{editsum},
        ihid      => $data->{hidden},
        ilock     => $data->{locked},
    });

    {
        my $base = $t->{base}{name} =~ s/_hist$//r;
        tuwf->dbExeci("UPDATE edit_${base} SET ", sql_comma(
            map sql("\"$_->{name}\"", ' = ', \$data->{$_->{name}}),
                grep exists $data->{$_->{name}}, $t->{base}{cols}->@*
        ));
    }

    while(my($name, $tbl) = each $t->{tables}->%*) {
        my $base = $tbl->{name} =~ s/_hist$//r;
        my @cols = map sql_comma(map "\"$_->{name}\""), $tbl->{cols}->$@;
        my @rows = map {
            my $d = $_;
            sql '(', sql_comma(map \$d, $tbl->{cols}->@*), ')'
        } $data->{$name}->@*;

        tuwf->dbExeci("DELETE FROM edit_${base}");
        tuwf->dbExeci("INSERT INTO edit_${base} (", @cols, ') VALUES ', sql_comma @rows) if @rows;
    }

    my $r = tuwf->dbRow("SELECT * FROM edit_${type}_commit()");
    ($r->{itemid}, $r->{chid}, $r->{rev})
}

1;
