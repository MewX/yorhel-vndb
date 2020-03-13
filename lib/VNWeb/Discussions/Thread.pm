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

elm_api DiscussionsPoll => $POLL_OUT, $POLL_IN, sub {
    my($data) = @_;
    return elm_Unauth if !auth;

    my $t = tuwf->dbRowi('SELECT poll_question, poll_max_options FROM threads t WHERE id =', \$data->{tid}, 'AND', sql_visible_threads());
    return tuwf->resNotFound if !$t->{poll_question};

    die 'Too many options' if $data->{options}->@* > $t->{poll_max_options};
    validate_dbid sql('SELECT id FROM threads_poll_options WHERE tid =', \$data->{tid}, 'AND id IN'), $data->{options}->@*;

    tuwf->dbExeci('DELETE FROM threads_poll_votes WHERE tid =', \$data->{tid}, 'AND uid =', \auth->uid);
    tuwf->dbExeci('INSERT INTO threads_poll_votes', { tid => $data->{tid}, uid => auth->uid, optid => $_ }) for $data->{options}->@*;
    elm_Success
};




my $REPLY = {
    tid => { id => 1 },
    old => { _when => 'out', anybool => 1 },
    msg => { _when => 'in', maxlength => 32768 }
};

my $REPLY_IN  = form_compile in  => $REPLY;
my $REPLY_OUT = form_compile out => $REPLY;

elm_api DiscussionsReply => $REPLY_OUT, $REPLY_IN, sub {
    my($data) = @_;
    my $t = tuwf->dbRowi('SELECT id, locked, count FROM threads t WHERE id =', \$data->{tid}, 'AND', sql_visible_threads());
    return tuwf->resNotFound if !$t->{id};
    return elm_Unauth if !can_edit t => $t;

    my $num = $t->{count}+1;
    my $msg = bb_subst_links $data->{msg};
    tuwf->dbExeci('INSERT INTO threads_posts', { tid => $t->{id}, num => $num, uid => auth->uid, msg => $msg });
    tuwf->dbExeci('UPDATE threads SET count =', \$num, 'WHERE id =', \$t->{id});
    elm_Redirect post_url $t->{id}, $num, 'last';
};




sub metabox_ {
    my($t) = @_;
    div_ class => 'mainbox', sub {
        h1_ $t->{title};
        h2_ 'Hidden' if $t->{hidden};
        h2_ 'Private' if $t->{private};
        h2_ 'Posted in';
        ul_ sub {
            li_ sub {
                a_ href => "/t/$_->{btype}", $BOARD_TYPE{$_->{btype}}{txt};
                if($_->{iid}) {
                    txt_ ' > ';
                    a_ style => 'font-weight: bold', href => "/t/$_->{btype}$_->{iid}", "$_->{btype}$_->{iid}";
                    txt_ ':';
                    if($_->{title}) {
                        a_ href => "/$_->{btype}$_->{iid}", title => $_->{original}||$_->{title}, $_->{title};
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
                    if(!$_->{hidden} || auth->permBoard) {
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
    my($t, $posts, $page) = @_;
    return if $t->{count} > $page*25;
    if(can_edit t => $t) {
        elm_ 'Discussions.Reply' => $REPLY_OUT, { tid => $t->{id}, old => $posts->[$#$posts]{date} < time-182*24*3600 };
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
    return tuwf->resNotFound if !@$posts;

    my $poll_options = $t->{poll_question} && tuwf->dbAlli(
        'SELECT tpo.id, tpo.option, count(u.id) as votes, tpm.optid IS NOT NULL as my
           FROM threads_poll_options tpo
           LEFT JOIN threads_poll_votes tpv ON tpv.optid = tpo.id
           LEFT JOIN users u ON tpv.uid = u.id AND NOT u.ign_votes
           LEFT JOIN threads_poll_votes tpm ON tpm.optid = tpo.id AND tpm.uid =', \auth->uid, '
          WHERE tpo.tid =', \$id, '
          GROUP BY tpo.id, tpo.option, tpm.optid'
    );

    framework_ title => $t->{title}, sub {
        metabox_ $t;
        elm_ 'Discussions.Poll' => $POLL_OUT, {
            question    => $t->{poll_question},
            max_options => $t->{poll_max_options},
            num_votes   => tuwf->dbVali('SELECT COUNT(DISTINCT tpv.uid) FROM threads_poll_votes tpv JOIN users u ON tpv.uid = u.id WHERE NOT u.ign_votes AND tid =', \$id),
            preview     => !!tuwf->reqGet('pollview'), # Old non-Elm way to preview poll results
            can_vote    => !!auth,
            tid         => $id,
            options     => $poll_options
        } if $t->{poll_question};
        posts_ $t, $posts, $page;
        reply_ $t, $posts, $page;
    }
};


TUWF::get qr{/$RE{postid}}, sub {
    my($id, $num) = (tuwf->capture('id'), tuwf->capture('num'));
    tuwf->resRedirect(post_url($id, $num, $num), 'perm')
};

1;
