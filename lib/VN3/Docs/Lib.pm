package VN3::Docs::Lib;

use VN3::Prelude;
use Text::MultiMarkdown 'markdown';

our @EXPORT = qw/md2html Sidebar/;


sub md2html {
    my $content = shift;

    $content =~ s{^:MODERATORS:$}{
        my %modperms = map auth->listPerms->{$_} & auth->defaultPerms ? () : ($_, auth->listPerms->{$_}), keys %{ auth->listPerms };
        my $l = tuwf->dbAlli('SELECT id, username, perm FROM users WHERE (perm & ', \(auth->allPerms &~ auth->defaultPerms), ') > 0 ORDER BY id LIMIT 100');
        '<dl>'.join('', map {
            my $u = $_;
            my $p = $u->{perm} >= auth->allPerms ? 'admin'
                : join ', ', sort grep $u->{perm} & $modperms{$_}, keys %modperms;
            sprintf '<dt><a href="/u%d">%s</a></dt><dd>%s</dd>', $_->{id}, $_->{username}, $p;
        } @$l).'</dl>';
    }me;

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
            qq{<h2><a href="#$sec" name="$sec">$sec. $2</a></h2>}
        } elsif($1 == 2) {
            $subsec++;
            qq|<h3><a href="#$sec.$subsec" name="$sec.$subsec">$sec.$subsec. $2</a></h3>\n|
        }
    }ge;

    # Text::MultiMarkdown doesn't handle fenced code blocks properly. The
    # following solution breaks inline code blocks, but I don't use those anyway.
    $html =~ s/<code>/<pre>/g;
    $html =~ s#</code>#</pre>#g;

    $html
}


sub Cat {
    Div class => 'doc-list__title', $_[0];
}

sub Doc {
    A mkclass('doc-list__doc' => 1, 'doc-list__doc--active' => tuwf->capture('id') == $_[0]),
        href => "/d$_[0]", $_[1];
}


sub Sidebar {
    # TODO: Turn this into a nav-sidebar for better mobile viewing?
    Cat 'About VNDB';
    Doc  7, 'About us';
    Doc  6, 'FAQ';
    Doc  9, 'Discussion board';
    Doc 17, 'Privacy Policy & Licensing';
    Doc 11, 'Database API';
    Doc 14, 'Database Dumps';
    Doc 18, 'Database Querying';
    Doc  8, 'Development';

    Cat 'Guidelines';
    Doc  5, 'Editing guidelines';
    Doc  2, 'Visual novels';
    Doc 15, 'Special games';
    Doc  3, 'Releases';
    Doc  4, 'Producers';
    Doc 16, 'Staff';
    Doc 12, 'Characters';
    Doc 10, 'Tags & Traits';
    Doc 13, 'Capturing screenshots';
}

1;
