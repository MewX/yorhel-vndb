# Convention:
#   All HTML-generating functions are in CamelCase
#
# TODO: HTML generation for dropdowns can be abstracted more nicely.

package VN3::HTML;

use strict;
use warnings;
use v5.10;
use utf8;
use List::Util 'pairs', 'max', 'sum';
use TUWF ':Html5', 'mkclass', 'uri_escape';
use VN3::Auth;
use VN3::Types;
use VN3::Validation;
use base 'Exporter';

our @EXPORT = qw/Framework EntryEdit Switch Debug Join FullPageForm VoteGraph ListIcon GridIcon/;


sub Navbar {
    Div class => 'nav navbar__nav navbar__main-nav', sub {
        Div class => 'nav__item navbar__menu dropdown', sub {
            A href => 'javascript:;', class => 'nav__link dropdown__toggle', sub { Txt 'Database '; Span class => 'caret', '' };
            Div class => 'dropdown-menu database-menu', sub {
                A class => 'dropdown-menu__item', href => '/v/all', 'Visual novels';
                A class => 'dropdown-menu__item', href => '/g',     'Tags';
                A class => 'dropdown-menu__item', href => '/c/all', 'Characters';
                A class => 'dropdown-menu__item', href => '/i',     'Traits';
                A class => 'dropdown-menu__item', href => '/p/all', 'Producers';
                A class => 'dropdown-menu__item', href => '/s/all', 'Staff';
                A class => 'dropdown-menu__item', href => '/r',     'Releases';
            };
        };
        Div class => 'nav__item navbar__menu', sub { A class => 'nav__link', href => '/d6', 'FAQ' };
        Div class => 'nav__item navbar__menu', sub { A class => 'nav__link', href => '/t',  'Forums' };
        Div class => 'nav__item navbar__menu dropdown', sub {
            A href => 'javascript:;', class => 'nav__link dropdown__toggle', sub { Txt 'Contribute '; Span class => 'caret', '' };
            Div class => 'dropdown-menu', sub {
                A class => 'dropdown-menu__item', href => '/hist',  'Recent changes';
                A class => 'dropdown-menu__item', href => '/v/add', 'Add Visual Novel';
                A class => 'dropdown-menu__item', href => '/p/add', 'Add Producer';
                A class => 'dropdown-menu__item', href => '/s/new', 'Add Staff';
            };
        };
        Div class => 'nav__item navbar__menu', sub {
            A href => '/v/all', class => 'nav__link', sub {
                Span class => 'icon-desc d-md-none', 'Search ';
                Img class => 'svg-icon', src => tuwf->conf->{url_static}.'/v3/heavy/search.svg';
            };
        };
    };

    Div class => 'nav navbar__nav', sub {
        my $notifies = auth && tuwf->dbVali('SELECT count(*) FROM notifications WHERE uid =', \auth->uid, 'AND read IS NULL');
        Div class => 'nav__item navbar__menu', sub {
            A href => '/'.auth->uid.'/notifies', class => 'nav__link notification-icon', sub {
                Span class => 'icon-desc d-md-none', 'Notifications ';
                Div class => 'icon-group', sub {
                    Img class => 'svg-icon', src => tuwf->conf->{url_static}.'/v3/bell.svg';
                    Div class => 'notification-icon__indicator', $notifies;
                };
            };
        } if $notifies;
        Div class => 'nav__item navbar__menu dropdown', sub {
            A href => 'javascript:;', class => 'nav__link dropdown__toggle', sub { Txt auth->username.' '; Span class => 'caret'; };
            Div class => 'dropdown-menu dropdown-menu--right', sub {
                my $id = auth->uid;
                A class => 'dropdown-menu__item', href => "/u$id",          'Profile';
                A class => 'dropdown-menu__item', href => "/u$id/edit",     'Settings';
                A class => 'dropdown-menu__item', href => "/u$id/list",     'List';
                A class => 'dropdown-menu__item', href => "/u$id/wish",     'Wishlist';
                A class => 'dropdown-menu__item', href => "/u$id/hist",     'Recent changes';
                A class => 'dropdown-menu__item', href => "/g/links?u=$id", 'Tags';
                Div class => 'dropdown__separator', '';
                A class => 'dropdown-menu__item', href => "/u$id/logout", 'Log out';
            };
        } if auth;
        if(!auth) {
            Div class => 'nav__item navbar__menu', sub { A class => 'nav__link', href => '/u/register', 'Register'; };
            Div class => 'nav__item navbar__menu', sub { A class => 'nav__link', href => '/u/login',    'Login'; };
        }
    };
}


sub Top {
    my($opt) = @_;
    Div class => 'raised-top-container', sub {
        Div class => 'raised-top', sub {
            Div class => 'container', sub {
                Div class => 'navbar navbar--expand-md', sub {
                    Div class => 'navbar__logo', sub {
                        A href => '/', 'vndb';
                    };
                    A href => 'javascript:;', class => 'navbar__toggler', sub {
                        Div class => 'navbar__toggler-icon', '';
                    };
                    Div class => 'navbar__collapse', \&Navbar;
                };
                Div class => 'row', $opt->{top} if $opt->{top};
            };
        };
    };
}


sub Bottom {
    Div class => 'col-md col-md--1', sub {
        Div class => 'footer__logo', sub {
            A href => '/', class => 'link-subtle', 'vndb';
        };
    };

    state $sep = sub { Span class => 'footer__sep', sub { Lit '&middot;'; }; };
    state $lnk = sub { A href => $_[0], class => 'link--subtle', $_[1]; };
    state $root = tuwf->root;
    state $ver = `git -C "$root" describe` =~ /^(.+)$/ ? $1 : '';

    Div class => 'col-md col-md--4', sub {
        Div class => 'footer__nav', sub {
            $lnk->('/d7', 'about us');
            $sep->();
            $lnk->('irc://irc.synirc.net/vndb', '#vndb');
            $sep->();
            $lnk->('mailto:contact@vndb.org', 'contact@vndb.org');
            $sep->();
            $lnk->('https://code.blicky.net/yorhel/vndb/src/branch/v3', 'source');
            $sep->();
            A href => '/v/rand', class => 'link--subtle footer__random', sub {
                Txt 'random vn ';
                Img class => 'svg-icon', src => tuwf->conf->{url_static}.'/v3/heavy/random.svg';
            };
            $sep->();
            Txt $ver;
        };

        my $q = tuwf->dbRow('SELECT vid, quote FROM quotes ORDER BY random() LIMIT 1');
        Div class => 'footer__quote', sub {
           $lnk->('/v'.$q->{vid}, $q->{quote});
        } if $q;
    };
}


sub Framework {
    my $body = pop;
    my %opt = @_;
    Html sub {
        Head prefix => 'og: http://ogp.me/ns#', sub {
            Meta name => 'viewport', content => 'width=device-width, initial-scale=1, shrink-to-fit=no';
            Meta name => 'csrf-token', content => auth->csrftoken;
            Meta charset => 'utf-8';
            Meta name => 'robots', content => 'noindex, follow' if exists $opt{index} && !$opt{index};
            Title $opt{title} . ' | vndb';
            Link rel => 'stylesheet', href => tuwf->conf->{url_static}.'/v3/style.css';
            Link rel => 'shortcut icon', href => '/favicon.ico', type => 'image/x-icon';
            Link rel => 'search', type => 'application/opensearchdescription+xml', title => 'VNDB VN Search', href => tuwf->reqBaseURI().'/opensearch.xml';

            # TODO: Link to RSS feeds.

            # Opengraph metadata
            if($opt{og}) {
                $opt{og}{site_name} ||= 'The Visual Novel Database';
                $opt{og}{type}      ||= 'object';
                $opt{og}{image}     ||= 'https://s.vndb.org/s/angel/bg.jpg'; # TODO: Something better
                $opt{og}{url}       ||= tuwf->reqURI;
                $opt{og}{title}     ||= $opt{title};
                Meta property => "og:$_", content => ($opt{og}{$_} =~ s/\n/ /gr) for sort keys %{$opt{og}};
            }
        };
        Body sub {
            Div class => 'top-bar', id => 'top', '';
            Top \%opt;
            Div class => 'page-container', sub {
                Div mkclass(
                        container               => 1,
                        'main-container'        => 1,
                        'container--narrow'     => $opt{narrow},
                        'flex-center-container' => $opt{center},
                        'main-container--single-col' => $opt{single_col},
                        $opt{main_classes} ? %{$opt{main_classes}} :()
                    ), $body;
                Div class => 'container', sub {
                    Div class => 'footer', sub {
                        Div class => 'row', \&Bottom;
                    };
                };
            };
            Script type => 'text/javascript', src => tuwf->conf->{url_static}.'/v3/elm.js', '';
            Script type => 'text/javascript', src => tuwf->conf->{url_static}.'/v3/vndb.js', '';
            #Script type => 'text/javascript', src => tuwf->conf->{url_static}.'/v3/min.js', '';
        };
    };
    if(tuwf->debug) {
        tuwf->dbCommit; # Hack to measure the commit time

        my $sql = uri_escape join "\n", map {
            my($sql, $params, $time) = @$_;
            sprintf "  [%6.2fms] %s | %s", $time*1000, $sql,
                join ', ', map "$_:".DBI::neat($params->{$_}),
                sort { $a =~ /^[0-9]+$/ && $b =~ /^[0-9]+$/ ? $a <=> $b : $a cmp $b }
                keys %$params;
        } @{ tuwf->{_TUWF}{DB}{queries} };
        A href => 'data:text/plain,'.$sql, 'SQL';

        my $modules = uri_escape join "\n", sort keys %INC;
        A href => 'data:text/plain,'.$modules, 'Modules';
    }
}


sub EntryEdit {
    my($type, $e) = @_;

    return if $type eq 'u' && !auth->permUsermod;

    Div class => 'dropdown pull-right', sub {
        A href => 'javascript:;', class => 'btn d-block dropdown__toggle', sub {
            Div class => 'opacity-muted', sub {
                Img class => 'svg-icon', src => tuwf->conf->{url_static}.'/v3/edit.svg';
                Span class => 'caret', '';
            };
        };
        Div class => 'dropdown-menu dropdown-menu--right database-menu', sub {
            A class => 'dropdown-menu__item', href => "/$type$e->{id}",        'Details';
            A class => 'dropdown-menu__item', href => "/$type$e->{id}/hist",   'History' if $type ne 'u';
            A class => 'dropdown-menu__item', href => "/$type$e->{id}/edit",   'Edit' if can_edit $type, $e;
            A class => 'dropdown-menu__item', href => "/$type$e->{id}/add",    'Add release' if $type eq 'v' && can_edit $type, $e;
            A class => 'dropdown-menu__item', href => "/$type$e->{id}/addchar",'Add character' if $type eq 'v' && can_edit $type, $e;
            A class => 'dropdown-menu__item', href => "/$type$e->{id}/copy",   'Copy' if $type =~ /[cr]/ && can_edit $type, $e;
        };
    }
}


sub Switch {
    my $label = shift;
    my $on = shift;
    my @class = mkclass
        'switch' => 1,
        'switch--on' => $on,
        @_;

    A @class, href => 'javascript:;', sub {
        Div class => 'switch__label', $label;
        Div class => 'switch__toggle', '';
    };
}


# Throw any data structure on the page for inspection.
sub Debug {
    return if !tuwf->debug;
    require JSON::XS;
    # This provides a nice JSON browser in FF, not sure how other browsers render it.
    my $data = uri_escape(JSON::XS->new->canonical->encode($_[0]));
    A style => 'margin: 0 5px', title => 'Debug', href => 'data:application/json,'.$data, ' ⚙ ';
}


# Similar to join($sep, map $item->($_), @list), but works for HTML generation functions.
#   Join ', ', sub { A href => '#', $_[0] }, @list;
#   Join \&Br, \&Txt, @list;
sub Join {
    my($sep, $item, @list) = @_;
    for my $i (0..$#list) {
        ref $sep ? $sep->() : Txt $sep if $i > 0;
        $item->($list[$i]);
    }
}


# Full-page form, optionally with sections. Options:
#
#   module   => '', # Elm module to load
#   data     => $form_data,
#   schema   => $tuwf_validate_schema, # Optional TUWF::Validate schema to use to encode the data
#   sections => [ # Optional list of sections
#       anchor1 => 'Section 1',
#       ..
#   ]
#
# If no sections are given, the parent Framework() should have narrow => 1.
sub FullPageForm {
    my %o = @_;

    my $form = sub { Div
        'data-elm-module' => $o{module},
        'data-elm-flags' => JSON::XS->new->encode($o{schema} ? $o{schema}->analyze->coerce_for_json($o{data}) : $o{data}),
        ''
    };

    Div class => 'row', $o{sections} ? sub {

        Div class => 'col-md col-md--1', sub {
            Div class => 'nav-sidebar nav-sidebar--expand-md', sub {
                A href => 'javascript:;', class => 'nav-sidebar__selection', sub {
                    Txt $o{sections}[1];
                    Div class => 'caret', '';
                };
                Div class => 'nav nav--vertical', sub {
                    my $x = 0;
                    for my $s (pairs @{$o{sections}}) {
                        Div mkclass(nav__item => 1, 'nav__item--active' => !$x++), sub {
                            A class => 'nav__link', href => '#'.$s->key, $s->value;
                        }
                    }
                };
            }
        };
        Div class => 'col-md col-md--4', $form;
    } : sub {
        Div class => 'col-md col-md--1', $form;
    };
}


sub VoteGraph {
    my($type, $id) = @_;

    my %histogram = map +($_->{vote}, $_), @{ tuwf->dbAlli(q{
        SELECT (vote::numeric/10)::int AS vote, COUNT(vote) as votes, SUM(vote) AS total
          FROM votes},
        $type eq 'v' ? (q{
            JOIN users ON id = uid AND NOT ign_votes
           WHERE vid =}, \$id
        ) : (q{
           WHERE uid =}, \$id
        ), q{
         GROUP BY (vote::numeric/10)::int
    })};

    my $max   = max map $_->{votes}, values %histogram;
    my $count = sum map $_->{votes}, values %histogram;
    my $sum   = sum map $_->{total}, values %histogram;

    my $Graph = sub {
        Div class => 'vote-graph', sub {
            Div class => 'vote-graph__scores', sub {
                Div class => 'vote-graph__score', $_ for (reverse 1..10);
            };
            Div class => 'vote-graph__bars', sub {
                Div class => 'vote-graph__bar', style => sprintf('width: %.2f%%', ($histogram{$_}{votes}||0)/$max*100), sub {
                    Div class => 'vote-graph__bar-label', $histogram{$_}{votes}||'1';
                } for (reverse 1..10);
            };
        };
        Div class => 'final-text',
            sprintf '%d vote%s total, average %.2f%s',
                $count, $count == 1 ? '' : 's', $sum/$count/10,
                $type eq 'v' ? ' ('.vote_string($sum/$count).')' : '';
    };
    return ($count, $Graph);
}

sub ListIcon {
    Lit q{<svg class="svg-icon" xmlns="http://www.w3.org/2000/svg" width="14" height="14" version="1">}
        .q{<g fill="currentColor" fill-rule="nonzero">}
         .q{<path d="M0 2h14v2H0zM0 6h14v2H0zM0 10h14v2H0z"/>}
        .q{</g>}
       .q{</svg>};
}


sub GridIcon {
    Lit q{<svg class="svg-icon" xmlns="http://www.w3.org/2000/svg" width="14" height="14" version="1">}
        .q{<g fill="currentColor" fill-rule="nonzero">}
         .q{<path d="M0 0h3v3H0zM0 5h3v3H0zM0 10h3v3H0zM5 0h3v3H5zM5 5h3v3H5zM5 10h3v3H5zM10 0h3v3h-3zM10 5h3v3h-3zM10 10h3v3h-3z"/>}
        .q{</g>}
       .q{</svg>};
}

1;
