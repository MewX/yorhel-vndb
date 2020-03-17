package Misc::ImageFlagging;

use VNWeb::Prelude;

# TODO: /img/<imageid> endpoint to open the imageflagging UI for a particular image.


sub enrich_image {
    my($l) = @_;
    enrich_merge id => sql('
      SELECT i.id, i.width, i.height, i.c_votecount AS votecount
           , i.c_sexual_avg AS sexual_avg, i.c_sexual_stddev AS sexual_stddev
           , i.c_violence_avg AS violence_avg, i.c_violence_stddev AS violence_stddev
           , iv.sexual AS my_sexual, iv.violence AS my_violence
        FROM images i
        LEFT JOIN image_votes iv ON iv.id = i.id AND iv.uid =', \auth->uid, '
       WHERE i.id IN'), $l;
    enrich_merge id => q{SELECT image  AS id, 'v' AS entry_type, id   AS entry_id, title   AS entry_title FROM vn WHERE image IN}, grep $_->{id} =~ /cv/, @$l;
    enrich_merge id => q{SELECT vs.scr AS id, 'v' AS entry_type, v.id AS entry_id, v.title AS entry_title FROM vn_screenshots vs JOIN vn v ON v.id = vs.id AND vs.scr IN}, grep $_->{id} =~ /sf/, @$l;
    enrich_merge id => q{SELECT image  AS id, 'c' AS entry_type, id   AS entry_id, name    AS entry_title FROM chars WHERE image IN}, grep $_->{id} =~ /ch/, @$l;
    $_->{url} = tuwf->imgurl($_->{id}) for @$l;
}


my $SEND = form_compile any => {
    history => $VNWeb::Elm::apis{ImageResult}[0]
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
         LIMIT 100'
    );
    warn sprintf 'Weighted random image sampling query returned %d < 100 rows for u%d', scalar @$l, auth->uid if @$l < 100;
    enrich_image $l;
    elm_ImageResult $l;
};


# TODO: This permits anyone to vote on any image; Might want to restrict that
# to images that have been randomly selected for the user to avoid abuse.
elm_api ImageVote => undef, {
    votes => { sort_keys => 'id', aoh => {
        id       => { regex => qr/^\((ch|cv|sf),[1-9][0-9]*\)$/ },
        sexual   => { uint => 1, range => [0,2] },
        violence => { uint => 1, range => [0,2] },
    } },
}, sub {
    my($data) = @_;
    return elm_Unauth if !auth->permImgvote;
    $_->{uid} = auth->uid for $data->{votes}->@*;
    tuwf->dbExeci('INSERT INTO image_votes', $_, 'ON CONFLICT (id, uid) DO UPDATE SET', $_, ', date = now()') for $data->{votes}->@*;
    elm_Success
};



TUWF::get qr{/img/vote}, sub {
    return tuwf->resDenied if !auth->permImgvote;

    my $recent = [ reverse tuwf->dbAlli('SELECT id FROM image_votes WHERE uid =', \auth->uid, 'ORDER BY date DESC LIMIT', \30)->@* ];
    enrich_image $recent;

    framework_ title => 'Image flagging', sub {
        elm_ 'ImageFlagging', $SEND, { history => $recent };
    };
};

1;
