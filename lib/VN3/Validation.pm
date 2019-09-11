# This module provides additional validations for tuwf->validate(), and exports
# a few convenient form handling/validation functions.
package VN3::Validation;

use strict;
use warnings;
use TUWF;
use VNDBUtil;
use VNDB::Types;
use VN3::DB;
use VN3::Auth;
use VN3::Types;
use JSON::XS;
use Exporter 'import';
use Time::Local 'timegm';
use Carp 'croak';
our @EXPORT = ('form_compile', 'form_changed', 'validate_dbid', 'can_edit');


TUWF::set custom_validations => {
    id          => { uint => 1, max => 1<<40 },
    page        => { uint => 1, min => 1, max => 1000, required => 0, default => 1 },
    username    => { regex => qr/^[a-z0-9-]{2,15}$/ },
    password    => { length => [ 4, 500 ] },
    editsum     => { required => 1, length => [ 2, 5000 ] },
    vn_length   => { required => 0, default => 0, uint => 1, range => [ 0, $#VN_LENGTHS ] },
    vn_relation => { enum => \%VN_RELATION },
    producer_relation => { enum => \%PRODUCER_RELATION },
    staff_role  => { enum => \%CREDIT_TYPE },
    char_role   => { enum => \%CHAR_ROLE },
    language    => { enum => \%LANGUAGE },
    platform    => { enum => \%PLATFORM },
    medium      => { enum => \%MEDIA },
    resolution  => { enum => \%RESOLUTIONS },
    gender      => { enum => \%GENDER },
    blood_type  => { enum => \%BLOOD_TYPE },
    gtin        => { uint => 1, func => sub { $_[0] eq 0 || gtintype($_[0]) } },
    minage      => { uint => 1, enum => \@MINAGE },
    animated    => { uint => 1, range => [ 0, $#ANIMATED ] },
    voiced      => { uint => 1, range => [ 0, $#VOICED ] },
    rdate       => { uint => 1, func => \&_validate_rdate },
    spoiler     => { uint => 1, range => [ 0, 2 ] },
    vnlist_status=>{ enum => \%VNLIST_STATUS },
    # Accepts a user-entered vote string (or '-' or empty) and converts that into a DB vote number (or undef)
    vnvote      => { regex => qr/^(?:|-|[1-9]|10|[1-9]\.[0-9]|10\.0)$/, required => 0, func => sub { $_[0] = $_[0] eq '-' ? undef : 10*$_[0]; 1 } },
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


sub _validate_rdate {
    return 0 if $_[0] ne 0 && $_[0] !~ /^([0-9]{4})([0-9]{2})([0-9]{2})$/;
    my($y, $m, $d) = $_[0] eq 0 ? (0,0,0) : ($1, $2, $3);

    # Re-normalize
    ($m, $d) = (0, 0) if $y == 0;
    $m = 99 if $y == 9999;
    $d = 99 if $m == 99;
    $_[0] = $y*10000 + $m*100 + $d;

    return 0 if $y && $y != 9999 && ($y < 1980 || $y > 2100);
    return 0 if $y && $m != 99 && (!$m || $m > 12);
    return 0 if $y && $d != 99 && !eval { timegm(0, 0, 0, $d, $m-1, $y) };
    return 1;
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
sub stripwhen {
    my($when, $o) = @_;
    return $o if ref $o ne 'HASH';
    +{ map $_ eq '_when' || (ref $o->{$_} eq 'HASH' && defined $o->{$_}{_when} && $o->{$_}{_when} !~ $when) ? () : ($_, stripwhen($when, $o->{$_})), keys %$o }
}


# Short-hand to compile a validation schema for a form. Usage:
#
#   form_compile $when, {
#       title => { _when => 'input' },
#       name  => { },
#       ..
#   };
sub form_compile {
    tuwf->compile({ type => 'hash', keys => stripwhen @_ });
}


sub eq_deep {
    my($a, $b) = @_;
    return 0 if ref $a ne ref $b;
    return 0 if defined $a != defined $b;
    return 1 if !defined $a;
    return 1 if !ref $a && $a eq $b;
    return 1 if ref $a eq 'ARRAY' && (@$a == @$b && !grep !eq_deep($a->[$_], $b->[$_]), 0..$#$a);
    return 1 if ref $a eq 'HASH' && eq_deep([sort keys %$a], [sort keys %$b]) && !grep !eq_deep($a->{$_}, $b->{$_}), keys %$a;
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
    !eq_deep $na, $nb;
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
    $sql = ref $sql eq 'CODE' ? sql $sql->(\@ids) : sql $sql, \@ids;
    my %dbids = map +((values %$_)[0],1), @{ tuwf->dbAlli($sql) };
    my @missing = grep !$dbids{$_}, @ids;
    croak "Invalid database IDs: ".join(',', @missing) if @missing;
}


# Returns whether the current user can edit the given database entry.
sub can_edit {
    my($type, $entry) = @_;

    return auth->permUsermod || $entry->{id} == (auth->uid||0) if $type eq 'u';
    return auth->permDbmod if $type eq 'd';

    die "Can't do authorization test when entry_hidden/entry_locked fields aren't present"
        if $entry->{id} && (!exists $entry->{entry_hidden} || !exists $entry->{entry_locked});

    auth->permDbmod || (auth->permEdit && !($entry->{entry_hidden} || $entry->{entry_locked}));
}

1;
