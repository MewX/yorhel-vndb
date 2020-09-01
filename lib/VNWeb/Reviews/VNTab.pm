package VNWeb::Reviews::VNTab;

use VNWeb::Prelude;


sub reviews_ {
    my($v, $mini) = @_;

    # TODO: Better order, pagination
    my $lst = tuwf->dbAlli(
        'SELECT r.id, r.rid, r.text, r.spoiler, r.c_count, uv.vote, rv.vote AS my, NOT r.isfull AND rm.id IS NULL AS can
              , ', sql_totime('r.date'), 'AS date, ', sql_user(), '
           FROM reviews r
           LEFT JOIN users u ON r.uid = u.id
           LEFT JOIN ulist_vns uv ON uv.uid = r.uid AND uv.vid = r.vid
           LEFT JOIN reviews_votes rv ON rv.uid =', \auth->uid, ' AND rv.id = r.id
           LEFT JOIN reviews rm ON rm.vid = r.vid AND rm.uid =', \auth->uid, '
          WhERE r.vid =', \$v->{id}, 'AND', ($mini ? 'NOT' : ''), 'r.isfull
          ORDER BY r.c_up-r.c_down DESC'
    );

    div_ class => 'mainbox', sub {
        h1_ $mini ? 'Mini reviews' : 'Reviews';
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
                    my $html = bb2html $r->{text}, $mini ? undef : 700;
                    $html .= '...' if !$mini;
                    if($r->{spoiler}) {
                        label_ class => 'review_spoil', sub {
                            input_ type => 'checkbox', class => 'visuallyhidden', (auth->pref('spoilers')||0) == 2 ? ('checked', 'checked') : (), undef;
                            div_ sub { lit_ $html };
                            span_ class => 'fake_link', 'This review contains spoilers, click to view.';
                        }
                    } else {
                        lit_ $html;
                    }
                };
                div_ sub {
                    a_ href => "/$r->{id}#review", 'Full review »' if !$mini;
                    a_ href => "/$r->{id}#threadstart", $r->{c_count} == 1 ? '1 comment' : "$r->{c_count} comments";
                    elm_ 'Reviews.Vote' => $VNWeb::Reviews::Elm::VOTE_OUT, $r if auth && $r->{can};
                };
            } for @$lst;
        }
    };
}


TUWF::get qr{/$RE{vid}/(?<mini>mini)?reviews}, sub {
    my $mini = !!tuwf->capture('mini');
    my $v = db_entry v => tuwf->capture('id');
    return tuwf->resNotFound if !$v;
    VNWeb::VN::Page::enrich_vn($v);

    framework_ title => ($mini?'Mini reviews':'Reviews')." for $v->{title}", index => 1, type => 'v', dbobj => $v, hiddenmsg => 1,
    sub {
        VNWeb::VN::Page::infobox_($v);
        VNWeb::VN::Page::tabs_($v, ($mini?'minireviews':'reviews'));
        reviews_ $v, $mini;
    };
};

1;
