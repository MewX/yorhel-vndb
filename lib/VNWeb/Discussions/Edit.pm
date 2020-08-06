package VNWeb::Discussions::Edit;

use VNWeb::Prelude;
use VNWeb::Discussions::Lib;


my $FORM = {
    tid         => { required => 0, vndbid => 't' }, # Thread ID, only when editing a post
    num         => { required => 0, id => 1 }, # Post number, only when editing

    # Only when num = 1 || tid = undef
    title       => { required => 0, maxlength => 50 },
    boards      => { required => 0, sort_keys => [ 'boardtype', 'iid' ], aoh => {
        btype     => { enum => \%BOARD_TYPE },
        iid       => { required => 0, default => 0, id => 1 }, #
        title     => { required => 0 },
    } },
    poll        => { required => 0, type => 'hash', keys => {
        question    => { maxlength => 100 },
        max_options => { uint => 1, min => 1, max => 20 }, #
        options     => { type => 'array', values => { maxlength => 100 }, minlength => 2, maxlength => 20 },
    } },

    can_mod     => { anybool => 1, _when => 'out' },
    can_private => { anybool => 1, _when => 'out' },
    locked      => { anybool => 1 }, # When can_mod && (num = 1 || tid = undef)
    hidden      => { anybool => 1 }, # When can_mod
    private     => { anybool => 1 }, # When can_private && (num = 1 || tid = undef)
    nolastmod   => { anybool => 1, _when => 'in' }, # When can_mod
    delete      => { anybool => 1 }, # When can_mod

    msg         => { maxlength => 32768 },
};

my $FORM_OUT = form_compile out => $FORM;
my $FORM_IN  = form_compile in  => $FORM;


elm_api DiscussionsEdit => $FORM_OUT, $FORM_IN, sub {
    my($data) = @_;
    my $tid = $data->{tid};
    my $num = $data->{num} || 1;

    my $t = !$tid ? {} : tuwf->dbRowi('
        SELECT t.id, tp.num, t.poll_question, t.poll_max_options, tp.hidden, tp.uid AS user_id,', sql_totime('tp.date'), 'AS date
          FROM threads t
          JOIN threads_posts tp ON tp.tid = t.id AND tp.num =', \$num,
        'WHERE t.id =', \$tid,
          'AND', sql_visible_threads());
    return tuwf->resNotFound if $tid && !$t->{id};
    return elm_Unauth if !can_edit t => $t;

    if($tid && $data->{delete} && auth->permBoardmod) {
        auth->audit($t->{user_id}, 'post delete', "deleted $tid.$num");
        if($num == 1) {
            tuwf->dbExeci('DELETE FROM threads WHERE id =', \$tid);
            tuwf->dbExeci(q{DELETE FROM notifications WHERE ltype = 't' AND iid = vndbid_num(}, \$tid, ')');
            return elm_Redirect '/t';
        } else {
            tuwf->dbExeci('DELETE FROM threads_posts WHERE tid =', \$tid, 'AND num =', \$num);
            tuwf->dbExeci(q{DELETE FROM notifications WHERE ltype = 't' AND iid = vndbid_num(}, \$tid, ') AND subid =', \$num);
            return elm_Redirect "/$tid";
        }
    }
    auth->audit($t->{user_id}, 'post edit', "edited $tid.$num") if $tid && $t->{user_id} != auth->uid;

    my $pollchanged = !$data->{tid} && $data->{poll};
    if($num == 1) {
        die "Invalid title" if !length $data->{title};
        die "Invalid boards" if !$data->{boards} || grep +(!$BOARD_TYPE{$_->{btype}}{dbitem})^(!$_->{iid}), $data->{boards}->@*;

        validate_dbid 'SELECT id FROM vn        WHERE id IN', map $_->{btype} eq 'v' ? $_->{iid} : (), $data->{boards}->@*;
        validate_dbid 'SELECT id FROM producers WHERE id IN', map $_->{btype} eq 'p' ? $_->{iid} : (), $data->{boards}->@*;
        # Do not validate user boards here, it's possible to have threads assigned to deleted users.

        die "Invalid max_options" if $data->{poll} && $data->{poll}{max_options} > $data->{poll}{options}->@*;
        $pollchanged = 1 if $tid && $data->{poll} && (
                 $data->{poll}{question} ne ($t->{poll_question}||'')
              || $data->{poll}{max_options} != $t->{poll_max_options}
              || join("\n", $data->{poll}{options}->@*) ne
                 join("\n", map $_->{option}, tuwf->dbAlli('SELECT option FROM threads_poll_options WHERE tid =', \$tid, 'ORDER BY id')->@*)
        )
    }

    my $thread = {
        title            => $data->{title},
        poll_question    => $data->{poll} ? $data->{poll}{question} : undef,
        poll_max_options => $data->{poll} ? $data->{poll}{max_options} : 1,
        auth->permBoardmod ? (
            hidden => $data->{hidden},
            locked => $data->{locked},
        ) : (),
        auth->isMod ? (
            private => $data->{private}
        ) : (),
    };
    tuwf->dbExeci('UPDATE threads SET', $thread, 'WHERE id =', \$tid) if $tid && $num == 1;
    $tid = tuwf->dbVali('INSERT INTO threads', $thread, 'RETURNING id') if !$tid;

    if($num == 1) {
        tuwf->dbExeci('DELETE FROM threads_boards WHERE tid =', \$tid);
        tuwf->dbExeci('INSERT INTO threads_boards', { tid => $tid, type => $_->{btype}, iid => $_->{iid}//0 }) for $data->{boards}->@*;
    }

    if($pollchanged) {
        tuwf->dbExeci('DELETE FROM threads_poll_options WHERE tid =', \$tid);
        tuwf->dbExeci('INSERT INTO threads_poll_options', { tid => $tid, option => $_ }) for $data->{poll}{options}->@*;
    }

    my $post = {
        tid => $tid,
        num => $num,
        msg => bb_subst_links($data->{msg}),
        $data->{tid} ? () : (uid => auth->uid),
        auth->permBoardmod && $num != 1 ? (hidden => $data->{hidden}) : (),
        !$data->{tid} || (auth->permBoardmod && $data->{nolastmod}) ? () : (edited => sql 'NOW()')
    };
    tuwf->dbExeci('INSERT INTO threads_posts', $post) if !$data->{tid};
    tuwf->dbExeci('UPDATE threads_posts SET', $post, 'WHERE', { tid => $tid, num => $num }) if $data->{tid};

    elm_Redirect "/$tid.$num";
};


TUWF::get qr{(?:/t/(?<board>$BOARD_RE)/new|/$RE{postid}/edit)}, sub {
    my($board_type, $board_id) = (tuwf->capture('board')||'') =~ /^([^0-9]+)([0-9]*)$/;
    my($tid, $num) = (tuwf->capture('id'), tuwf->capture('num'));

    $board_type = 'ge' if $board_type && $board_type eq 'an' && !auth->permBoardmod;

    my $t = !$tid ? {} : tuwf->dbRowi('
        SELECT t.id, tp.tid, tp.num, t.title, t.locked, t.private, t.hidden AS thread_hidden, t.poll_question, t.poll_max_options, tp.hidden, tp.msg, tp.uid AS user_id,', sql_totime('tp.date'), 'AS date
          FROM threads t
          JOIN threads_posts tp ON tp.tid = t.id AND tp.num =', \$num,
        'WHERE t.id =', \$tid,
          'AND', sql_visible_threads());
    return tuwf->resNotFound if $tid && !$t->{id};
    return tuwf->resDenied if !can_edit t => $t;

    $t->{poll}{options} = $t->{poll_question} && [ map $_->{option}, tuwf->dbAlli('SELECT option FROM threads_poll_options WHERE tid =', \$t->{id}, 'ORDER BY id')->@* ];
    $t->{poll}{question} = delete $t->{poll_question};
    $t->{poll}{max_options} = delete $t->{poll_max_options};
    $t->{poll} = undef if !$t->{poll}{question};

    if($tid) {
        enrich_boards undef, $t;
    } else {
        $t->{boards} = [ {
            btype => $board_type,
            iid   => $board_id||0,
            title => !$board_id ? undef :
                tuwf->dbVali('SELECT title FROM', sql_boards(), 'x WHERE btype =', \$board_type, 'AND iid =', \$board_id)
        } ];
        return tuwf->resNotFound if $board_id && !length $t->{boards}[0]{title};
        push $t->{boards}->@*, { btype => 'u', iid => auth->uid, title => auth->user->{user_name} }
            if $board_type eq 'u' && $board_id != auth->uid;
    }

    $t->{can_mod}     = auth->permBoardmod;
    $t->{can_private} = auth->isMod;

    $t->{hidden}  = $tid && $num == 1 ? $t->{thread_hidden}//0 : $t->{hidden}//0;
    $t->{msg}     //= '';
    $t->{title}   //= tuwf->reqGet('title');
    $t->{tid}     //= undef;
    $t->{num}     //= undef;
    $t->{private} //= auth->isMod && tuwf->reqGet('priv') ? 1 : 0;
    $t->{locked}  //= 0;
    $t->{delete}  =   0;

    framework_ title => $tid ? 'Edit post' : 'Create new thread', sub {
        elm_ 'Discussions.Edit' => $FORM_OUT, $t;
    };
};


1;
