package VNWeb::Tags::Links;

use VNWeb::Prelude;


# XXX: This is ugly, both in code and UI. Not sure what to replace it with.
sub tagscore_ {
    my $s = shift;
    div_ class => 'taglvl', style => sprintf('width: %.0fpx', ($s-floor($s))*10), ' ' if $s < 0 && $s-floor($s) > 0;
    for(-3..3) {
        if($_ < 0) {
            if($s > 0 || floor($s) > $_) {
                div_ class => "taglvl taglvl$_", ' ';
            } elsif(floor($s) != $_) {
                div_ class => "taglvl taglvl$_ taglvlsel", ' ';
            } else {
                div_ class => "taglvl taglvl$_ taglvlsel", style => sprintf('width: %.0fpx', 10-($s-$_)*10), ' ';
            }
        } elsif($_ > 0) {
            if($s < 0 || ceil($s) < $_) {
                div_ class => "taglvl taglvl$_", ' ';
            } elsif(ceil($s) != $_) {
                div_ class => "taglvl taglvl$_ taglvlsel", ' ';
            } else {
                div_ class => "taglvl taglvl$_ taglvlsel", style => sprintf('width: %.0fpx', 10-($_-$s)*10), ' ';
            }
        } else {
            div_ class => "taglvl taglvl0", sprintf '%.1f', $s;
        }
    }
    div_ class => 'taglvl', style => sprintf('width: %.0fpx', (ceil($s)-$s)*10), ' ' if $s > 0 && ceil($s)-$s > 0;
}


sub listing_ {
    my($opt, $lst, $np, $url) = @_;

    paginate_ $url, $opt->{p}, $np, 't';
    div_ class => 'mainbox browse taglinks', sub {
        table_ class => 'stripe', sub {
            thead_ sub { tr_ sub {
                    td_ class => 'tc1', sub { txt_ 'Date'; sortable_ 'date', $opt, $url; debug_ $lst; };
                    td_ class => 'tc2', 'User';
                    td_ class => 'tc3', 'Rating';
                    td_ class => 'tc4', sub { txt_ 'Tag';  sortable_ 'tag', $opt, $url };
                    td_ class => 'tc5', 'Spoiler';
                    td_ class => 'tc6', 'Visual novel';
                }};
            tr_ sub {
                my $i = $_;
                td_ class => 'tc1', fmtdate $i->{date};
                td_ class => 'tc2', sub {
                    a_ href => $url->(u => $i->{uid}, p=>undef), class => 'setfil', '> ' if !defined $opt->{u};
                    user_ $i;
                };
                td_ mkclass(tc3 => 1, ignored => $i->{ignored}), sub { tagscore_ $i->{vote} };
                td_ class => 'tc4', sub {
                    a_ href => $url->(t => $i->{uid}, p=>undef), class => 'setfil', '> ' if !defined $opt->{t};
                    a_ href => "/g$i->{tag}", $i->{name};
                };
                td_ class => 'tc5', !defined $i->{spoiler} ? '' : fmtspoil $i->{spoiler};
                td_ class => 'tc6', sub {
                    a_ href => $url->(v => $i->{vid}, p=>undef), class => 'setfil', '> ' if !defined $opt->{v};
                    a_ href => "/v$i->{vid}", shorten $i->{title}, 50;
                };
            } for @$lst;
        };
    };
    paginate_ $url, $opt->{p}, $np, 'b';
}


TUWF::get qr{/g/links}, sub {
    my $opt = tuwf->validate(get =>
        p => { page => 1 },
        o => { onerror => 'd', enum => ['a', 'd'] },
        s => { onerror => 'date', enum => [qw|date tag|] },
        v => { onerror => undef, id => 1 },
        u => { onerror => undef, id => 1 },
        t => { onerror => undef, id => 1 },
    )->data;

    my $where = sql_and
        defined $opt->{v} ? sql('tv.vid =', \$opt->{v}) : (),
        defined $opt->{u} ? sql('tv.uid =', \$opt->{u}) : (),
        defined $opt->{t} ? sql('tv.tag =', \$opt->{t}) : ();

    my $filt = defined $opt->{u} || defined $opt->{t} || defined $opt->{v};

    my $count = $filt && tuwf->dbVali('SELECT COUNT(*) FROM tags_vn tv WHERE', $where);
    my($lst, $np) = tuwf->dbPagei({ page => $opt->{p}, results => 50 }, '
        SELECT tv.vid, tv.uid, tv.tag, tv.vote, tv.spoiler,', sql_totime('tv.date'), 'as date, tv.ignore, v.title,', sql_user(), ', t.name
          FROM tags_vn tv
          JOIN vn v ON v.id = tv.vid
          JOIN users u ON u.id = tv.uid
          JOIN tags t ON t.id = tv.tag
         WHERE', $where, '
         ORDER BY', { date => 'tv.date', tag => 't.name' }->{$opt->{s}}, { a => 'ASC', d => 'DESC' }->{$opt->{o}}
    );
    $np = [ $count, 50 ] if $count;

    my sub url { '?'.query_encode %$opt, @_ }

    framework_ title => 'Tag link browser', sub {
        div_ class => 'mainbox', sub {
            h1_ 'Tag link browser';
            div_ class => 'warning', sub {
                h2_ 'Spoiler warning';
                p_ 'This list displays the tag votes of individual users. Spoilery tags are not hidden, and may not even be correctly flagged as such.';
            };
            br_;
            if($filt) {
                p_ 'Active filters:';
                ul_ sub {
                    li_ sub {
                        txt_ '['; a_ href => url(u=>undef, p=>undef), 'remove'; txt_ '] ';
                        txt_ 'User: ';
                        user_ tuwf->dbRowi('SELECT', sql_user(), 'FROM users u WHERE id=', \$opt->{u});
                    } if defined $opt->{u};
                    li_ sub {
                        txt_ '['; a_ href => url(t=>undef, p=>undef), 'remove'; txt_ '] ';
                        txt_ 'Tag:'; txt_ ' ';
                        a_ href => "/g$opt->{t}", tuwf->dbVali('SELECT name FROM tags WHERE id=', \$opt->{t})||'Unknown tag';
                    } if defined $opt->{t};
                    li_ sub {
                        txt_ '['; a_ href => url(v=>undef, p=>undef), 'remove'; txt_ '] ';
                        txt_ 'Visual novel'; txt_ ' ';
                        a_ href => "/v$opt->{v}", tuwf->dbVali('SELECT title FROM vn WHERE id=', \$opt->{v})||'Unknown VN';
                    } if defined $opt->{v};
                }
            }
            if($lst && @$lst) {
                p_ 'Click the arrow before a user, tag or VN to add it as a filter.'
                    if !defined $opt->{u} && !defined $opt->{t} && !defined $opt->{v};
            } else {
                p_ 'No tag votes matching the requested filters.';
            }
        };

        listing_ $opt, $lst, $np, \&url if $lst && @$lst;
    };
};

1;
