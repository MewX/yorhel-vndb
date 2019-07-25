package Staff::JS;

use VN3::Prelude;


json_api '/js/staff.json', {
    search => { maxlength => 500 }
}, sub {
    my $q = shift->{search};

    # XXX: This query is kinda slow
    my $qs = $q =~ s/[%_]//gr;
    my $r = tuwf->dbAlli(
        'SELECT s.id, st.aid, st.name, st.original',
        'FROM (',
            # ID search
            $q =~ /^$SID_RE$/ ? ('SELECT 1, id, aid, name, original FROM staff_alias WHERE id =', \"$1", 'UNION ALL') : (),
            # exact match
            'SELECT 2, id, aid, name, original FROM staff_alias WHERE lower(name) = lower(', \$q, ") OR lower(translate(original,' ', '')) = lower(", \($q =~ s/\s//gr), ')',
            'UNION ALL',
            # prefix match
            'SELECT 3, id, aid, name, original FROM staff_alias WHERE name ILIKE', \"$qs%", ' OR original ILIKE', \"$qs%",
            'UNION ALL',
            # substring match
            'SELECT 4, id, aid, name, original FROM staff_alias WHERE name ILIKE', \"%$qs%", ' OR original ILIKE', \"%$qs%",
        ') AS st (ord, id, aid, name, original)',
        'JOIN staff s ON s.id = st.id',
        'WHERE NOT s.hidden',
        'GROUP BY s.id, st.aid, st.name, st.original',
        'ORDER BY MIN(st.ord), st.name',
        'LIMIT 20'
    );

    tuwf->resJSON({StaffResult => $r});
};

1;
