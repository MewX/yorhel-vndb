package VNWeb::Misc::Reports;

use VNWeb::Prelude;

my $reportsperday = 5;

my @STATUS = qw/new busy done dismissed/;

# Requires objects with {rtype,object} fields, adds a HTML-formatted 'title' field, which formats and links to the entry.
sub enrich_object {
    for my $o (@_) {
        delete $o->{title};
        if($o->{rtype} eq 't' && $o->{object} =~ /^$RE{postid}$/) {
            my $post = tuwf->dbRowi(
               'SELECT tp.num, t.title, ', sql_user(), '
                  FROM threads t JOIN threads_posts tp ON tp.tid = t.id LEFT JOIN users u ON u.id = tp.uid
                 WHERE NOT t.hidden AND NOT t.private AND t.id =', \"$+{id}", 'AND tp.num =', \"$+{num}"
            );
            $o->{title} = xml_string sub {
                txt_ 'Post ';
                a_ href => "/$o->{object}", "#$post->{num}";
                txt_ ' on ';
                a_ href => "/$o->{object}", $post->{title};
                txt_ ' by ';
                user_ $post;
            } if $post->{num};

        } elsif($o->{rtype} eq 'db' && $o->{object} =~ /^([vrpcsd])$RE{num}$/) {
            my($t,$id) = ($1, $+{num});
            my $obj = dbobj $t, $id;
            $o->{title} = xml_string sub {
                txt_ {qw/v VN r Release p Producer c Character s Staff d Doc/}->{$t};
                txt_ ': ';
                a_ href => "/$t$id", $obj->{title};
            } if $obj->{id};
        }
    }
}


sub is_throttled {
    tuwf->dbVali('SELECT COUNT(*) FROM reports WHERE date > NOW()-\'1 day\'::interval AND', auth ? ('uid =', \auth->uid) : ('ip =', \tuwf->reqIP)) >= $reportsperday
}


my $FORM = form_compile any => {
    rtype    => {},
    object   => {},
    title    => {},
    reason   => { maxlength => 50 },
    message  => { required => 0, default => '', maxlength => 50000 },
    loggedin => { anybool => 1 },
};

elm_api Report => undef, $FORM, sub {
    my($data) = @_;
    enrich_object $data;
    return elm_Invalid if !$data->{title};
    return elm_Unauth if is_throttled;

    tuwf->dbExeci('INSERT INTO reports', {
        uid      => auth->uid,
        ip       => auth ? undef : tuwf->reqIP,
        rtype    => $data->{rtype},
        object   => $data->{object},
        reason   => $data->{reason},
        message  => $data->{message},
    });
    elm_Success
};


TUWF::get qr{/report/(?<rtype>t|db)/(?<object>.+)}, sub {
    my $obj = { rtype => tuwf->capture('rtype'), object => tuwf->capture('object') };
    enrich_object $obj;
    return tuwf->resNotFound if !$obj->{title};

    framework_ title => 'Submit report', sub {
        if(is_throttled) {
            div_ class => 'mainbox', sub {
                h1_ 'Submit report';
                p_ "Sorry, you can only submit $reportsperday reports per day. If you wish to report more, you can do so by sending an email to ".config->{admin_email}
            }
        } else {
            elm_ Report => $FORM, { elm_empty($FORM)->%*, %$obj, loggedin => !!auth };
        }
    };
};


sub report_ {
    my($r, $url) = @_;
    td_ style => 'padding: 3px 5px 5px 20px', sub {
        a_ href => "?id=$r->{id}", "#$r->{id}";
        b_ class => 'grayedout', ' '.fmtdate $r->{date}, 'full';
        txt_ ' by ';
        if($r->{uid}) {
            a_ href => "/u$r->{uid}", $r->{username};
            txt_ ' (';
            a_ href => "/t/u$r->{uid}/new?title=Regarding your report&priv=1", 'pm';
            txt_ ')';
        } else {
            txt_ $r->{ip}||'[anonymous]';
        }
        br_;
        lit_ $r->{title};
        br_;
        txt_ $r->{reason};
        div_ class => 'quote', sub { lit_ TUWF::XML::html_escape $r->{message} } if $r->{message};
    };
    td_ style => 'width: 300px', sub {
        form_ method => 'post', action => '/report/edit', sub {
            input_ type => 'hidden', name => 'id', value => $r->{id};
            input_ type => 'hidden', name => 'url', value => $url;
            textarea_ name => 'comment', rows => 2, cols => 25, style => 'width: 290px', placeholder => 'Mod comment... (optional)', '';
            br_;
            select_ style => 'width: 100px', name => 'status', sub {
                option_ value => $_, $_ eq $r->{status} ? (selected => 'selected') : (), ucfirst $_ for @STATUS;
            };
            input_ type => 'submit', class => 'submit', value => 'Update';
        };
    };
    td_ sub {
        lit_ TUWF::XML::html_escape $r->{log};
    };
}


TUWF::get qr{/report/list}, sub {
    return tuwf->resDenied if !auth->isMod;

    my $opt = tuwf->validate(get =>
        p      => { upage => 1 },
        status => { enum => \@STATUS, required => 0 },
        id     => { id => 1, required => 0 },
    )->data;

    my $where = sql_and
        $opt->{id} ? sql 'r.id =', \$opt->{id} : (),
        $opt->{status} ? sql 'r.status =', \$opt->{status} : ();

    my $cnt = tuwf->dbVali('SELECT count(*) FROM reports r WHERE', $where);
    my $lst = tuwf->dbPagei({results => 50, page => $opt->{p}},
       'SELECT r.id,', sql_totime('r.date'), 'as date, r.uid, u.username, r.ip, r.reason, r.rtype, r.object, r.status, r.message, r.log
          FROM reports r
          LEFT JOIN users u ON u.id = r.uid
         WHERE', $where, '
         ORDER BY r.id DESC'
    );
    enrich_object @$lst;

    my sub url { '?'.query_encode %$opt, @_ }

    framework_ title => 'Reports', sub {
        div_ class => 'mainbox', sub {
            h1_ 'Reports';
            p_  'Welcome to the super advanced reports handling interface. Reports can have the following statuses:';
            ul_ sub {
                li_ 'New: Default status for newly submitted reports';
                li_ 'Busy: You can use this state to indicate that you\'re working on it.';
                li_ 'Done: Report handled.';
                li_ 'Dismissed: Report ignored.';
            };
            p_ q{
              There's no flowchart you have to follow, if you can quickly handle a report you can go directly from 'New' to 'Done' or 'Dismissed'.
              If you want to bring an older report to other's attention you can go back from any existing state to 'New'.
            };
            p_ q{
              Feel free to skip over reports that you can't or don't want to handle, someone else will eventually pick it up.
            };
            p_ q{
              Changing the status and/or adding a comment will add an entry to the log, so other mods can see what is going on. Everything on this page is only visible to moderators.
            };
            br_;
            br_;
            p_ class => 'browseopts', sub {
                a_ href => url(p => undef, status => undef), !$opt->{status} ? (class => 'optselected') : (), 'All';
                a_ href => url(p => undef, status => $_), $opt->{status} && $opt->{status} eq $_ ? (class => 'optselected') : (), ucfirst $_ for @STATUS;
            };
        };

        paginate_ \&url, $opt->{p}, [$cnt, 50], 't';
        div_ class => 'mainbox thread', sub {
            table_ class => 'stripe', sub {
                my $url = '/report/list'.url;
                tr_ sub { report_ $_, $url } for @$lst;
                tr_ sub { td_ style => 'text-align: center', 'Nothing to report! (heh)' } if !@$lst;
            };
        };
        paginate_ \&url, $opt->{p}, [$cnt, 50], 'b';
    };
};


TUWF::post qr{/report/edit}, sub {
    return tuwf->resDenied if !auth->isMod;
    my $frm = tuwf->validate(post =>
        id      => { id => 1 },
        url     => { regex => qr{^/report/list} },
        status  => { enum => \@STATUS },
        comment => { required => 0, default => '' },
    )->data;
    my $r = tuwf->dbRowi('SELECT id, status FROM reports WHERE id =', \$frm->{id});
    return tuwf->resNotFound if !$r->{id};

    my $log = join '; ',
        $r->{status} ne $frm->{status} ? "$r->{status} -> $frm->{status}" : (),
        $frm->{comment} ? $frm->{comment} : ();

    if($log) {
        $log = sprintf "%s <%s> %s\n", fmtdate(time, 'full'), auth->user->{user_name}, $log;
        tuwf->dbExeci('UPDATE reports SET lastmod = NOW(), status =', \$frm->{status}, ', log = log ||', \$log, 'WHERE id =', \$r->{id});
    }
    tuwf->resRedirect($frm->{url}, 'post');
};

1;
