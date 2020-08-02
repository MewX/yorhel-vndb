package VNWeb::Reviews::VNTab;

use VNWeb::Prelude;


sub reviews_ {
    my($v) = @_;

    # TODO: Filters for upvote threshold, isfull and maybe vote

    # TODO: Order
    my $lst = tuwf->dbAlli(
        'SELECT r.id, r.rid, r.summary, r.text <> \'\' AS isfull, r.spoiler, uv.vote, s.up, s.down
              , ', sql_totime('r.date'), 'AS date, ', sql_user(), '
           FROM reviews r
           LEFT JOIN users u ON r.uid = u.id
           LEFT JOIN ulist_vns uv ON uv.uid = r.uid AND uv.vid = r.vid
           LEFT JOIN (SELECT id, COUNT(*) FILTER(WHERE vote), COUNT(*) FILTER(WHERE NOT vote) FROM reviews_votes GROUP BY id) AS s(id,up,down) ON s.id = r.id
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
                    a_ href => "/r$r->{rid}", "release" if $r->{rid};
                    span_ "Vote: ".fmtvote($r->{vote}) if $r->{vote};
                };
                div_ sub {
                    span_ sub {
                        txt_ '<';
                        if(can_edit w => $r) {
                            a_ href => "/$r->{id}/edit", 'edit';
                            txt_ ' - ';
                        }
                        a_ href => "/report/w/$r->{id}", 'report'; # TODO
                        txt_ '>';
                    };
                    if($r->{spoiler}) {
                        label_ class => 'review_spoil', sub {
                            input_ type => 'checkbox', class => 'visuallyhidden';
                            div_ sub { lit_ bb2html $r->{summary} };
                            span_ class => 'fake_link', 'This review contains spoilers, click here to view.';
                        }
                    } else {
                        lit_ bb2html $r->{summary};
                    }
                };
                # placeholder
                div_ sub {
                    span_ '' if !$r->{isfull};
                    a_ href => "/$r->{id}", 'Full review »' if $r->{isfull};
                    span_ sprintf '👍 %d 👎 %d', $r->{up}||0, $r->{down}||0;
                };
            } for @$lst;
        }
    };
}


TUWF::get qr{/$RE{vid}/reviews}, sub {
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
