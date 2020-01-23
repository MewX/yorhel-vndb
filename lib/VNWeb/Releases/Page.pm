package VNWeb::Releases::Page;

use VNWeb::Prelude;


sub enrich_item {
    my($r) = @_;

    enrich_merge pid => 'SELECT id AS pid, name, original FROM producers WHERE id IN', $r->{producers};
    enrich_merge vid => 'SELECT id AS vid, title, original FROM vn WHERE id IN', $r->{vn};

    $r->{lang}      = [ sort map $_->{lang},     $r->{lang}->@*      ];
    $r->{platforms} = [ sort map $_->{platform}, $r->{platforms}->@* ];
    $r->{vn}        = [ sort { $a->{title}  cmp $b->{title}  || $a->{vid} <=> $b->{vid} } $r->{vn}->@*        ];
    $r->{producers} = [ sort { $a->{name}   cmp $b->{name}   || $a->{pid} <=> $b->{pid} } $r->{producers}->@* ];
    $r->{media}     = [ sort { $a->{medium} cmp $b->{medium} || $a->{qty} <=> $b->{qty} } $r->{media}->@*     ];
}


sub _rev_ {
    my($r) = @_;
    revision_ r => $r, \&enrich_item,
        [ vn         => 'Relations', fmt => sub { a_ href => "/v$_->{vid}", title => $_->{original}||$_->{title}, $_->{title} } ],
        [ type       => 'Type' ],
        [ patch      => 'Patch',           fmt => 'bool' ],
        [ freeware   => 'Freeware',        fmt => 'bool' ],
        [ doujin     => 'Doujin',          fmt => 'bool' ],
        [ uncensored => 'Uncensored',      fmt => 'bool' ],
        [ title      => 'Title (Romaji)' ],
        [ original   => 'Original title' ],
        [ gtin       => 'JAN/EAN/UPC',     empty => 0 ],
        [ catalog    => 'Catalog number' ],
        [ lang       => 'Languages',       fmt => \%LANGUAGE ],
        [ released   => 'Release date',    fmt => sub { rdate_ $_ } ],
        [ minage     => 'Age rating',      fmt => sub { txt_ minage $_ } ],
        [ notes      => 'Notes' ],
        [ platforms  => 'Platforms',       fmt => \%PLATFORM ],
        [ media      => 'Media',           fmt => sub { txt_ fmtmedia $_->{medium}, $_->{qty}; } ],
        [ resolution => 'Resolution',      fmt => \%RESOLUTION ],
        [ voiced     => 'Voiced',          fmt => \%VOICED ],
        [ ani_story  => 'Story animation', fmt => \%ANIMATED ],
        [ ani_ero    => 'Ero animation',   fmt => \%ANIMATED ],
        [ engine     => 'Engine' ],
        [ producers  => 'Producers',       fmt => sub {
            a_ href => "/p$_->{pid}", title => $_->{original}||$_->{name}, $_->{name};
            txt_ ' (';
            txt_ join ', ', $_->{developer} ? 'developer' : (), $_->{publisher} ? 'publisher' : ();
            txt_ ')';
        } ],
        revision_extlinks 'r'
}


sub _infotable_ {
    my($r) = @_;

    table_ class => 'stripe', sub {
        tr_ sub {
            td_ class => 'key', 'Relation';
            td_ sub {
                join_ \&br_, sub {
                    a_ href => "/v$_->{vid}", title => $_->{original}||$_->{title}, $_->{title};
                }, $r->{vn}->@*
            }
        };

        tr_ sub {
            td_ 'Title';
            td_ $r->{title};
        };

        tr_ sub {
            td_ 'Original title';
            td_ lang_attr($r->{lang}), $r->{original};
        } if $r->{original};

        tr_ sub {
            td_ 'Type';
            td_ sub {
                abbr_ class => "icons rt$r->{type}", title => $r->{type}, ' ';
                txt_ ' '.$RELEASE_TYPE{$r->{type}};
                txt_ ', patch' if $r->{patch};
            }
        };

        tr_ sub {
            td_ 'Language';
            td_ sub {
                join_ \&br_, sub {
                    abbr_ class => "icons lang $_", title => $LANGUAGE{$_}, ' ';
                    txt_ ' '.$LANGUAGE{$_};
                }, $r->{lang}->@*;
            }
        };

        tr_ sub {
            td_ 'Publication';
            td_ join ', ',
                $r->{freeware} ? 'Freeware' : 'Non-free',
                $r->{patch} ? () : ($r->{doujin} ? 'doujin' : 'commercial');
        };

        tr_ sub {
            td_ 'Platform'.($r->{platforms}->@* == 1 ? '' : 's');
            td_ sub {
                join_ \&br_, sub {
                    abbr_ class => "icons $_", title => $PLATFORM{$_}, ' ';
                    txt_ ' '.$PLATFORM{$_};
                }, $r->{platforms}->@*;
            }
        } if $r->{platforms}->@*;

        tr_ sub {
            td_ $r->{media}->@* == 1 ? 'Medium' : 'Media';
            td_ sub {
                join_ \&br_, sub { txt_ fmtmedia $_->{medium}, $_->{qty} }, $r->{media}->@*;
            }
        } if $r->{media}->@*;

        tr_ sub {
            td_ 'Resolution';
            td_ $RESOLUTION{$r->{resolution}}{txt};
        } if $r->{resolution} ne 'unknown';

        tr_ sub {
            td_ 'Voiced';
            td_ $VOICED{$r->{voiced}}{txt};
        } if $r->{voiced};

        tr_ sub {
            td_ 'Animation';
            td_ sub {
                join_ \&br_, sub { txt_ $_ },
                    $r->{ani_story} ? "Story: $ANIMATED{$r->{ani_story}}{txt}" : (),
                    $r->{ani_ero}   ? "Ero scenes: $ANIMATED{$r->{ani_ero}}{txt}" : ();
            }
        } if $r->{ani_story} || $r->{ani_ero};

        tr_ sub {
            td_ 'Engine';
            td_ sub {
                # TODO: Should not rely on legacy VNDB::* functions!
                a_ href => '/r?fil='.VNDB::Util::Misc::fil_serialize({engine => $r->{engine}}), $r->{engine};
            }
        } if length $r->{engine};

        tr_ sub {
            td_ 'Released';
            td_ sub { rdate_ $r->{released} };
        };

        tr_ sub {
            td_ 'Age rating';
            td_ minage $r->{minage};
        } if $r->{minage} >= 0;

        tr_ sub {
            td_ 'Censoring';
            td_ $r->{uncensored} ? 'No optical censoring (e.g. mosaics)' : 'May include optical censoring (e.g. mosaics)';
        } if $r->{minage} == 18;

        for my $t (qw|developer publisher|) {
            my @prod = grep $_->{$t}, @{$r->{producers}};
            tr_ sub {
                td_ ucfirst($t).(@prod == 1 ? '' : 's');
                td_ sub {
                    join_ \&br_, sub {
                        a_ href => "/p$_->{pid}", title => $_->{original}||$_->{name}, $_->{name};
                    }, @prod
                }
            } if @prod;
        }

        tr_ sub {
            td_ gtintype($r->{gtin}) || 'GTIN';
            td_ $r->{gtin};
        } if $r->{gtin};

        tr_ sub {
            td_ 'Catalog no.';
            td_ $r->{catalog};
        } if $r->{catalog};

        tr_ sub {
            td_ 'Links';
            td_ sub {
                join_ ', ', sub { a_ href => $_->[1], $_->[0] }, $r->{extlinks}->@*;
            }
        } if $r->{extlinks}->@*;
    }
}


TUWF::get qr{/$RE{rrev}} => sub {
    my $r = db_entry r => tuwf->capture('id'), tuwf->capture('rev');
    return tuwf->resNotFound if !$r;

    enrich_item $r;
    enrich_extlinks r => $r;

    framework_ title => $r->{title}, index => !tuwf->capture('rev'), type => 'r', dbobj => $r, hiddenmsg => 1,
        og => {
            description => bb2text $r->{notes}
        },
    sub {
        _rev_ $r if tuwf->capture('rev');
        div_ class => 'mainbox release', sub {
            itemmsg_ r => $r;
            h1_ sub { txt_ $r->{title}; debug_ $r };
            h2_ class => 'alttitle', lang_attr($r->{lang}), $r->{original} if length $r->{original};
            _infotable_ $r;
            p_ class => 'description', sub { lit_ bb2html $r->{notes} } if $r->{notes};
        };
    };
};

1;
