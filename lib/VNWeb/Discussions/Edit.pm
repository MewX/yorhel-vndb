package VNWeb::Discussions::Edit;

use VNWeb::Prelude;
use VNWeb::Discussions::Lib;


my $FORM = {
    tid         => { required => 0, vndbid => 't' }, # Thread ID, only when editing a post

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
    locked      => { anybool => 1 }, # When can_mod
    hidden      => { anybool => 1 }, # When can_mod
    private     => { anybool => 1 }, # When can_private
    nolastmod   => { anybool => 1, _when => 'in' }, # When can_mod
    delete      => { anybool => 1 }, # When can_mod

    msg         => { maxlength => 32768 },
};

my $FORM_OUT = form_compile out => $FORM;
my $FORM_IN  = form_compile in  => $FORM;


elm_api DiscussionsEdit => $FORM_OUT, $FORM_IN, sub {
    my($data) = @_;
    my $tid = $data->{tid};

    my $t = !$tid ? {} : tuwf->dbRowi('
        SELECT t.id, t.poll_question, t.poll_max_options, t.hidden, tp.num, tp.uid AS user_id,', sql_totime('tp.date'), 'AS date
          FROM threads t
          JOIN threads_posts tp ON tp.tid = t.id AND tp.num = 1
         WHERE t.id =', \$tid,
          'AND', sql_visible_threads());
    return tuwf->resNotFound if $tid && !$t->{id};
    return elm_Unauth if !can_edit t => $t;

    if($tid && $data->{delete} && auth->permBoardmod) {
        auth->audit($t->{user_id}, 'post delete', "deleted $tid.1");
        tuwf->dbExeci('DELETE FROM threads WHERE id =', \$tid);
        tuwf->dbExeci(q{DELETE FROM notifications WHERE ltype = 't' AND iid = vndbid_num(}, \$tid, ')');
        return elm_Redirect '/t';
    }
    auth->audit($t->{user_id}, 'post edit', "edited $tid.1") if $tid && $t->{user_id} != auth->uid;


    die "Invalid title" if !length $data->{title};
    die "Invalid boards" if !$data->{boards} || grep +(!$BOARD_TYPE{$_->{btype}}{dbitem})^(!$_->{iid}), $data->{boards}->@*;

    validate_dbid 'SELECT id FROM vn        WHERE id IN', map $_->{btype} eq 'v' ? $_->{iid} : (), $data->{boards}->@*;
    validate_dbid 'SELECT id FROM producers WHERE id IN', map $_->{btype} eq 'p' ? $_->{iid} : (), $data->{boards}->@*;
    # Do not validate user boards here, it's possible to have threads assigned to deleted users.

    die "Invalid max_options" if $data->{poll} && $data->{poll}{max_options} > $data->{poll}{options}->@*;
    my $pollchanged = (!$tid && $data->{poll}) || ($tid && $data->{poll} && (
             $data->{poll}{question} ne ($t->{poll_question}||'')
          || $data->{poll}{max_options} != $t->{poll_max_options}
          || join("\n", $data->{poll}{options}->@*) ne
             join("\n", map $_->{option}, tuwf->dbAlli('SELECT option FROM threads_poll_options WHERE tid =', \$tid, 'ORDER BY id')->@*)
    ));

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
    tuwf->dbExeci('UPDATE threads SET', $thread, 'WHERE id =', \$tid) if $tid;
    $tid = tuwf->dbVali('INSERT INTO threads', $thread, 'RETURNING id') if !$tid;

    tuwf->dbExeci('DELETE FROM threads_boards WHERE tid =', \$tid);
    tuwf->dbExeci('INSERT INTO threads_boards', { tid => $tid, type => $_->{btype}, iid => $_->{iid}//0 }) for $data->{boards}->@*;

    if($pollchanged) {
        tuwf->dbExeci('DELETE FROM threads_poll_options WHERE tid =', \$tid);
        tuwf->dbExeci('INSERT INTO threads_poll_options', { tid => $tid, option => $_ }) for $data->{poll}{options}->@*;
    }

    my $post = {
        tid => $tid,
        num => 1,
        msg => bb_subst_links($data->{msg}),
        $data->{tid} ? () : (uid => auth->uid),
        !$data->{tid} || (auth->permBoardmod && $data->{nolastmod}) ? () : (edited => sql 'NOW()')
    };
    tuwf->dbExeci('INSERT INTO threads_posts', $post) if !$data->{tid};
    tuwf->dbExeci('UPDATE threads_posts SET', $post, 'WHERE', { tid => $tid, num => 1 }) if $data->{tid};

    elm_Redirect "/$tid.1";
};


TUWF::get qr{(?:/t/(?<board>$BOARD_RE)/new|/$RE{tid}\.1/edit)}, sub {
    my($board_type, $board_id) = (tuwf->capture('board')||'') =~ /^([^0-9]+)([0-9]*)$/;
    my $tid = tuwf->capture('id');

    $board_type = 'ge' if $board_type && $board_type eq 'an' && !auth->permBoardmod;

    my $t = !$tid ? {} : tuwf->dbRowi('
        SELECT t.id, tp.tid, t.title, t.locked, t.private, t.hidden, t.poll_question, t.poll_max_options, tp.msg, tp.uid AS user_id,', sql_totime('tp.date'), 'AS date
          FROM threads t
          JOIN threads_posts tp ON tp.tid = t.id AND tp.num = 1
         WHERE t.id =', \$tid,
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

    $t->{hidden}  //= 0;
    $t->{msg}     //= '';
    $t->{title}   //= tuwf->reqGet('title');
    $t->{tid}     //= undef;
    $t->{private} //= auth->isMod && tuwf->reqGet('priv') ? 1 : 0;
    $t->{locked}  //= 0;
    $t->{delete}  =   0;

    framework_ title => $tid ? 'Edit thread' : 'Create new thread', sub {
        elm_ 'Discussions.Edit' => $FORM_OUT, $t;
    };
};


1;
