package VNWeb::Reviews::VNTab;

use VNWeb::Prelude;


sub reviews_ {
    my($v) = @_;

    # TODO: Filters for upvote threshold, isfull and maybe vote

    # TODO: Order
    my $lst = tuwf->dbAlli(
        'SELECT r.id, r.rid, r.summary, r.text <> \'\' AS isfull, r.spoiler, uv.vote
              , COALESCE(c.count,0) AS count, COALESCE(s.up,0) AS up, COALESCE(s.down,0) AS down, rv.vote AS my
              , ', sql_totime('r.date'), 'AS date, ', sql_user(), '
           FROM reviews r
           LEFT JOIN users u ON r.uid = u.id
           LEFT JOIN ulist_vns uv ON uv.uid = r.uid AND uv.vid = r.vid
           LEFT JOIN (SELECT rv.id, COUNT(*) FILTER(WHERE rv.vote), COUNT(*) FILTER(WHERE NOT rv.vote)
                        FROM reviews_votes rv JOIN users u ON u.id = rv.uid WHERE NOT u.ign_votes GROUP BY rv.id
                     ) AS s(id,up,down) ON s.id = r.id
           LEFT JOIN (SELECT id, COUNT(*) FROM reviews_posts GROUP BY id) AS c(id,count) ON c.id = r.id
           LEFT JOIN reviews_votes rv ON rv.uid =', \auth->uid, ' AND rv.id = r.id
          WhERE r.vid =', \$v->{id}
    );

    div_ class => 'mainbox', sub {
        h1_ 'Reviews';
        debug_ $lst;
        div_ class => 'reviews', sub {
            article_ class => 'reviewbox', sub {
                my $r = $_;
                div_ sub {
                    span_ sub { txt_ 'By '; user_ $r; txt_ ' on '.fmtdate $r->{date}, 'compact' };
                    a_ href => "/r$r->{rid}", "r$r->{rid}" if $r->{rid};
                    span_ "Vote: ".fmtvote($r->{vote}) if $r->{vote};
                };
                div_ sub {
                    span_ sub {
                        txt_ '<';
                        if(can_edit w => $r) {
                            a_ href => "/$r->{id}/edit", 'edit';
                            txt_ ' - ';
                        }
                        a_ href => "/report/$r->{id}", 'report';
                        txt_ '>';
                    };
                    if($r->{spoiler}) {
                        label_ class => 'review_spoil', sub {
                            input_ type => 'checkbox', class => 'visuallyhidden', (auth->pref('spoilers')||0) == 2 ? ('checked', 'checked') : (), undef;
                            div_ sub { lit_ bb2html $r->{summary} };
                            span_ class => 'fake_link', 'This review contains spoilers, click to view.';
                        }
                    } else {
                        lit_ bb2html $r->{summary};
                    }
                };
                div_ sub {
                    a_ href => "/$r->{id}#review", 'Full review »' if $r->{isfull};
                    a_ href => "/$r->{id}#threadstart", $r->{count} == 1 ? '1 comment' : "$r->{count} comments";
                    elm_ 'Reviews.Vote' => $VNWeb::Reviews::Elm::VOTE_OUT, { %$r, can => !!auth }, sub {
                        span_ sprintf '👍 %d 👎 %d', $r->{up}, $r->{down};
                    };
                };
            } for @$lst;
        }
    };
}


TUWF::get qr{/$RE{vid}/reviews}, sub {
    return tuwf->resNotFound if !auth->permReview; #XXX:While in beta
    my $v = db_entry v => tuwf->capture('id');
    return tuwf->resNotFound if !$v;
    VNWeb::VN::Page::enrich_vn($v);

    framework_ title => "Reviews for $v->{title}", index => 1, type => 'v', dbobj => $v, hiddenmsg => 1,
    sub {
        VNWeb::VN::Page::infobox_($v);
        VNWeb::VN::Page::tabs_($v, 'reviews');
        reviews_ $v;
    };
};

1;
