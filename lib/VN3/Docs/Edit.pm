package VN3::Docs::Edit;

use VN3::Prelude;
use VN3::Docs::Lib;
use VN3::ElmGen;


my $FORM = {
    title   => { maxlength => 200 },
    content => { required => 0, default => '' },
    hidden  => { anybool => 1 },
    locked  => { anybool => 1 },

    editsum => { _when => 'in out', editsum => 1 },
    id      => { _when => 'out', id => 1 },
};

my $FORM_OUT = form_compile out => $FORM;
my $FORM_IN  = form_compile in  => $FORM;
my $FORM_CMP = form_compile cmp => $FORM;

elm_form DocEdit => $FORM_OUT, $FORM_IN;


TUWF::get qr{/$DREV_RE/edit} => sub {
    my $d = entry d => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    return tuwf->resDenied if !can_edit d => $d;

    $d->{editsum} = $d->{chrev} == $d->{maxrev} ? '' : "Reverted to revision d$d->{id}.$d->{chrev}";

    Framework title => "Edit $d->{title}", index => 0,
    sub {
        Div class => 'row', sub {
            Div class => 'fixed-size-left-sidebar-md doc-list', \&Sidebar;
            Div class => 'col-md col-md--4', sub {
                Div 'data-elm-module' => 'DocEdit',
                    'data-elm-flags' => JSON::XS->new->encode($FORM_OUT->analyze->coerce_for_json($d)), '';
            };
        };
    };
};


json_api qr{/$DOC_RE/edit}, $FORM_IN, sub {
    my $data = shift;
    my $doc = entry d => tuwf->capture('id') or return tuwf->resNotFound;

    return tuwf->resJSON({Unauth => 1}) if !can_edit d => $doc;
    return tuwf->resJSON({Unchanged => 1}) if !form_changed $FORM_CMP, $data, $doc;

    my($id,undef,$rev) = update_entry d => $doc->{id}, $data;
    tuwf->resJSON({Changed => [$id, $rev]});
};

1;
