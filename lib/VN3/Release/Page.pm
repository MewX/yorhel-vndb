package VN3::Release::Page;

use VN3::Prelude;

# TODO: Userlist options


sub Notes {
    my $e = shift;

    Div class => 'row', sub {
        Div class => 'fixed-size-left-sidebar-md', sub {
            H2 class => 'detail-page-sidebar-section-header', 'Notes';
        };
        Div class => 'col-md', sub {
            Div class => 'description serif mb-5', sub {
                P sub { Lit bb2html $e->{notes} };
            };
        };
    } if $e->{notes};
}


sub DetailsTable {
    my $e = shift;

    # TODO: Some of these properties could be moved into the title header thing
    # (type and languages, in particular)
    # (Not even sure this table format makes sense for all properties, there's gotta be a nicer way)
    my @list = (
        @{$e->{vn}} ? sub {
            Dt @{$e->{vn}} == 1 ? 'Visual Novel' : 'Visual Novels';
            Dd sub {
                Join \&Br, sub {
                    A href => "/v$_[0]{vid}", title => $_[0]{original}||$_[0]{title}, $_[0]{title};
                }, @{$e->{vn}};
            }
        } : (),

        sub {
            Dt 'Type';
            Dd sub {
                Txt ucfirst $e->{type};
                Txt ", patch" if $e->{patch};
            }
        },

        sub {
            Dt 'Released';
            Dd sub { ReleaseDate $e->{released} };
        },

        sub {
            Dt @{$e->{lang}} > 1 ? 'Languages' : 'Language';
            Dd sub {
                Join \&Br, sub {
                    Lang $_[0]{lang};
                    Txt " $LANGUAGE{$_[0]{lang}}";
                }, @{$e->{lang}};
            }
        },

        sub {
            Dt 'Publication';
            Dd join ', ',
                $e->{freeware} ? 'Freeware' : 'Non-free',
                $e->{patch} ? () : ($e->{doujin} ? 'doujin' : 'commercial')
        },

        $e->{minage} && $e->{minage} >= 0 ? sub {
            Dt 'Age rating';
            Dd minage_display $e->{minage};
        } : (),

        @{$e->{platforms}} ? sub {
            Dt @{$e->{platforms}} == 1 ? 'Platform' : 'Platforms';
            Dd sub {
                Join \&Br, sub {
                    Platform $_[0]{platform};
                    Txt " $PLATFORM{$_[0]{platform}}";
                }, @{$e->{platforms}};
            }
        } : (),

        @{$e->{media}} ? sub {
            Dt @{$e->{media}} == 1 ? 'Medium' : 'Media';
            Dd join ', ', map media_display($_->{medium}, $_->{qty}), @{$e->{media}};
        } : (),

        $e->{voiced} ? sub {
            Dt 'Voiced';
            Dd $VOICED[$e->{voiced}];
        } : (),

        $e->{ani_story} ? sub {
            Dt 'Story animation';
            Dd $ANIMATED[$e->{ani_story}];
        } : (),

        $e->{ani_ero} ? sub {
            Dt 'Ero animation';
            Dd $ANIMATED[$e->{ani_ero}];
        } : (),

        $e->{minage} && $e->{minage} == 18 ? sub {
            Dt 'Censoring';
            Dd $e->{uncensored} ? 'No optical censoring (e.g. mosaics)' : 'May include optical censoring (e.g. mosaics)';
        } : (),

        $e->{gtin} ? sub {
            Dt gtintype($e->{gtin}) || 'GTIN';
            Dd $e->{gtin};
        } : (),

        $e->{catalog} ? sub {
            Dt 'Catalog no.';
            Dd $e->{catalog};
        } : (),

        (map {
            my $type = $_;
            my @prod = grep $_->{$type}, @{$e->{producers}};
            @prod ? sub {
                Dt ucfirst($type) . (@prod == 1 ? '' : 's');
                Dd sub {
                    Join \&Br, sub {
                        A href => "/p$_[0]{pid}", title => $_[0]{original}||$_[0]{name}, $_[0]{name};
                    }, @prod;
                }
            } : ()
        } 'developer', 'publisher'),

        $e->{website} ? sub {
            Dt 'Links';
            Dd sub {
                A href => $e->{website}, rel => 'nofollow', 'Official website';
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


TUWF::get qr{/$RREV_RE}, sub {
    my $e = entry r => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    return tuwf->resNotFound if !$e->{id} || $e->{hidden};

    enrich vid => q{SELECT id AS vid, title, original FROM vn WHERE id IN}, $e->{vn};
    enrich pid => q{SELECT id AS pid, name, original  FROM producers WHERE id IN}, $e->{producers};

    Framework
        title => $e->{title},
        top => sub {
            Div class => 'col-md', sub {
                EntryEdit r => $e;
                Div class => 'detail-page-title', sub {
                    Txt $e->{title};
                    Debug $e;
                };
                Div class => 'detail-page-subtitle', $e->{original} if $e->{original};
            }
        },
        sub {
            DetailsTable $e;
            Notes $e;
        };
};

1;
