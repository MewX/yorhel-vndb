package VNWeb::User::Page;

use VNWeb::Prelude;
use VNWeb::Misc::History;


sub _info_table_ {
    my($u, $own) = @_;

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
            txt_ ucfirst $u->{user_name};
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
        my $num = sum map $_->{votes}, $u->{votes}->@*;
        my $sum = sum map $_->{total}, $u->{votes}->@*;
        td_ 'Votes';
        td_ !$num ? '-' : sub {
            txt_ sprintf '%d vote%s, %.2f average. ', $num, $num == 1 ? '' : 's', $sum/$num/10;
            a_ href => "/u$u->{id}/ulist?votes=1", 'Browse votes »';
        }
    };
    tr_ sub {
        my $vns = tuwf->dbVali(
            'SELECT COUNT(DISTINCT uvl.vid) FROM ulist_vns_labels uvl',
            $own ? () : ('JOIN ulist_labels ul ON ul.uid = uvl.uid AND ul.id = uvl.lbl AND NOT ul.private'),
            'WHERE uvl.lbl NOT IN(', \5, ',', \6, ') AND uvl.uid =', \$u->{id}
        )||0;
        my $privrel = $own ? '1=1' : 'EXISTS(
            SELECT 1 FROM releases_vn rv JOIN ulist_vns_labels uvl ON uvl.vid = rv.vid JOIN ulist_labels ul ON ul.id = uvl.lbl AND ul.uid = uvl.uid WHERE rv.id = r.rid AND uvl.uid = r.uid AND NOT ul.private
        )';
        my $rel = tuwf->dbVali('SELECT COUNT(*) FROM rlists r WHERE', $privrel, 'AND r.uid =', \$u->{id})||0;
        td_ 'List stats';
        td_ !$vns && !$rel ? '-' : sub {
            txt_ sprintf '%d release%s of %d visual novel%s. ',
                $rel, $rel == 1 ? '' : 's',
                $vns, $vns == 1 ? '' : 's';
            a_ href => "/u$u->{id}/ulist?vnlist=1", 'Browse list »';
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
        td_ 'Images';
        td_ sprintf '%d images flagged.', $u->{c_imgvotes};
    } if $u->{c_imgvotes};
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
    my($u, $own) = @_;

    my $sum = sum map $_->{total}, $u->{votes}->@*;
    my $max = max map $_->{votes}, $u->{votes}->@*;
    my $num = sum map $_->{votes}, $u->{votes}->@*;

    table_ class => 'votegraph', sub {
        thead_ sub { tr_ sub { td_ colspan => 2, 'Vote stats' } };
        tfoot_ sub { tr_ sub { td_ colspan => 2, sprintf '%d vote%s total, average %.2f', $num, $num == 1 ? '' : 's', $sum/$num/10 } };
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

    my $recent = tuwf->dbAlli('
        SELECT vn.id, vn.title, vn.original, uv.vote,', sql_totime('uv.vote_date'), 'AS date
          FROM ulist_vns uv
          JOIN vn ON vn.id = uv.vid
         WHERE uv.vote IS NOT NULL AND uv.uid =', \$u->{id},
          $own ? () : (
              'AND EXISTS(SELECT 1 FROM ulist_vns_labels uvl JOIN ulist_labels ul ON ul.uid = uvl.uid AND ul.id = uvl.lbl WHERE uvl.uid = uv.uid AND uvl.vid = uv.vid AND NOT ul.private)'
          ), '
         ORDER BY uv.vote_date DESC LIMIT', \8
    );

    table_ class => 'recentvotes stripe', sub {
        thead_ sub { tr_ sub { td_ colspan => 3, sub {
            txt_ 'Recent votes';
            b_ sub { txt_ ' ('; a_ href => "/u$u->{id}/ulist?votes=1", 'show all'; txt_ ')' };
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
        SELECT id, c_changes, c_votes, c_tags, c_imgvotes
             ,}, sql_totime('registered'), q{ AS registered
             ,}, sql_user(), q{
          FROM users u
         WHERE id =}, \tuwf->capture('id')
    );
    return tuwf->resNotFound if !$u->{id};

    my $own = (auth && auth->uid == $u->{id}) || auth->permUsermod;

    $u->{votes} = tuwf->dbAlli('
        SELECT (uv.vote::numeric/10)::int AS idx, COUNT(uv.vote) as votes, SUM(uv.vote) AS total
          FROM ulist_vns uv
         WHERE uv.vote IS NOT NULL AND uv.uid =', \$u->{id},
          $own ? () : (
              'AND EXISTS(SELECT 1 FROM ulist_vns_labels uvl JOIN ulist_labels ul ON ul.uid = uvl.uid AND ul.id = uvl.lbl WHERE uvl.uid = uv.uid AND uvl.vid = uv.vid AND NOT ul.private)'
          ), '
         GROUP BY (uv.vote::numeric/10)::int
    ');

    my $title = user_displayname($u)."'s profile";
    framework_ title => $title, type => 'u', dbobj => $u,
    sub {
        div_ class => 'mainbox userpage', sub {
            h1_ $title;
            table_ class => 'stripe', sub { _info_table_ $u, $own };
        };

        div_ class => 'mainbox', sub {
            h1_ 'Vote statistics';
            div_ class => 'votestats', sub { _votestats_ $u, $own };
        } if grep $_->{votes} > 0, $u->{votes}->@*;

        if($u->{c_changes}) {
            h1_ class => 'boxtitle', sub { a_ href => "/u$u->{id}/hist", 'Recent changes' };
            VNWeb::Misc::History::tablebox_ u => $u->{id}, {p=>1}, nopage => 1, results => 10;
        }
    };
};

1;
