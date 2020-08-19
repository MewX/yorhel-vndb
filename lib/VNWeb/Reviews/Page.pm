package VNWeb::Reviews::Page;

use VNWeb::Prelude;
use VNWeb::Releases::Lib;


my $COMMENT = form_compile any => {
    id  => { vndbid => 'w' },
    msg => { maxlength => 32768 }
};

elm_api ReviewsComment => undef, $COMMENT, sub {
    my($data) = @_;
    my $w = tuwf->dbRowi('SELECT id, false AS locked FROM reviews WHERE id =', \$data->{id});
    return tuwf->resNotFound if !$w->{id};
    return elm_Unauth if !can_edit t => $w;

    my $num = sql 'COALESCE((SELECT MAX(num)+1 FROM reviews_posts WHERE id =', \$data->{id}, '),1)';
    my $msg = bb_subst_links $data->{msg};
    $num = tuwf->dbVali('INSERT INTO reviews_posts', { id => $w->{id}, num => $num, uid => auth->uid, msg => $msg }, 'RETURNING num');
    elm_Redirect "/$w->{id}.$num#last";
};



sub review_ {
    my($w) = @_;

    input_ type => 'checkbox', class => 'visuallyhidden', id => 'reviewspoil', (auth->pref('spoilers')||0) == 2 ? ('checked', 'checked') : (), undef;
    my @spoil = $w->{spoiler} ? (class => 'reviewspoil') : ();
    table_ class => 'fullreview', sub {
        tr_ sub {
            td_ 'By';
            td_ sub {
                b_ style => 'float: right', 'Vote: '.fmtvote($w->{vote}) if $w->{vote};
                user_ $w;
                my($date, $lastmod) = map $_&&fmtdate($_,'compact'), $w->@{'date', 'lastmod'};
                txt_ " on $date";
                b_ class => 'grayedout', " last updated on $lastmod" if $lastmod && $date ne $lastmod;
            }
        };
        tr_ sub {
            td_ 'Release';
            td_ sub {
                abbr_ class => "icons $_", title => $PLATFORM{$_}, '' for grep $_ ne 'oth', $w->{platforms}->@*;
                abbr_ class => "icons lang $_", title => $LANGUAGE{$_}, '' for $w->{lang}->@*;
                abbr_ class => "icons rt$w->{rtype}", title => $w->{rtype}, '';
                a_ href => "/r$w->{rid}", title => $w->{roriginal}||$w->{rtitle}, $w->{rtitle};
            };
        } if $w->{rid};
        tr_ class => 'reviewnotspoil', sub {
            td_ '';
            td_ sub {
                label_ class => 'fake_link', for => 'reviewspoil', 'This review contains spoilers, click to view.';
            };
        } if $w->{spoiler};
        tr_ @spoil, sub {
            td_ length $w->{text} ? 'Summary' : 'Review';
            td_ sub { lit_ bb2html $w->{summary} }
        };
        tr_ @spoil, sub {
            td_ 'Full review';
            td_ sub { lit_ bb2html $w->{text} }
        } if length $w->{text};
        tr_ sub {
            td_ '';
            td_ style => 'text-align: right', sub {
                elm_ 'Reviews.Vote' => $VNWeb::Reviews::Elm::VOTE_OUT, { %$w, can => auth && $w->{user_id} != auth->uid }, sub {
                    span_ sprintf '👍 %d 👎 %d', $w->{c_up}, $w->{c_down};
                };
            }
        };
    }
}


TUWF::get qr{/$RE{wid}(?:(?<sep>[\./])$RE{num})?}, sub {
    return tuwf->resNotFound if !auth->permReview; #XXX:While in beta
    my($id, $sep, $num) = (tuwf->capture('id'), tuwf->capture('sep')||'', tuwf->capture('num'));
    my $w = tuwf->dbRowi(
        'SELECT r.id, r.vid, r.rid, r.summary, r.text, r.spoiler, c.count, r.c_up, r.c_down, uv.vote
              , rel.title AS rtitle, rel.original AS roriginal, rel.type AS rtype, rv.vote AS my
              , ', sql_user(), ',', sql_totime('r.date'), 'AS date,', sql_totime('r.lastmod'), 'AS lastmod
           FROM reviews r
           LEFT JOIN releases rel ON rel.id = r.rid
           LEFT JOIN users u ON u.id = r.uid
           LEFT JOIN ulist_vns uv ON uv.uid = r.uid AND uv.vid = r.vid
           LEFT JOIN (SELECT id, COUNT(*) FROM reviews_posts GROUP BY id) AS c(id,count) ON c.id = r.id
           LEFT JOIN reviews_votes rv ON rv.id = r.id AND rv.uid =', \auth->uid, '
          WHERE r.id =', \$id
    );
    return tuwf->resNotFound if !$w->{id};

    enrich_flatten lang => rid => id => sub { sql 'SELECT id, lang FROM releases_lang WHERE id IN', $_, 'ORDER BY id, lang' }, $w;
    enrich_flatten platforms => rid => id => sub { sql 'SELECT id, platform FROM releases_platforms WHERE id IN', $_, 'ORDER BY id, platform' }, $w;

    my $page = $sep eq '/' ? $num||1 : $sep ne '.' ? 1
        : ceil((tuwf->dbVali('SELECT COUNT(*) FROM reviews_posts WHERE num <=', \$num, 'AND id =', \$id)||9999)/25);
    $num = 0 if $sep ne '.';

    my $posts = tuwf->dbPagei({ results => 25, page => $page },
        'SELECT rp.id, rp.num, rp.hidden, rp.msg',
             ',', sql_user(),
             ',', sql_totime('rp.date'), ' as date',
             ',', sql_totime('rp.edited'), ' as edited
           FROM reviews_posts rp
           LEFT JOIN users u ON rp.uid = u.id
          WHERE rp.id =', \$id, '
          ORDER BY rp.num'
    );

    my $v = db_entry v => $w->{vid};
    VNWeb::VN::Page::enrich_vn($v);

    framework_ title => "Review of $v->{title}", index => 1, type => 'v', dbobj => $v, hiddenmsg => 1,
        js => 1, pagevars => {sethash=>$num?$num:$page>1?'threadstart':'review'},
    sub {
        VNWeb::VN::Page::infobox_($v);
        VNWeb::VN::Page::tabs_($v, 'reviews');
        div_ class => 'mainbox', id => 'review', sub {
            p_ class => 'mainopts', sub {
                if(can_edit w => $w) {
                    a_ href => "/$w->{id}/edit", 'Edit';
                    b_ class => 'grayedout', ' | ';
                }
                a_ href => "/report/$w->{id}", 'Report';
            };
            h1_ 'Review';
            review_ $w;
        };
        if(grep !$_->{hidden}, @$posts) {
            h1_ class => 'boxtitle', 'Comments';
            VNWeb::Discussions::Thread::posts_($w, $posts, $page);
        } else {
            div_ id => 'threadstart', '';
        }
        elm_ 'Reviews.Comment' => $COMMENT, { id => $w->{id}, msg => '' } if $w->{count} <= $page*25 && can_edit t => {%$w,locked=>0};
    };
};

1;
