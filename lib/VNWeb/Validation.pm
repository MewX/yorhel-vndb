package VNWeb::Validation;

use v5.26;
use TUWF;
use PWLookup;
use VNDB::Config;
use VNWeb::Auth;
use Exporter 'import';

our @EXPORT = qw/
    is_insecurepass
    form_compile
    form_changed
    can_edit
/;


TUWF::set custom_validations => {
    id          => { uint => 1, max => 1<<40 },
    editsum     => { required => 1, length => [ 2, 5000 ] },
    page        => { uint => 1, min => 1, max => 1000, required => 0, default => 1 },
    upage       => { uint => 1, min => 1, required => 0, default => 1 }, # pagination without a maximum
    username    => { regex => qr/^(?!-*[a-z][0-9]+-*$)[a-z0-9-]*$/, minlength => 2, maxlength => 15 },
    password    => { length => [ 4, 500 ] },
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


# Returns whether the current user can edit the given database entry.
sub can_edit {
    my($type, $entry) = @_;

    return auth->permUsermod || (auth && $entry->{id} == auth->uid) if $type eq 'u';
    return auth->permDbmod if $type eq 'd';

    die "Can't do authorization test when entry_hidden/entry_locked fields aren't present"
        if $entry->{id} && (!exists $entry->{entry_hidden} || !exists $entry->{entry_locked});

    auth->permDbmod || (auth->permEdit && !($entry->{entry_hidden} || $entry->{entry_locked}));
}

1;
