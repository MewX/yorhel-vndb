package VNWeb::Tags::Elm;

use VNWeb::Prelude;

elm_api Tags => undef, { search => {} }, sub {
    my $q = shift->{search};
    my $qs = sql_like $q;

    elm_TagResult tuwf->dbPagei({ results => 15, page => 1 },
        'SELECT t.id, t.name, t.searchable, t.applicable, t.state
           FROM (',
             sql_join('UNION ALL',
                 $q =~ /^$RE{gid}$/ ? sql('SELECT 1, id FROM tags WHERE id =', \"$+{id}") : (),
                 sql('SELECT  1+substr_score(lower(name),',  \$qs, '), id  FROM tags         WHERE name  ILIKE', \"%$qs%"),
                 sql('SELECT 10+substr_score(lower(alias),', \$qs, '), tag FROM tags_aliases WHERE alias ILIKE', \"%$qs%"),
             ), ') x (prio, id)
           JOIN tags t ON t.id = x.id
          WHERE t.state <> 1
          GROUP BY t.id, t.name, t.searchable, t.applicable, t.state
          ORDER BY MIN(x.prio), t.name
    ')
};

1;
