package VNWeb::User::Notifications;

use VNWeb::Prelude;

my %ntypes = (
    pm       => 'Private Message',
    dbdel    => 'Entry you contributed to has been deleted',
    listdel  => 'VN in your (wish)list has been deleted',
    dbedit   => 'Entry you contributed to has been edited',
    announce => 'Site announcement',
);


sub settings_ {
    my $id = shift;

    h1_ 'Settings';
    form_ action => "/u$id/notify_options", method => 'POST', sub {
        input_ type => 'hidden', class => 'hidden', name => 'csrf', value => auth->csrftoken;
        p_ sub {
            label_ sub {
                input_ type => 'checkbox', name => 'dbedit', auth->pref('notify_dbedit') ? (checked => 'checked') : ();
                txt_ ' Notify me about edits of database entries I contributed to.';
            };
            br_;
            label_ sub {
                input_ type => 'checkbox', name => 'announce', auth->pref('notify_announce') ? (checked => 'checked') : ();
                txt_ ' Notify me about site announcements.';
            };
            br_;
            input_ type => 'submit', class => 'submit', value => 'Save';
        }
    };
}


sub listing_ {
    my($id, $opt, $count, $list) = @_;

    my sub url { "/u$id/notifies?r=$opt->{r}&p=$_" }

    my sub tbl_ {
        thead_ sub { tr_ sub {
            td_ '';
            td_ 'Type';
            td_ 'Age';
            td_ 'ID';
            td_ 'Action';
        }};
        tfoot_ sub { tr_ sub {
            td_ colspan => 5, sub {
                input_ type => 'checkbox', class => 'checkall', name => 'notifysel', value => 0;
                txt_ ' ';
                input_ type => 'submit', class => 'submit', name => 'markread', value => 'mark selected read';
                input_ type => 'submit', class => 'submit', name => 'remove', value => 'remove selected';
                b_ class => 'grayedout', ' (Read notifications are automatically removed after one month)';
            }
        }};
        tr_ $_->{read} ? () : (class => 'unread'), sub {
            my $l = $_;
            my $lid = $l->{ltype}.$l->{iid}.($l->{subid}?'.'.$l->{subid}:'');
            my $url = "/u$id/notify/$l->{id}/$lid";
            td_ class => 'tc1', sub { input_ type => 'checkbox', name => 'notifysel', value => $l->{id}; };
            td_ class => 'tc2', $ntypes{$l->{ntype}};
            td_ class => 'tc3', fmtage $l->{date};
            td_ class => 'tc4', sub { a_ href => $url, $lid };
            td_ class => 'tc5', sub {
                a_ href => $url, sub {
                    txt_ $l->{ltype} eq 't' ? 'Edit of ' : $l->{subid} == 1 ? 'New thread ' : 'Reply to ';
                    i_ $l->{c_title};
                    txt_ ' by ';
                    i_ user_displayname $l;
                };
            };
        } for @$list;
    }

    form_ action => "/u$id/notify_update", method => 'POST', sub {
        input_ type => 'hidden', class => 'hidden', name => 'url', value => do { local $_ = $opt->{p}; url };
        paginate_ \&url, $opt->{p}, [$count, 25], 't';
        div_ class => 'mainbox browse notifies', sub {
            table_ class => 'stripe', \&tbl_;
        };
        paginate_ \&url, $opt->{p}, [$count, 25], 'b';
    } if $count;
}


TUWF::get qr{/$RE{uid}/notifies}, sub {
    my $id = tuwf->capture('id');
    return tuwf->resNotFound if !auth || $id != auth->uid;

    my $opt = eval { tuwf->validate(get =>
        p => { page => 1 },
        r => { anybool => 1 },
    )->data } || { p => 1, r => 0 };

    my $where = sql_and(
        sql('uid =', \$id),
        $opt->{r} ? () : 'read IS NULL'
    );
    my $count = tuwf->dbVali('SELECT count(*) FROM notifications WHERE', $where);
    my($list) = tuwf->dbPagei({ results => 25, page => $opt->{p} },
       'SELECT n.id, n.ntype, n.ltype, n.iid, n.subid, n.c_title
             , ', sql_totime('n.date'), ' as date
             , ', sql_totime('n.read'), ' as read
             , ', sql_user(),
         'FROM notifications n
          LEFT JOIN users u ON u.id = n.c_byuser
         WHERE ', $where,
        'ORDER BY n.id', $opt->{r} ? 'DESC' : 'ASC'
    );

    framework_ title => 'My notifications',
    sub {
        div_ class => 'mainbox', sub {
            h1_ 'My notifications';
            p_ class => 'browseopts', sub {
                a_ !$opt->{r} ? (class => 'optselected') : (), href => '?r=0', 'Unread notifications';
                a_  $opt->{r} ? (class => 'optselected') : (), href => '?r=1', 'All notifications';
            };
            p_ 'No notifications!' if !$count;
        };
        listing_ $id, $opt, $count, $list;
        div_ class => 'mainbox', sub { settings_ $id };
    };
};


TUWF::post qr{/$RE{uid}/notify_options}, sub {
    my $id = tuwf->capture('id');
    return tuwf->resNotFound if !auth || $id != auth->uid;

    my $frm = tuwf->validate(post =>
        csrf     => {},
        dbedit   => { anybool => 1 },
        announce => { anybool => 1 },
    )->data;
    return tuwf->resNotFound if !auth->csrfcheck($frm->{csrf});

    auth->prefSet(notify_dbedit   => $frm->{dbedit});
    auth->prefSet(notify_announce => $frm->{announce});
    tuwf->resRedirect("/u$id/notifies", 'post');
};


TUWF::post qr{/$RE{uid}/notify_update}, sub {
    my $id = tuwf->capture('id');
    return tuwf->resNotFound if !auth || $id != auth->uid;

    my $frm = tuwf->validate(post =>
        url       => { regex => qr{^/u$id/notifies} },
        notifysel => { required => 0, default => [], type => 'array', scalar => 1, values => { id => 1 } },
        markread  => { anybool => 1 },
        remove    => { anybool => 1 },
    )->data;

    if($frm->{notifysel}->@*) {
        my $where = sql 'uid =', \$id, ' AND id IN', $frm->{notifysel};
        tuwf->dbExeci('DELETE FROM notifications WHERE', $where) if $frm->{remove};
        tuwf->dbExeci('UPDATE notifications SET read = NOW() WHERE', $where) if $frm->{markread};
    }
    tuwf->resRedirect($frm->{url}, 'post');
};


TUWF::get qr{/$RE{uid}/notify/$RE{num}/(?<lid>[a-z0-9\.]+)}, sub {
    my $id = tuwf->capture('id');
    return tuwf->resNotFound if !auth || $id != auth->uid;
    tuwf->dbExeci('UPDATE notifications SET read = NOW() WHERE uid =', \$id, ' AND id =', \tuwf->capture('num'));
    tuwf->resRedirect('/'.tuwf->capture('lid'), 'temp');
};

1;
