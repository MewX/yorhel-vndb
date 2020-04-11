package VNWeb::VN::Page;

use VNWeb::Prelude;
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


sub og {
    my($v) = @_;
    +{
        description => bb2text($v->{desc}),
        image => $v->{image} && !$v->{img_nsfw} ? tuwf->imgurl($v->{image}) :
                 [map $_->{nsfw}?():(tuwf->imgurl($_->{scr})), $v->{screenshots}->@*]->[0]
    }
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
    my $lst = tuwf->dbRowi('SELECT vid, vote FROM ulist_vns WHERE uid =', \auth->uid, 'AND vid =', \$v->{id});

    tr_ class => 'nostripe', sub {
        td_ colspan => 2, sub {
            elm_ 'UList.VNPage', undef, { # TODO: Go through a TUWF::Validation schema
                uid      => 1*auth->uid,
                vid      => 1*$v->{id},
                onlist   => $lst->{vid}?\1:\0,
                canvote  => $minreleased && $minreleased < strftime('%Y%m%d', gmtime) ? \1 : \0,
                vote     => fmtvote($lst->{vote}).'',
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

    return if !$haschars && !auth->perm('edit');
    div_ class => 'maintabs', sub {
        ul_ sub {
            li_ class => (!$char ? ' tabselected' : ''), sub { a_ href => "/v$v->{id}#main", name => 'main', 'main' };
            li_ class => ($char  ? ' tabselected' : ''), sub { a_ href => "/v$v->{id}/chars#chars", name => 'chars', 'characters' };
        } if $haschars;
        ul_ sub {
            li_ sub { a_ href => "/v$v->{id}/add", 'add release' };
            li_ sub { a_ href => "/c/new?vid=$v->{id}", 'add character' };
        } if auth->perm('edit');
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
                    a_ mkclass(checked => $view->{spoilers} == 0), href => '?view='.viewset(spoilers=>0).'#chars', 'Hide spoilers';
                    a_ mkclass(checked => $view->{spoilers} == 1), href => '?view='.viewset(spoilers=>1).'#chars', 'Show minor spoilers';
                    a_ mkclass(standout =>$view->{spoilers} == 2), href => '?view='.viewset(spoilers=>2).'#chars', 'Spoil me!' if $max_spoil == 2;
                }
                b_ class => 'grayedout', ' | ' if $has_sex && $max_spoil;
                a_ mkclass(checked => $view->{traits_sexual}), href => '?view='.viewset(traits_sexual=>!$view->{traits_sexual}).'#chars', 'Show sexual traits' if $has_sex;
            } if !$first++;

            h1_ $CHAR_ROLE{$r}{ @c > 1 ? 'plural' : 'txt' };
            VNWeb::Chars::Page::chartable_($_, 1, $_ != $c[0], 1) for @c;
        }
    }
}


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
