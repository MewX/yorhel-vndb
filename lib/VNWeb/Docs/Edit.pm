package VNWeb::Docs::Edit;

use VNWeb::Prelude;
use VNWeb::Docs::Lib;


my $FORM = {
    id      => { id => 1 },
    title   => { maxlength => 200 },
    content => { required => 0, default => '' },
    hidden  => { anybool => 1 },
    locked  => { anybool => 1 },

    editsum => { _when => 'in out', editsum => 1 },
};

my $FORM_OUT = form_compile out => $FORM;
my $FORM_IN  = form_compile in  => $FORM;
my $FORM_CMP = form_compile cmp => $FORM;


TUWF::get qr{/$RE{drev}/edit} => sub {
    my $d = db_entry d => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    return tuwf->resDenied if !can_edit d => $d;

    $d->{editsum} = $d->{chrev} == $d->{maxrev} ? '' : "Reverted to revision d$d->{id}.$d->{chrev}";

    framework_ title => "Edit $d->{title}", type => 'd', dbobj => $d, tab => 'edit',
    sub {
        elm_ DocEdit => $FORM_OUT, $d;
    };
};


elm_api DocEdit => $FORM_OUT, $FORM_IN, sub {
    my $data = shift;
    my $doc = db_entry d => $data->{id} or return tuwf->resNotFound;

    return elm_Unauth if !can_edit d => $doc;
    return elm_Unchanged if !form_changed $FORM_CMP, $data, $doc;

    $data->{html} = md2html $data->{content};
    my($id,undef,$rev) = db_edit d => $doc->{id}, $data;
    elm_Redirect "/d$id.$rev";
};


elm_api Markdown => undef, {
    content => { required => 0, default => '' }
}, sub {
    return elm_Unauth if !auth->permDbmod;
    elm_Content enrich_html md2html shift->{content};
};


1;
