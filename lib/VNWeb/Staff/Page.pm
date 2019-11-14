package VNWeb::Staff::Page;

use VNWeb::Prelude;
use VNWeb::Docs::Lib;


sub enrich_item {
    my($s) = @_;

    # Add a 'main' flag to each alias
    $_->{main} = $s->{aid} == $_->{aid} for $s->{alias}->@*;

    # Sort aliases by name
    $s->{alias} = [ sort { $a->{name} cmp $b->{name} || ($a->{original}||'') cmp ($b->{original}||'') } $s->{alias}->@* ];
}


sub _rev_ {
    my($s) = @_;
    revision_ s => $s, \&enrich_item,
        [ alias  => 'Names', fmt => sub {
            txt_ $_->{name};
            txt_ " ($_->{original})" if $_->{original};
            b_ class => 'grayedout', ' (primary)' if $_->{main};
        } ],
        [ gender => 'Gender',     fmt => \%GENDER   ],
        [ lang   => 'Language',   fmt => \%LANGUAGE ],
        [ desc   => 'Description' ],
        revision_extlinks 's'
}


sub _infotable_ {
    my($main, $s) = @_;
    table_ class => 'stripe', sub {
        thead_ sub { tr_ sub {
            td_ colspan => 2, sub {
                b_ style => 'margin-right: 10px', $main->{name};
                b_ class => 'grayedout', style => 'margin-right: 10px', lang => $s->{lang}, $main->{original} if $main->{original};
                abbr_ class => "icons gen $s->{gender}", title => $GENDER{$s->{gender}}, '' if $s->{gender} ne 'unknown';
            }
        } };

        tr_ sub {
            td_ class => 'key', 'Language';
            td_ $LANGUAGE{$s->{lang}};
        };

        my @alias = grep !$_->{main}, $s->{alias}->@*;
        tr_ sub {
            td_ @alias == 1 ? 'Alias' : 'Aliases';
            td_ sub {
                table_ class => 'aliases', sub {
                    tr_ class => 'nostripe', sub {
                        td_ class => 'key', $_->{original} ? () : (colspan => 2), $_->{name};
                        td_ lang => $s->{lang}, $_->{original} if $_->{original};
                    } for @alias;
                };
            };
        } if @alias;

        tr_ sub {
            td_ class => 'key', 'Links';
            td_ sub {
                join_ \&br_, sub { a_ href => $_->[1], $_->[0] }, $s->{extlinks}->@*;
            };
        } if $s->{extlinks}->@*;
    };
}


sub _roles_ {
    my($s) = @_;
    my %alias = map +($_->{aid}, $_), $s->{alias}->@*;

    my $roles = tuwf->dbAlli(q{
        SELECT v.id, vs.aid, vs.role, vs.note, v.c_released, v.title, v.original
          FROM vn_staff vs
          JOIN vn v ON v.id = vs.id
         WHERE vs.aid IN}, [ keys %alias ], q{
           AND NOT v.hidden
         ORDER BY v.c_released ASC, v.title ASC, vs.role ASC
    });
    return if !@$roles;

    h1_ class => 'boxtitle', sprintf 'Credits (%d)', scalar @$roles;
    div_ class => 'mainbox browse staffroles', sub {
        table_ class => 'stripe', sub {
            thead_ sub { tr_ sub {
                td_ class => 'tc1', 'Title';
                td_ class => 'tc2', 'Released';
                td_ class => 'tc3', 'Role';
                td_ class => 'tc4', 'As';
                td_ class => 'tc5', 'Note';
            }};
            tr_ sub {
                my($v, $a) = ($_, $alias{$_->{aid}});
                td_ class => 'tc1', sub {
                    a_ href => "/v$v->{id}", title => $v->{original}||$v->{title}, shorten $v->{title}, 60;
                };
                td_ class => 'tc2', sub { rdate_ $v->{c_released} };
                td_ class => 'tc3', $CREDIT_TYPE{$v->{role}};
                td_ class => 'tc4', title => $a->{original}||$a->{name}, $a->{name};
                td_ class => 'tc5', $v->{note};
            } for @$roles;
        };
    };
}


sub _cast_ {
    my($s) = @_;
    my %alias = map +($_->{aid}, $_), $s->{alias}->@*;

    my $cast = tuwf->dbAlli(q{
        SELECT vs.aid, v.id, v.c_released, v.title, v.original, c.id AS cid, c.name AS c_name, c.original AS c_original, vs.note
          FROM vn_seiyuu vs
          JOIN vn v ON v.id = vs.id
          JOIN chars c ON c.id = vs.cid
         WHERE vs.aid IN}, [ keys %alias ], q{
           AND NOT v.hidden
           AND NOT c.hidden
         ORDER BY v.c_released ASC, v.title ASC
    });
    return if !@$cast;

    h1_ class => 'boxtitle', sprintf 'Voiced characters (%d)', scalar @$cast;
    div_ class => 'mainbox browse staffroles', sub {
        table_ class => 'stripe', sub {
            thead_ sub { tr_ sub {
                td_ class => 'tc1', 'Title';
                td_ class => 'tc2', 'Released';
                td_ class => 'tc3', 'Cast';
                td_ class => 'tc4', 'As';
                td_ class => 'tc5', 'Note';
            }};
            tr_ sub {
                my($v, $a) = ($_, $alias{$_->{aid}});
                td_ class => 'tc1', sub {
                    a_ href => "/v$v->{id}", title => $v->{original}||$v->{title}, shorten $v->{title}, 60;
                };
                td_ class => 'tc2', sub { rdate_ $v->{c_released} };
                td_ class => 'tc3', sub {
                    a_ href => "/c$v->{cid}", title => $v->{c_original}||$v->{c_name}, $v->{c_name};
                };
                td_ class => 'tc4', title => $a->{original}||$a->{name}, $a->{name};
                td_ class => 'tc5', $v->{note};
            } for @$cast;
        };
    };
}


TUWF::get qr{/$RE{srev}} => sub {
    my $s = db_entry s => tuwf->capture('id'), tuwf->capture('rev');
    return tuwf->resNotFound if !$s;

    enrich_item $s;
    enrich_extlinks s => $s;
    my($main) = grep $_->{aid} == $s->{aid}, $s->{alias}->@*;

    framework_ title => $main->{name}, index => 1, type => 's', dbobj => $s, hiddenmsg => 1,
        og => {
            description => bb2text $s->{desc}
        },
    sub {
        _rev_ $s if tuwf->capture('rev');
        div_ class => 'mainbox staffpage', sub {
            itemmsg_ s => $s;
            h1_ sub { txt_ $main->{name}; debug_ $s };
            h2_ class => 'alttitle', lang => $s->{lang}, $main->{original} if $main->{original};
            _infotable_ $main, $s;
            p_ class => 'description', sub { lit_ bb2html $s->{desc} };
        };

        _roles_ $s;
        _cast_ $s;
    };
};

1;
