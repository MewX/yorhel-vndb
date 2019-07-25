package VN3::VN::JS;

use VN3::Prelude;


my $OUT = tuwf->compile({ aoh => {
    id       => { id => 1 },
    title    => {},
    original => {},
    hidden   => { anybool => 1 },
}});


json_api '/js/vn.json', {
    search => { type => 'array', scalar => 1, minlength => 1, values => { maxlength => 500 } },
    hidden => { anybool => 1 }
}, sub {
    my $data = shift;

    my $r = tuwf->dbAlli(
        'SELECT v.id, v.title, v.original, v.hidden',
        'FROM (', (sql_join 'UNION ALL', map {
            my $qs = s/[%_]//gr;
            my @q = normalize_query $_;
            +(
                # ID search
                /^$VID_RE$/ ? (sql 'SELECT 1, id FROM vn WHERE id =', \"$1") : (),
                # prefix match
                sql('SELECT 2, id FROM vn WHERE title ILIKE', \"$qs%"),
                # substring match
                @q ? (sql 'SELECT 3, id FROM vn WHERE', sql_and map sql('c_search ILIKE', \"%$_%"), @q) : ()
            )
         } @{$data->{search}}),
        ') AS vt (ord, id)',
        'JOIN vn v ON v.id = vt.id',
        $data->{hidden} ? () : ('WHERE NOT v.hidden'),
        'GROUP BY v.id, v.title, v.original',
        'ORDER BY MIN(vt.ord), v.title',
        'LIMIT 20'
    );

    tuwf->resJSON({VNResult => $OUT->analyze->coerce_for_json($r)});
};

1;

