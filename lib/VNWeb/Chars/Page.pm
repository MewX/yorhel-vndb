package VNWeb::Chars::Page;

use VNWeb::Prelude;


sub enrich_seiyuu {
    my($vid, @chars) = @_;
    enrich seiyuu => id => cid => sub { sql '
        SELECT DISTINCT vs.cid, sa.id, sa.name, sa.original, vs.note
          FROM vn_seiyuu vs
          JOIN staff_alias sa ON sa.aid = vs.aid
         WHERE vs.cid IN', $_, $vid ? ('AND vs.id =', \$vid) : (), '
         ORDER BY sa.name'
    }, @chars;
}


sub enrich_image {
    enrich_obj image => id => 'SELECT id, width, height, c_votecount AS votecount, c_sexual_avg AS sexual_avg, c_violence_avg AS violence_avg FROM images WHERE id IN', @_;
}


sub enrich_item {
    my($c) = @_;

    enrich_image $c;
    enrich_merge vid => 'SELECT id AS vid, title, original FROM vn WHERE id IN', $c->{vns};
    enrich_merge rid => 'SELECT id AS rid, title AS rtitle, original AS roriginal FROM releases WHERE id IN', grep $_->{rid}, $c->{vns}->@*;
    enrich_merge tid =>
     'SELECT t.id AS tid, t.name, t.sexual, coalesce(g.id, t.id) AS group, coalesce(g.name, t.name) AS groupname, coalesce(g.order,0) AS order
        FROM traits t LEFT JOIN traits g ON t.group = g.id WHERE t.id IN', $c->{traits};

    $c->{vns}    = [ sort { $a->{title} cmp $b->{title} || $a->{vid} <=> $b->{vid} || ($a->{rid}||999999) <=> ($b->{rid}||999999) } $c->{vns}->@* ];
    $c->{traits} = [ sort { $a->{order} <=> $b->{order} || $a->{groupname} cmp $b->{groupname} || $a->{name} cmp $b->{name} } $c->{traits}->@* ];
}


# Fetch multiple character entries with a format suitable for chartable_()
# Also used by VN::Page
sub fetch_chars {
    my($vid, $where) = @_;
    my $l = tuwf->dbAlli('
        SELECT id, name, original, alias, "desc", gender, b_month, b_day, s_bust, s_waist, s_hip, height, weight, bloodt, cup_size, age, image
          FROM chars WHERE NOT hidden AND (', $where, ')
         ORDER BY name
    ');

    enrich vns => id => id => sub { sql '
        SELECT cv.id, cv.vid, cv.rid, cv.spoil, cv.role, v.title, v.original, r.title AS rtitle, r.original AS roriginal
          FROM chars_vns cv
          JOIN vn v ON v.id = cv.vid
          LEFT JOIN releases r ON r.id = cv.rid
         WHERE cv.id IN', $_, $vid ? ('AND cv.vid =', \$vid) : (), '
         ORDER BY v.title, cv.vid, cv.rid NULLS LAST'
    }, $l;

    enrich traits => id => id => sub { sql '
        SELECT ct.id, ct.tid, ct.spoil, t.name, t.sexual, coalesce(g.id, t.id) AS group, coalesce(g.name, t.name) AS groupname, coalesce(g.order,0) AS order
          FROM chars_traits ct
          JOIN traits t ON t.id = ct.tid
          LEFT JOIN traits g ON t.group = g.id
         WHERE ct.id IN', $_, '
         ORDER BY g.order NULLS FIRST, coalesce(g.name, t.name), t.name'
    }, $l;

    enrich_seiyuu $vid, $l;
    enrich_image $l;
    $l
}


# This and enrich_image() can prolly be used for VN cover images as well.
sub image_ {
    my($c) = @_;
    my $img = $c->{image};
    return p_ 'No image' if !$img;

    # XXX: no clue why I chose these thresholds.
    my $sex = $img->{sexual_avg}   > 1.3 ? 2 : $img->{sexual_avg}   > 0.4 ? 1 : 0 if $img->{votecount};
    my $vio = $img->{violence_avg} > 1.3 ? 2 : $img->{violence_avg} > 0.4 ? 1 : 0 if $img->{votecount};
    my $sexd = ['Safe', 'Suggestive', 'Explicit']->[$sex] if $img->{votecount};
    my $viod = ['Tame', 'Violent',    'Brutal'  ]->[$vio] if $img->{votecount};
    my $sexp = auth->pref('max_sexual')||0;
    my $viop = auth->pref('max_violence')||0;
    my $sexh = $sex > $sexp && $sexp >= 0 if $img->{votecount};
    my $vioh = $vio > $viop if $img->{votecount};
    my $hidden = $sexp < 0 || $sexh || $vioh || (!$img->{votecount} && ($sexp < 2 || $viop < 2));
    my $hide_on_click = $sexp < 0 || $sex || $vio || !$img->{votecount};

    label_ class => 'imghover', style => "width: $img->{width}px; height: $img->{height}px", sub {
        input_ type => 'checkbox', class => 'visuallyhidden', $hidden ? () : (checked => 'checked') if $hide_on_click;
        div_ class => 'imghover--visible', sub {
            img_ src => tuwf->imgurl($img->{id}), alt => $c->{name};
            a_ href => "/img/$img->{id}?view=".viewset(show_nsfw=>1),
                $img->{votecount} ? sprintf '%s / %s (%d)', $sexd, $viod, $img->{votecount} : 'Not flagged';
        };
        div_ class => 'imghover--warning', sub {
            if($img->{votecount}) {
                txt_ 'This image has been flagged as:';
                br_; br_;
                txt_ 'Sexual: '; $sexh ? b_ class => 'standout', $sexd : txt_ $sexd;
                br_;
                txt_ 'Violence '; $vioh ? b_ class => 'standout', $viod : txt_ $viod;
            } else {
                txt_ 'This image has not yet been flagged';
            }
            br_; br_;
            span_ class => 'fake_link', 'Show me anyway';
            br_; br_;
            b_ class => 'grayedout', 'This warning can be disabled in your account';
        } if $hide_on_click;
    }
}


sub _rev_ {
    my($c) = @_;
    revision_ c => $c, \&enrich_item,
        [ name       => 'Name'           ],
        [ original   => 'Original name'  ],
        [ alias      => 'Aliases'        ],
        [ desc       => 'Description'    ],
        [ gender     => 'Sex',           fmt => \%GENDER ],
        [ b_month    => 'Birthday/month',empty => 0 ],
        [ b_day      => 'Birthday/day',  empty => 0 ],
        [ s_bust     => 'Bust',          empty => 0 ],
        [ s_waist    => 'Waist',         empty => 0 ],
        [ s_hip      => 'Hip',           empty => 0 ],
        [ height     => 'Height',        empty => 0 ],
        [ weight     => 'Weight',        ],
        [ bloodt     => 'Blood type',    fmt => \%BLOOD_TYPE ],
        [ cup_size   => 'Cup size',      fmt => \%CUP_SIZE ],
        [ age        => 'Age',           empty => 0 ],
        [ main       => 'Main character',empty => 0, fmt => sub {
            my $c = tuwf->dbRowi('SELECT id, name, original FROM chars WHERE id =', \$_);
            a_ href => "/c$c->{id}", title => $c->{name}, "c$c->{id}"
        } ],
        [ main_spoil => 'Spoiler',       fmt => sub { txt_ fmtspoil $_ } ],
        [ image      => 'Image',         empty => 0, fmt => \&image_ ],
        [ vns        => 'Visual novels', fmt => sub {
            a_ href => "/v$_->{vid}", title => $_->{original}||$_->{title}, "v$_->{vid}";
            if($_->{rid}) {
                txt_ ' ['; a_ href => "/r$_->{rid}", "r$_->{rid}"; txt_ ']';
            }
            txt_ " $CHAR_ROLE{$_->{role}}{txt} (".fmtspoil($_->{spoil}).')';
        } ],
        [ traits => 'Traits', fmt => sub {
            b_ class => 'grayedout', "$_->{groupname} / " if $_->{group} != $_->{tid};
            a_ href => "/i$_->{tid}", $_->{name};
            txt_ ' ('.fmtspoil($_->{spoil}).')';
        } ],
}


sub spoil_ {
    sup_ title => 'Minor spoiler', 'S' if $_[0] == 1;
    sup_ title => 'Major spoiler', class => 'standout', 'S' if $_[0] == 2;
}


# Also used by VN::Page
sub chartable_ {
    my($c, $link, $sep, $vn) = @_;
    my $view = viewget;

    div_ mkclass(chardetails => 1, charsep => $sep), sub {
        div_ class => 'charimg', sub { image_ $c };
        table_ class => 'stripe', sub {
            thead_ sub { tr_ sub { td_ colspan => 2, sub {
                $link
                ? a_ href => "/c$c->{id}", style => 'margin-right: 10px; font-weight: bold', $c->{name}
                : b_ style => 'margin-right: 10px', $c->{name};
                b_ class => 'grayedout', style => 'margin-right: 10px', $c->{original} if $c->{original};
                abbr_ class => "icons gen $c->{gender}", title => $GENDER{$c->{gender}}, '' if $c->{gender} ne 'unknown';
                span_ $BLOOD_TYPE{$c->{bloodt}} if $c->{bloodt} ne 'unknown';
            }}};

            tr_ sub {
                td_ class => 'key', 'Aliases';
                td_ $c->{alias} =~ s/\n/, /rg;
            } if $c->{alias};

            tr_ sub {
                td_ class => 'key', 'Measurements';
                td_ join ', ',
                    $c->{height} ? "Height: $c->{height}cm" : (),
                    defined($c->{weight}) ? "Weight: $c->{weight}kg" : (),
                    $c->{s_bust} || $c->{s_waist} || $c->{s_hip} ?
                    sprintf 'Bust-Waist-Hips: %s-%s-%scm', $c->{s_bust}||'??', $c->{s_waist}||'??', $c->{s_hip}||'??' : (),
                    $c->{cup_size} ? "$CUP_SIZE{$c->{cup_size}} cup" : ();
            } if defined($c->{weight}) || $c->{height} || $c->{s_bust} || $c->{s_waist} || $c->{s_hip} || $c->{cup_size};

            tr_ sub {
                td_ class => 'key', 'Birthday';
                td_ $c->{b_day}.' '.[qw{January February March April May June July August September October November December}]->[$c->{b_month}-1];
            } if $c->{b_day} && $c->{b_month};

            tr_ sub {
                td_ class => 'key', 'Age';
                td_ $c->{age};
            } if defined $c->{age};

            my @groups;
            for(grep $_->{spoil} <= $view->{spoilers} && (!$_->{sexual} || $view->{traits_sexual}), $c->{traits}->@*) {
                push @groups, $_ if !@groups || $groups[$#groups]{group} != $_->{group};
                push $groups[$#groups]{traits}->@*, $_;
            }
            tr_ class => "trait_group_i$_->{group}", sub {
                td_ class => 'key', sub { a_ href => "/i$_->{group}", $_->{groupname} };
                td_ sub { join_ ', ', sub { a_ href => "/i$_->{tid}", $_->{name}; spoil_ $_->{spoil} }, $_->{traits}->@* };
            } for @groups;

            my @visvns = grep $_->{spoil} <= $view->{spoilers}, $c->{vns}->@*;
            tr_ sub {
                td_ class => 'key', $vn ? 'Releases' : 'Visual novels';
                td_ sub {
                    my @vns;
                    for(@visvns) {
                        push @vns, $_ if !@vns || $vns[$#vns]{vid} != $_->{vid};
                        push $vns[$#vns]{rels}->@*, $_;
                    }
                    join_ \&br_, sub {
                        my $v = $_;
                        # Just a VN link, no releases
                        if(!$vn && $v->{rels}->@* == 1 && !$v->{rels}[0]{rid}) {
                            txt_ $CHAR_ROLE{$v->{role}}{txt}.' - ';
                            a_ href => "/v$v->{vid}", title => $v->{original}||$v->{title}, $v->{title};
                            spoil_ $v->{spoil};
                        # With releases
                        } else {
                            a_ href => "/v$v->{vid}", title => $v->{original}||$v->{title}, $v->{title} if !$vn;
                            br_ if !$vn;
                            join_ \&br_, sub {
                                b_ class => 'grayedout', '> ';
                                txt_ $CHAR_ROLE{$_->{role}}{txt}.' - ';
                                if($_->{rid}) {
                                    b_ class => 'grayedout', "r$_->{rid}:";
                                    a_ href => "/r$_->{rid}", title => $_->{roriginal}||$_->{rtitle}, $_->{rtitle};
                                } else {
                                    txt_ 'All other releases';
                                }
                                spoil_ $_->{spoil};
                            }, $v->{rels}->@*;
                        }
                    }, @vns;
                };
            } if @visvns && (!$vn || $vn && (@visvns > 1 || $visvns[0]{rid}));

            tr_ sub {
                td_ class => 'key', 'Voiced by';
                td_ sub {
                    join_ \&br_, sub {
                        a_ href => "/s$_->{id}", title => $_->{original}||$_->{name}, $_->{name};
                        txt_ " ($_->{note})" if $_->{note};
                    }, $c->{seiyuu}->@*;
                };
            } if $c->{seiyuu}->@*;

            tr_ class => 'nostripe', sub {
                td_ colspan => 2, class => 'chardesc', sub {
                    h2_ 'Description';
                    p_ sub { lit_ bb2html $c->{desc}, 0, $view->{spoilers} == 2 ? 3 : 2 };
                };
            } if $c->{desc};
        };
    };
    clearfloat_;
}


TUWF::get qr{/$RE{crev}} => sub {
    my $c = db_entry c => tuwf->capture('id'), tuwf->capture('rev');
    return tuwf->resNotFound if !$c;

    enrich_item $c;
    enrich_seiyuu undef, $c;
    my $view = viewget;

    my $inst_maxspoil = tuwf->dbVali('SELECT MAX(main_spoil) FROM chars WHERE NOT hidden AND main IN', [ $c->{id}, $c->{main}||() ]);

    my $inst = !defined($inst_maxspoil) || ($c->{main} && $c->{main_spoil} > $view->{spoilers}) ? []
        : fetch_chars undef, sql
            # If this entry doesn't have a 'main', look for other entries with a 'main' referencing this entry
            !$c->{main} ? ('main =', \$c->{id}, 'AND main_spoil <=', \$view->{spoilers}) :
            # Otherwise, look for other entries with the same 'main', and also fetch the 'main' entry itself
            ('(id <>', \$c->{id}, 'AND main =', \$c->{main}, 'AND main_spoil <=', \$view->{spoilers}, ') OR id =', \$c->{main});

    my $max_spoil = max(
        $inst_maxspoil||0,
        (map $_->{spoil}, $c->{traits}->@*),
        (map $_->{spoil}, $c->{vns}->@*),
        $c->{desc} =~ /\[spoiler\]/i ? 2 : 0, # crude
    );
    # Only display the sexual traits toggle when there are sexual traits within the current spoiler level.
    my $has_sex = grep $_->{spoil} <= $view->{spoilers} && $_->{sexual}, map $_->{traits}->@*, $c, @$inst;

    framework_ title => $c->{name}, index => !tuwf->capture('rev'), type => 'c', dbobj => $c, hiddenmsg => 1,
        og => {
            description => bb2text($c->{desc}),
            image => $c->{image} && $c->{image}{votecount} && $c->{image}{sexual_avg} < 0.4 && $c->{image}{violence_avg} < 0.4 ? tuwf->imgurl($c->{image}{id}) : undef,
        },
    sub {
        _rev_ $c if tuwf->capture('rev');
        div_ class => 'mainbox', sub {
            itemmsg_ c => $c;
            p_ class => 'mainopts', sub {
                if($max_spoil) {
                    a_ mkclass(checked => $view->{spoilers} == 0), href => '?view='.viewset(spoilers=>0, traits_sexual => $view->{traits_sexual}), 'Hide spoilers';
                    a_ mkclass(checked => $view->{spoilers} == 1), href => '?view='.viewset(spoilers=>1, traits_sexual => $view->{traits_sexual}), 'Show minor spoilers';
                    a_ mkclass(standout =>$view->{spoilers} == 2), href => '?view='.viewset(spoilers=>2, traits_sexual => $view->{traits_sexual}), 'Spoil me!' if $max_spoil == 2;
                }
                b_ class => 'grayedout', ' | ' if $has_sex && $max_spoil;
                a_ mkclass(checked => $view->{traits_sexual}), href => '?view='.viewset(spoilers => $view->{spoilers}, traits_sexual=>!$view->{traits_sexual}), 'Show sexual traits' if $has_sex;
            };
            h1_ sub { txt_ $c->{name}; debug_ $c };
            h2_ class => 'alttitle', $c->{original} if length $c->{original};
            chartable_ $c;
        };

        div_ class => 'mainbox', sub {
            h1_ 'Other instances';
            chartable_ $_, 1, $_ != $inst->[0] for @$inst;
        } if @$inst;
    };
};

1;
