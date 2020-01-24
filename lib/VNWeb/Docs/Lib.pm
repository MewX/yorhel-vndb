package VNWeb::Docs::Lib;

use VNWeb::Prelude;

our @EXPORT = qw/enrich_html/;


sub _moderators {
    my $l = tuwf->dbAlli('SELECT id, username, perm FROM users WHERE (perm & ', \(auth->allPerms &~ auth->defaultPerms), ') > 0 ORDER BY id LIMIT 100');
    my @modperms = grep 0 == (auth->listPerms->{$_} & auth->defaultPerms), keys auth->listPerms->%*;

    xml_string sub {
        dl_ sub {
            for my $u (@$l) {
                dt_ sub { a_ href => "/u$u->{id}", $u->{username} };
                dd_ auth->allPerms == ($u->{perm} & auth->allPerms) ? 'admin'
                    : join ', ', sort grep $u->{perm} & auth->listPerms->{$_}, @modperms;
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
