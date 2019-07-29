package VN3::User::VNList;

use POSIX 'ceil';
use VN3::Prelude;
use VN3::User::Lib;


sub mkurl {
    my $opt = shift;
    $opt = { %$opt, @_ };
    delete $opt->{t} if $opt->{t} == -1;
    delete $opt->{g} if !$opt->{g};
    '?'.join ';', map "$_=$opt->{$_}", sort keys %$opt;
}


sub SideBar {
    my $opt = shift;

    Div class => 'fixed-size-left-sidebar-xl', sub {
        Div class => 'vertical-selector-label', 'Status';
        Div class => 'vertical-selector', sub {
            for (-1..$#VNLIST_STATUS) {
                A href => mkurl($opt, t => $_, p => 1), mkclass(
                    'vertical-selector__item' => 1,
                    'vertical-selector__item--active' => $_ == $opt->{t}
                ), $_ < 0 ? 'All' : $VNLIST_STATUS[$_];
            }
        };
    };
}


sub NextPrev {
    my($opt, $count) = @_;
    my $numpage = ceil($count/50);

    Div class => 'd-lg-flex jc-between align-items-center', sub {
        Div class => 'd-flex align-items-center', '';
        Div class => 'd-block d-lg-none mb-2', '';
        Div class => 'd-flex jc-right align-items-center', sub {
            A href => mkurl($opt, p => $opt->{p}-1), mkclass(btn => 1, 'btn--disabled' => $opt->{p} <= 1), '< Prev';
            Div class => 'mx-3 semi-muted', sprintf 'page %d of %d', $opt->{p}, $numpage;
            A href => mkurl($opt, p => $opt->{p}+1), mkclass(btn => 1, 'btn--disabled' => $opt->{p} >= $numpage), 'Next >';
        };
    };
}


sub EditDropDown {
    my($u, $opt, $item) = @_;
    return if $u->{id} != (auth->uid||0);
    Div 'data-elm-module' => 'UVNList.Options',
        'data-elm-flags'  => JSON::XS->new->encode({uid => $u->{id}, item => $item}),
        '';
}


sub VNTable {
    my($u, $lst, $opt) = @_;

    my $SortHeader = sub {
        my($id, $label) = @_;
        my $isasc = $opt->{s} eq $id && $opt->{o} eq 'a';
        A mkclass(
            'table-header'   => 1,
            'with-sort-icon' => 1,
            'with-sort-icon--down'   => !$isasc,
            'with-sort-icon--up'     => $isasc,
            'with-sort-icon--active' => $opt->{s} eq $id,
        ), href => mkurl($opt, p => 1, s => $id, o => $isasc ? 'd' : 'a'), $label;
    };

    Table class => 'table table--responsive-single-sm fs-medium vn-list', sub {
        Thead sub {
            Tr sub {
                Th width => '15%', class => 'th--nopad', sub { $SortHeader->(date  => 'Date' ) };
                Th width => '40%', class => 'th--nopad', sub { $SortHeader->(title => 'Title') };
                Th width => '10%', class => 'th--nopad', sub { $SortHeader->(vote  => 'Vote' ) };
                Th width => '13%', 'Status';
                Th width => '7.33%', '';
                Th width => '7.33%', '';
                Th width => '7.33%', '';
            };
        };
        Tbody sub {
            for my $l (@$lst) {
                Tr sub {
                    Td class => 'tabular-nums muted', date_display $l->{date};
                    Td sub {
                        A href => "/v$l->{id}", title => $l->{original}||$l->{title}, $l->{title};
                    };

                    if($u->{id} == (auth->uid||0)) {
                        Td class => 'table-edit-overlay-base', sub {
                            Div 'data-elm-module' => 'UVNList.Vote',
                                'data-elm-flags'  => JSON::XS->new->encode({uid => int $u->{id}, vid => int $l->{id}, vote => ''.vote_display $l->{vote}}),
                                vote_display $l->{vote};
                        };
                        Td class => 'table-edit-overlay-base', sub {
                            Div 'data-elm-module' => 'UVNList.Status',
                                'data-elm-flags'  => JSON::XS->new->encode({uid => int $u->{id}, vid => int $l->{id}, status => int $l->{status}||0}),
                                $VNLIST_STATUS[$l->{status}||0];
                        };
                    } else {
                        Td vote_display $l->{vote};
                        Td $VNLIST_STATUS[$l->{status}||0];
                    }

                    # Release info
                    Td sub {
                        A href => 'javascript:;', class => 'vn-list__expand-releases', sub {
                            Span class => 'expand-arrow mr-2', '';
                            Txt sprintf '%d/%d', (scalar grep $_->{status}==2, @{$l->{rel}}), scalar @{$l->{rel}};
                        } if @{$l->{rel}};
                    };

                    # Notes
                    Td sub {
                        # TODO: vn-list__expand-comment--empty for 'add comment' things
                        A href => 'javascript:;', class => 'vn-list__expand-comment', sub {
                            Span class => 'expand-arrow mr-2', '';
                            Img class => 'svg-icon', src => tuwf->conf->{url_static}.'/v3/heavy/comment.svg';
                        } if $l->{notes};
                    };

                    Td sub { EditDropDown $u, $opt, $l };
                };

                # Release info
                Tr class => 'vn-list__releases-row d-none', sub {
                    Td colspan => '6', sub {
                        Div class => 'vn-list__releases', sub {
                            Table class => 'table table--responsive-single-sm ml-3', sub {
                                Tbody sub {
                                    for my $r (@{$l->{rel}}) {
                                        Tr sub {
                                            Td width => '15%', class => 'tabular-nums muted pl-0', date_display $r->{date};
                                            Td width => '50%', sub {
                                                A href => "/v$r->{rid}", title => $r->{original}||$r->{title}, $r->{title};
                                            };
                                            # TODO: Editabe
                                            Td width => '20%', $RLIST_STATUS[$l->{status}];
                                            Td width => '15%', ''; # TODO: Edit menu
                                        }
                                    }
                                }
                            }
                        }
                    }
                } if @{$l->{rel}};

                # Notes
                Tr class => 'vn-list__comment-row d-none', sub {
                    Td colspan => '6', sub {
                        # TODO: Editable
                        Div class => 'vn-list__comment ml-3', $l->{notes};
                    }
                } if $l->{notes};
            };
        };
    };
}


sub VNGrid {
    my($u, $lst, $opt) = @_;

    Div class => 'vn-grid mb-4', sub {
        for my $l (@$lst) {
            Div class => 'vn-grid__item', sub {
                # TODO: NSFW hiding? What about missing images?
                Div class => 'vn-grid__item-bg', style => sprintf("background-image: url('%s')", tuwf->imgurl(cv => $l->{image})), '';
                Div class => 'vn-grid__item-overlay', sub {
                    A href => 'javascript:;', class => 'vn-grid__item-link', ''; # TODO: Open modal on click
                    Div class => 'vn-grid__item-top', sub {
                        EditDropDown $u, $opt, $l;
                        Div class => 'vn-grid__item-rating', sub {
                            Img class => 'svg-icon', src => tuwf->conf->{url_static}.'/v3/heavy/comment.svg' if $l->{notes};
                            Lit ' ';
                            Txt vote_display $l->{vote};
                        }
                    };
                    Div class => 'vn-grid__item-name', $l->{title};
                }
            }
        }
    }
}


sub List {
    my($u, $opt) = @_;

    my $lst = tuwf->dbAlli(q{
        SELECT v.id, v.title, v.original, vl.status, vl.notes, vo.vote, v.image, },
               sql_totime('LEAST(vl.added, vo.date)'), q{AS date,
               count(*) OVER() AS full_count
          FROM vn v
          LEFT JOIN votes vo   ON vo.vid = v.id AND vo.uid =}, \$u->{id}, q{
          LEFT JOIN vnlists vl ON vl.vid = v.id AND vl.uid =}, \$u->{id}, q{
         WHERE }, sql_and(
                   'vo.vid IS NOT NULL OR vl.vid IS NOT NULL',
                   $opt->{t} >= 1 ? sql('vl.status =', \$opt->{t}) : $opt->{t} == 0 ? 'vl.status = 0 OR vl.status IS NULL' : ()
               ),
        'ORDER BY', {
                         title => 'v.title',
                         date  => 'LEAST(vl.added, vo.date)',
                         vote  => 'vo.vote',
                     }->{$opt->{s}},
                     $opt->{o} eq 'a' ? 'ASC' : 'DESC',
                     'NULLS LAST',
        'LIMIT', \50,
       'OFFSET', \(($opt->{p}-1)*50)
    );
    my $count = @$lst ? $lst->[0]{full_count} : 0;
    delete $_->{full_count} for @$lst;

    enrich_list rel => id => vid => sub { sql q{
        SELECT rv.vid, rl.rid, rl.status, r.title, r.original, }, sql_totime('rl.added'), q{ AS date
          FROM rlists rl
          JOIN releases r ON r.id = rl.rid
          JOIN releases_vn rv ON rv.id = r.id
         WHERE rl.uid =}, \$u->{id}, q{AND rv.vid IN}, $_[0]
    }, $lst;

    Div class => 'col-md', sub {
        Div class => 'card card--white card--no-separators mb-5', sub {
            Div class => 'card__header', sub {
                Div class => 'card__title', 'List';
                Debug $lst;
                Div class => 'card__header-buttons', sub {
                    Div class => 'btn-group', sub {
                        A href => mkurl($opt, g => 0), mkclass(btn => 1, active => !$opt->{g}, 'js-show-vn-list' => 1), \&ListIcon;
                        A href => mkurl($opt, g => 1), mkclass(btn => 1, active =>  $opt->{g}, 'js-show-vn-grid' => 1), \&GridIcon;
                    };
                };
            };

            VNTable $u, $lst, $opt unless $opt->{g};
            Div class => 'card__body fs-medium', sub {
                VNGrid $u, $lst, $opt if $opt->{g};
                NextPrev $opt, $count;
            };
        }
    };
}


TUWF::get qr{/$UID_RE/list}, sub {
    my $uid = tuwf->capture('id');
    my $u = tuwf->dbRowi(q{
        SELECT u.id, u.username, hd.value AS hide_list
          FROM users u
     LEFT JOIN users_prefs hd ON hd.uid = u.id AND hd.key = 'hide_list'
         WHERE u.id =}, \$uid
    );
    return tuwf->resNotFound if !$u->{id} || !show_list $u;

    my $opt = tuwf->validate(get =>
        t => { vnlist_status => 1, required => 0, default => -1 },  # status
        p => { page => 1 },  # page
        o => { enum => ['d','a'], required => 0, default => 'a' }, # order (asc/desc)
        s => { enum => ['title', 'date', 'vote'], required => 0, default => 'title' }, # sort column
        g => { anybool => 1 }, # grid
    )->data;

    Framework
        title => $u->{username},
        index => 0,
        top => sub {
            Div class => 'col-md', sub {
                Div class => 'detail-page-title', ucfirst $u->{username};
                TopNav list => $u;
            }
        },
        sub {
            Div class => 'row', sub {
                SideBar $opt;
                List $u, $opt;
            };
        };
};


json_api '/u/setvote', {
    uid  => { id => 1 },
    vid  => { id => 1 },
    vote => { vnvote => 1 }
}, sub {
    my $data = shift;
    return $elm_Unauth->() if (auth->uid||0) != $data->{uid};

    tuwf->dbExeci(
        'DELETE FROM votes WHERE',
        { vid => $data->{vid}, uid => $data->{uid} }
    ) if !$data->{vote};

    tuwf->dbExeci(
        'INSERT INTO votes',
        { vid => $data->{vid}, uid => $data->{uid}, vote => $data->{vote} },
        'ON CONFLICT (vid, uid) DO UPDATE SET',
        { vote => $data->{vote} }
    ) if $data->{vote};

    $elm_Success->()
};


json_api '/u/setvnstatus', {
    uid    => { id => 1 },
    vid    => { id => 1 },
    status => { vnlist_status => 1 }
}, sub {
    my $data = shift;
    return $elm_Unauth->() if (auth->uid||0) != $data->{uid};

    tuwf->dbExeci(
        'INSERT INTO vnlists',
        { vid => $data->{vid}, uid => $data->{uid}, status => $data->{status} },
        'ON CONFLICT (vid, uid) DO UPDATE SET',
        { status => $data->{status} }
    );
    $elm_Success->();
};
