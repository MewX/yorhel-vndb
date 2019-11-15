package VNWeb::Discussions::Search;

use VNWeb::Prelude;


sub filters_ {
    state $schema = tuwf->compile({ type => 'hash', keys => {
        bq => { required => 0, default => '' },
        b  => { type => 'array', scalar => 1, required => 0, default => [keys %BOARD_TYPE], values => { enum => \%BOARD_TYPE } },
        t  => { anybool => 1 },
        p  => { page => 1 },
    }});
    my $filt = eval { tuwf->validate(get => $schema)->data } || tuwf->pass;
    my %boards = map +($_,1), $filt->{b}->@*;

    form_ method => 'get', action => tuwf->reqPath(), sub {
        table_ style => 'margin: 0 auto', sub { tr_ sub {
                td_ style => 'padding: 10px', sub {
                    p_ class => 'linkradio', sub {
                        join_ \&br_, sub {
                            input_ type => 'checkbox', name => 'b', id => "b_$_", value => $_, $boards{$_} ? (checked => 'checked') : ();
                            label_ for => "b_$_", $BOARD_TYPE{$_}{txt};
                        }, keys %BOARD_TYPE;
                    }
                };
                td_ style => 'padding: 10px', sub {
                    input_ type => 'text', class => 'text', name => 'bq', style => 'width: 400px', placeholder => 'Search', value => $filt->{bq};

                    p_ class => 'linkradio', sub {
                        input_ type => 'checkbox', name => 't', id => 't', value => 1, $filt->{t} ? (checked => 'checked') : ();
                        label_ for => 't', 'Only search thread titles';
                    };

                    input_ type => 'submit', class => 'submit', value => 'Search';
                    debug_ $filt;
                };
            };
        }
    };
    $filt
}


sub noresults_ {
    div_ class => 'mainbox', sub {
        h1_ 'No results';
        p_ 'No threads or messages found matching your criteria.';
    };
}


sub posts_ {
    my($filt) = @_;

    # Turn query into something suitable for to_tsquery()
    # TODO: Use Postgres 11 websearch_to_tsquery() instead.
    (my $ts = $filt->{bq}) =~ y{+|&:*()="';!?$%^\\[]{}<>~` }{ }s;
    $ts =~ s/ +/ /;
    $ts =~ s/^ //;
    $ts =~ s/ $//;
    $ts =~ s/ / & /g;
    $ts =~ s/(?:^| )-([^ ]+)/ !$1 /;

    # HACK: The bbcodes are stripped from the original messages when creating
    # the headline, so they are guaranteed not to show up in the message. This
    # means we can re-use them for highlighting without worrying that they
    # conflict with the message contents.

    my($posts, $np) = tuwf->dbPagei({ results => 20, page => $filt->{p} }, q{
        SELECT tp.tid, tp.num, t.title
             , }, sql_user(), q{
             , }, sql_totime('tp.date'), q{as date
             , ts_headline('english', strip_bb_tags(strip_spoilers(tp.msg)), to_tsquery(}, \$ts, '),',
                 \'MaxFragments=2,MinWords=15,MaxWords=40,StartSel=[raw],StopSel=[/raw],FragmentDelimiter=[code]',
               q{) as headline
          FROM threads_posts tp
          JOIN threads t ON t.id = tp.tid
          JOIN users u ON u.id = tp.uid
         WHERE NOT t.hidden AND NOT t.private AND NOT tp.hidden
           AND bb_tsvector(tp.msg) @@ to_tsquery(}, \$ts, ')',
               $filt->{b}->@* < keys %BOARD_TYPE ? ('AND t.id IN(SELECT tid FROM threads_boards WHERE type IN', $filt->{b}, ')') : (), q{
         ORDER BY tp.date DESC
    });

    return noresults_ if !@$posts;

    my sub url { '?'.query_encode %$filt, @_ }
    paginate_ \&url, $filt->{p}, $np, 't';
    div_ class => 'mainbox browse postsearch', sub {
        table_ class => 'stripe', sub {
            thead_ sub { tr_ sub {
                td_ class => 'tc1_1', 'Id';
                td_ class => 'tc1_2', '';
                td_ class => 'tc2', 'Date';
                td_ class => 'tc3', 'User';
                td_ class => 'tc4', sub { txt_ 'Message'; debug_ $posts; };
            }};
            tr_ sub {
                my $l = $_;
                my $link = "/t$l->{tid}.$l->{num}";
                td_ class => 'tc1_1', sub { a_ href => $link, 't'.$l->{tid} };
                td_ class => 'tc1_2', sub { a_ href => $link, '.'.$l->{num} };
                td_ class => 'tc2', fmtdate $l->{date};
                td_ class => 'tc3', sub { user_ $l };
                td_ class => 'tc4', sub {
                    div_ class => 'title', sub { a_ href => $link, $l->{title} };
                    div_ class => 'thread', sub { lit_(
                        TUWF::XML::xml_escape($l->{headline})
                            =~ s/\[raw\]/<b class="standout">/gr
                            =~ s/\[\/raw\]/<\/b>/gr
                            =~ s/\[code\]/<b class="grayedout">...<\/b><br \/>/gr
                    )};
                };
            } for @$posts;
        }
    };
    paginate_ \&url, $filt->{p}, $np, 'b';
}


sub threads_ {
    my($filt) = @_;

    my $where = sql_and
        'NOT t.hidden',
        'NOT t.private',
        $filt->{b}->@* < keys %BOARD_TYPE ? sql('t.id IN(SELECT tid FROM threads_boards WHERE type IN', $filt->{b}, ')') : (),
        map sql('t.title ilike', \('%'.($_ =~ s/%//gr).'%')), grep length($_) > 0, split /[ -,._]/, $filt->{bq};

    my $count = tuwf->dbVali('SELECT count(*) FROM threads t WHERE', $where);
    return noresults_ if !$count;

    my $lst = tuwf->dbPagei({ results => 50, page => $filt->{p} }, q{
        SELECT t.id, t.title, t.count, t.locked, t.poll_question IS NOT NULL AS haspoll
             , }, sql_user('tfu', 'firstpost_'), ',', sql_totime('tf.date'), q{ as firstpost_date
             , }, sql_user('tlu', 'lastpost_'),  ',', sql_totime('tl.date'), q{ as lastpost_date
          FROM threads t
          JOIN threads_posts tf ON tf.tid = t.id AND tf.num = 1
          JOIN threads_posts tl ON tl.tid = t.id AND tl.num = t.count
          JOIN users tfu ON tfu.id = tf.uid
          JOIN users tlu ON tlu.id = tl.uid
         WHERE }, $where, q{
         ORDER BY tl.date DESC
    });

    enrich boards => id => tid => sub { sql q{
        SELECT tb.tid, tb.type, tb.iid, COALESCE(u.username, v.title, p.name) AS title, COALESCE(u.username, v.original, p.original) AS original
          FROM threads_boards tb
          LEFT JOIN vn v ON tb.type = 'v' AND v.id = tb.iid
          LEFT JOIN producers p ON tb.type = 'p' AND p.id = tb.iid
          LEFT JOIN users u ON tb.type = 'u' AND u.id = tb.iid
         WHERE tb.tid IN}, $_[0], q{
         ORDER BY tb.type, tb.iid
    }}, $lst;


    my sub url { '?'.query_encode %$filt, @_ }
    paginate_ \&url, $filt->{p}, [ $count, 50 ], 't';
    div_ class => 'mainbox browse discussions', sub {
        table_ class => 'stripe', sub {
            thead_ sub { tr_ sub {
                td_ class => 'tc1', sub { txt_ 'Topic'; debug_ $lst };
                td_ class => 'tc2', 'Replies';
                td_ class => 'tc3', 'Starter';
                td_ class => 'tc4', 'Last post';
            }};
            tr_ sub {
                my $l = $_;
                td_ class => 'tc1', sub {
                    a_ mkclass(locked => $l->{locked}), href => "/t$l->{id}", sub {
                        span_ class => 'pollflag', '[poll]' if $l->{haspoll};
                        txt_ shorten $l->{title}, 50;
                    };
                    b_ class => 'boards', sub {
                        join_ ', ', sub {
                            a_ href => "/t/$_->{type}".($_->{iid}||''),
                                title => $_->{original}||$BOARD_TYPE{$_->{type}}{txt},
                                shorten $_->{title}||$BOARD_TYPE{$_->{type}}{txt}, 30;
                        }, $l->{boards}->@[0 .. min 4, $#{$l->{boards}}];
                        txt_ ', ...' if $l->{boards}->@* > 4;
                    };
                };
                td_ class => 'tc2', $l->{count}-1;
                td_ class => 'tc3', sub { user_ $l, 'firstpost_' };
                td_ class => 'tc4', sub {
                    user_ $l, 'lastpost_';
                    txt_ ' @ ';
                    a_ href => "/t$l->{id}.$l->{count}", fmtdate $l->{lastpost_date}, 'full';
                };
            } for @$lst;
        }
    };
    paginate_ \&url, $filt->{p}, [ $count, 50 ], 'b';
}


TUWF::get qr{/t/search}, sub {
    framework_ title => 'Search the discussion board',
    sub {
        my $filt;
        div_ class => 'mainbox', sub {
            h1_ 'Search the discussion board';
            $filt = filters_;
        };
        posts_   $filt if $filt->{bq} && !$filt->{t};
        threads_ $filt if $filt->{bq} &&  $filt->{t};
    };
};

1;
