
package VNDB::Handler::Producers;

use strict;
use warnings;
use TUWF ':html', ':xml';
use VNDB::Func;
use VNDB::Types;


TUWF::register(
  qr{p/([a-z0]|all)}               => \&list,
  qr{xml/producers\.xml}           => \&pxml,
);


sub list {
  my($self, $char) = @_;

  my $f = $self->formValidate(
    { get => 'p', required => 0, default => 1, template => 'page' },
    { get => 'q', required => 0, default => '' },
  );
  return $self->resNotFound if $f->{_err};

  my($list, $np) = $self->dbProducerGet(
    $char ne 'all' ? ( char => $char ) : (),
    $f->{q} ? ( search => $f->{q} ) : (),
    results => 150,
    page => $f->{p}
  );

  $self->htmlHeader(title => 'Browse producers');

  div class => 'mainbox';
   h1 'Browse producers';
   form action => '/p/all', 'accept-charset' => 'UTF-8', method => 'get';
    $self->htmlSearchBox('p', $f->{q});
   end;
   p class => 'browseopts';
    for ('all', 'a'..'z', 0) {
      a href => "/p/$_", $_ eq $char ? (class => 'optselected') : (), $_ eq 'all' ? 'ALL' : $_ ? uc $_ : '#';
    }
   end;
  end;

  my $pageurl = "/p/$char" . ($f->{q} ? "?q=$f->{q}" : '');
  $self->htmlBrowseNavigate($pageurl, $f->{p}, $np, 't');
  div class => 'mainbox producerbrowse';
   h1 $f->{q} ? 'Search results' : 'Producer list';
   if(!@$list) {
     p 'No results found';
   } else {
     # spread the results over 3 equivalent-sized lists
     my $perlist = @$list/3 < 1 ? 1 : @$list/3;
     for my $c (0..(@$list < 3 ? $#$list : 2)) {
       ul;
       for ($perlist*$c..($perlist*($c+1))-1) {
         li;
          cssicon 'lang '.$list->[$_]{lang}, $LANGUAGE{$list->[$_]{lang}};
          a href => "/p$list->[$_]{id}", title => $list->[$_]{original}, $list->[$_]{name};
         end;
       }
       end;
     }
   }
   clearfloat;
  end 'div';
  $self->htmlBrowseNavigate($pageurl, $f->{p}, $np, 'b');
  $self->htmlFooter;
}


# peforms a (simple) search and returns the results in XML format
sub pxml {
  my $self = shift;

  my $f = $self->formValidate(
    { get => 'q', required => 0, maxlength => 500 },
    { get => 'id', required => 0, multi => 1, template => 'id' },
    { get => 'r', required => 0, template => 'uint', min => 1, max => 50, default => 10 },
  );
  return $self->resNotFound if $f->{_err} || (!$f->{q} && !$f->{id} && !$f->{id}[0]);

  my($list, $np) = $self->dbProducerGet(
    !$f->{q} ? () : $f->{q} =~ /^p([1-9]\d*)/ ? (id => $1) : (search => $f->{q}, sort => 'search'),
    $f->{id} && $f->{id}[0] ? (id => $f->{id}) : (),
    results => $f->{r},
    page => 1,
  );

  $self->resHeader('Content-type' => 'text/xml; charset=UTF-8');
  xml;
  tag 'producers', more => $np ? 'yes' : 'no', query => $f->{q}||'';
   for(@$list) {
     tag 'item', id => $_->{id}, $_->{name};
   }
  end;
}


1;

