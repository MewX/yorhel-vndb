package VNWeb::Validation;

use v5.26;
use TUWF;
use PWLookup;
use VNDB::Types;
use VNDB::Config;
use VNWeb::Auth;
use VNWeb::DB;
use Carp 'croak';
use Exporter 'import';

our @EXPORT = qw/
    is_insecurepass
    form_compile
    form_changed
    validate_dbid
    can_edit
/;


TUWF::set custom_validations => {
    id          => { uint => 1, max => 1<<40 },
    editsum     => { required => 1, length => [ 2, 5000 ] },
    page        => { uint => 1, min => 1, max => 1000, required => 0, default => 1, onerror => 1 },
    upage       => { uint => 1, min => 1, required => 0, default => 1, onerror => 1 }, # pagination without a maximum
    username    => { regex => qr/^(?!-*[a-z][0-9]+-*$)[a-z0-9-]*$/, minlength => 2, maxlength => 15 },
    password    => { length => [ 4, 500 ] },
    language    => { enum => \%LANGUAGE },
    # Accepts a user-entered vote string (or '-' or empty) and converts that into a DB vote number (or undef) - opposite of fmtvote()
    vnvote      => { required => 0, default => undef, regex => qr/^(?:|-|[1-9]|10|[1-9]\.[0-9]|10\.0)$/, func => sub { $_[0] = $_[0] eq '-' ? undef : 10*$_[0]; 1 } },
    # Sort an array by the listed hash keys, using string comparison on each key
    sort_keys   => sub {
        my @keys = ref $_[0] eq 'ARRAY' ? @{$_[0]} : $_[0];
        +{ type => 'array', sort => sub {
            for(@keys) {
                my $c = defined($_[0]{$_}) cmp defined($_[1]{$_}) || (defined($_[0]{$_}) && $_[0]{$_} cmp $_[1]{$_});
                return $c if $c;
            }
            0
        } }
    },
    # Sorted and unique array-of-hashes (default order is sort_keys on the sorted keys...)
    aoh         => sub { +{ type => 'array', unique => 1, sort_keys => [sort keys %{$_[0]}], values => { type => 'hash', keys => $_[0] } } },
};


sub is_insecurepass {
    config->{password_db} && PWLookup::lookup(config->{password_db}, shift)
}


# Recursively remove keys from hashes that have a '_when' key that doesn't
# match $when. This is a quick and dirty way to create multiple validation
# schemas from a single schema. For example:
#
#   {
#       title => { _when => 'input' },
#       name  => { },
#   }
#
# If $when is 'input', then this function returns:
#   { title => {}, name => {} }
# Otherwise, it returns:
#   { name => {} }
sub _stripwhen {
    my($when, $o) = @_;
    return $o if ref $o ne 'HASH';
    +{ map $_ eq '_when' || (ref $o->{$_} eq 'HASH' && defined $o->{$_}{_when} && $o->{$_}{_when} !~ $when) ? () : ($_, _stripwhen($when, $o->{$_})), keys %$o }
}


# Short-hand to compile a validation schema for a form. Usage:
#
#   form_compile $when, {
#       title => { _when => 'input' },
#       name  => { },
#       ..
#   };
sub form_compile {
    tuwf->compile({ type => 'hash', keys => _stripwhen @_ });
}


sub _eq_deep {
    my($a, $b) = @_;
    return 0 if ref $a ne ref $b;
    return 0 if defined $a != defined $b;
    return 1 if !defined $a;
    return 1 if !ref $a && $a eq $b;
    return 1 if ref $a eq 'ARRAY' && (@$a == @$b && !grep !_eq_deep($a->[$_], $b->[$_]), 0..$#$a);
    return 1 if ref $a eq 'HASH' && _eq_deep([sort keys %$a], [sort keys %$b]) && !grep !_eq_deep($a->{$_}, $b->{$_}), keys %$a;
    0
}


# Usage: form_changed $schema, $a, $b
# Returns 1 if there is a difference between the data ($a) and the form input
# ($b), using the normalization defined in $schema. The $schema must validate.
sub form_changed {
    my($schema, $a, $b) = @_;
    my $na = $schema->validate($a)->data;
    my $nb = $schema->validate($b)->data;

    #warn "a=".JSON::XS->new->pretty->canonical->encode($na);
    #warn "b=".JSON::XS->new->pretty->canonical->encode($nb);
    !_eq_deep $na, $nb;
}


# Validate identifiers against an SQL query. The query must end with a 'id IN'
# clause, where the @ids array is appended. The query must return exactly 1
# column, the id of each entry. This function throws an error if an id is
# missing from the query. For example, to test for non-hidden VNs:
#
#   validate_dbid 'SELECT id FROM vn WHERE NOT hidden AND id IN', 2,3,5,7,...;
#
# If any of those ids is hidden or not in the database, an error is thrown.
sub validate_dbid {
    my($sql, @ids) = @_;
    return if !@ids;
    $sql = ref $sql eq 'CODE' ? do { local $_ = \@ids; sql $sql->(\@ids) } : sql $sql, \@ids;
    my %dbids = map +((values %$_)[0],1), @{ tuwf->dbAlli($sql) };
    my @missing = grep !$dbids{$_}, @ids;
    croak "Invalid database IDs: ".join(',', @missing) if @missing;
}


# Returns whether the current user can edit the given database entry.
#
# Supported types:
#
#   u:
#     Requires 'id' field, can only test for editing.
#
#   t:
#     If no 'id' field, checks if the user can create a new thread
#       (permission to post in specific boards is not handled here).
#     If no 'num' field, checks if the user can reply to the existing thread.
#       Requires the 'locked' field.
#       Assumes the user is permitted to see the thread in the first place, i.e. neither hidden nor private.
#     Otherwise, checks if the user can edit the post.
#       Requires the 'user_id', 'date' and 'hidden' fields.
#
#   'dbentry_type's:
#     If no 'id' field, checks whether the user can create a new entry.
#     Otherwise, requires 'entry_hidden' and 'entry_locked' fields.
#
sub can_edit {
    my($type, $entry) = @_;

    return auth->permUsermod || (auth && $entry->{id} == auth->uid) if $type eq 'u';
    return auth->permDbmod if $type eq 'd';

    if($type eq 't') {
        return 0 if !auth->permBoard;
        return 1 if auth->permBoardmod;
        if(!$entry->{id}) {
            # Allow at most 5 new threads per day per user.
            return auth && tuwf->dbVali('SELECT count(*) < ', \5, 'FROM threads_posts WHERE num = 1 AND date > NOW()-\'1 day\'::interval AND uid =', \auth->uid);
        } elsif(!$entry->{num}) {
            die "Can't do authorization test when 'locked' field isn't present" if !exists $entry->{locked};
            return !$entry->{locked};
        } else {
            die "Can't do authorization test when hidden/date/user_id fields aren't present"
                if !exists $entry->{hidden} || !exists $entry->{date} || !exists $entry->{user_id};
            return auth && $entry->{user_id} == auth->uid && !$entry->{hidden} && $entry->{date} > time-config->{board_edit_time};
        }
    }

    die "Can't do authorization test when entry_hidden/entry_locked fields aren't present"
        if $entry->{id} && (!exists $entry->{entry_hidden} || !exists $entry->{entry_locked});

    auth->permDbmod || (auth->permEdit && !($entry->{entry_hidden} || $entry->{entry_locked}));
}

1;
