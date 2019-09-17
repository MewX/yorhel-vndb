package VNWeb::DB;

use v5.24;
use warnings;
use TUWF;
use SQL::Interp ':all';
use Carp 'carp';
use Exporter 'import';

our @EXPORT = qw/
    sql
    sql_join sql_comma sql_and sql_array sql_func sql_fromhex sql_tohex sql_fromtime sql_totime
    enrich enrich_merge enrich_flatten
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


1;
