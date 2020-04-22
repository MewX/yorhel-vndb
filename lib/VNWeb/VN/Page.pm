package VNWeb::VN::Page;

use VNWeb::Prelude;
use VNWeb::Releases::Lib 'release_extlinks_';
use VNDB::Func 'fmtrating';
use POSIX 'strftime';


# Enrich everything necessary to at least render infobox_().
sub enrich_vn {
    my($v) = @_;
    enrich_merge id => 'SELECT id, c_votecount, c_olang::text[] AS c_olang FROM vn WHERE id IN', $v;
    enrich_merge vid => 'SELECT id AS vid, title, original FROM vn WHERE id IN', $v->{relations};
    enrich_merge aid => 'SELECT id AS aid, title_romaji, title_kanji, year, type, ann_id, lastfetch FROM anime WHERE id IN', $v->{anime};
    enrich_extlinks v => $v;

    # This fetches rather more information than necessary for infobox_(), but it'll have to do.
    # (And we'll need it for the releases tab anyway)
    $v->{releases} = tuwf->dbAlli('
        SELECT r.id, r.type, r.patch, r.released, r.gtin,', sql_extlinks(r => 'r.'), '
             , (SELECT COUNT(*) FROM releases_vn rv WHERE rv.id = r.id) AS num_vns
          FROM releases r
          JOIN releases_vn rv ON rv.id = r.id
         WHERE NOT r.hidden AND rv.vid =', \$v->{id}
    );
    enrich_extlinks r => $v->{releases};
}


# Enrich everything necessary for rev_() (that also needs enrich_vn())
sub enrich_item {
    my($v) = @_;
    enrich_merge aid => 'SELECT id AS sid, aid, name, original FROM staff_alias WHERE aid IN', $v->{staff}, $v->{seiyuu};
    enrich_merge cid => 'SELECT id AS cid, name AS char_name, original AS char_original FROM chars WHERE id IN', $v->{seiyuu};

    $v->{relations}   = [ sort { $a->{vid} <=> $b->{vid} } $v->{relations}->@* ];
    $v->{anime}       = [ sort { $a->{aid} <=> $b->{aid} } $v->{anime}->@* ];
    $v->{staff}       = [ sort { $a->{aid} <=> $b->{aid} || $a->{role} cmp $b->{role} } $v->{staff}->@* ];
    $v->{seiyuu}      = [ sort { $a->{aid} <=> $b->{aid} || $a->{cid} <=> $b->{cid} || $a->{note} cmp $b->{note} } $v->{seiyuu}->@* ];
    $v->{screenshots} = [ sort { idcmp($a->{scr}, $b->{scr}) } $v->{screenshots}->@* ];
}


sub og {
    my($v) = @_;
    +{
        description => bb2text($v->{desc}),
        image => $v->{image} && !$v->{img_nsfw} ? tuwf->imgurl($v->{image}) :
                 [map $_->{nsfw}?():(tuwf->imgurl($_->{scr})), $v->{screenshots}->@*]->[0]
    }
}


sub rev_ {
    my($v) = @_;
    revision_ v => $v, \&enrich_item,
        [ title       => 'Title (romaji)' ],
        [ original    => 'Original title' ],
        [ alias       => 'Alias'          ],
        [ desc        => 'Description'    ],
        [ length      => 'Length',        fmt => \%VN_LENGTH ],
        [ staff       => 'Credits',       fmt => sub {
            a_ href => "/s$_->{sid}", title => $_->{original}||$_->{name}, $_->{name};
            txt_ " [$CREDIT_TYPE{$_->{role}}]";
            txt_ " [$_->{note}]" if $_->{note};
        }],
        [ seiyuu      => 'Seiyuu',        fmt => sub {
            a_ href => "/s$_->{sid}", title => $_->{original}||$_->{name}, $_->{name};
            txt_ ' as ';
            a_ href => "/c$_->{cid}", title => $_->{char_original}||$_->{char_name}, $_->{char_name};
            txt_ " [$_->{note}]" if $_->{note};
        }],
        [ relations   => 'Relations',     fmt => sub {
            txt_ sprintf '[%s] %s: ', $_->{official} ? 'official' : 'unofficial', $VN_RELATION{$_->{relation}}{txt};
            a_ href => "/v$_->{vid}", title => $_->{original}||$_->{title}, $_->{title};
        }],
        [ anime       => 'Anime',         fmt => sub { a_ href => "https://anidb.net/anime/$_->{aid}", "a$_->{aid}" }],
        [ screenshots => 'Screenshots',   fmt => sub {
            txt_ '[';
            a_ href => "/r$_->{rid}", "r$_->{rid}" if $_->{rid};
            txt_ 'no release' if !$_->{rid};
            txt_ '] ';
            a_ href => tuwf->imgurl($_->{scr}), $_->{scr}; # TODO: Image viewer
            txt_ $_->{nsfw} ? ' (Not safe)' : ' (Safe)';
        }],
        [ image       => 'Image',         fmt => sub { a_ href => tuwf->imgurl($_), $_ } ], # TODO: Preview if SFW
        [ img_nsfw    => 'Image NSFW',    fmt => sub { $_ ? 'Not safe' : 'Safe' } ],
        revision_extlinks 'v'
}


sub infobox_img_ {
    my($v) = @_;
    p_ 'No image uploaded yet.' if !$v->{image};
    img_ src => tuwf->imgurl($v->{image}), alt => $v->{title} if $v->{image} && !$v->{img_nsfw};

    p_ class => 'nsfw_pic', sub {
        input_ id => 'nsfw_chk', type => 'checkbox', class => 'visuallyhidden', tuwf->authPref('show_nsfw') ? (checked => 'checked') : ();
        label_ for => 'nsfw_chk', sub {
            span_ id => 'nsfw_show', sub {
                txt_ 'This image has been flagged as Not Safe For Work.';
                br_; br_;
                span_ class => 'fake_link', 'Show me anyway';
                br_; br_;
                txt_ '(This warning can be disabled in your account)';
            };
            span_ id => 'nsfw_hid', sub {
                img_ src => tuwf->imgurl($v->{image}), alt => $v->{title};
                i_ 'Flagged as NSFW';
            };
        };
    } if $v->{image} && $v->{img_nsfw};
}


sub infobox_relations_ {
    my($v) = @_;
    return if !$v->{relations}->@*;

    my %rel;
    push $rel{$_->{relation}}->@*, $_ for sort { $a->{title} cmp $b->{title} } $v->{relations}->@*;

    tr_ sub {
        td_ 'Relations';
        td_ class => 'relations', sub { dl_ sub {
            for(sort keys %rel) {
                dt_ $VN_RELATION{$_}{txt};
                dd_ sub {
                    join_ \&br_, sub {
                        b_ class => 'grayedout', '[unofficial] ' if !$_->{official};
                        a_ href => "/v$_->{vid}", title => $_->{original}||$_->{title}, shorten $_->{title}, 40;
                    }, $rel{$_}->@*;
                }
            }
        }}
    }
}


sub infobox_producers_ {
    my($v) = @_;

    my $p = tuwf->dbAlli('
        SELECT p.id, p.name, p.original, rl.lang, bool_or(rp.developer) as developer, bool_or(rp.publisher) as publisher
          FROM releases_vn rv
          JOIN releases r ON r.id = rv.id
          JOIN releases_lang rl ON rl.id = rv.id
          JOIN releases_producers rp ON rp.id = rv.id
          JOIN producers p ON p.id = rp.pid
         WHERE NOT r.hidden AND rv.vid =', \$v->{id}, '
         GROUP BY p.id, p.name, p.original, rl.lang
         ORDER BY MIN(r.released), p.name
    ');
    return if !@$p;

    my $prev = 0;
    my @dev = grep $_->{developer} && $prev != $_->{id} && ($prev = $_->{id}), @$p;

    tr_ sub {
        td_ 'Developer';
        td_ sub {
            join_ ' & ', sub { a_ href => "/p$_->{id}", title => $_->{original}||$_->{name}, $_->{name}; }, @dev;
        };
    } if @dev;

    my(%lang, @lang, $lang);
    for(grep $_->{publisher}, @$p) {
        push @lang, $_->{lang} if !$lang{$_->{lang}};
        push $lang{$_->{lang}}->@*, $_;
    }

    tr_ sub {
        td_ 'Publishers';
        td_ sub {
            join_ \&br_, sub {
                abbr_ class => "icons lang $_", title => $LANGUAGE{$_}, '';
                join_ ' & ', sub { a_ href => "/p$_->{id}", title => $_->{original}||$_->{name}, $_->{name} }, $lang{$_}->@*;
            }, @lang;
        }
    } if keys %lang;
}


sub infobox_affiliates_ {
    my($v) = @_;

    # If the same shop link has been added to multiple releases, use the 'first' matching type in this list.
    my @type = ('bundle', '', 'partial', 'trial', 'patch');

    # url => [$title, $url, $price, $type]
    my %links;
    for my $rel ($v->{releases}->@*) {
        my $type =    $rel->{patch} ? 4 :
            $rel->{type} eq 'trial' ? 3 :
          $rel->{type} eq 'partial' ? 2 :
                $rel->{num_vns} > 1 ? 0 : 1;

        $links{$_->[1]} = [ @$_, min $type, $links{$_->[1]}[3]||9 ] for grep $_->[2], $rel->{extlinks}->@*;
    }
    return if !keys %links;

    tr_ id => 'buynow', sub {
        td_ 'Shops';
        td_ sub {
            join_ \&br_, sub {
                b_ class => 'standout', '» ';
                a_ href => $_->[1], sub {
                    txt_ $_->[2];
                    b_ class => 'grayedout', ' @ ';
                    txt_ $_->[0];
                    b_ class => 'grayedout', " ($type[$_->[3]])" if $_->[3] != 1;
                };
            }, sort { $a->[0] cmp $b->[0] || $a->[2] cmp $b->[2] } values %links;
        }
    }
}


sub infobox_anime_ {
    my($v) = @_;
    return if !$v->{anime}->@*;
    tr_ sub {
        td_ 'Related anime';
        td_ class => 'anime', sub { join_ \&br_, sub {
            if(!$_->{lastfetch} || !$_->{year} || !$_->{title_romaji}) {
                b_ sub {
                    txt_ '[no information available at this time: ';
                    a_ href => 'https://anidb.net/anime/'.$_->{aid}, "a$_->{aid}";
                    txt_ ']';
                };
            } else {
                b_ sub {
                    txt_ '[';
                    a_ href => "https://anidb.net/anime/$_->{aid}", title => 'AniDB', 'DB';
                    if($_->{ann_id}) {
                        txt_ '-';
                        a_ href => "http://www.animenewsnetwork.com/encyclopedia/anime.php?id=$_->{ann_id}", title => 'Anime News Network', 'ANN';
                    }
                    txt_ '] ';
                };
                abbr_ title => $_->{title_kanji}||$_->{title_romaji}, shorten $_->{title_romaji}, 50;
                b_ ' ('.(defined $_->{type} ? $ANIME_TYPE{$_->{type}}{txt}.', ' : '').$_->{year}.')';
            }
        }, sort { ($a->{year}||9999) <=> ($b->{year}||9999) } $v->{anime}->@* }
    }
}


sub infobox_tags_ {
    my($v) = @_;
    my $rating = 'avg(CASE WHEN tv.ignore THEN NULL ELSE tv.vote END)';
    my $tags = tuwf->dbAlli("
        SELECT t.id, t.name, t.cat, count(*) as cnt, $rating as rating
             , coalesce(avg(CASE WHEN tv.ignore THEN NULL ELSE tv.spoiler END), t.defaultspoil) as spoiler
          FROM tags t
          JOIN tags_vn tv ON tv.tag = t.id
         WHERE t.state = 1+1 AND tv.vid =", \$v->{id}, "
         GROUP BY t.id, t.name, t.cat
        HAVING $rating > 0
         ORDER BY rating DESC"
    );
    return if !@$tags;

    div_ id => 'tagops', sub {
        debug_ $tags;
        for (keys %TAG_CATEGORY) {
            input_ id => "cat_$_", type => 'checkbox', class => 'visuallyhidden',
                (auth ? auth->pref("tags_$_") : $_ ne 'ero') ? (checked => 'checked') : ();
            label_ for => "cat_$_", lc $TAG_CATEGORY{$_};
        }
        my $spoiler = auth->pref('spoilers') || 0;
        input_ id => 'tag_spoil_none', type => 'radio', class => 'visuallyhidden', name => 'tag_spoiler', $spoiler == 0 ? (checked => 'checked') : ();
        label_ for => 'tag_spoil_none', class => 'sec', 'hide spoilers';
        input_ id => 'tag_spoil_some', type => 'radio', class => 'visuallyhidden', name => 'tag_spoiler', $spoiler == 1 ? (checked => 'checked') : ();
        label_ for => 'tag_spoil_some', 'show minor spoilers';
        input_ id => 'tag_spoil_all', type => 'radio', class => 'visuallyhidden', name => 'tag_spoiler', $spoiler == 2 ? (checked => 'checked') : ();
        label_ for => 'tag_spoil_all', 'spoil me!';

        input_ id => 'tag_toggle_summary', type => 'radio', class => 'visuallyhidden', name => 'tag_all', auth->pref('tags_all') ? () : (checked => 'checked');
        label_ for => 'tag_toggle_summary', class => 'sec', 'summary';
        input_ id => 'tag_toggle_all', type => 'radio', class => 'visuallyhidden', name => 'tag_all', auth->pref('tags_all') ? (checked => 'checked') : ();
        label_ for => 'tag_toggle_all', class => 'lst', 'all';
        div_ id => 'vntags', sub {
            my %counts = map +($_,[0,0,0]), keys %TAG_CATEGORY;
            join_ ' ', sub {
                my $spoil = $_->{spoiler} > 1.3 ? 2 : $_->{spoiler} > 0.4 ? 1 : 0;
                my $cnt = $counts{$_->{cat}};
                $cnt->[2]++;
                $cnt->[1]++ if $spoil < 2;
                $cnt->[0]++ if $spoil < 1;
                my $cut = $cnt->[0] > 15 ? ' cut cut2 cut1 cut0' : $cnt->[1] > 15 ? ' cut cut2 cut1' : $cnt->[2] > 15 ? ' cut cut2' : '';
                span_ class => "tagspl$spoil cat_$_->{cat} $cut", sub {
                    a_ href => "/g$_->{id}", style => sprintf('font-size: %dpx', $_->{rating}*3.5+6), $_->{name};
                    b_ class => 'grayedout', sprintf ' %.1f', $_->{rating};
                }
            }, @$tags;
        }
    }
}


sub infobox_useroptions_ {
    my($v) = @_;
    return if !auth;

    # Voting option is hidden if nothing has been released yet
    my $minreleased = min grep $_, map $_->{released}, $v->{releases}->@*;

    my $labels = tuwf->dbAlli('
        SELECT l.id, l.label, l.private, uvl.vid IS NOT NULL as assigned
          FROM ulist_labels l
          LEFT JOIN ulist_vns_labels uvl ON uvl.uid = l.uid AND uvl.lbl = l.id AND uvl.vid =', \$v->{id}, '
         WHERE l.uid =', \auth->uid,  '
         ORDER BY CASE WHEN l.id < 10 THEN l.id ELSE 10 END, l.label'
    );
    my $lst = tuwf->dbRowi('SELECT vid, vote, notes FROM ulist_vns WHERE uid =', \auth->uid, 'AND vid =', \$v->{id});

    tr_ class => 'nostripe', sub {
        td_ colspan => 2, sub {
            elm_ 'UList.VNPage', undef, { # TODO: Go through a TUWF::Validation schema
                uid      => 1*auth->uid,
                vid      => 1*$v->{id},
                onlist   => $lst->{vid}?\1:\0,
                canvote  => $minreleased && $minreleased < strftime('%Y%m%d', gmtime) ? \1 : \0,
                vote     => fmtvote($lst->{vote}).'',
                notes    => $lst->{notes}||'',
                labels   => [ map +{ id => 1*$_->{id}, label => $_->{label}, private => $_->{private}?\1:\0 }, @$labels ],
                selected => [ map $_->{id}, grep $_->{assigned}, @$labels ],
            };
        }
    }
}


sub infobox_ {
    my($v) = @_;
    div_ class => 'mainbox', sub {
        h1_ $v->{title};
        h2_ class => 'alttitle', lang_attr($v->{c_olang}), $v->{original} if $v->{original};

        div_ class => 'vndetails', sub {
            div_ class => 'vnimg', sub { infobox_img_ $v };

            table_ class => 'stripe', sub {
                tr_ sub {
                    td_ class => 'key', 'Title';
                    td_ sub { txt_ $v->{title}; debug_ $v; };
                };

                tr_ sub {
                    td_ 'Original title';
                    td_ lang_attr($v->{c_olang}), $v->{original};
                } if $v->{original};

                tr_ sub {
                    td_ 'Aliases';
                    td_ $v->{alias} =~ s/\n/, /gr;
                } if $v->{alias};

                tr_ sub {
                    td_ 'Length';
                    td_ "$VN_LENGTH{$v->{length}}{txt} ($VN_LENGTH{$v->{length}}{time})";
                } if $v->{length};

                infobox_producers_ $v;
                infobox_relations_ $v;

                tr_ sub {
                    td_ 'Links';
                    td_ sub { join_ ', ', sub { a_ href => $_->[1], $_->[0] }, $v->{extlinks}->@* };
                } if $v->{extlinks}->@*;

                infobox_affiliates_ $v;
                infobox_anime_ $v;
                infobox_useroptions_ $v;

                tr_ class => 'nostripe', sub {
                    td_ class => 'vndesc', colspan => 2, sub {
                        h2_ 'Description';
                        p_ sub { lit_ $v->{desc} ? bb2html $v->{desc} : '-' };
                    }
                }
            }
        };
        div_ class => 'clearfloat', style => 'height: 5px', ''; # otherwise the tabs below aren't positioned correctly
        infobox_tags_ $v;
    }
}


sub tabs_ {
    my($v, $char) = @_;
    # XXX: This query is kind of silly because we'll be fetching a list of characters regardless of which tab we have open.
    my $haschars = tuwf->dbVali('SELECT 1 FROM chars c JOIN chars_vns cv ON cv.id = c.id WHERE NOT c.hidden AND cv.vid =', \$v->{id}, 'LIMIT 1');

    return if !$haschars && !auth->permEdit;
    div_ class => 'maintabs', sub {
        ul_ sub {
            if($haschars) {
                li_ class => (!$char ? ' tabselected' : ''), sub { a_ href => "/v$v->{id}#main", name => 'main', 'main' };
                li_ class => ($char  ? ' tabselected' : ''), sub { a_ href => "/v$v->{id}/chars#chars", name => 'chars', 'characters' };
            }
        };
        ul_ sub {
            if(auth->permEdit) {
                li_ sub { a_ href => "/v$v->{id}/add", 'add release' };
                li_ sub { a_ href => "/c/new?vid=$v->{id}", 'add character' };
            }
        };
    }
}


sub releases_ {
    my($v) = @_;

    # TODO: Organize a long list of releases a bit better somehow? Collapsable language sections?

    enrich_merge id => '
        SELECT id, title, original, notes, minage, freeware, doujin, resolution, voiced, ani_story, ani_ero, uncensored
          FROM releases WHERE id IN', $v->{releases};
    enrich_merge id => sql('SELECT rid as id, status as rlist_status FROM rlists WHERE uid =', \auth->uid, 'AND rid IN'), $v->{releases} if auth;
    enrich_flatten lang => id => id => 'SELECT id, lang FROM releases_lang WHERE id IN', $v->{releases};
    enrich_flatten platforms => id => id => 'SELECT id, platform FROM releases_platforms WHERE id IN', $v->{releases};
    enrich media => id => id => 'SELECT id, medium, qty FROM releases_media WHERE id IN', $v->{releases};

    $v->{releases} = [ sort { $a->{released} <=> $b->{released} || $a->{id} <=> $b->{id} } $v->{releases}->@* ];
    my %lang;
    my @lang = grep !$lang{$_}++, map $_->{lang}->@*, $v->{releases}->@*;

    my sub icon_ {
        my($img, $label, $class) = @_;
        $class = $class ? " release_icon_$class" : '';
        img_ src => config->{url_static}."/f/$img.svg", class => "release_icons$class", title => $label;
    }

    my sub icons_ {
        my($r) = @_;
        icon_ 'voiced', $VOICED{$r->{voiced}}{txt}, "voiced$r->{voiced}" if $r->{voiced};
        icon_ 'story_animated', "Story: $ANIMATED{$r->{ani_story}}{txt}", "anim$r->{ani_story}" if $r->{ani_story};
        icon_ 'ero_animated', "Ero: $ANIMATED{$r->{ani_ero}}{txt}", "anim$r->{ani_ero}" if $r->{ani_ero};
        icon_ 'free', 'Freeware' if $r->{freeware};
        icon_ 'nonfree', 'Non-free' if !$r->{freeware};
        icon_ 'doujin', 'Doujin' if !$r->{patch} && $r->{doujin};
        icon_ 'commercial', 'Commercial' if !$r->{patch} && !$r->{doujin};
        if($r->{resolution} ne 'unknown') {
            my $type = $r->{resolution} eq 'nonstandard' ? 'custom' : $RESOLUTION{$r->{resolution}}{cat} eq 'widescreen' ? '16-9' : '4-3';
            # Ugly workaround: PC-98 has non-square pixels, thus not widescreen
            $type = '4-3' if $type eq '16-9' && grep $_ eq 'p98', $r->{platforms}->@*;
            icon_ "resolution_$type", $RESOLUTION{$r->{resolution}}{txt};
        }
        icon_ $MEDIUM{ $r->{media}[0]{medium} }{icon}, join ', ', map fmtmedia($_->{medium}, $_->{qty}), $r->{media}->@* if $r->{media}->@*;
        icon_ 'uncensor', 'Uncensored' if $r->{uncensored};
        icon_ 'notes', bb2text $r->{notes} if $r->{notes};
    }

    my sub lang_ {
        my($lang) = @_;
        tr_ class => 'lang', sub {
            td_ colspan => 7, sub {
                abbr_ class => "icons lang $lang", title => $LANGUAGE{$lang}, '';
                txt_ $LANGUAGE{$lang};
            }
        };
        tr_ sub {
            td_ class => 'tc1', sub { rdate_ $_->{released} };
            td_ class => 'tc2', $_->{minage} < 0 ? '' : minage $_->{minage};
            td_ class => 'tc3', sub {
                abbr_ class => "icons $_", title => $PLATFORM{$_}, '' for grep $_ ne 'oth', $_->{platforms}->@*;
                abbr_ class => "icons rt$_->{type}", title => $_->{type}, '';
            };
            td_ class => 'tc4', sub {
                a_ href => "/r$_->{id}", title => $_->{original}||$_->{title}, $_->{title};
                b_ class => 'grayedout', ' (patch)' if $_->{patch};
            };
            td_ class => 'tc_icons', sub { icons_ $_ };
            td_ class => 'tc5 elm_dd_left', sub {
                elm_ 'UList.ReleaseEdit', $VNWeb::User::Lists::RLIST_STATUS, { rid => $_->{id}, uid => auth->uid, status => $_->{rlist_status}, empty => '--' };
            };
            td_ class => 'tc6', sub { release_extlinks_ $_, "$lang$_->{id}" };
        } for grep grep($_ eq $lang, $_->{lang}->@*), $v->{releases}->@*;
    }

    div_ class => 'mainbox releases', sub {
        h1_ 'Releases';
        if(!$v->{releases}->@*) {
            p_ 'We don\'t have any information about releases of this visual novel yet...';
        } else {
            table_ sub { lang_ $_ for @lang };
        }
    }
}


sub staff_ {
    my($v) = @_;

    # XXX: The staff listing is included in the page 3 times, for 3 different
    # layouts. A better approach to get the same layout is to add the boxes to
    # the HTML once with classes indicating the box position (e.g.
    # "4col-col1-row1 3col-col2-row1" etc) and then using CSS to position the
    # box appropriately. My attempts to do this have failed, however. The
    # layouting can also be done in JS, but that's not my preferred option.

    # Step 1: Get a list of 'boxes'; Each 'box' represents a role with a list of staff entries.
    # @boxes = [ $height, $roleimp, $html ]
    my %roles;
    push $roles{$_->{role}}->@*, $_ for $v->{staff}->@*;
    my $i=0;
    my @boxes =
        sort { $b->[0] <=> $a->[0] || $a->[1] <=> $b->[1] }
        map [ 2+$roles{$_}->@*, $i++,
            xml_string sub {
                li_ class => 'vnstaff_head', $CREDIT_TYPE{$_};
                li_ sub {
                    a_ href => "/s$_->{sid}", title => $_->{original}||$_->{name}, $_->{name};
                    b_ title => $_->{note}, class => 'grayedout', $_->{note} if $_->{note};
                } for sort { $a->{name} cmp $b->{name} } $roles{$_}->@*;
            }
        ], grep $roles{$_}, keys %CREDIT_TYPE;

    # Step 2. Assign boxes to columns for 2 to 4 column layouts,
    # efficiently packing the boxes to use the least vertical space,
    # sorting the columns and boxes within columns by role importance.
    # (There is no 1-column layout, that's just the 2-column layout stacked with css)
    my @cols = map [map [0,99,[]], 1..$_], 2..4; # [ $height, $min_roleimp, $boxes ] for each column in each layout
    for my $c (@cols) {
        for (@boxes) {
            my $smallest = $c->[0];
            $c->[$_][0] < $smallest->[0] && ($smallest = $c->[$_]) for 1..$#$c;
            $smallest->[0] += $_->[0];
            $smallest->[1] = $_->[1] if $_->[1] < $smallest->[1];
            push $smallest->[2]->@*, $_;
        }
        $_->[2] = [ sort { $a->[1] <=> $b->[1] } $_->[2]->@* ] for @$c;
        @$c = sort { $a->[1] <=> $b->[1] } @$c;
    }

    div_ class => 'mainbox', 'data-mainbox-summarize' => 200, sub {
        h1_ 'Staff';
        div_ class => sprintf('vnstaff vnstaff-%d', scalar @$_), sub {
            ul_ sub {
                lit_ $_->[2] for $_->[2]->@*;
            } for @$_
        } for @cols;
    } if $v->{staff}->@*;
}


sub charsum_ {
    my($v) = @_;

    my $spoil = viewget->{spoilers};
    my $c = tuwf->dbAlli('
        SELECT c.id, c.name, c.original, c.gender, v.role
          FROM chars c
          JOIN (SELECT id, MIN(role) FROM chars_vns WHERE role <> \'appears\' AND spoil <=', \$spoil, 'AND vid =', \$v->{id}, 'GROUP BY id) v(id,role) ON c.id = v.id
         WHERE NOT c.hidden
         ORDER BY v.role, c.name, c.id'
    );
    return if !@$c;
    enrich seiyuu => id => cid => sub { sql('
        SELECT vs.cid, sa.id, sa.name, sa.original, vs.note
          FROM vn_seiyuu vs
          JOIN staff_alias sa ON sa.aid = vs.aid
         WHERE vs.id =', \$v->{id}, 'AND vs.cid IN', $_, '
         ORDER BY sa.name'
    ) }, $c;

    div_ class => 'mainbox', 'data-mainbox-summarize' => 200, sub {
        p_ class => 'mainopts', sub {
            a_ href => "/v$v->{id}/chars#chars", 'Full character list';
        };
        h1_ 'Character summary';
        div_ class => 'charsum_list', sub {
            div_ class => 'charsum_bubble', sub {
                div_ class => 'name', sub {
                    i_ $CHAR_ROLE{$_->{role}}{txt};
                    abbr_ class => "icons gen $_->{gender}", title => $GENDER{$_->{gender}}, '' if $_->{gender} ne 'unknown';
                    a_ href => "/c$_->{id}", title => $_->{original}||$_->{name}, $_->{name};
                };
                div_ class => 'actor', sub {
                    txt_ 'Voiced by';
                    $_->{seiyuu}->@* > 1 ? br_ : txt_ ' ';
                    join_ \&br_, sub {
                        a_ href => "/s$_->{id}", title => $_->{original}||$_->{name}, $_->{name};
                        b_ class => 'grayedout', $_->{note} if $_->{note};
                    }, $_->{seiyuu}->@*;
                } if $_->{seiyuu}->@*;
            } for @$c;
        };
    };
}


sub stats_ {
    my($v) = @_;

    my $stats = tuwf->dbAlli('
        SELECT (uv.vote::numeric/10)::int AS idx, COUNT(uv.vote) as votes, SUM(uv.vote) AS total
          FROM ulist_vns uv
         WHERE uv.vote IS NOT NULL
           AND NOT EXISTS(SELECT 1 FROM users u WHERE u.id = uv.uid AND u.ign_votes)
           AND uv.vid =', \$v->{id}, '
         GROUP BY (uv.vote::numeric/10)::int'
    );
    my $sum = sum map $_->{total}, @$stats;
    my $max = max map $_->{votes}, @$stats;
    my $num = sum map $_->{votes}, @$stats;

    my $recent = @$stats && tuwf->dbAlli('
         SELECT uv.vote,', sql_totime('uv.vote_date'), 'as date, ', sql_user(), '
              , NOT EXISTS(SELECT 1 FROM ulist_vns_labels uvl JOIN ulist_labels ul ON ul.uid = uvl.uid AND ul.id = uvl.lbl WHERE uvl.uid = uv.uid AND uvl.vid = uv.vid AND NOT ul.private) AS hide_list
           FROM ulist_vns uv
           JOIN users u ON u.id = uv.uid
          WHERE uv.vid =', \$v->{id}, 'AND uv.vote IS NOT NULL
            AND NOT EXISTS(SELECT 1 FROM users u WHERE u.id = uv.uid AND u.ign_votes)
          ORDER BY uv.vote_date DESC
          LIMIT', \8
    );

    my $rank = $v->{c_votecount} && tuwf->dbRowi('
        SELECT c_rating, c_popularity
             , (SELECT COUNT(*)+1 FROM vn iv WHERE NOT iv.hidden AND iv.c_popularity > COALESCE(v.c_popularity, 0.0)) AS pop_rank
             , (SELECT COUNT(*)+1 FROM vn iv WHERE NOT iv.hidden AND iv.c_rating > COALESCE(v.c_rating, 0.0)) AS rating_rank
          FROM vn v WHERE id =', \$v->{id}
    );

    my sub votestats_ {
        table_ class => 'votegraph', sub {
            thead_ sub { tr_ sub { td_ colspan => 2, 'Vote stats' } };
            tfoot_ sub { tr_ sub { td_ colspan => 2, sprintf '%d vote%s total, average %.2f (%s)', $num, $num == 1 ? '' : 's', $sum/$num/10, fmtrating(ceil($sum/$num/10-1)||1) } };
            tr_ sub {
                my $num = $_;
                my $votes = [grep $num == $_->{idx}, @$stats]->[0]{votes} || 0;
                td_ class => 'number', $num;
                td_ class => 'graph', sub {
                    div_ style => sprintf('width: %dpx', ($votes||0)/$max*250), ' ';
                    txt_ $votes||0;
                };
            } for (reverse 1..10);
        };

        table_ class => 'recentvotes stripe', sub {
            thead_ sub { tr_ sub { td_ colspan => 3, sub {
                txt_ 'Recent votes';
                b_ sub {
                    txt_ '(';
                    a_ href => "/v$v->{id}/votes", 'show all';
                    txt_ ')';
                }
            } } };
            tr_ sub {
                td_ sub {
                    b_ class => 'grayedout', 'hidden' if $_->{hide_list};
                    user_ $_ if !$_->{hide_list};
                };
                td_ fmtvote $_->{vote};
                td_ fmtdate $_->{date};
            } for @$recent;
        } if $recent && @$recent;

        clearfloat_;
        div_ sub {
            h3_ 'Ranking';
            p_ sprintf 'Popularity: ranked #%d with a score of %.2f', $rank->{pop_rank}, ($rank->{c_popularity}||0)*100;
            p_ sprintf 'Bayesian rating: ranked #%d with a rating of %.2f', $rank->{rating_rank}, $rank->{c_rating}/10;
        } if $v->{c_votecount};
    }

    div_ class => 'mainbox', sub {
        h1_ 'User stats';
        if(!@$stats) {
            p_ 'Nobody has voted on this visual novel yet...';
        } else {
            div_ class => 'votestats', \&votestats_;
        }
    }
}


sub chars_ {
    my($v) = @_;
    my $view = viewget;
    my $chars = VNWeb::Chars::Page::fetch_chars($v->{id}, sql('id IN(SELECT id FROM chars_vns WHERE vid =', \$v->{id}, ')'));
    return if !@$chars;

    my $max_spoil = max(
        map max(
            (map $_->{spoil}, $_->{traits}->@*),
            (map $_->{spoil}, $_->{vns}->@*),
            $_->{desc} =~ /\[spoiler\]/i ? 2 : 0,
        ), @$chars
    );
    $chars = [ grep +grep($_->{spoil} <= $view->{spoilers}, $_->{vns}->@*), @$chars ];
    my $has_sex = grep $_->{spoil} <= $view->{spoilers} && $_->{sexual}, map $_->{traits}->@*, @$chars;

    my %done;
    my $first = 0;
    for my $r (keys %CHAR_ROLE) {
        my @c = grep grep($_->{role} eq $r, $_->{vns}->@*) && !$done{$_->{id}}++, @$chars;
        next if !@c;
        div_ class => 'mainbox', sub {

            p_ class => 'mainopts', sub {
                if($max_spoil) {
                    a_ mkclass(checked => $view->{spoilers} == 0), href => '?view='.viewset(spoilers=>0,traits_sexual=>$view->{traits_sexual}).'#chars', 'Hide spoilers';
                    a_ mkclass(checked => $view->{spoilers} == 1), href => '?view='.viewset(spoilers=>1,traits_sexual=>$view->{traits_sexual}).'#chars', 'Show minor spoilers';
                    a_ mkclass(standout =>$view->{spoilers} == 2), href => '?view='.viewset(spoilers=>2,traits_sexual=>$view->{traits_sexual}).'#chars', 'Spoil me!' if $max_spoil == 2;
                }
                b_ class => 'grayedout', ' | ' if $has_sex && $max_spoil;
                a_ mkclass(checked => $view->{traits_sexual}), href => '?view='.viewset(spoilers=>$view->{spoilers},traits_sexual=>!$view->{traits_sexual}).'#chars', 'Show sexual traits' if $has_sex;
            } if !$first++;

            h1_ $CHAR_ROLE{$r}{ @c > 1 ? 'plural' : 'txt' };
            VNWeb::Chars::Page::chartable_($_, 1, $_ != $c[0], 1) for @c;
        }
    }
}


TUWF::get qr{/$RE{vrev}}, sub {
    my $v = db_entry v => tuwf->capture('id'), tuwf->capture('rev');
    return tuwf->resNotFound if !$v;

    enrich_vn $v;
    enrich_item $v;

    framework_ title => $v->{title}, index => !tuwf->capture('rev'), type => 'v', dbobj => $v, hiddenmsg => 1, og => og($v),
    sub {
        rev_ $v if tuwf->capture('rev');
        infobox_ $v;
        tabs_ $v, 0;
        releases_ $v;
        staff_ $v;
        charsum_ $v;
        stats_ $v;
        # TODO: Screenshots
    };
};


TUWF::get qr{/$RE{vid}/chars}, sub {
    my $v = db_entry v => tuwf->capture('id');
    return tuwf->resNotFound if !$v;

    enrich_vn $v;

    framework_ title => $v->{title}, index => 1, type => 'v', dbobj => $v, hiddenmsg => 1, og => og($v),
    sub {
        infobox_ $v;
        tabs_ $v, 1;
        chars_ $v;
    };
};

1;
