package VN3::Docs::Page;

use VN3::Prelude;
use VN3::Docs::Lib;

TUWF::get qr{/$DREV_RE} => sub {
    my $d = entry d => tuwf->capture('id'), tuwf->capture('rev');
    return tuwf->resNotFound if !$d || $d->{hidden};

    Framework title => $d->{title},
    sub {
        Div class => 'row', sub {
            Div class => 'fixed-size-left-sidebar-md doc-list', \&Sidebar;
            Div class => 'col-md doc', sub {
                EntryEdit d => $d;
                H1 $d->{title};
                Lit md2html $d->{content};
            };
        };
    };
};

1;
