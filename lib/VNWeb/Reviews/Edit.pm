package VNWeb::Reviews::Edit;

use VNWeb::Prelude;


my $FORM = {
    id      => { vndbid => 'w', required => 0 },
    vid     => { id => 1 },
    vntitle => { _when => 'out' },
    rid     => { id => 1, required => 0 },
    spoiler => { anybool => 1 },
    summary => { maxlength => 700 },
    text    => { maxlength => 100_000, required => 0, default => '' },

    releases => { _when => 'out', $VNWeb::Elm::apis{Releases}[0]->%* },
};

my $FORM_IN  = form_compile in  => $FORM;
my $FORM_OUT = form_compile out => $FORM;


sub _releases {
    my($id) = @_;
    my $r = tuwf->dbAlli('
        SELECT rv.vid, r.id, r.title, r.original, r.released, r.type as rtype, r.reso_x, r.reso_y
          FROM releases r
          JOIN releases_vn rv ON rv.id = r.id
         WHERE NOT r.hidden AND rv.vid =', \$id, '
         ORDER BY r.released, r.title, r.id'
    );
    enrich_flatten lang => id => id => sub { sql('SELECT id, lang FROM releases_lang WHERE id IN', $_, 'ORDER BY lang') }, $r;
    enrich_flatten platforms => id => id => sub { sql('SELECT id, platform FROM releases_platforms WHERE id IN', $_, 'ORDER BY platform') }, $r;
    $r
}


TUWF::get qr{/$RE{vid}/addreview}, sub {
    my $v = tuwf->dbRowi('SELECT id, title FROM vn WHERE NOT hidden AND id =', \tuwf->capture('id'));
    return tuwf->resNotFound if !$v->{id};

    my $id = tuwf->dbVali('SELECT id FROM reviews WHERE vid =', \$v->{id}, 'AND uid =', \auth->uid);
    return tuwf->resRedirect("/$id/edit") if $id;
    return tuwf->resDenied if !can_edit w => {};

    framework_ title => "Write review for $v->{title}", sub {
        elm_ 'Reviews.Edit' => $FORM_OUT, { elm_empty($FORM_OUT)->%*, vid => $v->{id}, vntitle => $v->{title}, releases => _releases $v->{id} };
    };
};


TUWF::get qr{/$RE{wid}/edit}, sub {
    my $e = tuwf->dbRowi(
        'SELECT r.id, r.uid, r.vid, r.rid, r.summary, r.text, r.spoiler, v.title AS vntitle
          FROM reviews r JOIN vn v ON v.id = r.vid WHERE r.id =', \tuwf->capture('id')
    );
    return tuwf->resNotFound if !$e->{id};
    return tuwf->resDenied if !can_edit w => $e;

    $e->{releases} = _releases $e->{vid};
    framework_ title => "Edit review for $e->{vntitle}", sub {
        elm_ 'Reviews.Edit' => $FORM_OUT, $e;
    };
};



elm_api ReviewsEdit => $FORM_OUT, $FORM_IN, sub {
    my($data) = @_;
    my $id = delete $data->{id};

    my $review = $id ? tuwf->dbRowi('SELECT id, uid FROM reviews WHERE id =', \$id) : {};
    return elm_Unauth if !can_edit w => $review;

    validate_dbid 'SELECT id FROM vn WHERE id IN', $data->{vid};
    validate_dbid 'SELECT id FROM releases WHERE id IN', $data->{rid} if defined $data->{rid};

    if($id) {
        $data->{lastmod} = sql 'NOW()';
        tuwf->dbExeci('UPDATE reviews SET', $data, 'WHERE id =', \$id) if $id;
        auth->audit($review->{uid}, 'review edit', "edited $review->{id}") if auth->uid != $review->{uid};

    } else {
        return elm_Unauth if tuwf->dbVali('SELECT 1 FROM reviews WHERE vid =', \$data->{vid}, 'AND uid =', \auth->uid);
        $data->{uid} = auth->uid;
        $id = tuwf->dbVali('INSERT INTO reviews', $data, 'RETURNING id');
    }

    elm_Redirect "/$id"
};


elm_api ReviewsDelete => undef, { id => { vndbid => 'w' } }, sub {
    my($data) = @_;
    my $review = tuwf->dbRowi('SELECT id, uid FROM reviews WHERE id =', \$data->{id});
    return elm_Unauth if !can_edit w => $review;
    auth->audit($review->{uid}, 'review delete', "deleted $review->{id}");
    tuwf->dbExeci('DELETE FROM reviews WHERE id =', \$data->{id});
    elm_Success
};


1;
