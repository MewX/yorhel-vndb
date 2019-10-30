package VNWeb::Discussions::UPosts;

use VNWeb::Prelude;


sub listing_ {
    my($count, $list, $page) = @_;

    my sub url { '?'.query_encode @_ }

    paginate_ \&url, $page, [ $count, 50 ], 't';
    div_ class => 'mainbox browse uposts', sub {
        table_ class => 'stripe', sub {
            thead_ sub { tr_ sub {
                td_ class => 'tc1', sub { debug_ $list };
                td_ class => 'tc2', '';
                td_ class => 'tc3', 'Date';
                td_ class => 'tc4', 'Title';
            }};
            tr_ sub {
                my $url = "/t$_->{tid}.$_->{num}";
                td_ class => 'tc1', sub { a_ href => $url, 't'.$_->{tid} };
                td_ class => 'tc2', sub { a_ href => $url, '.'.$_->{num} };
                td_ class => 'tc3', fmtdate $_->{date};
                td_ class => 'tc4', sub {
                    a_ href => $url, $_->{title};
                    b_ class => 'grayedout', sub { lit_ bb2html $_->{msg}, 150 };
                };
            } for @$list;
        }
    };

    paginate_ \&url, $page, [ $count, 50 ], 'b';
}


TUWF::get qr{/$RE{uid}/posts}, sub {
    my $u = tuwf->dbRowi('SELECT id, ', sql_user(), ', pubskin_can, pubskin_enabled, customcss, skin FROM users u WHERE id =', \tuwf->capture('id'));
    return tuwf->resNotFound if !$u->{id};

    my $page = eval { tuwf->validate(get => p => { upage => 1 })->data } || 1;

    my $from_and_where = sql
        'FROM threads_posts tp
         JOIN threads t ON t.id = tp.tid
        WHERE NOT t.private AND NOT t.hidden AND NOT tp.hidden AND tp.uid =', \$u->{id};

    my $count = tuwf->dbVali('SELECT count(*)', $from_and_where);
    my($list) = $count ? tuwf->dbPagei(
        { results => 50, page => $page },
        'SELECT tp.tid, tp.num, substring(tp.msg from 1 for 1000) as msg, t.title
              , ', sql_totime('tp.date'), 'as date',
          $from_and_where, 'ORDER BY tp.date DESC'
    ) : ();

    my $own = auth && $u->{id} == auth->uid;
    my $title = $own ? 'My posts' : 'Posts by '.user_displayname $u;
    framework_ title => $title, type => 'u', dbobj => $u, tab => 'posts', pubskin => $u,
    sub {
        div_ class => 'mainbox', sub {
            h1_ $title;
            if(!$count) {
                p_ +($own ? 'You have' : user_displayname($u).' has').' not posted anything on the forums yet.';
            }
        };

        listing_ $count, $list, $page if $count;
    };
};


1;
