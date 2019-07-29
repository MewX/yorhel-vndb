package Docs::JS;

use VN3::Prelude;
use VN3::Docs::Lib;

my $elm_Content = elm_api Content => {};

json_api '/js/markdown.json', {
    content => { required => 0, default => '' }
}, sub {
    return $elm_Unauth->() if !auth->permDbmod;
    $elm_Content->(md2html shift->{content});
};

1;
