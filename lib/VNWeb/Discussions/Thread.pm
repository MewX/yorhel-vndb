package VNWeb::Discussions::Thread;

use VNWeb::Prelude;
use VNWeb::Discussions::Lib;


my $POLL_OUT = form_compile any => {
    question    => {},
    max_options => { uint => 1 },
    num_votes   => { uint => 1 },
    can_vote    => { anybool => 1 },
    preview     => { anybool => 1 },
    tid         => { id => 1 },
    options     => { aoh => {
        id     => { id => 1 },
        option => {},
        votes  => { uint => 1 },
        my     => { anybool => 1 },
    } },
};


my $POLL_IN = form_compile any => {
    tid     => { id => 1 },
    options => { type => 'array', values => { id => 1 } },
};


elm_form 'DiscussionsPoll' => $POLL_OUT, $POLL_IN;


sub metabox_ {
    my($t) = @_;
    div_ class => 'mainbox', sub {
        h1_ $t->{title};
        h2_ 'Hidden' if $t->{hidden};
        h2_ 'Private' if $t->{private};
        h2_ 'Posted in';
        ul_ sub {
            li_ sub {
                a_ href => "/t/$_->{type}", $BOARD_TYPE{$_->{type}}{txt};
                if($_->{iid}) {
                    txt_ ' > ';
                    a_ style => 'font-weight: bold', href => "/t/$_->{type}$_->{iid}", "$_->{type}$_->{iid}";
                    txt_ ':';
                    if($_->{title}) {
                        a_ href => "/$_->{type}$_->{iid}", title => $_->{original}, $_->{title};
                    } else {
                        b_ '[deleted]';
                    }
                }
            } for $t->{boards}->@*;
        };
    }
}


sub posts_ {
    my($t, $posts, $page) = @_;
    my sub url { "/t$t->{id}".($_?"/$_":'') }

    paginate_ \&url, $page, [ $t->{count}, 25 ], 't';
    div_ class => 'mainbox thread', sub {
        table_ class => 'stripe', sub {
            tr_ mkclass(deleted => $_->{hidden}), id => $_->{num}, sub {
                td_ class => 'tc1', $t->{count} == $_->{num} ? (id => 'last') : (), sub {
                    a_ href => "/t$t->{id}.$_->{num}", "#$_->{num}";
                    if(!$_->{hidden}) {
                        txt_ ' by ';
                        user_ $_;
                        br_;
                        txt_ fmtdate $_->{date}, 'full';
                    }
                };
                td_ class => 'tc2', sub {
                    i_ class => 'edit', sub {
                        txt_ '< ';
                        a_ href => "/t$t->{id}.$_->{num}/edit", 'edit';
                        txt_ ' >';
                    } if can_edit t => $_;
                    if($_->{hidden}) {
                        i_ class => 'deleted', 'Post deleted.';
                    } else {
                        lit_ bb2html $_->{msg};
                        i_ class => 'lastmod', 'Last modified on '.fmtdate($_->{edited}, 'full') if $_->{edited};
                    }
                };
            } for @$posts;
        };
    };
    paginate_ \&url, $page, [ $t->{count}, 25 ], 'b';
}


sub reply_ {
    my($t, $page) = @_;
    return if $t->{count} > $page*25;
    if(can_edit t => $t) {
        # TODO: Elmify
        form_ action => "/t$t->{id}/reply", method => 'post', 'accept-charset' => 'UTF-8', sub {
            div_ class => 'mainbox', sub {
                fieldset_ class => 'submit', sub {
                    input_ type => 'hidden', class => 'hidden', name => 'formcode', value => auth->csrftoken;
                    h2_ sub {
                        txt_ 'Quick reply';
                        b_ class => 'standout', ' (English please!)';
                    };
                    textarea_ name => 'msg', id => 'msg', rows => 4, cols => 50, '';
                    br_;
                    input_ type => 'submit', value => 'Reply', class => 'submit';
                    input_ type => 'submit', value => 'Go advanced...', class => 'submit', name => 'fullreply';
                }
            }
        }
    } else {
        div_ class => 'mainbox', sub {
            h1_ 'Reply';
            p_ class => 'center',
                    !auth ? 'You must be logged in to reply to this thread.' :
             $t->{locked} ? 'This thread has been locked, you can\'t reply to it anymore.' : 'You can not currently reply to this thread.';
        }
    }
}


TUWF::get qr{/$RE{tid}(?:/$RE{num})?}, sub {
    my($id, $page) = (tuwf->capture('id'), tuwf->capture('num')||1);

    my $t = tuwf->dbRowi(
        'SELECT id, title, count, hidden, locked, private
              , poll_question, poll_max_options
           FROM threads t
          WHERE', sql_visible_threads(), 'AND id =', \$id
    );
    return tuwf->resNotFound if !$t->{id};

    enrich_boards '', $t;

    my $posts = tuwf->dbPagei({ results => 25, page => $page },
        'SELECT tp.tid as id, tp.num, tp.hidden, tp.msg',
             ',', sql_user(),
             ',', sql_totime('tp.date'), ' as date',
             ',', sql_totime('tp.edited'), ' as edited
           FROM threads_posts tp
           JOIN users u ON tp.uid = u.id
          WHERE tp.tid =', \$id, '
          ORDER BY tp.num'
    );

    my $poll_options = $t->{poll_question} && tuwf->dbAlli(
        'SELECT tpo.id, tpo.option, count(tpv.uid) as votes, tpm.optid IS NOT NULL as my
           FROM threads_poll_options tpo
           LEFT JOIN threads_poll_votes tpv ON tpv.optid = tpo.id
           LEFT JOIN threads_poll_votes tpm ON tpm.optid = tpo.id AND tpm.uid =', \auth->uid, '
          WHERE tpo.tid =', \$id, '
          GROUP BY tpo.id, tpo.option, tpm.optid'
    );

    framework_ title => $t->{title}, sub {
        metabox_ $t;
        elm_ 'Discussions.Poll' => $POLL_OUT, {
            question    => $t->{poll_question},
            max_options => $t->{poll_max_options},
            num_votes   => tuwf->dbVali('SELECT COUNT(DISTINCT uid) FROM threads_poll_votes WHERE tid =', \$id),
            preview     => !!tuwf->reqGet('pollview'), # Old non-Elm way to preview poll results
            can_vote    => !!auth,
            tid         => $id,
            options     => $poll_options
        } if $t->{poll_question};
        posts_ $t, $posts, $page;
        reply_ $t, $page;
    }
};


TUWF::get qr{/$RE{postid}}, sub {
    my($id, $num) = (tuwf->capture('id'), tuwf->capture('num'));
    tuwf->resRedirect(post_url($id, $num, $num), 'perm')
};


json_api qr{/t/pollvote.json}, $POLL_IN, sub {
    my($data) = @_;
    return elm_Unauth if !auth;

    my $t = tuwf->dbRowi('SELECT poll_question, poll_max_options FROM threads WHERE id =', \$data->{tid});
    return tuwf->resNotFound if !$t->{poll_question};

    die 'Too many options' if $data->{options}->@* > $t->{poll_max_options};
    validate_dbid sql('SELECT id FROM threads_poll_options WHERE tid =', \$data->{tid}, 'AND id IN'), $data->{options}->@*;

    tuwf->dbExeci('DELETE FROM threads_poll_votes WHERE tid =', \$data->{tid}, 'AND uid =', \auth->uid);
    tuwf->dbExeci('INSERT INTO threads_poll_votes (tid, uid, optid) VALUES(', \$data->{tid}, ',', \auth->uid, ',', \$_, ')') for $data->{options}->@*;
    elm_Success
};

1;
