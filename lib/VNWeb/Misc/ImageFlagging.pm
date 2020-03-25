package Misc::ImageFlagging;

use VNWeb::Prelude;


# Add signed tokens to the image ist - indicating that the current user is
# permitted to vote on these images. These tokens ensure that non-moderators
# can only vote on images that they have been randomly assigned, thus
# preventing possible abuse when a single person uses multiple accounts to
# influence the rating of a single image.
sub enrich_token {
    my($canvote, $l) = @_;
    $_->{token} = $canvote ? auth->csrftoken(0, "imgvote-$_->{id}") : undef for @$l;
}


# Does the reverse of enrich_token. Returns true if all tokens validated.
sub validate_token {
    my($l) = @_;
    my $ok = 1;
    $ok &&= $_->{token} && auth->csrfcheck($_->{token}, "imgvote-$_->{id}") for @$l;
    $ok;
}


sub enrich_image {
    my($l) = @_;
    # XXX: Can't use "IN($image_ids)" here because of an odd PostgreSQL
    #   limitation regarding input of composite types. "IN('(ch,1)')" throws an
    #   error, though IN(..) with multiple values works just fine.
    enrich_merge id => sub { sql q{
      SELECT i.id, i.width, i.height, i.c_votecount AS votecount
           , i.c_sexual_avg AS sexual_avg, i.c_sexual_stddev AS sexual_stddev
           , i.c_violence_avg AS violence_avg, i.c_violence_stddev AS violence_stddev
           , iv.sexual AS my_sexual, iv.violence AS my_violence
           , COALESCE('v'||v.id, 'c'||c.id, 'v'||vsv.id) AS entry_id
           , COALESCE(v.title, c.name, vsv.title) AS entry_title
        FROM images i
        LEFT JOIN image_votes iv ON iv.id = i.id AND iv.uid =}, \auth->uid, q{
        LEFT JOIN vn v ON (i.id).itype = 'cv' AND v.image = i.id
        LEFT JOIN chars c ON (i.id).itype = 'ch' AND c.image = i.id
        LEFT JOIN vn_screenshots vs ON (i.id).itype = 'sf' AND vs.scr = i.id
        LEFT JOIN vn vsv ON (i.id).itype = 'sf' AND vsv.id = vs.id
       WHERE i.id = ANY(ARRAY}, $_, '::image_id[])'
    }, $l;

    enrich votes => id => id => sub { sql '
        SELECT iv.id, iv.sexual, iv.violence, ', sql_user(), '
          FROM image_votes iv
          LEFT JOIN users u ON u.id = iv.uid
         WHERE iv.id = ANY(ARRAY', $_, '::image_id[])',
               auth ? ('AND iv.uid <> ', \auth->uid) : (), '
         ORDER BY u.username'
    }, $l;

    for(@$l) {
        $_->{url} = tuwf->imgurl($_->{id});
        $_->{entry} = $_->{entry_id} ? { id => $_->{entry_id}, title => $_->{entry_title} } : undef;
        delete $_->{entry_id};
        delete $_->{entry_title};
        for my $v ($_->{votes}->@*) {
            $v->{user} = xml_string sub { user_ $v }; # Easier than duplicating user_() in Elm
            delete $v->{$_} for grep /^user_/, keys %$v;
        }
    }
}


my $SEND = form_compile any => {
    images => $VNWeb::Elm::apis{ImageResult}[0],
    single => { anybool => 1 },
    warn   => { anybool => 1 },
};

# Fetch a list of images for the user to vote on.
elm_api Images => $SEND, {}, sub {
    return elm_Unauth if !auth->permImgvote;

    # TODO: Return nothing when the user has voted on >90% of the images?

    # This query is kind of slow, but there's a few ways to improve:
    # - create index .. on images (id) include (c_weight) where c_weight > 0;
    #   (Probably won't work with TABLESAMPLE)
    # - Add a 'images.c_uids integer[]' cache to filter out rows faster.
    #   (Ought to work wonderfully well with TABLESAMPLE, probably gets rid of a few sorts, too)
    # - Distribute images in a fixed number of buckets and choose a random bucket up front.
    #   (This is similar to how TABLESAMPLE works, but (hopefully) avoids an extra sort
    #    in the query plan and allows for the same sampling algorithm to be used on image_votes)

    # This query uses a 2% TABLESAMPLE to speed things up:
    # - With ~220k images, a 2% sample gives ~4.4k images to work with
    # - 80% of all images have c_weight > 0, so that leaves ~3.5k images
    # - To actually fetch 100 rows on average, the user should not have voted on more than ~97% of the images.
    #   ^ But TABLESAMPLE SYSTEM isn't perfectly uniform, so we need some headroom for outliers.
    #   ^ Doing a regular CLUSTER on a random value may help with getting a more uniform sampling.
    #
    # This probably won't give (many?) rows on the dev database; A nicer solution
    # would calculate an appropriate sampling percentage based on actual data.
    my $l = tuwf->dbAlli('
        SELECT id
          FROM images i TABLESAMPLE SYSTEM (1+1)
         WHERE c_weight > 0
           AND NOT EXISTS(SELECT 1 FROM image_votes iv WHERE iv.id = i.id AND iv.uid =', \auth->uid, ')
         ORDER BY random() ^ (1.0/c_weight) DESC
         LIMIT', \30
    );
    warn sprintf 'Weighted random image sampling query returned %d < 30 rows for u%d', scalar @$l, auth->uid if @$l < 30;
    enrich_image $l;
    enrich_token 1, $l;
    elm_ImageResult $l;
};


elm_api ImageVote => undef, {
    votes => { sort_keys => 'id', aoh => {
        id       => { regex => qr/^\((?:ch|cv|sf),[1-9][0-9]*\)$/ },
        token    => {},
        sexual   => { uint => 1, range => [0,2] },
        violence => { uint => 1, range => [0,2] },
    } },
}, sub {
    my($data) = @_;
    return elm_Unauth if !auth->permImgvote;
    return elm_CSRF if !validate_token $data->{votes};
    for($data->{votes}->@*) {
        $_->{uid} = auth->uid ;
        delete $_->{token};
        tuwf->dbExeci('INSERT INTO image_votes', $_, 'ON CONFLICT (id, uid) DO UPDATE SET', $_, ', date = now()');
    }
    elm_Success
};



TUWF::get qr{/img/vote}, sub {
    return tuwf->resDenied if !auth->permImgvote;

    my $recent = tuwf->dbAlli('SELECT id FROM image_votes WHERE uid =', \auth->uid, 'ORDER BY date DESC LIMIT', \30);
    enrich_image $recent;
    enrich_token 1, $recent;

    framework_ title => 'Image flagging', sub {
        elm_ 'ImageFlagging', $SEND, { images => [ reverse @$recent ], single => 0, warn => 1 };
    };
};


TUWF::get qr{/img/(ch|cv|sf)([1-9][0-9]*)}, sub {
    my($itype, $id) = (tuwf->capture(1), tuwf->capture(2));

    my $l = [{ id => "($itype,$id)" }];
    enrich_image $l;
    return tuwf->resNotFound if !defined $l->[0]{width};

    enrich_token defined($l->[0]{my_sexual}) || auth->permDbmod(), $l; # XXX: permImgmod?

    framework_ title => "Image flagging for $itype$id", sub {
        elm_ 'ImageFlagging', $SEND, { images => $l, single => 1, warn => !tuwf->samesite() };
    };
};

1;
