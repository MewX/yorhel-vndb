package VNWeb::Reviews::Page;

use VNWeb::Prelude;
use VNWeb::Releases::Lib;


sub review_ {
    my($w) = @_;

    input_ type => 'checkbox', class => 'visuallyhidden', id => 'reviewspoil', undef;
    my @spoil = $w->{spoiler} ? (class => 'reviewspoil') : ();
    table_ class => 'fullreview', sub {
        tr_ sub {
            td_ 'By';
            td_ sub {
                b_ style => 'float: right', 'Vote: '.fmtvote($w->{vote}) if $w->{vote};
                user_ $w;
                my($date, $lastmod) = map fmtdate($_,'compact'), $w->@{'date', 'lastmod'};
                txt_ " on $date";
                b_ class => 'grayedout', " last updated on $lastmod" if $date ne $lastmod;
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
                elm_ 'Reviews.Vote' => $VNWeb::Reviews::Elm::VOTE_OUT, { %$w, can => !!auth }, sub {
                    span_ sprintf '👍 %d 👎 %d', $w->{up}, $w->{down};
                };
            }
        };
    }
}


TUWF::get qr{/$RE{wid}}, sub {
    my $w = tuwf->dbRowi(
        'SELECT r.id, r.vid, r.rid, r.summary, r.text, r.spoiler, uv.vote
              , rel.title AS rtitle, rel.original AS roriginal, rel.type AS rtype
              , COALESCE(s.up,0) AS up, COALESCE(s.down,0) AS down, rv.vote AS my
              , ', sql_user(), ',', sql_totime('r.date'), 'AS date,', sql_totime('r.lastmod'), 'AS lastmod
           FROM reviews r
           LEFT JOIN releases rel ON rel.id = r.rid
           LEFT JOIN users u ON u.id = r.uid
           LEFT JOIN ulist_vns uv ON uv.uid = r.uid AND uv.vid = r.vid
           LEFT JOIN (SELECT id, COUNT(*) FILTER(WHERE vote), COUNT(*) FILTER(WHERE NOT vote) FROM reviews_votes GROUP BY id) AS s(id,up,down) ON s.id = r.id
           LEFT JOIN reviews_votes rv ON rv.id = r.id AND rv.uid =', \auth->uid, '
          WHERE r.id =', \tuwf->capture('id')
    );
    return tuwf->resNotFound if !$w->{id};

    enrich_flatten lang => rid => id => sub { sql 'SELECT id, lang FROM releases_lang WHERE id IN', $_, 'ORDER BY id, lang' }, $w;
    enrich_flatten platforms => rid => id => sub { sql 'SELECT id, platform FROM releases_platforms WHERE id IN', $_, 'ORDER BY id, platform' }, $w;

    my $v = db_entry v => $w->{vid};
    VNWeb::VN::Page::enrich_vn($v);

    framework_ title => "Review of $v->{title}", index => 1, type => 'v', dbobj => $v, hiddenmsg => 1, sub {
        VNWeb::VN::Page::infobox_($v);
        VNWeb::VN::Page::tabs_($v, 'reviews');
        div_ class => 'mainbox', sub {
            p_ class => 'mainopts', sub {
                if(can_edit w => $w) {
                    a_ href => "/$w->{id}/edit", 'Edit';
                    b_ class => 'grayedout', ' | ';
                }
                a_ href => "/report/w/$w->{id}", 'Report'; # TODO
            };
            h1_ "Review";
            review_ $w;
        };
    };
};

1;
