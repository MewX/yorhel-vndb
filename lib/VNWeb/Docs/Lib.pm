package VNWeb::Docs::Lib;

use VNWeb::Prelude;

our @EXPORT = qw/enrich_html/;


my @special_perms = qw/boardmod dbmod usermod tagmod/;

sub _moderators {
    my $cols = sql_comma map "perm_$_", @special_perms;
    my $where = sql_or map "perm_$_", @special_perms;
    my $l = tuwf->dbAlli("SELECT id, username, $cols FROM users WHERE $where ORDER BY id LIMIT 100");

    xml_string sub {
        dl_ sub {
            for my $u (@$l) {
                dt_ sub { a_ href => "/u$u->{id}", $u->{username} };
                dd_ @special_perms == grep($u->{"perm_$_"}, @special_perms) ? 'admin'
                    : join ', ', grep $u->{"perm_$_"}, @special_perms;
            }
        }
    }
}


sub _skincontrib {
    my %users;
    push $users{ tuwf->{skins}{$_}[1] }->@*, [ $_, tuwf->{skins}{$_}[0] ]
        for sort { tuwf->{skins}{$a}[0] cmp tuwf->{skins}{$b}[0] } keys tuwf->{skins}->%*;

    my $u = tuwf->dbAlli('SELECT id, username FROM users WHERE id IN', [keys %users]);

    xml_string sub {
        dl_ sub {
            for my $u (@$u) {
                dt_ sub { a_ href => "/u$u->{id}", $u->{username} };
                dd_ sub {
                    join_ ', ', sub { a_ href => "?skin=$_->[0]", $_->[1] }, $users{$u->{id}}->@*
                }
            }
        }
    }
}


sub enrich_html {
    my $html = shift;

    $html =~ s{^:MODERATORS:}{_moderators}me;
    $html =~ s{^:SKINCONTRIB:}{_skincontrib}me;

    $html
}

1;
