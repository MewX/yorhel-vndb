package VNWeb::Images::Lib;

use VNWeb::Prelude;
use Exporter 'import';

our @EXPORT = qw/enrich_image validate_token image_ enrich_image_obj/;


# Enrich images so that they match the format expected by the 'ImageResult' Elm
# API response.
#
# Also adds signed tokens to the image list - indicating that the current user
# is permitted to vote on these images. These tokens ensure that non-moderators
# can only vote on images that they have been randomly assigned, thus
# preventing possible abuse when a single person uses multiple accounts to
# influence the rating of a single image.
sub enrich_image {
    my($canvote, $l) = @_;
    enrich_merge id => sub { sql q{
      SELECT i.id, i.width, i.height, i.c_votecount AS votecount
           , i.c_sexual_avg AS sexual_avg, i.c_sexual_stddev AS sexual_stddev
           , i.c_violence_avg AS violence_avg, i.c_violence_stddev AS violence_stddev
           , iv.sexual AS my_sexual, iv.violence AS my_violence
           , COALESCE(EXISTS(SELECT 1 FROM image_votes iv0 WHERE iv0.id = i.id AND iv0.ignore) AND NOT iv.ignore, FALSE) AS my_overrule
           , COALESCE('v'||v.id, 'c'||c.id, 'v'||vsv.id) AS entry_id
           , COALESCE(v.title, c.name, vsv.title) AS entry_title
        FROM images i
        LEFT JOIN image_votes iv ON iv.id = i.id AND iv.uid =}, \auth->uid, q{
        LEFT JOIN vn v ON i.id BETWEEN 'cv1' AND vndbid_max('cv') AND v.image = i.id
        LEFT JOIN chars c ON i.id BETWEEN 'ch1' AND vndbid_max('ch') AND c.image = i.id
        LEFT JOIN vn_screenshots vs ON i.id BETWEEN 'sf1' AND vndbid_max('sf') AND vs.scr = i.id
        LEFT JOIN vn vsv ON i.id BETWEEN 'sf1' AND vndbid_max('sf') AND vsv.id = vs.id
       WHERE i.id IN}, $_
    }, $l;

    enrich votes => id => id => sub { sql '
        SELECT iv.id, iv.uid, iv.sexual, iv.violence, iv.ignore OR (u.id IS NOT NULL AND NOT u.perm_imgvote) AS ignore, ', sql_user(), '
          FROM image_votes iv
          LEFT JOIN users u ON u.id = iv.uid
         WHERE iv.id IN', $_,
               auth ? ('AND (iv.uid IS NULL OR iv.uid <> ', \auth->uid, ')') : (), '
         ORDER BY u.username'
    }, $l;

    for(@$l) {
        $_->{token} = $canvote || ($_->{votecount} == 0 && auth->permImgvote) ? auth->csrftoken(0, "imgvote-$_->{id}") : undef;
        $_->{entry} = $_->{entry_id} ? { id => $_->{entry_id}, title => $_->{entry_title} } : undef;
        delete $_->{entry_id};
        delete $_->{entry_title};
        for my $v ($_->{votes}->@*) {
            $v->{user} = xml_string sub { user_ $v }; # Easier than duplicating user_() in Elm
            delete $v->{$_} for grep /^user_/, keys %$v;
        }
    }
}

# Validates the token generated by enrich_image;
sub validate_token {
    my($l) = @_;
    my $ok = 1;
    $ok &&= $_->{token} && auth->csrfcheck($_->{token}, "imgvote-$_->{id}") for @$l;
    $ok;
}


# Display (or not) an image with preference toggle and hover-information.
# Given $img is assumed to be an object generated by enrich_image_obj().
sub image_ {
    my($img, %opt) = @_;
    return p_ 'No image' if !$img;

    my($sex,$vio) = $img->@{'sexual', 'violence'};
    my $sexd = ['Safe', 'Suggestive', 'Explicit']->[$sex] if $img->{votecount};
    my $viod = ['Tame', 'Violent',    'Brutal'  ]->[$vio] if $img->{votecount};
    my $sexp = auth->pref('max_sexual')||0;
    my $viop = auth->pref('max_violence')||0;
    my $sexh = $sex > $sexp && $sexp >= 0 if $img->{votecount};
    my $vioh = $vio > $viop if $img->{votecount};
    my $hidden = $sexp < 0 || $sexh || $vioh || (!$img->{votecount} && ($sexp < 2 || $viop < 2));
    my $hide_on_click = $sexp < 0 || $sex || $vio || !$img->{votecount};

    label_ class => 'imghover', style => "width: $img->{width}px; height: $img->{height}px", sub {
        input_ type => 'checkbox', class => 'visuallyhidden', $hidden ? () : (checked => 'checked') if $hide_on_click;
        div_ class => 'imghover--visible', sub {
            img_ src => tuwf->imgurl($img->{id}), $opt{alt} ? (alt => $opt{alt}) : ();
            a_ class => 'imghover--overlay', href => "/img/$img->{id}?view=".viewset(show_nsfw=>1),
                $img->{votecount} ? sprintf '%s / %s (%d)', $sexd, $viod, $img->{votecount} : 'Not flagged';
        };
        div_ class => 'imghover--warning', sub {
            if($img->{votecount}) {
                txt_ 'This image has been flagged as:';
                br_; br_;
                txt_ 'Sexual: '; $sexh ? b_ class => 'standout', $sexd : txt_ $sexd;
                br_;
                txt_ 'Violence '; $vioh ? b_ class => 'standout', $viod : txt_ $viod;
            } else {
                txt_ 'This image has not yet been flagged';
            }
            br_; br_;
            span_ class => 'fake_link', 'Show me anyway';
            br_; br_;
            b_ class => 'grayedout', 'This warning can be disabled in your account';
        } if $hide_on_click;
    }
}


sub enrich_image_obj {
    my $field = shift;
    enrich_obj $field => id => 'SELECT id, width, height, c_votecount AS votecount, c_sexual_avg AS sexual_avg, c_violence_avg AS violence_avg FROM images WHERE id IN', @_;

    # Also add our final verdict. Still no clue why I chose these thresholds, but they seem to work.
    for (map +(ref $_ eq 'ARRAY' ? @$_ : $_), @_) {
        local $_ = $_->{$field};
        if(ref $_) {
            $_->{sexual}   = !$_->{votecount} ? 2 : $_->{sexual_avg}   > 1.3 ? 2 : $_->{sexual_avg}   > 0.4 ? 1 : 0;
            $_->{violence} = !$_->{votecount} ? 2 : $_->{violence_avg} > 1.3 ? 2 : $_->{violence_avg} > 0.4 ? 1 : 0;
        }
    }
}

1;
