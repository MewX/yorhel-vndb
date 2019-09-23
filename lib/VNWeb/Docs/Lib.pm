package VNWeb::Docs::Lib;

use VNWeb::Prelude;
use Text::MultiMarkdown 'markdown';

our @EXPORT = qw/md2html/;


# Lets you call TUWF::XML functions and returns a string, doesn't affect any existing TUWF::XML outputs.
# Nice idea for a TUWF::XML feature.
sub lexicalxml(&) {
    my $f = shift;
    my $buf = '';
    local $TUWF::XML::OBJ = TUWF::XML->new(write => sub { $buf .= shift });
    $f->();
    $buf
}


sub _moderators {
    my $l = tuwf->dbAlli('SELECT id, username, perm FROM users WHERE (perm & ', \(auth->allPerms &~ auth->defaultPerms), ') > 0 ORDER BY id LIMIT 100');
    my @modperms = grep 0 == (auth->listPerms->{$_} & auth->defaultPerms), keys auth->listPerms->%*;

    lexicalxml {
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

    lexicalxml {
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


sub md2html {
    my $content = shift;

    $content =~ s{^:MODERATORS:$}{_moderators}me;
    $content =~ s{^:SKINCONTRIB:$}{_skincontrib}me;

    my $html = markdown $content, {
        strip_metadata => 1,
        img_ids => 0,
        disable_footnotes => 1,
        disable_bibliography => 1,
    };

    # Number sections and turn them into links
    my($sec, $subsec) = (0,0);
    $html =~ s{<h([1-2])[^>]+>(.*?)</h\1>}{
        if($1 == 1) {
            $sec++;
            $subsec = 0;
            qq{<h3><a href="#$sec" name="$sec">$sec. $2</a></h3>}
        } elsif($1 == 2) {
            $subsec++;
            qq|<h4><a href="#$sec.$subsec" name="$sec.$subsec">$sec.$subsec. $2</a></h4>\n|
        }
    }ge;

    # Text::MultiMarkdown doesn't handle fenced code blocks properly. The
    # following solution breaks inline code blocks, but I don't use those anyway.
    $html =~ s/<code>/<pre>/g;
    $html =~ s#</code>#</pre>#g;

    $html
}

1;
