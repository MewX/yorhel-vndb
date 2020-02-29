package VNWeb::Producers::Elm;

use VNWeb::Prelude;

elm_api Producers => undef, { search => {} }, sub {
    my $q = shift->{search};
    my $qs = $q =~ s/[%_]//gr;

    elm_ProducerResult tuwf->dbPagei({ results => 15, page => 1 },
        'SELECT p.id, p.name, p.original
           FROM (',
			sql_join('UNION ALL',
                $q =~ /^$RE{pid}$/ ? sql('SELECT 1, id FROM producers WHERE id =', \"$+{id}") : (),
                sql('SELECT  1+substr_score(lower(name),'    , \$qs, '), id FROM producers WHERE name     ILIKE', \"$qs%"),
                sql('SELECT 10+substr_score(lower(original),', \$qs, '), id FROM producers WHERE original ILIKE', \"$qs%"),
            ), ') x(prio, id)
           JOIN producers p ON p.id = x.id
          WHERE NOT p.hidden
          GROUP BY p.id, p.name, p.original
          ORDER BY MIN(x.prio), p.name
    ');
};

1;
