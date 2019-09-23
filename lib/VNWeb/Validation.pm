package VNWeb::Validation;

use v5.26;
use TUWF;
use VNWeb::Auth;
use Exporter 'import';

our @EXPORT = qw/
    can_edit
/;


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
