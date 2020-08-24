package VNWeb::Reviews::Lib;

use VNWeb::Prelude;
use Exporter 'import';

our @EXPORT = qw/review_vote_/;


# Display the up/down vote counts for a review, optionally with the option for the user to vote.
# Takes an object with the following fields: id, c_up, c_down, my, can
sub review_vote_ {
    my($w) = @_;
    my sub plain_ {
        span_ sprintf '👍 %d 👎 %d', $w->{c_up}, $w->{c_down};
    };
    return plain_ if !auth || !$w->{can};
    elm_ 'Reviews.Vote' => $VNWeb::Reviews::Elm::VOTE_OUT, { id => $w->{id}, up => $w->{c_up}, down => $w->{c_down}, my => $w->{my} }, \&plain_;
}

1;
