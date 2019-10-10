package VNWeb::User::Page;

use VNWeb::Prelude;
use VNWeb::Misc::History;


sub _info_table_ {
    my($u, $vis) = @_;

    my sub sup {
        b_ ' ⭐supporter⭐' if $u->{user_support_can} && $u->{user_support_enabled};
    }

    tr_ sub {
        td_ class => 'key', 'Display name';
        td_ sub {
            txt_ $u->{user_uniname};
            sup;
        };
    } if $u->{user_uniname_can} && $u->{user_uniname};
    tr_ sub {
        td_ class => 'key', 'Username';
        td_ sub {
            txt_ $u->{user_name};
            txt_ ' ('; a_ href => "/u$u->{id}", "u$u->{id}";
            txt_ ')';
            debug_ $u;
            sup if !($u->{user_uniname_can} && $u->{user_uniname});
        };
    };
    tr_ sub {
        td_ 'Registered';
        td_ fmtdate $u->{registered};
    };
    tr_ sub {
        td_ 'Edits';
        td_ !$u->{c_changes} ? '-' : sub {
            a_ href => "/u$u->{id}/hist", $u->{c_changes}
        };
    };
    tr_ sub {
        td_ 'Votes';
        td_ !$vis ? 'hidden' : !$u->{c_votes} ? '-' : sub {
            my $sum   = sum map $_->{total}, $u->{votes}->@*;
            txt_ sprintf '%d vote%s, %.2f average. ', $u->{c_votes}, $u->{c_votes} == 1 ? '' : 's', $sum/$u->{c_votes}/10;
            a_ href => "/u$u->{id}/votes", 'Browse votes »';
        }
    };
    tr_ sub {
        my $vns = tuwf->dbVali('SELECT COUNT(*) FROM vnlists WHERE uid =', \$u->{id})||0;
        my $rel = tuwf->dbVali('SELECT COUNT(*) FROM rlists  WHERE uid =', \$u->{id})||0;
        td_ 'List stats';
        td_ !$vis ? 'hidden' : !$vns && !$rel ? '-' : sub {
            txt_ sprintf '%d release%s of %d visual novel%s. ',
                $rel, $rel == 1 ? '' : 's',
                $vns, $vns == 1 ? '' : 's';
            a_ href => "/u$u->{id}/list", 'Browse list »';
        };
    };
    tr_ sub {
        my $stats = tuwf->dbRowi('SELECT COUNT(DISTINCT tag) AS tags, COUNT(DISTINCT vid) AS vns FROM tags_vn WHERE uid =', \$u->{id});
        td_ 'Tags';
        td_ !$u->{c_tags} ? '-' : !$stats->{tags} ? '-' : sub {
            txt_ sprintf '%d vote%s on %d distinct tag%s and %d visual novel%s. ',
                $u->{c_tags},   $u->{c_tags}   == 1 ? '' : 's',
                $stats->{tags}, $stats->{tags} == 1 ? '' : 's',
                $stats->{vns},  $stats->{vns}  == 1 ? '' : 's';
            a_ href => "/g/links?u=$u->{id}", 'Browse tags »';
        };
    };
    tr_ sub {
        my $stats = tuwf->dbRowi('SELECT COUNT(*) AS posts, COUNT(*) FILTER (WHERE num = 1) AS threads FROM threads_posts WHERE uid =', \$u->{id});
        td_ 'Forum stats';
        td_ !$stats->{posts} ? '-' : sub {
            txt_ sprintf '%d post%s, %d new thread%s. ',
                $stats->{posts},   $stats->{posts}   == 1 ? '' : 's',
                $stats->{threads}, $stats->{threads} == 1 ? '' : 's';
            a_ href => "/u$u->{id}/posts", 'Browse posts »';
        };
    };
}


sub _votestats_ {
    my($u) = @_;

    my $sum = sum map $_->{total}, $u->{votes}->@*;
    my $max = max map $_->{votes}, $u->{votes}->@*;

    table_ class => 'votegraph', sub {
        thead_ sub { tr_ sub { td_ colspan => 2, 'Vote stats' } };
        tfoot_ sub { tr_ sub { td_ colspan => 2, sprintf '%d vote%s total, average %.2f', $u->{c_votes}, $u->{c_votes} == 1 ? '' : 's', $sum/$u->{c_votes}/10 } };
        tr_ sub {
            my $num = $_;
            my $votes = [grep $num == $_->{idx}, $u->{votes}->@*]->[0]{votes} || 0;
            td_ class => 'number', $num;
            td_ class => 'graph', sub {
                div_ style => sprintf('width: %dpx', ($votes||0)/$max*250), ' ';
                txt_ $votes||0;
            };
        } for (reverse 1..10);
    };

    my $recent = tuwf->dbAlli(q{
        SELECT vn.id, vn.title, vn.original, v.vote,}, sql_totime('v.date'), q{AS date
         FROM votes v JOIN vn ON vn.id = v.vid WHERE v.uid =}, \$u->{id}, 'ORDER BY v.date DESC LIMIT', \8
    );

    table_ class => 'recentvotes stripe', sub {
        thead_ sub { tr_ sub { td_ colspan => 3, sub {
            txt_ 'Recent votes';
            b_ sub { txt_ ' ('; a_ href => "/u$u->{id}/votes", 'show all'; txt_ ')' };
        } } };
        tr_ sub {
            my $v = $_;
            td_ sub { a_ href => "/v$v->{id}", title => $v->{original}||$v->{title}, shorten $v->{title}, 30 };
            td_ fmtvote $v->{vote};
            td_ fmtdate $v->{date};
        } for @$recent;
    };

    clearfloat_;
}


TUWF::get qr{/$RE{uid}}, sub {
    my $u = tuwf->dbRowi(q{
        SELECT id, hide_list, c_changes, c_votes, c_tags, pubskin_can, skin, customcss
             ,}, sql_totime('registered'), q{ AS registered
             ,}, sql_user(), q{
          FROM users u
         WHERE id =}, \tuwf->capture('id')
    );
    return tuwf->resNotFound if !$u->{id};

    my $vis = !$u->{hide_list} || (auth && auth->uid == $u->{id}) || auth->permUsermod;

    $u->{votes} = $vis && $u->{c_votes} && tuwf->dbAlli(q{
        SELECT (vote::numeric/10)::int AS idx, COUNT(vote) as votes, SUM(vote) AS total
          FROM votes
         WHERE uid =}, \$u->{id}, q{
         GROUP BY (vote::numeric/10)::int
    });

    my $title = user_displayname($u)."'s profile";
    framework_ title => $title, index => 0, type => 'u', pubskin => $u, dbobj => $u,
    sub {
        div_ class => 'mainbox userpage', sub {
            h1_ $title;
            table_ class => 'stripe', sub { _info_table_ $u, $vis };
        };

        div_ class => 'mainbox', sub {
            h1_ 'Vote statistics';
            div_ class => 'votestats', sub { _votestats_ $u };
        } if $vis && $u->{c_votes};

        if($u->{c_changes}) {
            h1_ class => 'boxtitle', sub { a_ href => "/u$u->{id}/hist", 'Recent changes' };
            VNWeb::Misc::History::tablebox_ u => $u->{id}, {p=>1}, nopage => 1, results => 10;
        }
    };
};

1;
