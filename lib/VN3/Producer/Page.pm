package VN3::Producer::Page;

use VN3::Prelude;

# TODO: Releases/VNs
# TODO: Relation graph

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
        $e->{website} ? [ 'Official website', $e->{website}                              ] : (),
        $e->{l_wp}    ? [ 'Wikipedia',        "https://en.wikipedia.org/wiki/$e->{l_wp}" ] : (),
    );

    my %rel;
    push @{$rel{$_->{relation}}}, $_ for (sort { $a->{name} cmp $b->{name} } @{$e->{relations}});

    my @list = (
        $e->{alias} ? sub {
            Dt $e->{alias} =~ /\n/ ? 'Aliases' : 'Alias';
            Dd $e->{alias} =~ s/\n/, /gr;
        } : (),

        sub {
            Dt 'Type';
            Dd $PRODUCER_TYPE{$e->{type}};
        },

        sub {
            Dt 'Language';
            Dd sub {
                Lang $e->{lang};
                Txt " $LANGUAGE{$e->{lang}}";
            }
        },

        @links ? sub {
            Dt 'Links';
            Dd sub {
                Join ', ', sub { A href => $_[0][1], rel => 'nofollow', $_[0][0] }, @links;
            };
        } : (),

        (map {
            my $r = $_;
            sub {
                Dt producer_relation_display $r;
                Dd sub {
                    Join ', ', sub {
                        A href => "/p$_[0]{pid}", title => $_[0]{original}||$_[0]{name}, $_[0]{name};
                    }, @{$rel{$r}}
                }
            }
        } grep $rel{$_}, keys %PRODUCER_RELATION)
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


TUWF::get qr{/$PREV_RE}, sub {
    my $e = entry p => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    return tuwf->resNotFound if !$e->{id} || $e->{hidden};

    enrich pid => q{SELECT id AS pid, name, original FROM producers WHERE id IN}, $e->{relations};

    Framework
        title => $e->{name},
        top => sub {
            Div class => 'col-md', sub {
                EntryEdit p => $e;
                Div class => 'detail-page-title', sub {
                    Txt $e->{name};
                    Debug $e;
                };
                Div class => 'detail-page-subtitle', $e->{original} if $e->{original};
                # TODO: link to discussions page. Prolly needs a TopNav
            }
        },
        sub {
            DetailsTable $e;
            Notes $e;
        };
};

1;
