package VNWeb::User::List;

use VNWeb::Prelude;


sub listing_ {
    my($opt, $list, $count) = @_;

    my sub url { '?'.query_encode %$opt, @_ }

    paginate_ \&url, $opt->{p}, [$count, 50], 't';
    div_ class => 'mainbox browse', sub {
        table_ class => 'stripe', sub {
            thead_ sub { tr_ sub {
                td_ class => 'tc1', sub { txt_ 'Username';   sortable_ 'username',   $opt, \&url };
                td_ class => 'tc2', sub { txt_ 'Registered'; sortable_ 'registered', $opt, \&url };
                td_ class => 'tc3', sub { txt_ 'Votes';      sortable_ 'votes',      $opt, \&url };
                td_ class => 'tc4', sub { txt_ 'Edits';      sortable_ 'changes',    $opt, \&url };
                td_ class => 'tc5', sub { txt_ 'Tags';       sortable_ 'tags',       $opt, \&url };
            } };
            tr_ sub {
                my $l = $_;
                td_ class => 'tc1', sub { user_ $l };
                td_ class => 'tc2', fmtdate $l->{registered};
                td_ mkclass(tc3 => 1, linethrough => $l->{hide_list} && auth->permUsermod), sub {
                    if($l->{hide_list} && !auth->permUsermod) {
                        txt_ '-';
                    } elsif(!$l->{c_votes}) {
                        txt_ '0';
                    } else {
                        a_ href => "/u$l->{user_id}/votes", $l->{c_votes};
                    }
                };
                td_ class => 'tc4', sub {
                    txt_ '-' if !$l->{c_changes};
                    a_ href => "/u$l->{user_id}/hist", $l->{c_changes} if $l->{c_changes};
                };
                td_ class => 'tc5', sub {
                    txt_ '-' if !$l->{c_tags};
                    a_ href => "/g/links?u=$l->{user_id}", $l->{c_tags} if $l->{c_tags};
                };
            } for @$list;
        };
    };
    paginate_ \&url, $opt->{p}, [$count, 50], 'b';
}


TUWF::get qr{/u/(?<char>[0a-z]|all)}, sub {
    my $char = tuwf->capture('char');

    my $opt = eval { tuwf->validate(get =>
        p => { upage => 1 },
        s => { required => 0, default => 'registered', enum => [qw[username registered votes changes tags]] },
        o => { required => 0, default => 'd',          enum => [qw[a d]] },
        q => { required => 0, default => '' },
    )->data } || return tuwf->resNotFound;

    my @where = (
        $char eq 'all' ? () : $char eq '0' ? "ascii(username) not between ascii('a') and ascii('z')" : "username like '$char%'",
        $opt->{q} ? sql_or(
            $opt->{q} =~ /^u?([0-9]+)$/ ? sql 'id =', \"$1" : (),
            sql 'position(', \$opt->{q}, 'in username) > 0'
        ) : ()
    );

    my($list) = tuwf->dbPagei({ results => 50, page => $opt->{p} },
        'SELECT', sql_user(), ',', sql_totime('registered'), 'as registered, c_votes, c_changes, c_tags, hide_list
           FROM users u
          WHERE', sql_and('id > 0', @where),
         'ORDER BY', {
                  username   => 'username',
                  registered => 'id',
                  votes      => auth->permUsermod ? 'c_votes' : 'hide_list, c_votes',
                  changes    => 'c_changes',
                  tags       => 'c_tags'
                }->{$opt->{s}}, $opt->{o} eq 'd' ? 'DESC' : 'ASC'
    );
    my $count = @where ? tuwf->dbVali('SELECT count(*) FROM users WHERE', sql_and @where) : tuwf->{stats}{users};

    framework_ title => 'Browse users', index => 0, sub {
        div_ class => 'mainbox', sub {
            h1_ 'Browse users';
            form_ action => '/u/all', method => 'get', sub {
                searchbox_ u => $opt->{q};
            };
            p_ class => 'browseopts', sub {
                a_ href => "/u/$_", $_ eq $char ? (class => 'optselected') : (), $_ eq 'all' ? 'ALL' : $_ ? uc $_ : '#'
                    for ('all', 'a'..'z', 0);
            };
        };
        listing_ $opt, $list, $count if $count;
    };
};

1;
