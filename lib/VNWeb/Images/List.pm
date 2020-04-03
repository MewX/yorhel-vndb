package VNWeb::Images::List;

use VNWeb::Prelude;

sub listing_ {
    my($lst, $np, $opt, $url) = @_;

    sub rednum_ {
        my $d = sprintf $_[1]||'%4.2f', $_[0];
        $_[0] >= 0.5 || $_[0] <= -0.5 ? b_ class => 'standout', $d : $_[0] == 0 ? b_ class => 'grayedout', $d : txt_ $d;
    }

    # TODO: Display a histogram or something rather than all those numbers.

    paginate_ $url, $opt->{p}, $np, 't';
    div_ class => 'mainbox imagebrowse', sub {
        div_ class => 'imagecard', sub {
            my $id = $_->{id} =~ s/[^a-z0-9]+//gr;
            a_ href => "/img/$id", style => 'background-image: url('.tuwf->imgurl($_->{id}, 1).')', '';
            div_ sub {
                a_ href => "/img/$id", $id;
                txt_ ' / ';
                a_ href => tuwf->imgurl($_->{id}), "$_->{width}x$_->{height}";
                br_;
                txt_ sprintf '#%d', $_->{c_votecount},;
                b_ class => 'grayedout', sprintf ' w%.1f', $_->{c_weight};
                dl_ sub {
                    if(defined $_->{c_sexual_avg}) {
                        dt_ 'S:';
                        dd_ sub { txt_ sprintf '%4.2f σ ', $_->{c_sexual_avg}; rednum_ $_->{c_sexual_stddev} };
                        dt_ 'V:';
                        dd_ sub { txt_ sprintf '%4.2f σ ', $_->{c_violence_avg}; rednum_ $_->{c_violence_stddev} };
                    }
                    if(defined $_->{user_sexual}) {
                        dt_ 'User:';
                        dd_ sub {
                            txt_ sprintf 'S%d', $_->{user_sexual}; rednum_ $_->{user_sexual}-$_->{c_sexual_avg}, '%+4.2f';
                            txt_ sprintf ' V%d', $_->{user_violence}; rednum_ $_->{user_violence}-$_->{c_violence_avg}, '%+4.2f';
                        }
                    }
                    if(defined $_->{my_sexual} && $opt->{u} != $opt->{u2}) {
                        dt_ 'My';
                        dd_ sub {
                            txt_ sprintf 'S%d', $_->{my_sexual}; rednum_ $_->{my_sexual}-$_->{c_sexual_avg}, '%+4.2f';
                            txt_ sprintf ' V%d', $_->{my_violence}; rednum_ $_->{my_violence}-$_->{c_violence_avg}, '%+4.2f';
                        }
                    }
                }
            };
        } for @$lst;
    };
    paginate_ $url, $opt->{p}, $np, 'b';
}


sub opts_ {
    my($opt) = @_;

    my sub opt_ {
        my($type, $key, $val, $label, $checked) = @_;
        input_ type => $type, name => $key, id => "form_${key}{$val}", value => $val,
            $checked // $opt->{$key} eq $val ? (checked => 'checked') : ();
        label_ for => "form_${key}{$val}", $label;
    };

    form_ sub {
        input_ type => 'hidden', class => 'hidden', name => 'u', value => $opt->{u};
        input_ type => 'hidden', class => 'hidden', name => 'u2', value => $opt->{u2} if $opt->{u2} != auth->uid;
        p_ class => 'center', sub {
            span_ class => 'linkradio', sub {
                txt_ 'Image types: ';
                opt_ checkbox => t => 'ch', 'Character images', $opt->{t}->@* == 0 || in ch => $opt->{t}; em_ ' / ';
                opt_ checkbox => t => 'cv', 'VN images',        $opt->{t}->@* == 0 || in cv => $opt->{t}; em_ ' / ';
                opt_ checkbox => t => 'sf', 'Screenshots',      $opt->{t}->@* == 0 || in sf => $opt->{t};
                br_;
                txt_ 'Minimum votes: ';
                join_ sub { em_ ' / ' }, sub { opt_ radio => m => $_, $_ }, 0..10;
                br_;
                if($opt->{u} != $opt->{u2}) {
                    opt_ checkbox => my => 1, 'Only images I voted on';
                    br_;
                }
                txt_ 'Order by: ';
                if($opt->{u}) {
                    opt_ radio => s => 'date', 'Recent'; em_ ' / ';
                    if(auth->permDbmod) { # XXX: Hidden for regular users to discourage people from adjusting their votes to the average
                        opt_ radio => s => 'diff', 'Vote difference'; em_ ' / '; 
                    }
                }
                opt_ radio => s => 'weight', 'Weight'; em_ ' / ';
                opt_ radio => s => 'sdev', 'Sexual stddev'; em_ ' / ';
                opt_ radio => s => 'vdev', 'Violence stddev';
                br_;
            };
            input_ type => 'submit', class => 'submit', value => 'Update';
        };
    };
}


TUWF::get qr{/img/list}, sub {
    return tuwf->resDenied if !auth->permImgvote || !tuwf->samesite;

    # TODO filters: sexual / violence?
    my $opt = tuwf->validate(get =>
        s  => { onerror => 'date', enum => [qw/ weight sdev vdev date diff/] },
        t  => { onerror => [], scalar => 1, type => 'array', values => { enum => [qw/ ch cv sf /] } },
        m  => { onerror => 0, range => [0,10] },
        u  => { onerror => 0, id => 1 },
        u2 => { onerror => 0, id => 1 }, # Hidden option, allows comparing two users by overriding the 'My' user.
        my => { anybool => 1 },
        p  => { page => 1 },
    )->data;

    $opt->{u2} ||= auth->uid;
    $opt->{s} = 'weight' if !$opt->{u} && ($opt->{s} eq 'date' || $opt->{s} eq 'diff');
    $opt->{s} = 'weight' if $opt->{s} eq 'diff' && !auth->permDbmod;
    $opt->{t} = [ List::Util::uniq sort $opt->{t}->@* ];
    $opt->{t} = [] if $opt->{t}->@* == 3;

    my $u = $opt->{u} && tuwf->dbRowi(select => sql_user() => 'from users u where id =', \$opt->{u});
    return tuwf->resNotFound if $opt->{u} && !$u->{user_id};

    my $where = sql_and
        $opt->{t}->@* ? sql('(i.id).itype IN', $opt->{t}) : (),
        $opt->{m} ? sql('i.c_votecount >', \$opt->{m}) : ();

    my($lst, $np) = tuwf->dbPagei({ results => 100, page => $opt->{p} }, '
        SELECT i.id, i.width, i.height, i.c_votecount, i.c_weight
             , i.c_sexual_avg, i.c_sexual_stddev, i.c_violence_avg, i.c_violence_stddev
             , iv.sexual as my_sexual, iv.violence as my_violence',
          $opt->{u} ? ', iu.sexual as user_sexual, iu.violence as user_violence' : (), '
          FROM images i',
          $opt->{u} ? ('JOIN image_votes iu ON iu.uid =', \$opt->{u}, ' AND iu.id = i.id') : (),
          $opt->{my} ? () : 'LEFT', 'JOIN image_votes iv ON iv.uid =', \$opt->{u2}, ' AND iv.id = i.id
         WHERE', $where, '
         ORDER BY', {
             weight => 'i.c_weight DESC',
             sdev   => 'i.c_sexual_stddev DESC NULLS LAST',
             vdev   => 'i.c_violence_stddev DESC NULLS LAST',
             date   => 'iu.date DESC',
             diff   => 'abs(iu.sexual-i.c_sexual_avg) + abs(iu.violence-i.c_violence_avg) DESC',
         }->{$opt->{s}}, ', i.id'
    );

    my sub url { '?'.query_encode %$opt, @_ }

    my $title = $u ? 'Images flagged by '.user_displayname($u) : 'Image browser';

    framework_ title => $title, sub {
        div_ class => 'mainbox', sub {
            h1_ $title;
            opts_ $opt;
        };
        listing_ $lst, $np, $opt, \&url if @$lst;
    };
};

1;
