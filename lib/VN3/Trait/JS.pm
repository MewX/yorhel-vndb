package VN3::Trait::JS;

use VN3::Prelude;

my $elm_TraitResult = elm_api TraitResult => { aoh => {
    id    => { id => 1 },
    name  => {},
    gid   => { id => 1, required => 0 },
    group => { required => 0 }
}};

# Returns only approved and applicable traits
json_api '/js/trait.json', {
    search => { maxlength => 500 }
}, sub {
    my $q = shift->{search};

    my $qs = $q =~ s/[%_]//gr;
    my $r = tuwf->dbAlli(
        'SELECT t.id, t.name, g.id AS gid, g.name AS group',
        'FROM (',
            # ID search
            $q =~ /^$IID_RE$/ ? ('SELECT 1, id FROM traits WHERE id =', \"$1", 'UNION ALL') : (),
            # exact match
            'SELECT 2, id FROM traits WHERE lower(name) = lower(', \$q, ")",
            'UNION ALL',
            # prefix match
            'SELECT 3, id FROM traits WHERE name ILIKE', \"$qs%",
            'UNION ALL',
            # substring match + alias search
            'SELECT 4, id FROM traits WHERE name ILIKE', \"%$qs%", ' OR alias ILIKE', \"%$qs%",
        ') AS tt (ord, id)',
        'JOIN traits t ON t.id = tt.id',
        'LEFT JOIN traits g ON g.id = t.group',
        'WHERE t.state = 2 AND t.applicable',
        'GROUP BY t.id, t.name, g.id, g.name',
        'ORDER BY MIN(tt.ord), t.name',
        'LIMIT 20'
    );

    $elm_TraitResult->($r);
};

1;
