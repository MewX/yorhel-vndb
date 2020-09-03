package VNWeb::Reviews::Edit;

use VNWeb::Prelude;
use VNWeb::Releases::Lib;


my $FORM = {
    id      => { vndbid => 'w', required => 0 },
    vid     => { id => 1 },
    vntitle => { _when => 'out' },
    rid     => { id => 1, required => 0 },
    spoiler => { anybool => 1 },
    isfull  => { anybool => 1 },
    text    => { maxlength => 100_000, required => 0, default => '' },

    releases => { _when => 'out', $VNWeb::Elm::apis{Releases}[0]->%* },
};

my $FORM_IN  = form_compile in  => $FORM;
my $FORM_OUT = form_compile out => $FORM;


TUWF::get qr{/$RE{vid}/addreview}, sub {
    my $v = tuwf->dbRowi('SELECT id, title FROM vn WHERE NOT hidden AND id =', \tuwf->capture('id'));
    return tuwf->resNotFound if !$v->{id};

    my $id = tuwf->dbVali('SELECT id FROM reviews WHERE vid =', \$v->{id}, 'AND uid =', \auth->uid);
    return tuwf->resRedirect("/$id/edit") if $id;
    return tuwf->resDenied if !can_edit w => {};

    framework_ title => "Write review for $v->{title}", sub {
        elm_ 'Reviews.Edit' => $FORM_OUT, { elm_empty($FORM_OUT)->%*, vid => $v->{id}, vntitle => $v->{title}, releases => releases_by_vn $v->{id} };
    };
};


TUWF::get qr{/$RE{wid}/edit}, sub {
    my $e = tuwf->dbRowi(
        'SELECT r.id, r.uid AS user_id, r.vid, r.rid, r.isfull, r.text, r.spoiler, v.title AS vntitle
          FROM reviews r JOIN vn v ON v.id = r.vid WHERE r.id =', \tuwf->capture('id')
    );
    return tuwf->resNotFound if !$e->{id};
    return tuwf->resDenied if !can_edit w => $e;

    $e->{releases} = releases_by_vn $e->{vid};
    framework_ title => "Edit review for $e->{vntitle}", type => 'w', dbobj => $e, tab => 'edit', sub {
        elm_ 'Reviews.Edit' => $FORM_OUT, $e;
    };
};



elm_api ReviewsEdit => $FORM_OUT, $FORM_IN, sub {
    my($data) = @_;
    my $id = delete $data->{id};

    my $review = $id ? tuwf->dbRowi('SELECT id, uid AS user_id FROM reviews WHERE id =', \$id) : {};
    return elm_Unauth if !can_edit w => $review;

    validate_dbid 'SELECT id FROM vn WHERE id IN', $data->{vid};
    validate_dbid 'SELECT id FROM releases WHERE id IN', $data->{rid} if defined $data->{rid};

    die "Review too long" if !$data->{isfull} && length $data->{text} > 800;
    $data->{text} = bb_subst_links $data->{text};

    if($id) {
        $data->{lastmod} = sql 'NOW()';
        tuwf->dbExeci('UPDATE reviews SET', $data, 'WHERE id =', \$id) if $id;
        auth->audit($review->{user_id}, 'review edit', "edited $review->{id}") if auth->uid != $review->{user_id};

    } else {
        return elm_Unauth if tuwf->dbVali('SELECT 1 FROM reviews WHERE vid =', \$data->{vid}, 'AND uid =', \auth->uid);
        $data->{uid} = auth->uid;
        $id = tuwf->dbVali('INSERT INTO reviews', $data, 'RETURNING id');
        tuwf->dbExeci('UPDATE users SET perm_review = false WHERE id =', \auth->uid) if !auth->isMod; # XXX: While in beta, 1 review per user.
    }

    elm_Redirect "/$id"
};


elm_api ReviewsDelete => undef, { id => { vndbid => 'w' } }, sub {
    my($data) = @_;
    my $review = tuwf->dbRowi('SELECT id, uid AS user_id FROM reviews WHERE id =', \$data->{id});
    return elm_Unauth if !can_edit w => $review;
    auth->audit($review->{user_id}, 'review delete', "deleted $review->{id}");
    tuwf->dbExeci('DELETE FROM reviews WHERE id =', \$data->{id});
    elm_Success
};


1;
