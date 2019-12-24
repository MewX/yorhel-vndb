
package VNDB::Handler::ULists;

use strict;
use warnings;
use TUWF ':xml';
use VNDB::Func;
use VNDB::Types;


TUWF::register(
  qr{r([1-9]\d*)/list},  \&rlist_e,
  qr{xml/rlist.xml},     \&rlist_e,
);


sub rlist_e {
  my($self, $id) = @_;

  my $rid = $id;
  if(!$rid) {
    my $f = $self->formValidate({ get => 'id', required => 1, template => 'id' });
    return $self->resNotFound if $f->{_err};
    $rid = $f->{id};
  }

  my $uid = $self->authInfo->{id};
  return $self->htmlDenied() if !$uid;

  return if !$self->authCheckCode;
  my $f = $self->formValidate(
    { get => 'e', required => 1, enum => [ -1, keys %RLIST_STATUS ] },
    { get => 'ref', required => 0, default => "/r$rid" }
  );
  return $self->resNotFound if $f->{_err};

  $self->dbRListDel($uid, $rid) if $f->{e} == -1;
  $self->dbRListAdd($uid, $rid, $f->{e}) if $f->{e} >= 0;

  if($id) {
    $self->resRedirect($f->{ref}, 'temp');
  } else {
    # doesn't really matter what we return, as long as it's XML
    $self->resHeader('Content-type' => 'text/xml');
    xml;
    tag 'done', '';
  }
}

1;

