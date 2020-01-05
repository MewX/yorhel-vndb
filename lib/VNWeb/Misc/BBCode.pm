package VNWeb::Misc::BBCode;

use VNWeb::Prelude;

elm_api BBCode => undef, {
    content => { required => 0, default => '' }
}, sub {
    elm_Content bb2html bb_subst_links shift->{content};
};

1;
