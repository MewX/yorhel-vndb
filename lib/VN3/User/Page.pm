package VN3::User::Page;

use VN3::Prelude;
use VN3::User::Lib;


sub StatsLeft {
    my $u = shift;
    my $vns = show_list($u) && tuwf->dbVali('SELECT COUNT(*) FROM vnlists WHERE uid =', \$u->{id});
    my $rel = show_list($u) && tuwf->dbVali('SELECT COUNT(*) FROM rlists WHERE uid =', \$u->{id});
    my $posts = tuwf->dbVali('SELECT COUNT(*) FROM threads_posts WHERE uid =', \$u->{id});
    my $threads = tuwf->dbVali('SELECT COUNT(*) FROM threads_posts WHERE num = 1 AND uid =', \$u->{id});

    Div class => 'card__title mb-4', 'Stats';
    Div class => 'big-stats mb-5', sub {
        A href => "/u$u->{id}/list", class => 'big-stats__stat', sub {
            Txt 'Votes';
            Div class => 'big-stats__value', show_list($u) ? $u->{c_votes} : '-';
        };
        A href => "/u$u->{id}/hist", class => 'big-stats__stat', sub {
            Txt 'Edits';
            Div class => 'big-stats__value', $u->{c_changes};
        };
        A href => "/g/links?u=$u->{id}", class => 'big-stats__stat', sub {
            Txt 'Tags';
            Div class => 'big-stats__value', $u->{c_tags};
        };
    };
    Div class => 'user-stats__text', sub {
        Dl class => 'dl--horizontal', sub {
            if(show_list $u) {
                Dt 'List stats';
                Dd sprintf '%d release%s of %d visual novel%s', $rel, $rel == 1 ? '' : 's', $vns, $vns == 1 ? '' : 's';
            }
            Dt 'Forum stats';
            Dd sprintf '%d post%s, %d new thread%s', $posts, $posts == 1 ? '' : 's', $threads, $threads == 1 ? '' : 's';
            Dt 'Registered';
            Dd date_display $u->{registered};
        };
    };
}


sub Stats {
    my $u = shift;

    my($count, $Graph) = show_list($u) ? VoteGraph u => $u->{id} : ();

    Div class => 'card card--white card--no-separators flex-expand mb-5', sub {
        Div class => 'card__section fs-medium', sub {
            Div class => 'user-stats', sub {
                Div class => 'user-stats__left', sub { StatsLeft $u };
                Div class => 'user-stats__right', sub {
                    Div class => 'card__title mb-2', 'Vote distribution';
                    $Graph->();
                } if $count;
            }
        }
    }
}


sub List {
    my $u = shift;
    return if !show_list $u;

    # XXX: This query doesn't catch vote or list *changes*, only new entries.
    # We don't store the modification date in the DB at the moment.
    my $l = tuwf->dbAlli(q{
        SELECT il.vid, EXTRACT('epoch' FROM GREATEST(v.date, l.added)) AS date, vn.title, vn.original, v.vote, l.status
          FROM (
                  SELECT vid FROM votes   WHERE uid = }, \$u->{id}, q{
            UNION SELECT vid FROM vnlists WHERE uid = }, \$u->{id}, q{
          ) AS il (vid)
     LEFT JOIN votes v ON v.vid = il.vid
     LEFT JOIN vnlists l ON l.vid = il.vid
          JOIN vn ON vn.id = il.vid
         WHERE v.uid = }, \$u->{id}, q{
           AND l.uid = }, \$u->{id}, q{
         ORDER BY GREATEST(v.date, l.added) DESC
         LIMIT 10
    });
    return if !@$l;

    Div class => 'card card--white card--no-separators mb-5', sub {
        Div class => 'card__header', sub {
            Div class => 'card__title', 'Recent list additions';
        };
        Table class => 'table table--responsive-single-sm fs-medium', sub {
            Thead sub {
                Tr sub {
                    Th width => '15%', 'Date';
                    Th width => '50%', 'Visual novel';
                    Th width => '10%', 'Vote';
                    Th width => '25%', 'Status';
                };
            };
            Tbody sub {
                for my $i (@$l) {
                    Tr sub {
                        Td class => 'tabular-nums muted', date_display $i->{date};
                        Td sub {
                            A href => "/v$i->{vid}", title => $i->{original}||$i->{title}, $i->{title};
                        };
                        Td vote_display $i->{vote};
                        Td $i->{status} ? $VNLIST_STATUS[$i->{status}] : '';
                    };
                }
            };
        };
        Div class => 'card__section fs-medium', sub {
            A href => "/u$u->{id}/list", 'View full list';
        }
    };
}


sub Edits {
    my $u = shift;
    # XXX: This is a lazy implementation, could probably share code/UI with the database entry history tables (as in VNDB 2)

    my $l = tuwf->dbAlli(q{
        SELECT ch.id, ch.itemid, ch.rev, ch.type, EXTRACT('epoch' FROM ch.added) AS added
          FROM changes ch
         WHERE ch.requester =}, \$u->{id}, q{
         ORDER BY ch.added DESC LIMIT 10
    });
    return if !@$l;

    # This can also be written as a UNION, haven't done any benchmarking yet.
    # It doesn't matter much with only 10 entries, but it will matter if this
    # query is re-used for other history browsing purposes.
    enrich id => q{
        SELECT ch.id, COALESCE(d.title, v.title, p.name, r.title, c.name, sa.name) AS title
          FROM changes ch
     LEFT JOIN docs_hist d         ON ch.type = 'd' AND d.chid = ch.id
     LEFT JOIN vn_hist v           ON ch.type = 'v' AND v.chid = ch.id
     LEFT JOIN producers_hist p    ON ch.type = 'p' AND p.chid = ch.id
     LEFT JOIN releases_hist r     ON ch.type = 'r' AND r.chid = ch.id
     LEFT JOIN chars_hist c        ON ch.type = 'c' AND c.chid = ch.id
     LEFT JOIN staff_hist s        ON ch.type = 's' AND s.chid = ch.id
     LEFT JOIN staff_alias_hist sa ON ch.type = 's' AND sa.chid = ch.id AND s.aid = sa.aid
         WHERE ch.id IN}, $l;

    Div class => 'card card--white card--no-separators mb-5', sub {
        Div class => 'card__header', sub {
            Div class => 'card__title', 'Recent database contributions';
        };
        Table class => 'table table--responsive-single-sm fs-medium', sub {
            Thead sub {
                Tr sub {
                    Th width => '15%', 'Date';
                    Th width => '10%', 'Rev.';
                    Th width => '75%', 'Entry';
                };
            };
            Tbody sub {
                for my $i (@$l) {
                    my $id = "$i->{type}$i->{itemid}.$i->{rev}";
                    Tr sub {
                        Td class => 'tabular-nums muted', date_display $i->{added};
                        Td sub {
                            A href => "/$id", $id;
                        };
                        Td sub {
                            A href => "/$id", $i->{title};
                        };
                    }
                }
            }
        };
        Div class => 'card__section fs-medium', sub {
            A href => "/u$u->{id}/hist", 'View all';
        }
    };
}


TUWF::get qr{/$UID_RE}, sub {
    my $uid = tuwf->capture('id');
    my $u = tuwf->dbRowi(q{
        SELECT u.id, u.username, EXTRACT('epoch' FROM u.registered) AS registered, u.c_votes, u.c_changes, u.c_tags, hd.value AS hide_list
          FROM users u
     LEFT JOIN users_prefs hd ON hd.uid = u.id AND hd.key = 'hide_list'
         WHERE u.id =}, \$uid
    );
    return tuwf->resNotFound if !$u->{id};

    Framework
        title => lcfirst($u->{username}),
        index => 0,
        single_col => 1,
        top => sub {
            Div class => 'col-md', sub {
                EntryEdit u => $u;
                Div class => 'detail-page-title', ucfirst $u->{username};
                TopNav details => $u;
            }
        },
        sub {
            Stats $u;
            List $u;
            Edits $u;
        };
};

1;
