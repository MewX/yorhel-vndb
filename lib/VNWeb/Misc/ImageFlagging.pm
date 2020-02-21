package Misc::ImageFlagging;

use VNWeb::Prelude;

# TODO: /img/<imageid> endpoint to open the imageflagging UI for a particular image.

TUWF::get qr{/img/vote}, sub {
    return tuwf->resDenied if !auth->permEdit; # TODO: permImg?
    framework_ title => 'Image flagging', sub {
        # TODO: Include recent votes
        elm_ 'ImageFlagging';
    };
};


# Fetch a list of images for the user to vote on.
elm_api Images => undef, {}, sub {
    return elm_Unauth if !auth->permEdit; # XXX

    # TODO: Return nothing when the user has voted on >90% of the images?

    # This query is kind of slow, but there's a few ways to improve:
    # - create index .. on images (id) include (c_weight) where c_weight > 0;
    # - Add a 'images.c_uids integer[]' cache to filter out rows faster.
    # - Distribute images in a fixed number of buckets and choose a random bucket up front.
    my $l = tuwf->dbAlli('
        SELECT id, width, height, c_votecount AS votecount, c_sexual_avg AS sexual_avg, c_sexual_stddev AS sexual_stddev, c_violence_avg AS violence_avg, c_violence_stddev AS violence_stddev
          FROM images i
         WHERE c_weight > 0
           AND NOT EXISTS(SELECT 1 FROM image_votes iv WHERE iv.id = i.id AND iv.uid =', \auth->uid, ')
         ORDER BY random() ^ (1.0/c_weight) DESC
         LIMIT 100'
    );
    enrich_merge id => q{SELECT image  AS id, 'v' AS entry_type, id   AS entry_id, title   AS entry_title FROM vn WHERE image IN}, grep $_->{id} =~ /cv/, @$l;
    enrich_merge id => q{SELECT vs.scr AS id, 'v' AS entry_type, v.id AS entry_id, v.title AS entry_title FROM vn_screenshots vs JOIN vn v ON v.id = vs.id AND vs.scr IN}, grep $_->{id} =~ /sf/, @$l;
    enrich_merge id => q{SELECT image  AS id, 'c' AS entry_type, id   AS entry_id, name    AS entry_title FROM chars WHERE image IN}, grep $_->{id} =~ /ch/, @$l;
    $_->{url} = tuwf->imgurl($_->{id}) for @$l;
    $_->{my_sexual} = $_->{my_violence} = undef for @$l;
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
    return elm_Unauth if !auth->permEdit; # XXX
    $_->{uid} = auth->uid for $data->{votes}->@*;
    tuwf->dbExeci('INSERT INTO image_votes', $_, 'ON CONFLICT (id, uid) DO UPDATE SET', $_, ', date = now()') for $data->{votes}->@*;
    elm_Success
};

1;
