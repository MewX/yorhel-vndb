package VNWeb::Discussions::Index;

use VNWeb::Prelude;
use VNWeb::Discussions::Lib;


TUWF::get qr{/t}, sub {
    framework_ title => 'Discussion board index', sub {
        form_ method => 'get', action => '/t/search', sub {
            div_ class => 'mainbox', sub {
                h1_ 'Discussion board index';
                fieldset_ class => 'search', sub {
                    input_ type => 'text', name => 'bq', id => 'bq', class => 'text';
                    input_ type => 'submit', class => 'submit', value => 'Search!';
                };
                p_ class => 'browseopts', sub {
                    a_ href => '/t/all', 'All boards';
                    a_ href => '/t/'.$_, $BOARD_TYPE{$_}{txt} for (keys %BOARD_TYPE);
                };
            }
        };

        for my $b (keys %BOARD_TYPE) {
            h1_ class => 'boxtitle', sub {
                a_ href => "/t/$b", $BOARD_TYPE{$b}{txt};
            };
            threadlist_
                where   => sql('NOT t.private AND NOT t.hidden AND t.id IN(SELECT tid FROM threads_boards WHERE type =', \$b, ')'),
                boards  => sql('NOT (tb.type =', \$b, 'AND tb.iid = 0)'),
                results => $BOARD_TYPE{$b}{index_rows},
                page    => 1;
        }
    }
};

1;
