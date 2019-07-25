package VN3::VN::Page;

use VN3::Prelude;
use VN3::VN::Lib;


TUWF::get '/v/rand', sub {
    # TODO: Apply stored filters?
    my $vid = tuwf->dbVal('SELECT id FROM vn WHERE NOT hidden ORDER BY RANDOM() LIMIT 1');
    tuwf->resRedirect("/v$vid", 'temp');
};


sub CVImage {
    my($vn, $class, $class_sfw, $class_nsfw) = @_;
    return if !$vn->{image};

    my $img = tuwf->imgurl(cv => $vn->{image});
    my $nsfw = tuwf->conf->{url_static}.'/v3/nsfw.svg';
    Img class => $class.' '.($vn->{img_nsfw} ? $class_nsfw : $class_sfw),
          !$vn->{img_nsfw}        ? (src => $img)
        : auth->pref('show_nsfw') ? (src => $img, 'data-toggle-img' => $nsfw)
                                  : (src => $nsfw, 'data-toggle-img' => $img);
}


sub Top {
    my $vn = shift;
    Div class => 'fixed-size-left-sidebar-md', '';
    Div class => 'col-md', sub {
        Div class => 'vn-header', sub {
            EntryEdit v => $vn;
            CVImage $vn, 'page-header-img-mobile img img--rounded d-md-none', '', 'nsfw-outline';
            Div class => 'vn-header__title', $vn->{title};
            Div class => 'vn-header__original-title', $vn->{original} if $vn->{original};
            Div class => 'vn-header__details', sub {
                Txt $vn->{c_rating} ? sprintf '%.1f ', $vn->{c_rating}/10 : '-';
                Div class => 'vn-header__sep', '';
                Txt vn_length_time $vn->{length};
                Div class => 'vn-header__sep', '';
                Txt join ', ', map $LANG{$_}, @{$vn->{c_languages}};
                Debug $vn;
            };
        };
        TopNav details => $vn;
    };
}


sub SidebarProd {
    my $vn = shift;

    my $prod = tuwf->dbAlli(q{
        SELECT p.id, p.name, p.original, bool_or(rp.developer) AS dev, bool_or(rp.publisher) AS pub
          FROM releases r
          JOIN releases_producers rp ON rp.id = r.id
          JOIN releases_vn rv ON rv.id = r.id
          JOIN producers p ON rp.pid = p.id
         WHERE rv.vid =}, \$vn->{id}, q{
           AND NOT r.hidden
         GROUP BY p.id, p.name, p.original
         ORDER BY p.name
    });

    my $Fmt = sub {
        my($single, $multi, @lst) = @_;

        Dt @lst == 1 ? $single : $multi;
        Dd sub {
            Join ', ', sub {
                A href => "/p$_[0]{id}", title => $_[0]{original}||$_[0]{name}, $_[0]{name}
            }, @lst;
        };
    };

    $Fmt->('Developer', 'Developers', grep $_->{dev}, @$prod);
    $Fmt->('Publisher', 'Publishers', grep $_->{pub}, @$prod);
}


sub SidebarRel {
    my $vn = shift;
    return if !@{$vn->{relations}};

    Dt 'Relations';
    Dd sub {
        Dl sub {
            for my $type (vn_relations) {
                my @rel = grep $_->{relation} eq $type, @{$vn->{relations}};
                next if !@rel;
                Dt vn_relation_display $type;
                Dd class => 'single-line-md', sub {
                    Span 'unofficial ' if !$_->{official};
                    A href => "/v$_->{vid}", title => $_->{original}||$_->{title}, $_->{title};
                } for @rel;
            }
        }
    }
}


sub Sidebar {
    my $vn = shift;

    CVImage $vn, 'img img--fit img--rounded d-none d-md-block vn-img-desktop', 'elevation-1', 'elevation-1-nsfw' if $vn->{image};
    Div class => 'vn-image-placeholder img--rounded elevation-1 d-none d-md-block vn-img-desktop', sub {
        Div class => 'vn-image-placeholder__icon', sub {
            Img class => 'svg-icon', src => tuwf->conf->{url_static}.'/v3/camera-alt.svg';
        }
    } if !$vn->{image};

    Div class => 'add-to-list elevated-button elevation-1', sub {
        Img class => 'svg-icon', src => tuwf->conf->{url_static}.'/v3/plus.svg';
        Txt 'Add to my list';
    };

    Dl class => 'vn-page__dl', sub {
        if($vn->{original}) {
            Dt 'Original Title';
            Dd $vn->{original};
        }

        Dt 'Main Title';
        Dd $vn->{title};

        if($vn->{alias}) {
            Dt 'Aliases';
            Dd $vn->{alias} =~ s/\n/, /gr;
        }

        if($vn->{length}) {
            Dt 'Length';
            Dd vn_length_display $vn->{length};
        }

        SidebarProd $vn;
        SidebarRel $vn;

        # TODO: Affiliate links
        # TODO: Anime
    };
}


sub Tags {
    my $vn = shift;

    my $tag_rating = 'avg(CASE WHEN tv.ignore THEN NULL ELSE tv.vote END)';
    my $tags = tuwf->dbAlli(qq{
        SELECT tv.tag, t.name, t.cat, count(*) as cnt, $tag_rating as rating,
               COALESCE(avg(CASE WHEN tv.ignore THEN NULL ELSE tv.spoiler END), t.defaultspoil) as spoiler
        FROM tags_vn tv
        JOIN tags t ON tv.tag = t.id
        WHERE tv.vid =}, \$vn->{id}, qq{
          AND t.state = 1+1
        GROUP BY tv.tag, t.name, t.cat, t.defaultspoil
        HAVING $tag_rating > 0
        ORDER BY $tag_rating DESC
    });

    my $spoil = auth->pref('spoilers') || 0;
    my $cat = auth->pref('tags_cat') || 'cont,tech';
    my %cat = map +($_, !!($cat =~ /$_/)), qw/cont ero tech/;

    Div mkclass(
        'tag-summary__tags' => 1,
        'tag-summary--collapsed' => 1,
        'tag-summary--hide-spoil-1' => $spoil < 1,
        'tag-summary--hide-spoil-2' => $spoil < 2,
        map +("tag-summary--hide-$_", !$cat{$_}), keys %cat
    ), sub {
        for my $tag (@$tags) {
            Div class => sprintf(
                'tag-summary__tag tag-summary__tag--%s tag-summary__tag--spoil-%d',
                $tag->{cat}, $tag->{spoiler} > 1.3 ? 2 : $tag->{spoiler} > 0.4 ? 1 : 0
            ), sub {
                A href => "/g$tag->{tag}", class => 'link--subtle', $tag->{name};
                Div class => 'tag-summary__tag-meter', style => sprintf('width: %dpx', $tag->{rating}*10), '';
            };
        }
    };

    Div class => 'tag-summary__options', sub {
        Div class => 'tag-summary__options-left', sub {
            A href => 'javascript:;', class => 'link--subtle d-none tag-summary__show-all', sub {
                Span class => 'caret caret--pre', '';
                Txt ' Show all tags';
            };
            Debug $tags;
        };
        Div class => 'tag-summary__options-right', sub {
            Div class => 'tag-summary__option dropdown', sub {
                A href => 'javascript:;', class => 'link--subtle dropdown__toggle', sub {
                    Span class => 'tag-summary_option--spoil', spoil_display $spoil;
                    Lit ' ';
                    Span class => 'caret', '';
                };
                Div class => 'dropdown-menu', sub {
                    A class => 'dropdown-menu__item tag-summary_option--spoil-0', href => 'javascript:;', spoil_display 0;
                    A class => 'dropdown-menu__item tag-summary_option--spoil-1', href => 'javascript:;', spoil_display 1;
                    A class => 'dropdown-menu__item tag-summary_option--spoil-2', href => 'javascript:;', spoil_display 2;
                };
            };
            Div class => 'tag-summary__option', sub { Switch 'Content',   $cat{cont}, 'tag-summary__option--cont' => 1; };
            Div class => 'tag-summary__option', sub { Switch 'Sexual',    $cat{ero},  'tag-summary__option--ero'  => 1; };
            Div class => 'tag-summary__option', sub { Switch 'Technical', $cat{tech}, 'tag-summary__option--tech' => 1; };
        };
    };
}


sub Releases {
    my $vn = shift;

    my %lang;
    my @lang = grep !$lang{$_}++, map @{$_->{lang}}, @{$vn->{releases}};

    for my $lang (@lang) {
        Div class => 'relsm__language', sub {
            Lang $lang;
            Txt " $LANG{$lang}";
        };
        Div class => 'relsm__table', sub {
            Div class => 'relsm__rel', sub {
                my $rel = $_;

                Div class => 'relsm__rel-col relsm__rel-date tabular-nums', sub { ReleaseDate $rel->{released}; };
                A class => 'relsm__rel-col relsm__rel-name', href => "/r$rel->{id}", title => $rel->{original}||$rel->{title}, $rel->{title};
                Div class => 'relsm__rel-col relsm__rel-platforms', sub { Platform $_ for @{$rel->{platforms}} };
                Div class => 'relsm__rel-col relsm__rel-mylist', sub {
                    # TODO: Make this do something
                    Img class => 'svg-icon', src => tuwf->conf->{url_static}.'/v3/plus-circle.svg';
                };
                if($rel->{website}) {
                    Div class => 'relsm__rel-col relsm__rel-link', sub {
                        A href => $rel->{website}, 'Link';
                    };
                } else {
                    Div class => 'relsm__rel-col relsm__rel-link relsm__rel-link--none', 'Link';
                }

                # TODO: Age rating
                # TODO: Release type
                # TODO: Release icons
            } for grep grep($_ eq $lang, @{$_->{lang}}), @{$vn->{releases}};
        }
    }
}


sub Staff {
    my $vn = shift;
    return if !@{$vn->{staff}};

    my $Role = sub {
        my $role = shift;
        my @staff = grep $_->{role} eq $role, @{$vn->{staff}};
        return if !@staff;

        Div class => 'staff-credits__section', sub {
            Div class => 'staff-credits__section-title', $STAFF_ROLES{$role};
            Div class => 'staff-credits__item', sub {
                A href => "/s$_->{id}", title => $_->{original}||$_->{name}, $_->{name};
                Span class => 'staff-credits__note', " $_->{note}" if $_->{note};
            } for (@staff);
        };
    };

    Div class => 'section', id => 'staff', sub {
        H2 class => 'section__title', 'Staff';
        Div class => 'staff-credits js-columnize', 'data-columns' => 3, sub {
            $Role->($_) for keys %STAFF_ROLES;
        };
    };
}


sub Gallery {
    my $vn = shift;

    return if !@{$vn->{screenshots}};
    my $show = auth->pref('show_nsfw');

    Div mkclass(section => 1, gallery => 1, 'gallery--show-r18' => $show), id => 'gallery', sub {
        H2 class => 'section__title', sub {
            Switch '18+', $show, 'gallery-r18-toggle' => 1 if grep $_->{nsfw}, @{$vn->{screenshots}};
            Txt 'Gallery';
        };

        # TODO: Thumbnails are being upscaled, we should probably recreate all thumbnails at higher resolution

        Div class => 'gallery__section', sub {
            for my $s (@{$vn->{screenshots}}) {
                my $r = (grep $_->{id} == $s->{rid}, @{$vn->{releases}})[0];
                my $meta = {
                    width  => 1*$s->{width},
                    height => 1*$s->{height},
                    rel    => {
                        id    => 1*$s->{rid},
                        title => $r->{title},
                        lang  => $r->{lang},
                        plat  => $r->{platforms},
                    }
                };

                A mkclass('gallery__image-link' => 1, 'gallery__image--r18' => $s->{nsfw}),
                    'data-lightbox-nfo' => JSON::XS->new->encode($meta),
                    href => tuwf->imgurl(sf => $s->{scr}),
                sub {
                    Img mkclass(gallery__image => 1, 'nsfw-outline' => $s->{nsfw}), src => tuwf->imgurl(st => $s->{scr});
                }
            }
        }
    };
}


sub CharacterList {
    my($vn, $roles, $first_char) = @_;

    # TODO: Implement spoiler & sexual stuff settings
    # TODO: Make long character lists collapsable

    Div class => 'character-browser__top-item dropdown', sub {
        A href => 'javascript:;', class => 'link--subtle dropdown__toggle', sub {
            Txt spoil_display 0;
            Lit ' ';
            Span class => 'caret', '';
        };
        Div class => 'dropdown-menu', sub {
            A class => 'dropdown-menu__item', href => 'javascript:;', spoil_display 0;
            A class => 'dropdown-menu__item', href => 'javascript:;', spoil_display 1;
            A class => 'dropdown-menu__item', href => 'javascript:;', spoil_display 2;
        };
    };
    Div class => 'character-browser__top-item d-none d-md-block', sub { Switch 'Sexual traits', 0 };
    Div class => 'character-browser__top-item', sub {
        A href => "/v$vn->{id}/chars", 'View all on one page';
    };

    Div class => 'character-browser__list', sub {
        Div class => 'character-browser__list-title', char_role_display $_, scalar @{$roles->{$_}};
        A mkclass('character-browser__char' => 1, 'character-browser__char--active' => $_->{id} == $first_char),
            href => "/c$_->{id}", title => $_->{original}||$_->{name}, 'data-character' => $_->{id}, $_->{name}
            for @{$roles->{$_}};
    } for grep @{$roles->{$_}}, char_roles;
}


sub CharacterInfo {
    my $char = shift;

    Div class => 'row', sub {
        Div class => 'col-md', sub {
            # TODO: Gender & blood type
            Div class => 'character__name', $char->{name};
            Div class => 'character__subtitle', $char->{original} if $char->{original};
            Div class => 'character__description serif', sub {
                P sub { Lit bb2html $char->{desc}, 0, 1 };
            };
        };
        Div class => 'col-md character__image', sub {
            Img class => 'img img--fit img--rounded',
                src => tuwf->imgurl(ch => $char->{image})
        } if $char->{image};
    };

    my(%groups, @groups);
    for(@{$char->{traits}}) {
        push @groups, $_->{gid} if !$groups{$_->{gid}};
        push @{$groups{$_->{gid}}}, $_;
    }

    # Create a list of key/value things, so that we can neatly split them in
    # two. The split occurs on the number of sections, so long sections can
    # still cause some imbalance.
    # TODO: Date of birth?
    my @traits = (
        $char->{alias} ? sub {
            Dt 'Aliases';
            Dd $char->{alias} =~ s/\n/, /gr;
        } : (),

        $char->{weight} || $char->{height} || $char->{s_bust} || $char->{s_waist} || $char->{s_hip} ? sub {
            Dt 'Measurements';
            Dd join ', ',
                $char->{height} ? "Height: $char->{height}cm" : (),
                $char->{weight} ? "Weight: $char->{weight}kg" : (),
                $char->{s_bust} || $char->{s_waist} || $char->{s_hip} ?
                    sprintf 'Bust-Waist-Hips: %s-%s-%scm', $char->{s_bust}||'??', $char->{s_waist}||'??', $char->{s_hip}||'??' : ();
        } : (),

        # TODO: Do something with spoiler settings.
        (map { my $g = $_; sub {
            Dt sub { A href => "/i$g", $groups{$g}[0]{group} };
            Dd sub {
                Join ', ', sub {
                    A href => "/i$_[0]{tid}", $_[0]{name};
                }, @{$groups{$g}};
            };
        } } @groups),

        @{$char->{seiyuu}} ? sub {
            Dt 'Voiced by';
            Dd sub {
                my $prev = '';
                for my $s (sort { $a->{name} cmp $b->{name} } @{$char->{seiyuu}}) {
                    next if $s->{name} eq $prev;
                    A href => "/s$s->{id}", title => $s->{original}||$s->{name}, $s->{name};
                    Txt ' ('.$s->{note}.')' if $s->{note};
                }
            };
        } : (),
    );

    Div class => 'character__traits row mt-4', sub {
        Dl class => 'col-md dl--horizontal', sub { $_->() for @traits[0..$#traits/2]; };
        Dl class => 'col-md dl--horizontal', sub { $_->() for @traits[$#traits/2+1..$#traits]; };
    } if @traits;
}


sub Characters {
    my $vn = shift;

    # XXX: Fetching and rendering all character details on the VN page is a bit
    # inefficient and bloats the HTML. We should probably load data from other
    # characters on demand.

    my $chars = tuwf->dbAlli(q{
        SELECT id, name, original, alias, image, "desc", gender, s_bust, s_waist, s_hip,
               b_month, b_day, height, weight, bloodt
          FROM chars
         WHERE NOT hidden
           AND id IN(SELECT id FROM chars_vns WHERE vid =}, \$vn->{id}, q{)
         ORDER BY name
    });
    return if !@$chars;

    enrich_list releases => id => id =>
        sql('SELECT id, rid, spoil, role FROM chars_vns WHERE vid =', \$vn->{id}, ' AND id IN'),
        $chars;

    # XXX: Just fetching this list takes ~10ms for a large VN (v92). I worry
    # about formatting and displaying it on every page view. (This query can
    # probably be sped up by grabbing/caching the group tag names separately,
    # there are only 12 groups in the DB anyway).
    enrich_list traits => id => id => sub {sql q{
        SELECT ct.id, ct.tid, ct.spoil, t.name, t.sexual, g.id AS gid, g.name AS group, g.order
          FROM chars_traits ct
          JOIN traits t ON t.id = ct.tid
          JOIN traits g ON g.id = t.group
         WHERE ct.id IN}, $_[0], q{
         ORDER BY g.order, t.name
    }}, $chars;

    enrich_list seiyuu => id => cid => sub{sql q{
        SELECT va.id, vs.aid, vs.cid, vs.note, va.name, va.original
          FROM vn_seiyuu_hist vs JOIN staff_alias va ON va.aid = vs.aid
         WHERE vs.chid =}, \$vn->{chid}
    }, $chars;

    my %done;
    my %roles = map {
        my $r = $_;
        ($r, [ grep grep($_->{role} eq $r, @{$_->{releases}}) && !$done{$_->{id}}++, @$chars ]);
    } char_roles;

    my($first_char) = map @{$roles{$_}} ? $roles{$_}[0]{id} : (), char_roles;

    Div class => 'section', id => 'characters', sub {
        H2 class => 'section__title', sub { Txt 'Characters'; Debug \%roles };
        Div class => 'character-browser', sub {
            Div class => 'row', sub {
                Div class => 'fixed-size-left-sidebar-md', sub {
                    Div class => 'character-browser__top-items', sub { CharacterList $vn, \%roles, $first_char; }
                };
                Div class => 'col-md col-md--3 d-none d-md-block', sub {
                    Div mkclass(character => 1, 'd-none' => $_->{id} != $first_char), 'data-character' => $_->{id},
                        sub { CharacterInfo $_ }
                        for @$chars;
                };
            };
        };
    };
}


sub Stats {
    my $vn = shift;

    my($has_data, $Dist) = VoteGraph v => $vn->{id};
    return if !$has_data;

    my $recent_votes = tuwf->dbAlli(q{
        SELECT v.vid, v.vote,}, sql_totime('v.date'), q{AS date, u.id, u.username
          FROM votes v JOIN users u ON u.id = v.uid
         WHERE NOT EXISTS(SELECT 1 FROM users_prefs WHERE uid = u.id AND key = 'hide_list')
           AND NOT u.ign_votes
           AND v.vid =}, \$vn->{id}, q{
         ORDER BY v.date DESC LIMIT 10
    });
    my $Recent = sub {
        H4 'Recent votes';
        Div class => 'recent-votes', sub {
            Table class => 'recent-votes__table tabular-numbs', sub {
                Tbody sub {
                    Tr sub {
                        Td sub { A href => "/u$_->{id}", $_->{username}; };
                        Td vote_display $_->{vote};
                        Td date_display $_->{date};
                    } for @$recent_votes;
                };
            };
            Div class => 'final-text', sub {
                A href => "/v$vn->{id}/votes", 'All votes';
            };
        };
    };


    my $popularity_rank = tuwf->dbVali(
        'SELECT COUNT(*)+1 FROM vn WHERE NOT hidden AND c_popularity >',
        \($vn->{c_popularity}||0)
    );
    my $rating_rank = tuwf->dbVali(
        'SELECT COUNT(*)+1 FROM vn WHERE NOT hidden AND c_rating >',
        \($vn->{c_rating}||0)
    );

    my $Popularity = sub {
        H4 'Ranking';
        Dl class => 'stats__ranking', sub {
            Dt 'Popularity';
            Dd sprintf 'ranked #%d with a score of %.2f', $popularity_rank, 100*($vn->{c_popularity}||0);
            Dt 'Bayesian rating';
            Dd sprintf 'ranked #%d with a rating of %.2f', $rating_rank, $vn->{c_rating}/10;
        };
        Div class => 'final-text', sub {
            A href => '/v/all', 'See best rated games';
        };
    };


    Div class => 'section stats', id => 'stats', sub {
        H2 class => 'section__title', 'Stats';
        Div class => 'row semi-muted', sub {
            Div class => 'stats__col col-md col-md-1', sub {
                H4 'Vote distribution';
                $Dist->();
            };
            Div class => 'stats__col col-md col-md-1', $Recent if @$recent_votes;
            Div class => 'stats__col col-md col-md-1', $Popularity;
        };
    };
}


sub Contents {
    my $vn = shift;

    Div class => 'vn-page', sub {
        Div class => 'row', sub {
            Div class => 'col-md', sub {
                Div class => 'row', sub {
                    Div class => 'fixed-size-left-sidebar-md vn-page__top-details', sub { Sidebar $vn };
                    Div class => 'fixed-size-left-sidebar-md', '';
                    Div class => 'col-md', sub {
                        Div class => 'description serif', id => 'about', sub {
                            P sub { Lit bb2html $vn->{desc}||'No description.' };
                        };
                        Div class => 'section', id => 'tags', sub {
                            Div class => 'tag-summary', sub { Tags $vn };
                        };
                        Div class => 'section', id => 'releases', sub {
                            H2 class => 'section__title', 'Releases';
                            Div class => 'relsm', sub { Releases $vn };
                        };
                        Staff $vn;
                        Gallery $vn;
                    };
                };
            };
        };
        Div class => 'row', sub {
            Div class => 'col-xxl', sub {
                Characters $vn;
                Stats $vn;
            };
        };
    };
}


TUWF::get qr{/$VREV_RE}, sub {
    my $vn = entry v => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    return tuwf->resNotFound if !$vn->{id} || $vn->{hidden};

    enrich id => q{SELECT id, rgraph, c_languages::text[], c_popularity, c_rating, c_votecount FROM vn WHERE id IN}, $vn;
    enrich scr => q{SELECT id AS scr, width, height FROM screenshots WHERE id IN}, $vn->{screenshots};
    enrich vid => q{SELECT id AS vid, title, original FROM vn WHERE id IN}, $vn->{relations};
    enrich aid => q{SELECT aid, id, name, original FROM staff_alias WHERE aid IN}, $vn->{staff};

    enrich_list releases => id => vid => sub {sql q{
        SELECT rv.vid, r.id, r.title, r.original, r.type, r.website, r.released, r.notes,
               r.minage, r.patch, r.freeware, r.doujin, r.resolution, r.voiced, r.ani_story, r.ani_ero
          FROM releases r
          JOIN releases_vn rv ON r.id = rv.id
         WHERE NOT r.hidden AND rv.vid IN}, $_[0], q{
         ORDER BY r.released
    }}, $vn;

    enrich_list1 platforms => id => id => 'SELECT id, platform FROM releases_platforms WHERE id IN', $vn->{releases};
    enrich_list1 lang => id => id => 'SELECT id, lang FROM releases_lang WHERE id IN', $vn->{releases};
    enrich_list media => id => id => 'SELECT id, medium, qty FROM releases_media WHERE id IN', $vn->{releases};

    Framework
        og => {
            description => bb2text($vn->{desc}),
            $vn->{image} && !$vn->{img_nsfw} ? (
                image => tuwf->imgurl(cv => $vn->{image})
            ) : (($_) = grep !$_->{nsfw}, @{$vn->{screenshots}}) ? (
                image => tuwf->imgurl(st => $_->{scr})
            ) : ()
        },
        title => $vn->{title},
        top => sub { Top $vn },
        sub { Contents $vn };
};

1;
