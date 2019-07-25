package VN3::Char::Page;

use VN3::Prelude;
use List::Util 'all', 'min';

sub Top {
    my $e = shift;

    my $img = $e->{image} && tuwf->imgurl(ch => $e->{image});

    Div class => 'fixed-size-left-sidebar-md', sub {
        Img class => 'page-header-img-mobile img img--rounded d-md-none', src => $img;
        Div class => 'detail-header-image-container', sub {
            Img class => 'img img--fit img--rounded elevation-1 d-none d-md-block detail-header-image', src => $img;
        };
    } if $img;

    Div class => 'col-md', sub {
        EntryEdit c => $e;
        Div class => 'detail-page-title', sub {
            Txt $e->{name};
            Txt ' '.gender_icon $e->{gender};
            Txt ' '.blood_type_display $e->{bloodt} if $e->{bloodt} ne 'unknown';
            Debug $e;
        };
        Div class => 'detail-page-subtitle', $e->{original} if $e->{original};
    };
}


sub Settings {
    my $spoil = auth->pref('spoilers') || 0;
    my $ero   = auth->pref('traits_sexual');

    Div class => 'page-inner-controls', id => 'charpage_settings', sub {
        Div class => 'page-inner-controls__option dropdown', sub {
            A href => 'javascript:;', class => 'link--subtle dropdown__toggle', sub {
                Span class => 'page-inner-controls__option-spoil', spoil_display $spoil;
                Lit ' ';
                Span class => 'caret', '';
            };
            Div class => 'dropdown-menu', sub {
                A class => 'dropdown-menu__item page-inner-controls__option-spoil-0', href => 'javascript:;', spoil_display 0;
                A class => 'dropdown-menu__item page-inner-controls__option-spoil-1', href => 'javascript:;', spoil_display 1;
                A class => 'dropdown-menu__item page-inner-controls__option-spoil-2', href => 'javascript:;', spoil_display 2;
            };
        };
        Div class => 'page-inner-controls__option', sub {
            Switch 'Sexual traits', $ero, 'page-inner-controls__option-ero' => 1;
        };
    };
}


sub Description {
    my $e = shift;

    Div class => 'row', sub {
        Div class => 'fixed-size-left-sidebar-md', sub {
            if($e->{image}) {
                # second copy of image to ensure there's enough space (uh, mkay)
                Img class => 'img img--fit d-none d-md-block detail-header-image-push', src => tuwf->imgurl(ch => $e->{image});
            } else {
                H3 class => 'detail-page-sidebar-section-header', 'Description';
            }
        };
        Div class => 'col-md', sub {
            Div class => 'description serif mb-5', sub {
                P sub { Lit bb2html $e->{desc} };
            };
        };
    } if $e->{desc};
}


sub DetailsTable {
    my $e = shift;

    my(%groups, @groups);
    for(@{$e->{traits}}) {
        push @groups, $_->{gid} if !$groups{$_->{gid}};
        push @{$groups{$_->{gid}}}, $_;
    }

    # TODO: This was copy-pasted from VN::Page, need to consolidate (...once we figure out how to actually display chars on the VN page)
    my @list = (
        $e->{alias} ? sub {
            Dt 'Aliases';
            Dd $e->{alias} =~ s/\n/, /gr;
        } : (),

        defined $e->{weight} || $e->{height} || $e->{s_bust} || $e->{s_waist} || $e->{s_hip} ? sub {
            Dt 'Measurements';
            Dd join ', ',
                $e->{height} ? "Height: $e->{height}cm" : (),
                defined $e->{weight} ? "Weight: $e->{weight}kg" : (),
                $e->{s_bust} || $e->{s_waist} || $e->{s_hip} ?
                    sprintf 'Bust-Waist-Hips: %s-%s-%scm', $e->{s_bust}||'??', $e->{s_waist}||'??', $e->{s_hip}||'??' : ();
        } : (),

        $e->{b_month} && $e->{b_day} ? sub {
            Dt 'Birthday';
            Dd sprintf '%d %s', $e->{b_day}, [qw{January February March April May June July August September October November December}]->[$e->{b_month}-1];
        } : (),

        # XXX: Group visibility is determined by the same 'charpage--x' classes
        # as the individual traits (group is considered 'ero' if all traits are
        # ero, and the lowest trait spoiler determines group spoiler level).
        # But this has an unfortunate special case that isn't handled: A trait
        # with (ero && spoil>0) in a group that isn't itself (ero && spoil>0)
        # will display an empty group if settings are (ero && spoil==0).
        # XXX#2: I'd rather have the traits delimited by a comma, but that's a
        # hard problem to solve in combination with the dynamic hiding of
        # traits.
        (map { my $g = $_; sub {
            my @c = mkclass
                'charpage--ero' => (all { $_->{sexual} } @{$groups{$g}}),
                sprintf('charpage--spoil-%d', min map $_->{spoil}, @{$groups{$g}}) => 1;

            Dt @c, sub { A href => "/i$g", $groups{$g}[0]{group} };
            Dd @c, sub {
                Join ' ', sub {
                    A mkclass('trait-summary--trait' => 1, 'charpage--ero' => $_[0]{sexual}, sprintf('charpage--spoil-%d', $_[0]{spoil}), 1),
                        style => 'padding-right: 15px; white-space: nowrap',
                        href => "/i$_[0]{tid}", $_[0]{name}
                }, @{$groups{$g}};
            };
        } } @groups),
    );

    Div class => 'row', sub {
        Div class => 'fixed-size-left-sidebar-md', sub {
            H2 class => 'detail-page-sidebar-section-header', 'Details';
        };
        Div class => 'col-md', sub {
            Div class => 'card card--white mb-5', sub {
                Div class => 'card__section fs-medium', sub {
                    Div class => 'row', sub {
                        Dl class => 'col-md dl--horizontal', sub { $_->() for @list[0..$#list/2] };
                        Dl class => 'col-md dl--horizontal', sub { $_->() for @list[$#list/2+1..$#list] };
                    }
                }
            }
        }
    } if @list;
}


sub VNs {
    my $e = shift;

    # TODO: Maybe this table should be full-width?
    # TODO: Improved styling of release rows

    my $rows = sub {
        for my $vn (@{$e->{vns}}) {
            Tr class => sprintf('charpage--spoil-%d', $vn->{spoil}), sub {
                Td class => 'tabular-nums muted', sub { ReleaseDate $vn->{c_released} };
                Td sub {
                    A href => "/v$vn->{vid}", title => $vn->{original}||$vn->{title}, $vn->{title};
                };
                Td $vn->{releases}[0]{rid} ? '' : join ', ', map char_role_display($_->{role}), @{$vn->{releases}};
                Td sub {
                    Join ', ', sub {
                        A href => "/s$_[0]{sid}", title => $_[0]{original}||$_[0]{name}, $_[0]{name};
                        Span class => 'muted', " ($_[0]{note})" if $_[0]{note};
                    }, @{$vn->{seiyuu}};
                }
            };
            for my $rel ($vn->{releases}[0]{rid} ? @{$vn->{releases}} : ()) {
                Tr class => sprintf('charpage--spoil-%d', $rel->{spoil}), sub {
                    Td class => 'tabular-nums muted', $rel->{rid} ? sub { Lit '&nbsp;&nbsp;'; ReleaseDate $rel->{released} } : '';
                    Td sub {
                        Span class => 'muted', '» ';
                        A href => "/r$rel->{rid}", title => $rel->{title}||$rel->{original}, $rel->{title} if $rel->{rid};
                        Span class => 'muted', 'Other releases' if !$rel->{rid};
                    };
                    Td char_role_display $rel->{role};
                    Td '';
                };
            }
        }
    };

    Div class => 'row', sub {
        Div class => 'fixed-size-left-sidebar-md', sub {
            H2 class => 'detail-page-sidebar-section-header', 'Visual Novels';
        };
        Div class => 'col-md', sub {
            Div class => 'card card--white mb-5', sub {
                Table class => 'table table--responsive-single-sm fs-medium', sub {
                    Thead sub {
                        Tr sub {
                            Th width => '15%', 'Date';
                            Th width => '40%', 'Title';
                            Th width => '20%', 'Role';
                            Th width => '25%', 'Voiced by';
                        };
                    };
                    Tbody $rows;
                };
            }
        }
    }
}


sub Instances {
    my $e = shift;

    return if !@{$e->{instances}};

    my $minspoil = min map $_->{spoiler}, @{$e->{instances}};

    Div class => sprintf('row charpage--spoil-%d', $minspoil), sub {
        Div class => 'fixed-size-left-sidebar-md', sub {
            H2 class => 'detail-page-sidebar-section-header', 'Other instances';
        };
        Div class => 'col-md', sub {
            for my $c (@{$e->{instances}}) {
                A class => sprintf('card card--white character-card mb-3 charpage--spoil-%d', $c->{spoiler}), href => "/c$c->{id}", sub {
                    Div class => 'character-card__left', sub {
                        Div class => 'character-card__image-container', sub {
                            Img class => 'character-card__image', src => tuwf->imgurl(ch => $c->{image}) if $c->{image};
                        };
                        Div class => 'character-card__main', sub {
                            Div class => 'character-card__name', sub {
                                Txt $c->{name};
                                Txt ' '.gender_icon $c->{gender};
                                Txt ' '.blood_type_display $c->{bloodt} if $c->{bloodt} ne 'unknown';
                            };
                            Div class => 'character-card__sub-name', $c->{original} if $c->{original};
                            Div class => 'character-card__vns muted single-line', join ', ', map $_->{title}, @{$c->{vns}} if @{$c->{vns}};
                        };
                        Div class => 'character-card__right serif semi-muted', sub {
                            Lit bb2text $c->{desc}; # TODO: maxlength?
                        };
                    }
                }
            }
        };
    };
}


TUWF::get qr{/$CREV_RE}, sub {
    my $e = entry c => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    return tuwf->resNotFound if !$e->{id} || $e->{hidden};

    enrich tid => q{
        SELECT t.id AS tid, t.name, t.sexual, g.id AS gid, g.name AS group, g.order
          FROM traits t
          JOIN traits g ON g.id = t.group
         WHERE t.id IN
    }, $e->{traits};

    $e->{traits} = [ sort { $a->{order} <=> $b->{order} || $a->{name} cmp $b->{name} } @{$e->{traits}} ];

    $e->{vns} = tuwf->dbAlli(q{
        SELECT cv.vid, v.title, v.original, v.c_released, MIN(cv.spoil) AS spoil
          FROM chars_vns_hist cv
          JOIN vn v ON cv.vid = v.id
         WHERE cv.chid =}, \$e->{chid}, q{
         GROUP BY v.c_released, cv.vid, v.title, v.original
         ORDER BY v.c_released, cv.vid
    });

    enrich_list releases => vid => vid => sub {sql q{
        SELECT cv.rid, cv.vid, cv.role, cv.spoil, r.title, r.original, r.released
          FROM chars_vns_hist cv
          LEFT JOIN releases r ON r.id = cv.rid
         WHERE cv.chid =}, \$e->{chid}, q{
         ORDER BY r.released, r.id
    }}, $e->{vns};

    enrich_list seiyuu => vid => vid => sub {sql q{
        SELECT vs.id AS vid, vs.note, sa.id AS sid, sa.aid, sa.name, sa.original
          FROM vn_seiyuu vs
          JOIN staff_alias sa ON vs.aid = sa.aid
         WHERE vs.cid =}, \$e->{id}, q{
         ORDER BY sa.name, sa.aid
    }}, $e->{vns};

    $e->{instances} = tuwf->dbAlli(q{
        SELECT id, name, original, image, gender, bloodt, "desc",
               (CASE WHEN id =}, \$e->{main}, THEN => \$e->{main_spoil}, q{ELSE main_spoil END) AS spoiler
          FROM chars
         WHERE NOT hidden
           AND id <>}, \$e->{id}, q{
           AND (  main =}, \$e->{id}, q{
               OR main =}, \$e->{main}, q{
               OR id =}, \$e->{main}, q{
               )
         ORDER BY name, id
    });
    enrich_list vns => id => cid => sub {sql q{
        SELECT cv.id AS cid, v.id, v.title
          FROM chars_vns cv
          JOIN vn v ON v.id = cv.vid
         WHERE cv.id IN}, $_[0], q{
           AND cv.spoil = 0
         GROUP BY v.id, cv.id, v.title
         ORDER BY MIN(cv.role), v.title, v.id
    }}, $e->{instances};

    my $spoil = auth->pref('spoilers') || 0;
    my $ero   = auth->pref('traits_sexual');

    Framework
        og => {
            description => bb2text($e->{desc}),
            $e->{image} ? (image => tuwf->imgurl(ch => $e->{image})) : ()
        },
        title => $e->{name},
        main_classes => {
            'charpage--hide-spoil-1' => $spoil < 1,
            'charpage--hide-spoil-2' => $spoil < 2,
            'charpage--hide-ero'     => !$ero
        },
        top => sub { Top $e },
        sub {
            Settings $e;
            Description $e;
            DetailsTable $e;
            VNs $e;
            Instances $e;
        };
};

1;
