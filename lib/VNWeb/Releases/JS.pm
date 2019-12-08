package VNWeb::Releases::JS;

use VNWeb::Prelude;


# Used by UList.Opt to fetch releases from a VN id.
json_api qr{/r/get\.json}, { vid => { id => 1 } }, sub {
    my($data) = @_;
    my $l = tuwf->dbAlli(
        'SELECT r.id, r.title, r.original, r.type AS rtype, r.released
           FROM releases r
           JOIN releases_vn rv ON rv.id = r.id
          WHERE NOT r.hidden
            AND rv.vid =', \$data->{vid},
         'ORDER BY r.released, r.title, r.id'
    );
    enrich_flatten lang => id => id => sub { sql('SELECT id, lang FROM releases_lang WHERE id IN', $_, 'ORDER BY lang') }, $l;
    elm_Releases $l;
};

1;
