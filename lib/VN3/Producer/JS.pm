package VN3::Producer::JS;

use VN3::Prelude;


my $OUT = tuwf->compile({ aoh => {
    id       => { id => 1 },
    name     => {},
    original => {},
    hidden   => { anybool => 1 },
}});


json_api '/js/producer.json', {
    search => { type => 'array', scalar => 1, minlength => 1, values => { maxlength => 500 } },
    hidden => { anybool => 1 }
}, sub {
    my $data = shift;

    my $r = tuwf->dbAlli(
        'SELECT p.id, p.name, p.original, p.hidden',
        'FROM (', (sql_join 'UNION ALL', map {
            my $q = $_;
            my $qs = s/[%_]//gr;
            +(
                # ID search
                /^$PID_RE$/ ? (sql 'SELECT 1, id FROM producers WHERE id =', \"$1") : (),
                # exact match
                sql('SELECT 2, id FROM producers WHERE lower(name) = lower(', \$q, ") OR lower(translate(original,' ', '')) = lower(", \($q =~ s/\s//gr), ')'),
                # prefix match
                sql('SELECT 3, id FROM producers WHERE name ILIKE', \"$qs%", ' OR original ILIKE', \"$qs%"),
                # substring match
                sql('SELECT 4, id FROM producers WHERE name ILIKE', \"%$qs%", ' OR original ILIKE', \"%$qs%", ' OR alias ILIKE', \"%$qs%")
            )
         } @{$data->{search}}),
        ') AS pt (ord, id)',
        'JOIN producers p ON p.id = pt.id',
        $data->{hidden} ? () : ('WHERE NOT p.hidden'),
        'GROUP BY p.id',
        'ORDER BY MIN(pt.ord), p.name',
        'LIMIT 20'
    );

    tuwf->resJSON({ProducerResult => $OUT->analyze->coerce_for_json($r)});
};

1;
