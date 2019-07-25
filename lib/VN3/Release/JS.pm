package VN3::Release::JS;

use VN3::Prelude;


my $OUT = tuwf->compile({ aoh => {
    id       => { id => 1 },
    title    => {},
    lang     => { type => 'array', values => {} },
}});


# Fetch all releases assigned to a VN
json_api '/js/release.json', {
    vid => { id => 1 },
}, sub {
    my $vid = shift->{vid};

    my $r = tuwf->dbAlli(q{
        SELECT r.id, r.title
          FROM releases r
          JOIN releases_vn rv ON rv.id = r.id
         WHERE NOT r.hidden
           AND rv.vid =}, \$vid, q{
         ORDER BY r.id
    });
    enrich_list1 lang => id => id => sub { sql 'SELECT id, lang FROM releases_lang WHERE id IN', $_[0], 'ORDER BY id, lang' }, $r;

    tuwf->resJSON({ReleaseResult => $OUT->analyze->coerce_for_json($r)});
};

1;
