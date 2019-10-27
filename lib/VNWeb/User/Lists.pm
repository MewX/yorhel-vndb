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


elm_form 'ManageLabels', undef, $LABELS;


# TODO: Filters to find unlabeled VNs or VNs with notes?
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
            input_ type => 'button', class => 'submit', id => 'labeledit', value => 'Manage labels' if $own;
        };
    };
    $opt;
}


sub vn_ {
    my($n, $v, $labels) = @_;
    tr_ mkclass(odd => $n % 2 == 0), sub {
        td_ class => 'tc1', sub {
            input_ type => 'checkbox', class => 'checkhidden', name => 'collapse_vid', id => 'collapse_vid'.$v->{id}, value => 'collapsed_vid'.$v->{id};
            label_ for => 'collapse_vid'.$v->{id}, sub {
                my $obtained = grep $_->{status} == 2, $v->{rels}->@*;
                my $total = $v->{rels}->@*;
                my $txt = sprintf '%d/%d', $obtained, $total;
                if($total && $obtained == $total) { b_ class => 'done', $txt }
                elsif($obtained < $total)         { b_ class => 'todo', $txt }
                else                              { txt_ $txt }
            };
        };
        td_ class => 'tc2', sub {
            a_ href => "/v$v->{id}", title => $v->{original}||$v->{title}, shorten $v->{title}, 70;
            b_ class => 'grayedout', $v->{notes} if $v->{notes};
        };
        td_ class => 'tc3', sub {
            my %l = map +($_,1), $v->{labels}->@*;
            my @l = grep $l{$_->{id}} && $_->{id} != 7, @$labels;
            join_ ', ', sub { txt_ $_->{label} }, @l if @l;
            txt_ '-' if !@l;
        };
        td_ class => 'tc4', fmtvote $v->{vote};
        td_ class => 'tc5', fmtdate $v->{added}, 'compact';
        td_ class => 'tc6', $v->{started}||'';
        td_ class => 'tc7', $v->{finished}||'';
    };

    tr_ mkclass(hidden => 1, 'collapsed_vid'.$v->{id} => 1, odd => $n % 2 == 0), sub {
        td_ colspan => 7, 'Options, releases and note stuff here (likely Elm)';
    };
}


sub listing_ {
    my($uid, $own, $opt, $labels) = @_;

    my $where = sql_and
        sql('ul.uid =', \$uid),
        $opt->{l}->@* ? sql('ul.vid IN(SELECT vid FROM ulists_vn_labels WHERE uid =', \$uid, 'AND lbl IN', $opt->{l}, ')') :
                !$own ? sql('ul.vid IN(SELECT vid FROM ulists_vn_labels WHERE uid =', \$uid, 'AND lbl IN(SELECT id FROM ulists_labels WHERE uid =', \$uid, 'AND NOT private))') : ();

    my $count = tuwf->dbVali('SELECT count(*) FROM ulists ul WHERE', $where);

    my($lst) = tuwf->dbPagei({ page => $opt->{p}, results => 50 },
        'SELECT v.id, v.title, v.original, ul.vote, ul.notes, ul.started, ul.finished
              ,', sql_totime('ul.added'), ' as added
              ,', sql_totime('ul.lastmod'), ' as lastmod
              ,', sql_totime('ul.vote_date'), ' as vote_date
           FROM ulists ul
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

    enrich_flatten labels => id => vid => sql('SELECT vid, lbl FROM ulists_vn_labels WHERE uid =', \$uid, 'AND vid IN'), $lst;

    enrich rels => id => vid => sub { sql '
        SELECT rv.vid, r.id, r.title, r.original, r.released, r.type, rl.status
          FROM rlists rl
          JOIN releases r ON rl.rid = r.id
          JOIN releases_vn rv ON rv.id = r.id
         WHERE rl.uid =', \$uid, '
           AND rv.vid IN', $_, '
         ORDER BY r.released ASC'
    }, $lst;

    enrich_flatten lang => id => id => sub { sql('SELECT id, lang FROM releases_lang WHERE id IN', $_, 'ORDER BY lang') }, map $_->{rels}, @$lst;

    my sub url { '?'.query_encode %$opt, @_ }

    # TODO: In-line editable
    # TODO: Releases
    # TODO: Thumbnail view
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
                td_ class => 'tc7', sub { txt_ 'End date';   sortable_ 'finished', $opt, \&url };
            }};
            vn_ $_, $lst->[$_], $labels for (0..$#$lst);
        };
    };
    paginate_ \&url, $opt->{p}, [ $count, 50 ], 'b';
}


# TODO: Keep this URL? Steal /u+/list when that one's gone?
# TODO: Display something useful when all labels are private?
TUWF::get qr{/$RE{uid}/ulist}, sub {
    my $u = tuwf->dbRowi('SELECT id,', sql_user(), 'FROM users u WHERE id =', \tuwf->capture('id'));
    return tuwf->resNotFound if !$u->{id};

    my $own = auth && $u->{id} == auth->uid;
    my $labels = tuwf->dbAlli(
        'SELECT l.id, l.label, l.private, count(vl.vid) as count, null as delete
           FROM ulists_labels l LEFT JOIN ulists_vn_labels vl ON vl.uid = l.uid AND vl.lbl = l.id
          WHERE', { 'l.uid' => $u->{id}, $own ? () : ('l.private' => 0) },
         'GROUP BY l.id, l.label, l.private
          ORDER BY CASE WHEN l.id < 10 THEN l.id ELSE 10 END, l.label'
    );

    my $title = $own ? 'My list' : user_displayname($u)."'s list";
    framework_ title => $title, type => 'u', dbobj => $u, tab => 'list',
    sub {
        my $opt;
        div_ class => 'mainbox', sub {
            h1_ $title;
            $opt = filters_ $own, $labels;
            elm_ 'ULists.ManageLabels', $LABELS, { uid => $u->{id}, labels => $labels } if $own;
        };
        listing_ $u->{id}, $own, $opt, $labels;
    };
};


json_api qr{/u/ulist/labels.json}, $LABELS, sub {
    my($uid, $labels) = ($_[0]{uid}, $_[0]{labels});
    return elm_Unauth if !auth || auth->uid != $uid;

    # Insert new labels
    my @new = grep $_->{id} < 0 && !$_->{delete}, @$labels;
    # Subquery to get the lowest unused id
    my $newid = sql '(
        SELECT min(x.n)
         FROM generate_series(10,
                greatest((SELECT max(id)+1 from ulists_labels ul WHERE ul.uid =', \$uid, '), 10)
              ) x(n)
        WHERE NOT EXISTS(SELECT 1 FROM ulists_labels ul WHERE ul.uid =', \$uid, 'AND ul.id = x.n)
    )';
    tuwf->dbExeci(
        'INSERT INTO ulists_labels (id, uid, label, private)
         VALUES (', sql_comma($newid, \$uid, \$_->{label}, \$_->{private}), ')'
    ) for @new;

    # Update private flag
    tuwf->dbExeci(
        'UPDATE ulists_labels SET private =', \$_->{private},
         'WHERE uid =', \$uid, 'AND id =', \$_->{id}, 'AND private <>', \$_->{private}
    ) for grep $_->{id} > 0 && !$_->{delete}, @$labels;

    # Update label
    tuwf->dbExeci(
        'UPDATE ulists_labels SET label =', \$_->{label},
         'WHERE uid =', \$uid, 'AND id =', \$_->{id}, 'AND label <>', \$_->{label}
    ) for grep $_->{id} >= 10 && !$_->{delete}, @$labels;

    # Delete labels
    my @delete = grep $_->{id} >= 10 && $_->{delete}, @$labels;
    my @delete_lblonly = map $_->{id}, grep $_->{delete} == 1, @delete;
    my @delete_empty   = map $_->{id}, grep $_->{delete} == 2, @delete;
    my @delete_all     = map $_->{id}, grep $_->{delete} == 3, @delete;

    # delete vns with: (a label in option 3) OR ((a label in option 2) AND (no labels other than in option 1 or 2))
    my @where =
        @delete_all ? sql('vid IN(SELECT vid FROM ulists_vn_labels WHERE uid =', \$uid, 'AND lbl IN', \@delete_all, ')') : (),
        @delete_empty ? sql(
                'vid IN(SELECT vid FROM ulists_vn_labels WHERE uid =', \$uid, 'AND lbl IN', \@delete_empty, ')',
            'AND NOT EXISTS(SELECT 1 FROM ulists_vn_labels WHERE uid =', \$uid, 'AND lbl NOT IN(', [ @delete_lblonly, @delete_empty ], '))'
        ) : ();
    tuwf->dbExeci('DELETE FROM ulists WHERE uid =', \$uid, 'AND (', sql_or(@where), ')') if @where;

    # (This will also delete all relevant vn<->label rows from ulists_vn_labels)
    tuwf->dbExeci('DELETE FROM ulists_labels WHERE uid =', \$uid, 'AND id IN', [ map $_->{id}, @delete ]) if @delete;

    elm_Success
};

1;
