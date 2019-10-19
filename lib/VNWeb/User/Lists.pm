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


# TODO: Keep this URL? Steal /u+/list when that one's gone?
TUWF::get qr{/$RE{uid}/ulist}, sub {
    my $u = tuwf->dbRowi('SELECT id,', sql_user(), 'FROM users u WHERE id =', \tuwf->capture('id'));
    return tuwf->resNotFound if !$u->{id};

    my $own = auth && $u->{id} == auth->uid;
    my $labels = tuwf->dbAlli(
        'SELECT l.id, l.label, l.private, count(vl.vid) as count, null as delete
           FROM ulists_labels l LEFT JOIN ulists_vn_labels vl ON vl.uid = l.uid AND vl.lbl = l.id
          WHERE', { 'l.uid' => $u->{id}, $own ? () : ('l.private' => 0) },
         'GROUP BY l.id, l.label, l.private
          ORDER BY CASE WHEN l.id < 1000 THEN l.id ELSE 1000 END, l.label'
    );

    my sub lblfilt_ {
        input_ type => 'checkbox', name => 'l', value => $_->{id}, id => "form_l$_->{id}", 0 ? (checked => 'checked') : ();
        label_ for => "form_l$_->{id}", "$_->{label} ";
        txt_ " ($_->{count})" if !$_->{private};
        b_ class => 'grayedout', " ($_->{count})" if $_->{private};
    }

    my $title = $own ? 'My list' : user_displayname($u)."'s list";
    framework_ title => $title, type => 'u', dbobj => $u, tab => 'list',
    sub {
        div_ class => 'mainbox', sub {
            h1_ $title;
            form_ method => 'get', sub {
                p_ class => 'labelfilters', sub {
                    span_ class => 'linkradio', sub {
                        join_ sub { em_ ' / ' }, \&lblfilt_, grep $_->{id} < 1000, @$labels;
                        em_ ' | ';
                        input_ type => 'checkbox', name => 'l', class => 'checkall', value => 0, id => 'form_l_all';
                        label_ for => 'form_l_all', 'Select all';
                        debug_ $labels;
                    };
                    my @cust = grep $_->{id} >= 1000, @$labels;
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
            elm_ 'ULists.ManageLabels', $LABELS, { uid => $u->{id}, labels => $labels } if $own;
        }
    };
};


json_api qr{/u/ulist/labels.json}, $LABELS, sub {
    my($uid, $labels) = ($_[0]{uid}, $_[0]{labels});
    return elm_Unauth if !auth || auth->uid != $uid;

    # Insert new labels
    my @new = grep $_->{id} < 0 && !$_->{delete}, @$labels;
    tuwf->dbExeci(
        'INSERT INTO ulists_labels (uid, label, private)',
        'VALUES ', sql_comma(
            map sql('(', sql_comma(\$uid, \$_->{label}, \$_->{private}), ')'), @new
        )
    ) if @new;

    # Update private flag
    tuwf->dbExeci(
        'UPDATE ulists_labels SET private =', \$_->{private},
         'WHERE uid =', \$uid, 'AND id =', \$_->{id}, 'AND private <>', \$_->{private}
    ) for grep $_->{id} > 0 && !$_->{delete}, @$labels;

    # Update label
    tuwf->dbExeci(
        'UPDATE ulists_labels SET label =', \$_->{label},
         'WHERE uid =', \$uid, 'AND id =', \$_->{id}, 'AND label <>', \$_->{label}
    ) for grep $_->{id} >= 1000 && !$_->{delete}, @$labels;

    # Delete labels
    my @delete = grep $_->{id} >= 1000 && $_->{delete}, @$labels;
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
