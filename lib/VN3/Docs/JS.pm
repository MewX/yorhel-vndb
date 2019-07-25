package Docs::JS;

use VN3::Prelude;
use VN3::Docs::Lib;

json_api '/js/markdown.json', {
    content => { required => 0, default => '' }
}, sub {
    tuwf->resJSON({Unauth => 1}) if !auth->permDbmod;
    tuwf->resJSON({Content => md2html shift->{content}});
};

1;
