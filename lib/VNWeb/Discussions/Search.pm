package VNWeb::Discussions::Search;

use VNWeb::Prelude;
use VNWeb::Discussions::Lib;


sub filters_ {
    state $schema = tuwf->compile({ type => 'hash', keys => {
        bq => { required => 0, default => '' },
        b  => { type => 'array', scalar => 1, onerror => [keys %BOARD_TYPE], values => { enum => \%BOARD_TYPE } },
        t  => { anybool => 1 },
        p  => { page => 1 },
    }});
    my $filt = tuwf->validate(get => $schema)->data;
    my %boards = map +($_,1), $filt->{b}->@*;

    form_ method => 'get', action => tuwf->reqPath(), sub {
        boardtypes_;
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
          LEFT JOIN users u ON u.id = tp.uid
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
                my $link = "/$l->{tid}.$l->{num}";
                td_ class => 'tc1_1', sub { a_ href => $link, $l->{tid} };
                td_ class => 'tc1_2', sub { a_ href => $link, '.'.$l->{num} };
                td_ class => 'tc2', fmtdate $l->{date};
                td_ class => 'tc3', sub { user_ $l };
                td_ class => 'tc4', sub {
                    div_ class => 'title', sub { a_ href => $link, $l->{title} };
                    div_ class => 'thread', sub { lit_(
                        xml_escape($l->{headline})
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
        $filt->{b}->@* < keys %BOARD_TYPE ? sql('t.id IN(SELECT tid FROM threads_boards WHERE type IN', $filt->{b}, ')') : (),
        map sql('t.title ilike', \('%'.sql_like($_).'%')), grep length($_) > 0, split /[ ,._-]/, $filt->{bq};

    noresults_ if !threadlist_
        where    => $where,
        results  => 50,
        page     => $filt->{p},
        paginate => sub { '?'.query_encode %$filt, @_ };
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
