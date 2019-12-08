package VNWeb::Misc::BBCode;

use VNWeb::Prelude;

json_api qr{/js/bbcode\.json}, {
    content => { required => 0, default => '' }
}, sub {
    elm_Content bb2html bb_subst_links shift->{content};
};
