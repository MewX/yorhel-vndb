package VNWeb::Misc::History;

use VNWeb::Prelude;


sub fetch {
    my($type, $id, $filt, $opt) = @_;

    my $where = sql_and
         !$type ? ()
         : $type eq 'u' ? sql 'c.requester =', \$id
         : sql_or(
            sql('c.type =', \$type, ' AND c.itemid =', \$id),

            # This may need an index on releases_vn_hist.vid
            $type eq 'v' && $filt->{r} ?
                sql 'c.id IN(SELECT chid FROM releases_vn_hist WHERE vid =', \$id, ')' : ()
         ),

         $filt->{t} && $filt->{t}->@* ? sql 'c.type IN', \$filt->{t} : (),
         $filt->{m} ? sql 'c.requester <> 1' : (),

         $filt->{e} && $filt->{e} == 1 ? sql 'c.rev <> 1' : (),
         $filt->{e} && $filt->{e} ==-1 ? sql 'c.rev = 1' : (),

         $filt->{h} ? sql $filt->{h} == 1 ? 'NOT' : '',
            'EXISTS(SELECT 1 FROM changes c_i
                WHERE c_i.type = c.type AND c_i.itemid = c.itemid AND c_i.ihid
                  AND c_i.rev = (SELECT MAX(c_ii.rev) FROM changes c_ii WHERE c_ii.type = c.type AND c_ii.itemid = c.itemid))' : ();

    my($lst, $np) = tuwf->dbPagei({ page => $filt->{p}, results => $opt->{results}||50 }, q{
        SELECT c.id, c.type, c.itemid, c.comments, c.rev,}, sql_totime('c.added'), q{ AS added
             , c.requester, u.username
          FROM changes c
          JOIN users u ON c.requester = u.id
         WHERE}, $where, q{
         ORDER BY c.id DESC
    });

    # Fetching the titles in a separate query is faster, for some reason.
    enrich_merge id => sql(q{
        SELECT id, title, original FROM (
                      SELECT chid, title, original FROM vn_hist
            UNION ALL SELECT chid, title, original FROM releases_hist
            UNION ALL SELECT chid, name,  original FROM producers_hist
            UNION ALL SELECT chid, name,  original FROM chars_hist
            UNION ALL SELECT chid, title, '' AS original FROM docs_hist
            UNION ALL SELECT sh.chid, name, original FROM staff_hist sh JOIN staff_alias_hist sah ON sah.chid = sh.chid AND sah.aid = sh.aid
                ) t(id, title, original)
        WHERE id IN}), $lst;
    ($lst, $np)
}


sub _filturl {
    my($filt) = @_;
    return '?'.join '&', map {
        my $k = $_;
        ref $filt->{$k} ? map "$k=$_", sort $filt->{$k}->@* : "$k=$filt->{$k}"
    } sort keys %$filt;
}


# Also used by User::Page.
# %opt: nopage => 1/0, results => $num
sub tablebox_ {
    my($type, $id, $filt, %opt) = @_;

    my($lst, $np) = fetch $type, $id, $filt, \%opt;

    my sub url { _filturl {%$filt, p => $_} }

    paginate_ \&url, $filt->{p}, $np, 't' unless $opt{nopage};
    div_ class => 'mainbox browse history', sub {
        table_ class => 'stripe', sub {
            thead_ sub { tr_ sub {
                td_ class => 'tc1_1', 'Rev.';
                td_ class => 'tc1_2', '';
                td_ class => 'tc2', 'Date';
                td_ class => 'tc3', 'User';
                td_ class => 'tc4', sub { txt_ 'Page'; debug_ $lst; };
            }};
            tr_ sub {
                my $i = $_;
                my $revurl = "/$i->{type}$i->{itemid}.$i->{rev}";

                td_ class => 'tc1_1', sub { a_ href => $revurl, "$i->{type}$i->{itemid}" };
                td_ class => 'tc1_2', sub { a_ href => $revurl, ".$i->{rev}" };
                td_ class => 'tc2', fmtdate $i->{added}, 'full';
                td_ class => 'tc3', sub { user_ $i->{requester}, $i->{username} };
                td_ class => 'tc4', sub {
                    a_ href => $revurl, title => $i->{original}, shorten $i->{title}, 80;
                    b_ class => 'grayedout', sub { lit_ bb2html $i->{comments}, 150 };
                };
            } for @$lst;
        };
    };
    paginate_ \&url, $filt->{p}, $np, 'b' unless $opt{nopage};
}


sub filters_ {
    my($type) = @_;

    my @types = (
        [ v => 'Visual novels' ],
        [ r => 'Releases' ],
        [ p => 'Producers' ],
        [ s => 'Staff' ],
        [ c => 'Characters' ],
        [ d => 'Docs' ]
    );

    state $schema = tuwf->compile({ type => 'hash', keys => {
        # Types
        t => { type => 'array', scalar => 1, required => 0, default => [map $_->[0], @types], values => { enum => [(map $_->[0], @types), 'a'] } },
        m => { required => 0, enum => [ 0, 1 ] },  # Automated edits
        h => { required => 0, default => 0, enum => [ -1..1 ] }, # Hidden items
        e => { required => 0, default => 0, enum => [ -1..1 ] }, # Existing/new items
        r => { required => 0, default => 0, enum => [ 0, 1 ] },  # Include releases
        p => { page => 1 },
    }});
    my $filt = eval { tuwf->validate(get => $schema)->data } || tuwf->pass;

    $filt->{m} //= $type ? 0 : 1; # Exclude automated edits by default on the main 'recent changes' view.

    # For compat with old URLs, 't=a' means "everything except characters". Let's also weed out duplicates
    my %t = map +($_, 1), map $_ eq 'a' ? (qw|v r p s d|) : ($_), $filt->{t}->@*;
    $filt->{t} = keys %t == @types ? [] : [ keys %t ];

    # Not all filters apply everywhere
    delete @{$filt}{qw/ t e h /} if $type && $type ne 'u';
    delete $filt->{m} if $type eq 'u';
    delete $filt->{r} if $type ne 'v';

    my sub opt_ {
        my($key, $val, $label) = @_;
        input_ type => 'radio', name => $key, id => "form_${key}{$val}", value => $val,
            $filt->{$key} eq $val ? (checked => 'checked') : ();
        label_ for => "form_${key}{$val}", $label;
    };

    form_ method => 'get', action => tuwf->reqPath(), sub {
        table_ style => 'margin: 0 auto', sub { tr_ sub {
            td_ style => 'padding: 10px', sub {
                p_ class => 'linkradio', sub {
                    join_ \&br_, sub {
                        input_ type => 'checkbox', name => 't', value => $_->[0], id => "form_t$_->[0]", $t{$_->[0]}? (checked => 'checked') : ();
                        label_ for => "form_t$_->[0]", ' '.$_->[1]
                    }, @types;
                }
            } if exists $filt->{t};

            td_ style => 'padding: 10px', sub {
                p_ class => 'linkradio', sub {
                    opt_ e => 0, 'All'; em_ ' | ';
                    opt_ e => 1, 'Only changes to existing items'; em_ ' | ';
                    opt_ e =>-1, 'Only newly created items';
                } if exists $filt->{e};
                p_ class => 'linkradio', sub {
                    opt_ h => 0, 'All'; em_ ' | ';
                    opt_ h => 1, 'Only non-deleted items'; em_ ' | ';
                    opt_ h =>-1, 'Only deleted';
                } if exists $filt->{h};
                p_ class => 'linkradio', sub {
                    opt_ m => 0, 'Show'; em_ ' | ';
                    opt_ m => 1, 'Hide'; txt_ ' automated edits';
                } if exists $filt->{m};
                p_ class => 'linkradio', sub {
                    opt_ r => 0, 'Exclude'; em_ ' | ';
                    opt_ r => 1, 'Include'; txt_ ' releases';
                } if exists $filt->{r};
                input_ type => 'submit', class => 'submit', value => 'Update';
                debug_ $filt;
            };
        }};
    };
    $filt;
}


TUWF::get qr{/(?:([upvrcsd])([1-9]\d*)/)?hist} => sub {
    my($type, $id) = (tuwf->capture(1)||'', tuwf->capture(2));

    my sub dbitem {
        my($table, $title) = @_;
        tuwf->dbRowi('SELECT id,', $title, ' AS title, hidden AS entry_hidden, locked AS entry_locked FROM', $table, 'WHERE id =', \$id);
    };

    my $obj = !$type ? undef :
        $type eq 'u' ? tuwf->dbRowi('SELECT id, username AS title FROM users WHERE id =', \$id) :
        $type eq 'p' ? dbitem producers => 'name' :
        $type eq 'v' ? dbitem vn        => 'title' :
        $type eq 'r' ? dbitem releases  => 'title' :
        $type eq 'c' ? dbitem chars     => 'name' :
        $type eq 's' ? dbitem staff     => '(SELECT name FROM staff_alias WHERE aid = staff.aid)' :
        $type eq 'd' ? dbitem docs      => 'title' : die;

    return tuwf->resNotFound if $type && !$obj->{id};

    my $title = $type ? "Edit history of $obj->{title}" : 'Recent changes';
    framework_ title => $title, index => 0, type => $type, dbobj => $obj, tab => 'hist',
    sub {
        my $filt;
        div_ class => 'mainbox', sub {
            h1_ $title;
            $filt = filters_ $type;
        };
        tablebox_ $type, $id, $filt;
    };
};

1;
