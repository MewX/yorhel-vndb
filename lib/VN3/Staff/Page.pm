package VN3::Staff::Page;

use VN3::Prelude;

sub Notes {
    my $e = shift;

    Div class => 'row', sub {
        Div class => 'fixed-size-left-sidebar-md', sub {
            H2 class => 'detail-page-sidebar-section-header', 'Notes';
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

    my @links = (
        $e->{l_site}    ? [ 'Official website', $e->{l_site}                               ] : (),
        $e->{l_wp}      ? [ 'Wikipedia',        "https://en.wikipedia.org/wiki/$e->{l_wp}" ] : (),
        $e->{l_twitter} ? [ 'Twitter',          "https://twitter.com/$e->{l_twitter}"      ] : (),
        $e->{l_anidb}   ? [ 'AniDB',            "http://anidb.net/cr$e->{l_anidb}"         ] : (),
    );
    my @alias = grep $_->{aid} != $e->{aid}, @{$e->{alias}};

    my @list = (
        @alias ? sub {
            Dt @alias > 1 ? 'Aliases' : 'Alias';
            Dd sub {
                Join \&Br, sub {
                    Txt $_[0]{name};
                    Txt " ($_[0]{original})" if $_[0]{original};
                }, sort { $a->{name} cmp $b->{name} || $a->{original} cmp $b->{original} } @alias;
            }
        } : (),

        sub {
            Dt 'Language';
            Dd sub {
                Lang $e->{lang};
                Txt " $LANG{$e->{lang}}";
            }
        },

        @links ? sub {
            Dt 'Links';
            Dd sub {
                Join ', ', sub { A href => $_[0][1], rel => 'nofollow', $_[0][0] }, @links;
            };
        } : (),
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


sub Roles {
    my $e = shift;

    my $roles = tuwf->dbAlli(q{
      SELECT sa.id, sa.aid, v.id AS vid, sa.name, sa.original, v.c_released, v.title, v.original AS t_original, vs.role, vs.note
        FROM vn_staff vs
        JOIN vn v ON v.id = vs.id
        JOIN staff_alias sa ON vs.aid = sa.aid
       WHERE sa.id =}, \$e->{id}, q{ AND NOT v.hidden
       ORDER BY v.c_released ASC, v.title ASC, vs.role ASC
    });
    return if !@$roles;

    my $rows = sub {
        for my $r (@$roles) {
            Tr sub {
                Td class => 'tabular-nums muted', sub { ReleaseDate $r->{c_released} };
                Td sub {
                    A href => "/v$r->{vid}", title => $r->{t_original}||$r->{title}, $r->{title};
                };
                Td $STAFF_ROLES{$r->{role}};
                Td title => $r->{original}||$r->{name}, $r->{name};
                Td $r->{note};
            };
        }
    };

    # TODO: Full-width table? It's pretty dense
    Div class => 'row', sub {
        Div class => 'fixed-size-left-sidebar-md', sub {
            H2 class => 'detail-page-sidebar-section-header', 'Credits';
            Debug $roles;
        };
        Div class => 'col-md', sub {
            Div class => 'card card--white mb-5', sub {
                Table class => 'table table--responsive-single-sm fs-medium', sub {
                    Thead sub {
                        Tr sub {
                            Th width => '15%', 'Date';
                            Th width => '30%', 'Title';
                            Th width => '20%', 'Role';
                            Th width => '20%', 'As';
                            Th width => '15%', 'Note';
                        };
                    };
                    Tbody $rows;
                };
            }
        }
    }
}


sub Cast {
    my $e = shift;

    my $cast = tuwf->dbAlli(q{
      SELECT sa.id, sa.aid, v.id AS vid, sa.name, sa.original, v.c_released, v.title, v.original AS t_original, c.id AS cid, c.name AS c_name, c.original AS c_original, vs.note
        FROM vn_seiyuu vs
        JOIN vn v ON v.id = vs.id
        JOIN chars c ON c.id = vs.cid
        JOIN staff_alias sa ON vs.aid = sa.aid
       WHERE sa.id =}, \$e->{id}, q{ AND NOT v.hidden
       ORDER BY v.c_released ASC, v.title ASC
    });
    return if !@$cast;

    my $rows = sub {
        for my $c (@$cast) {
            Tr sub {
                Td class => 'tabular-nums muted', sub { ReleaseDate $c->{c_released} };
                Td sub {
                    A href => "/v$c->{vid}", title => $c->{t_original}||$c->{title}, $c->{title};
                };
                Td sub {
                    A href => "/c$c->{cid}", title => $c->{c_original}||$c->{c_name}, $c->{c_name};
                };
                Td title => $c->{original}||$c->{name}, $c->{name};
                Td $c->{note};
            };
        }
    };

    # TODO: Full-width table? It's pretty dense
    Div class => 'row', sub {
        Div class => 'fixed-size-left-sidebar-md', sub {
            H2 class => 'detail-page-sidebar-section-header', 'Voiced Characters';
            Debug $cast;
        };
        Div class => 'col-md', sub {
            Div class => 'card card--white mb-5', sub {
                Table class => 'table table--responsive-single-sm fs-medium', sub {
                    Thead sub {
                        Tr sub {
                            Th width => '15%', 'Date';
                            Th width => '30%', 'Title';
                            Th width => '20%', 'Cast';
                            Th width => '20%', 'As';
                            Th width => '15%', 'Note';
                        };
                    };
                    Tbody $rows;
                };
            }
        }
    }
}


TUWF::get qr{/$SREV_RE}, sub {
    my $e = entry s => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    return tuwf->resNotFound if !$e->{id} || $e->{hidden};

    ($e->{name}, $e->{original}) = @{(grep $_->{aid} == $e->{aid}, @{$e->{alias}})[0]}{'name', 'original'};

    Framework
        title => $e->{name},
        top => sub {
            Div class => 'col-md', sub {
                EntryEdit s => $e;
                Div class => 'detail-page-title', sub {
                    Txt $e->{name};
                    Txt ' '.gender_icon $e->{gender};
                    Debug $e;
                };
                Div class => 'detail-page-subtitle', $e->{original} if $e->{original};
            }
        },
        sub {
            DetailsTable $e;
            Notes $e;
            Roles $e;
            Cast $e;
        };
};

1;
