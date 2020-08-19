package VNWeb::Reviews::List;

use VNWeb::Prelude;


sub tablebox_ {
    my($opt, $lst, $count) = @_;

    my sub url { '?'.query_encode %$opt, @_ }

    paginate_ \&url, $opt->{p}, [$count, 50], 't';
    div_ class => 'mainbox browse reviewlist', sub {
        table_ class => 'stripe', sub {
            thead_ sub { tr_ sub {
                td_ class => 'tc1', sub { txt_ 'Date'; sortable_ 'id', $opt, \&url };
                td_ class => 'tc2', 'By';
                td_ class => 'tc3', 'Review';
                td_ class => 'tc4', 'Vote';
                td_ class => 'tc5', sub { txt_ 'Score';  sortable_ 'rating', $opt, \&url if auth->isMod };
                td_ class => 'tc6', 'C#';
                td_ class => 'tc7', sub { txt_ 'Last comment'; sortable_ 'lastpost', $opt, \&url };
            } };
            tr_ sub {
                td_ class => 'tc1', fmtdate $_->{date}, 'compact';
                td_ class => 'tc2', sub { user_ $_ };
                td_ class => 'tc3', sub { a_ href => "/$_->{id}", $_->{title} };
                td_ class => 'tc4', fmtvote $_->{vote};
                td_ class => 'tc5', sprintf '👍 %d 👎 %d', $_->{c_up}, $_->{c_down};
                td_ class => 'tc6', $_->{c_count};
                td_ class => 'tc7', $_->{c_lastnum} ? sub {
                    user_ $_, 'lu_';
                    txt_ ' @ ';
                    a_ href => "/$_->{id}.$_->{c_lastnum}#last", fmtdate $_->{ldate}, 'full';
                } :  '';
            } for @$lst;
        };
    };
    paginate_ \&url, $opt->{p}, [$count, 50], 'b';
}


TUWF::get qr{/w}, sub {
    return tuwf->resNotFound if !auth->permReview; #XXX:While in beta

    # TODO: User filter, so we can link from the user's page
    # TODO: Display full/short indicator

    my $opt = tuwf->validate(get =>
        p => { page => 1 },
        s => { onerror => 'id', enum => [qw[id lastpost rating]] },
        o => { onerror => 'd',  enum => [qw[a d]] },
    )->data;
    $opt->{s} = 'id' if $opt->{s} eq 'rating' && !auth->isMod;

    my $count = tuwf->dbVali('SELECT COUNT(*) FROM reviews');
    my $lst = tuwf->dbPagei({results => 50, page => $opt->{p}}, '
        SELECT w.id, w.vid, w.c_up, w.c_down, w.c_count, w.c_lastnum, v.title, uv.vote
             , ', sql_user(), ',', sql_totime('w.date'), 'as date
             , ', sql_user('wpu','lu_'), ',', sql_totime('wp.date'), 'as ldate
          FROM reviews w
          JOIN vn v ON v.id = w.vid
          LEFT JOIN users u ON u.id = w.uid
          LEFT JOIN reviews_posts wp ON w.id = wp.id AND w.c_lastnum = wp.num
          LEFT JOIN users wpu ON wpu.id = wp.uid
          LEFT JOIN ulist_vns uv ON uv.uid = w.uid AND uv.vid = w.vid
         ORDER BY', {id => 'w.id', lastpost => 'wp.date', rating => 'w.c_up-w.c_down'}->{$opt->{s}}, {a=>'ASC',d=>'DESC'}->{$opt->{o}}, 'NULLS LAST'
    );

    framework_ title => 'Browse reviews', sub {
        div_ class => 'mainbox', sub {
            h1_ 'Browse reviews';
            debug_ $lst;
        };
        tablebox_ $opt, $lst, $count;
    };
};

1;
