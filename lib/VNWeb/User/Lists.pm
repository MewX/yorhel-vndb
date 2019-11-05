package VNWeb::User::Lists;

use VNWeb::Prelude;



my $LABELS = form_compile any => {
    uid => { id => 1 },
    labels => { aoh => {
        id      => { int => 1 },
        label   => { maxlength => 50 },
        private => { anybool => 1 },
        count   => { uint => 1 },
        delete  => { required => 0, default => undef, uint => 1, range => [1, 3] }, # 1=keep vns, 2=delete when no other label, 3=delete all
    } }
};

elm_form 'UListManageLabels', undef, $LABELS;

json_api qr{/u/ulist/labels.json}, $LABELS, sub {
    my($uid, $labels) = ($_[0]{uid}, $_[0]{labels});
    return elm_Unauth if !auth || auth->uid != $uid;

    # Insert new labels
    my @new = grep $_->{id} < 0 && !$_->{delete}, @$labels;
    # Subquery to get the lowest unused id
    my $newid = sql '(
        SELECT min(x.n)
         FROM generate_series(10,
                greatest((SELECT max(id)+1 from ulist_labels ul WHERE ul.uid =', \$uid, '), 10)
              ) x(n)
        WHERE NOT EXISTS(SELECT 1 FROM ulist_labels ul WHERE ul.uid =', \$uid, 'AND ul.id = x.n)
    )';
    tuwf->dbExeci(
        'INSERT INTO ulist_labels (id, uid, label, private)
         VALUES (', sql_comma($newid, \$uid, \$_->{label}, \$_->{private}), ')'
    ) for @new;

    # Update private flag
    tuwf->dbExeci(
        'UPDATE ulist_labels SET private =', \$_->{private},
         'WHERE uid =', \$uid, 'AND id =', \$_->{id}, 'AND private <>', \$_->{private}
    ) for grep $_->{id} > 0 && !$_->{delete}, @$labels;

    # Update label
    tuwf->dbExeci(
        'UPDATE ulist_labels SET label =', \$_->{label},
         'WHERE uid =', \$uid, 'AND id =', \$_->{id}, 'AND label <>', \$_->{label}
    ) for grep $_->{id} >= 10 && !$_->{delete}, @$labels;

    # Delete labels
    my @delete = grep $_->{id} >= 10 && $_->{delete}, @$labels;
    my @delete_lblonly = map $_->{id}, grep $_->{delete} == 1, @delete;
    my @delete_empty   = map $_->{id}, grep $_->{delete} == 2, @delete;
    my @delete_all     = map $_->{id}, grep $_->{delete} == 3, @delete;

    # delete vns with: (a label in option 3) OR ((a label in option 2) AND (no labels other than in option 1 or 2))
    my @where =
        @delete_all ? sql('vid IN(SELECT vid FROM ulist_vns_labels WHERE uid =', \$uid, 'AND lbl IN', \@delete_all, ')') : (),
        @delete_empty ? sql(
                'vid IN(SELECT vid FROM ulist_vns_labels WHERE uid =', \$uid, 'AND lbl IN', \@delete_empty, ')',
            'AND NOT EXISTS(SELECT 1 FROM ulist_vns_labels WHERE uid =', \$uid, 'AND lbl NOT IN(', [ @delete_lblonly, @delete_empty ], '))'
        ) : ();
    tuwf->dbExeci('DELETE FROM ulist_vns WHERE uid =', \$uid, 'AND (', sql_or(@where), ')') if @where;

    # (This will also delete all relevant vn<->label rows from ulist_vns_labels)
    tuwf->dbExeci('DELETE FROM ulist_labels WHERE uid =', \$uid, 'AND id IN', [ map $_->{id}, @delete ]) if @delete;

    elm_Success
};




my $VNVOTE = form_compile any => {
    uid  => { id => 1 },
    vid  => { id => 1 },
    vote => { vnvote => 1 },
};

elm_form 'UListVoteEdit', undef, $VNVOTE;

json_api qr{/u/ulist/setvote.json}, $VNVOTE, sub {
    my($data) = @_;
    return elm_Unauth if !auth || auth->uid != $data->{uid};
    tuwf->dbExeci(
        'UPDATE ulist_vns
            SET vote =', \$data->{vote},
             ', vote_date = CASE WHEN', \$data->{vote}, '::smallint IS NULL THEN NULL WHEN vote IS NULL THEN NOW() ELSE vote_date END
          WHERE uid =', \$data->{uid}, 'AND vid =', \$data->{vid}
    );
    elm_Success
};




my $VNLABELS = {
    uid      => { id => 1 },
    vid      => { id => 1 },
    label    => { _when => 'in', id => 1 },
    applied  => { _when => 'in', anybool => 1 },
    labels   => { _when => 'out', aoh => { id => { int => 1 }, label => {}, private => { anybool => 1 } } },
    selected => { _when => 'out', type => 'array', values => { id => 1 } },
};

my $VNLABELS_OUT = form_compile out => $VNLABELS;
my $VNLABELS_IN  = form_compile in  => $VNLABELS;

elm_form 'UListLabelEdit', $VNLABELS_OUT, $VNLABELS_IN;

json_api qr{/u/ulist/setlabel.json}, $VNLABELS_IN, sub {
    my($data) = @_;
    return elm_Unauth if !auth || auth->uid != $data->{uid};
    die "Attempt to set vote label" if $data->{label} == 7;

    tuwf->dbExeci(
        'DELETE FROM ulist_vns_labels
          WHERE uid =', \$data->{uid}, 'AND vid =', \$data->{vid}, 'AND lbl =', \$data->{label}
    ) if !$data->{applied};
    tuwf->dbExeci(
        'INSERT INTO ulist_vns_labels (uid, vid, lbl)
         VALUES (', sql_comma(\$data->{uid}, \$data->{vid}, \$data->{label}), ')
             ON CONFLICT (uid, vid, lbl) DO NOTHING'
    ) if $data->{applied};

    elm_Success
};




my $VNDATE = form_compile any => {
    uid   => { id => 1 },
    vid   => { id => 1 },
    date  => { required => 0, default => '', regex => qr/^(?:19[7-9][0-9]|20[0-9][0-9])-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])$/ }, # 1970 - 2099 for sanity
    start => { anybool => 1 }, # Field selection, started/finished
};

elm_form 'UListDateEdit', undef, $VNDATE;

json_api qr{/u/ulist/setdate.json}, $VNDATE, sub {
    my($data) = @_;
    return elm_Unauth if !auth || auth->uid != $data->{uid};
    tuwf->dbExeci(
        'UPDATE ulist_vns SET lastmod = NOW(), ', $data->{start} ? 'started' : 'finished', '=', \($data->{date}||undef),
         'WHERE uid =', \$data->{uid}, 'AND vid =', \$data->{vid}
    );
    elm_Success
};




my $VNOPT = form_compile any => {
    own   => { anybool => 1 },
    uid   => { id => 1 },
    vid   => { id => 1 },
    notes => {},
    rels  => { aoh => {
        id       => { id => 1 },
        title    => {},
        original => {},
        released => { uint => 1 },
        rtype    => {},
        status   => { uint => 1 },
        lang     => { type => 'array', values => {} },
    } },
};

elm_form 'UListVNOpt', $VNOPT, undef;




my $VNNOTES = form_compile any => {
    uid   => { id => 1 },
    vid   => { id => 1 },
    notes => { required => 0, default => '', maxlength => 2000 },
};

elm_form 'UListVNNotes', undef, $VNNOTES;

json_api qr{/u/ulist/setnote.json}, $VNNOTES, sub {
    my($data) = @_;
    return elm_Unauth if !auth || auth->uid != $data->{uid};
    tuwf->dbExeci(
        'UPDATE ulist_vns SET lastmod = NOW(), notes = ', \$data->{notes},
         'WHERE uid =', \$data->{uid}, 'AND vid =', \$data->{vid}
    );
    elm_Success
};




my $VNDEL = form_compile any => {
    uid => { id => 1 },
    vid => { id => 1 },
};

elm_form 'UListDel', undef, $VNDEL;

json_api qr{/u/ulist/del.json}, $VNDEL, sub {
    my($data) = @_;
    return elm_Unauth if !auth || auth->uid != $data->{uid};
    tuwf->dbExeci('DELETE FROM ulist_vns WHERE uid =', \$data->{uid}, 'AND vid =', \$data->{vid});
    elm_Success
};




# TODO: Filters to find unlabeled VNs or VNs with/without notes?
sub filters_ {
    my($own, $labels) = @_;

    my $opt = eval { tuwf->validate(get =>
        p => { upage => 1 },
        l => { type => 'array', scalar => 1, required => 0, default => [], values => { id => 1 } },
        s => { required => 0, default => 'title', enum => [qw[ title vote added started finished ]] },
        o => { required => 0, default => 'a', enum => ['a', 'd'] },
    )->data } || { p => 1, l => [], s => 'title', o => 'a' };

    # $labels only includes labels we are allowed to see, getting rid of any labels in 'l' that aren't in $labels ensures we only filter on visible labels
    my %accessible_labels = map +($_->{id}, 1), @$labels;
    my %opt_l = map +($_, 1), grep $accessible_labels{$_}, $opt->{l}->@*;
    %opt_l = %accessible_labels if !keys %opt_l;
    $opt->{l} = keys %opt_l == keys %accessible_labels ? [] : [ sort keys %opt_l ];


    my sub lblfilt_ {
        input_ type => 'checkbox', name => 'l', value => $_->{id}, id => "form_l$_->{id}", $opt_l{$_->{id}} ? (checked => 'checked') : ();
        label_ for => "form_l$_->{id}", "$_->{label} ";
        txt_ " ($_->{count})" if !$_->{private};
        b_ class => 'grayedout', " ($_->{count})" if $_->{private};
    }

    form_ method => 'get', sub {
        p_ class => 'labelfilters', sub {
            span_ class => 'linkradio', sub {
                join_ sub { em_ ' / ' }, \&lblfilt_, grep $_->{id} < 10, @$labels;
                em_ ' | ';
                input_ type => 'checkbox', name => 'l', class => 'checkall', value => 0, id => 'form_l_all', $opt->{l}->@* == 0 ? (checked => 'checked') : ();
                label_ for => 'form_l_all', 'Select all';
                debug_ $labels;
            };
            my @cust = grep $_->{id} >= 10, @$labels;
            if(@cust) {
                br_;
                span_ class => 'linkradio', sub {
                    join_ sub { em_ ' / ' }, \&lblfilt_, @cust;
                }
            }
            br_;
            input_ type => 'submit', class => 'submit', value => 'Update filters';
            input_ type => 'button', class => 'submit', id => 'managelabels', value => 'Manage labels' if $own;
        };
    };
    $opt;
}


sub vn_ {
    my($uid, $own, $n, $v, $labels) = @_;
    tr_ mkclass(odd => $n % 2 == 0), id => "ulist_tr_$v->{id}", sub {
        my %labels = map +($_,1), $v->{labels}->@*;

        td_ class => 'tc1', sub {
            input_ type => 'checkbox', class => 'checkhidden', name => 'collapse_vid', id => 'collapse_vid'.$v->{id}, value => 'collapsed_vid'.$v->{id};
            label_ for => 'collapse_vid'.$v->{id}, sub {
                my $obtained = grep $_->{status} == 2, $v->{rels}->@*;
                my $total = $v->{rels}->@*;
                my $txt = sprintf '%d/%d', $obtained, $total;
                if($total && $obtained == $total) { b_ class => 'done', $txt }
                elsif($obtained < $total)         { b_ class => 'todo', $txt }
                else                              { txt_ $txt }
                span_ id => 'ulist_noteflag_'.$v->{id}, mkclass(blurred => !$v->{notes}), ' 💬';
                if($own) {
                    my $public = List::Util::any { $labels{$_->{id}} && !$_->{private} } @$labels;
                    my $publicLabel = List::Util::any { $_->{id} != 7 && $labels{$_->{id}} && !$_->{private} } @$labels;
                    span_ mkclass(invisible => !$public),
                          id              => 'ulist_public_'.$v->{id},
                          'data-publabel' => !!$publicLabel,
                          'data-voted'    => !!$labels{7},
                          title           => 'This item is public', ' 👁';
                }
            };
        };
        td_ class => 'tc2', sub {
            a_ href => "/v$v->{id}", title => $v->{original}||$v->{title}, shorten $v->{title}, 70;
            b_ class => 'grayedout', id => 'ulist_notes_'.$v->{id}, $v->{notes} if $v->{notes} || $own;
        };
        td_ class => 'tc3', sub {
            my @l = grep $labels{$_->{id}} && $_->{id} != 7, @$labels;
            my $txt = @l ? join ', ', map $_->{label}, @l : '-';
            if($own) {
                elm_ 'UList.LabelEdit' => $VNLABELS_OUT, { vid => $v->{id}, selected => [ grep $_ != 7, $v->{labels}->@* ] }, $txt;
            } else {
                txt_ $txt;
            }
        };
        td_ mkclass(tc4 => 1, compact => $own, stealth => $own), sub {
            txt_ fmtvote $v->{vote} if !$own;
            elm_ 'UList.VoteEdit' => $VNVOTE, { uid => $uid, vid => $v->{id}, vote => fmtvote($v->{vote}) }, fmtvote $v->{vote} if $own;
        };
        td_ class => 'tc5', fmtdate $v->{added}, 'compact';
        td_ class => 'tc6', sub {
            txt_ $v->{started}||'' if !$own;
            elm_ 'UList.DateEdit' => $VNDATE, { uid => $uid, vid => $v->{id}, date => $v->{started}||'', start => 1 }, $v->{started}||'' if $own;
        };
        td_ class => 'tc7', sub {
            txt_ $v->{finished}||'' if !$own;
            elm_ 'UList.DateEdit' => $VNDATE, { uid => $uid, vid => $v->{id}, date => $v->{finished}||'', start => 0 }, $v->{finished}||'' if $own;
        };
    };

    tr_ mkclass(hidden => 1, 'collapsed_vid'.$v->{id} => 1, odd => $n % 2 == 0), sub {
        td_ colspan => 7, class => 'tc_opt', sub {
            elm_ 'UList.Opt' => $VNOPT, { own => $own, uid => $uid, vid => $v->{id}, notes => $v->{notes}, rels => $v->{rels} };
        };
    };
}


sub listing_ {
    my($uid, $own, $opt, $labels) = @_;

    my $where = sql_and
        sql('ul.uid =', \$uid),
        $opt->{l}->@* ? sql('ul.vid IN(SELECT vid FROM ulist_vns_labels WHERE uid =', \$uid, 'AND lbl IN', $opt->{l}, ')') :
                !$own ? sql('ul.vid IN(SELECT vid FROM ulist_vns_labels WHERE uid =', \$uid, 'AND lbl IN(SELECT id FROM ulist_labels WHERE uid =', \$uid, 'AND NOT private))') : ();

    my $count = tuwf->dbVali('SELECT count(*) FROM ulist_vns ul WHERE', $where);

    my($lst) = tuwf->dbPagei({ page => $opt->{p}, results => 50 },
        'SELECT v.id, v.title, v.original, ul.vote, ul.notes, ul.started, ul.finished
              ,', sql_totime('ul.added'), ' as added
              ,', sql_totime('ul.lastmod'), ' as lastmod
              ,', sql_totime('ul.vote_date'), ' as vote_date
           FROM ulist_vns ul
           JOIN vn v ON v.id = ul.vid
          WHERE', $where, '
          ORDER BY', {
                    title    => 'v.title',
                    vote     => 'ul.vote',
                    added    => 'ul.added',
                    started  => 'ul.started',
                    finished => 'ul.finished'
                }->{$opt->{s}}, $opt->{o} eq 'd' ? 'DESC' : 'ASC', 'NULLS LAST, v.title'
    );

    enrich_flatten labels => id => vid => sql('SELECT vid, lbl FROM ulist_vns_labels WHERE uid =', \$uid, 'AND vid IN'), $lst;

    enrich rels => id => vid => sub { sql '
        SELECT rv.vid, r.id, r.title, r.original, r.released, r.type as rtype, rl.status
          FROM rlists rl
          JOIN releases r ON rl.rid = r.id
          JOIN releases_vn rv ON rv.id = r.id
         WHERE rl.uid =', \$uid, '
           AND rv.vid IN', $_, '
         ORDER BY r.released ASC'
    }, $lst;

    enrich_flatten lang => id => id => sub { sql('SELECT id, lang FROM releases_lang WHERE id IN', $_, 'ORDER BY lang') }, map $_->{rels}, @$lst;

    my sub url { '?'.query_encode %$opt, @_ }

    # TODO: Thumbnail view?
    paginate_ \&url, $opt->{p}, [ $count, 50 ], 't';
    div_ class => 'mainbox browse ulist', sub {
        table_ sub {
            thead_ sub { tr_ sub {
                td_ class => 'tc1', sub {
                    input_ type => 'checkbox', class => 'checkall', name => 'collapse_vid', id => 'collapse_vid';
                    label_ for => 'collapse_vid', sub { txt_ 'Opt' };
                };
                td_ class => 'tc2', sub { txt_ 'Title';      sortable_ 'title',    $opt, \&url; debug_ $lst };
                td_ class => 'tc3', 'Labels';
                td_ class => 'tc4', sub { txt_ 'Vote';       sortable_ 'vote',     $opt, \&url };
                td_ class => 'tc5', sub { txt_ 'Added';      sortable_ 'added',    $opt, \&url };
                td_ class => 'tc6', sub { txt_ 'Start date'; sortable_ 'started',  $opt, \&url };
                td_ class => 'tc7', sub { txt_ 'Finish date';sortable_ 'finished', $opt, \&url };
            }};
            vn_ $uid, $own, $_, $lst->[$_], $labels for (0..$#$lst);
        };
    };
    paginate_ \&url, $opt->{p}, [ $count, 50 ], 'b';
}


# TODO: Display something useful when all labels are private?
# TODO: Ability to add VNs from this page
TUWF::get qr{/$RE{uid}/ulist}, sub {
    my $u = tuwf->dbRowi('SELECT id,', sql_user(), 'FROM users u WHERE id =', \tuwf->capture('id'));
    return tuwf->resNotFound if !$u->{id};

    my $own = auth && $u->{id} == auth->uid;
    my $labels = tuwf->dbAlli(
        'SELECT l.id, l.label, l.private, count(vl.vid) as count, null as delete
           FROM ulist_labels l LEFT JOIN ulist_vns_labels vl ON vl.uid = l.uid AND vl.lbl = l.id
          WHERE', { 'l.uid' => $u->{id}, $own ? () : ('l.private' => 0) },
         'GROUP BY l.id, l.label, l.private
          ORDER BY CASE WHEN l.id < 10 THEN l.id ELSE 10 END, l.label'
    );

    my $title = $own ? 'My list' : user_displayname($u)."'s list";
    framework_ title => $title, type => 'u', dbobj => $u, tab => 'list',
        $own ? ( pagevars => {
            uid         => $u->{id}*1,
            labels      => $LABELS->analyze->{keys}{labels}->coerce_for_json($labels),
            voteprivate => (map \($_->{private}?1:0), grep $_->{id} == 7, @$labels),
        } ) : (),
    sub {
        my $opt;
        div_ class => 'mainbox', sub {
            h1_ $title;
            $opt = filters_ $own, $labels;
            elm_ 'UList.ManageLabels' if $own;
        };
        listing_ $u->{id}, $own, $opt, $labels;
    };
};

1;