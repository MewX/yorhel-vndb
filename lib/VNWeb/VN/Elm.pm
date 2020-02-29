package VNWeb::VN::Elm;

use VNWeb::Prelude;

elm_api VN => undef, { search => {} }, sub {
    my $q = shift->{search};
    my $qs = $q =~ s/[%_]//gr;
	my @q = normalize_query $q;

    elm_VNResult tuwf->dbPagei({ results => 15, page => 1 },
        'SELECT v.id, v.title, v.original
           FROM (',
			sql_join('UNION ALL',
                $q =~ /^$RE{vid}$/ ? sql('SELECT 1, id FROM vn WHERE id =', \"$+{id}") : (),
                sql('SELECT 1+substr_score(lower(title),', \$qs, '), id FROM vn WHERE title ILIKE', \"$qs%"),
                @q ? (sql 'SELECT 10, id FROM vn WHERE', sql_and map sql('c_search ILIKE', \"%$_%"), @q) : ()
            ), ') x(prio, id)
           JOIN vn v ON v.id = x.id
          WHERE NOT v.hidden
          GROUP BY v.id, v.title, v.original
          ORDER BY MIN(x.prio), v.title
    ');
};

1;
