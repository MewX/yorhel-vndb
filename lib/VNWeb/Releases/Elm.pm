package VNWeb::Releases::Elm;

use VNWeb::Prelude;
use VNWeb::Releases::Lib;


# Used by UList.Opt and CharEdit to fetch releases from a VN id.
elm_api Release => undef, { vid => { id => 1 } }, sub {
    my($data) = @_;
    elm_Releases releases_by_vn $data->{vid};
};

1;
