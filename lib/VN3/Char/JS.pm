package VN3::Char::JS;

use VN3::Prelude;


my $elm_CharResult = elm_api CharResult => { aoh => {
    id            => { id => 1 },
    name          => {},
    original      => {},
    main          => { type => 'hash', required => 0, keys => {
        id            => { id => 1 },
        name          => {},
        original      => {},
    }},
}};

json_api '/js/char.json', {
    search => { maxlength => 500 }
}, sub {
    my $q = shift->{search};

    # XXX: This query is kinda slow
    my $qs = $q =~ s/[%_]//gr;
    my $r = tuwf->dbAlli(
        'SELECT c.id, c.name, c.original, c.main, c2.name AS main_name, c2.original AS main_original',
        'FROM (',
            # ID search
            $q =~ /^$CID_RE$/ ? ('SELECT 1, id FROM chars WHERE id =', \"$1", 'UNION ALL') : (),
            # exact match
            'SELECT 2, id FROM chars WHERE lower(name) = lower(', \$q, ") OR lower(translate(original,' ', '')) = lower(", \($q =~ s/\s//gr), ')',
            'UNION ALL',
            # prefix match
            'SELECT 3, id FROM chars WHERE name ILIKE', \"$qs%", ' OR original ILIKE', \"$qs%",
            'UNION ALL',
            # substring match
            'SELECT 4, id FROM chars WHERE name ILIKE', \"%$qs%", ' OR original ILIKE', \"%$qs%",
        ') AS ct (ord, id)',
        'JOIN chars c ON c.id = ct.id',
        'LEFT JOIN chars c2 ON c2.id = c.main',
        'WHERE NOT c.hidden',
        'GROUP BY c.id, c.name, c.original, c.main, c2.name, c2.original',
        'ORDER BY MIN(ct.ord), c.name',
        'LIMIT 20'
    );

    for (@$r) {
        $_->{main} = $_->{main} ? { id => $_->{main}, name => $_->{main_name}, original => $_->{main_original} } : undef;
        delete $_->{main_name};
        delete $_->{main_original};
    }

    $elm_CharResult->($r);
};

1;
