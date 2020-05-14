package VNWeb::Traits::Elm;

use VNWeb::Prelude;

elm_api Traits => undef, { search => {} }, sub {
    my $q = shift->{search};
    my $qs = $q =~ s/[%_]//gr;

    elm_TraitResult tuwf->dbPagei({ results => 15, page => 1 },
        'SELECT t.id, t.name, t.searchable, t.applicable, t.defaultspoil, t.state, g.id AS group_id, g.name AS group_name
           FROM (SELECT MIN(prio), id FROM (',
             sql_join('UNION ALL',
                 $q =~ /^$RE{iid}$/ ? sql('SELECT 1, id FROM traits WHERE id =', \"$+{id}") : (),
                 sql('SELECT  1+substr_score(lower(name),',  \$qs, '), id FROM traits WHERE name  ILIKE', \"%$qs%"),
                 sql('SELECT 10+substr_score(lower(alias),', \$qs, '), id FROM traits WHERE alias ILIKE', \"%$qs%"),
             ), ') x(prio, id) GROUP BY id) x(prio,id)
           JOIN traits t ON t.id = x.id
           LEFT JOIN traits g ON g.id = t.group
          WHERE t.state <> 1
          ORDER BY x.prio, t.name
    ')
};

1;
