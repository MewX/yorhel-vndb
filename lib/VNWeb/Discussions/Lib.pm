package VNWeb::Discussions::Lib;

use VNWeb::Prelude;
use Exporter 'import';

our @EXPORT = qw/threadlist_/;


# Generate a thread list table, options:
#   where    => SQL for the WHERE clause ('t' is available as alias for 'threads').
#   boards   => SQL for the WHERE clause of the boards ('tb' as alias for 'threads_boards').
#   results  => Number of threads to display.
#   page     => Current page number.
#   paginate => sub {} reference that generates a url for paginate_(); pagination is disabled when not set.
#
# Returns 1 if something was displayed, 0 if no threads matched the where clause.
sub threadlist_ {
    my %opt = @_;

    my $count = $opt{paginate} && tuwf->dbVali('SELECT count(*) FROM threads t WHERE', $opt{where});
    return 0 if $opt{paginate} && !$count;

    my $lst = tuwf->dbPagei(\%opt, q{
        SELECT t.id, t.title, t.count, t.locked, t.poll_question IS NOT NULL AS haspoll
             , }, sql_user('tfu', 'firstpost_'), ',', sql_totime('tf.date'), q{ as firstpost_date
             , }, sql_user('tlu', 'lastpost_'),  ',', sql_totime('tl.date'), q{ as lastpost_date
          FROM threads t
          JOIN threads_posts tf ON tf.tid = t.id AND tf.num = 1
          JOIN threads_posts tl ON tl.tid = t.id AND tl.num = t.count
          JOIN users tfu ON tfu.id = tf.uid
          JOIN users tlu ON tlu.id = tl.uid
         WHERE }, $opt{where}, q{
         ORDER BY tl.date DESC
    });
    return 0 if !@$lst;

    enrich boards => id => tid => sub { sql q{
        SELECT tb.tid, tb.type, tb.iid, COALESCE(u.username, v.title, p.name) AS title, COALESCE(u.username, v.original, p.original) AS original
          FROM threads_boards tb
          LEFT JOIN vn v ON tb.type = 'v' AND v.id = tb.iid
          LEFT JOIN producers p ON tb.type = 'p' AND p.id = tb.iid
          LEFT JOIN users u ON tb.type = 'u' AND u.id = tb.iid
         WHERE }, sql_and(sql('tb.tid IN', $_[0]), $opt{boards}||()), q{
         ORDER BY tb.type, tb.iid
    }}, $lst;


    paginate_ $opt{paginate}, $opt{page}, [ $count, $opt{results} ], 't' if $opt{paginate};
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
    paginate_ $opt{paginate}, $opt{page}, [ $count, $opt{results} ], 'b' if $opt{paginate};
    1;
}

1;
