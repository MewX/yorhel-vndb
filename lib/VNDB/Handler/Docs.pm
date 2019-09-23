
package VNDB::Handler::Docs;


use strict;
use warnings;
use TUWF ':html';
use VNDB::Func;
use Text::MultiMarkdown 'markdown';
use VNWeb::Docs::Lib;


TUWF::register(
  qr{d([1-9]\d*)(?:\.([1-9]\d*))?/edit} => \&edit,
);


sub edit {
  my($self, $id, $rev) = @_;

  my $d = $self->dbDocGetRev(id => $id, rev => $rev)->[0];
  return $self->resNotFound if !$d->{id};
  $rev = undef if $d->{lastrev};

  return $self->htmlDenied if !$self->authCan('dbmod');

  my %b4 = map { $_ => $d->{$_} } qw|title content ihid ilock|;
  my $frm;

  if($self->reqMethod eq 'POST') {
    return if !$self->authCheckCode;
    $frm = $self->formValidate(
      { post => 'title',         maxlength => 200 },
      { post => 'content',       },
      { post => 'editsum',       template => 'editsum' },
      { post => 'ihid',          required  => 0 },
      { post => 'ilock',         required  => 0 },
      { post => 'preview',       required  => 0 },
    );
    if(!$frm->{_err} && !$frm->{preview}) {
      $frm->{ihid} = $frm->{ihid}?1:0;
      $frm->{ilock} = $frm->{ilock}?1:0;

      return $self->resRedirect("/d$id", 'post') if !form_compare(\%b4, $frm);
      my $nrev = $self->dbItemEdit(d => $id, $d->{rev}, %$frm);
      return $self->resRedirect("/d$nrev->{itemid}.$nrev->{rev}", 'post');
    }
  }

  !defined $frm->{$_} && ($frm->{$_} = $b4{$_}) for keys %b4;
  $frm->{editsum} = sprintf 'Reverted to revision d%d.%d', $id, $rev if $rev && !defined $frm->{editsum};
  delete $frm->{_err} if $frm->{preview};

  my $title = "Edit $d->{title}";
  $self->htmlHeader(title => $title, noindex => 1);
  $self->htmlMainTabs('d', $d, 'edit');

  if($frm->{preview}) {
    div class => 'mainbox';
     h1 'Preview';
     div class => 'docs';
      lit md2html $frm->{content};
     end;
    end;
  }

  $self->htmlForm({ frm => $frm, action => "/d$id/edit", editsum => 1, preview => 1 }, dedit => [ $title,
    [ input  => name => 'Title', short => 'title', width => 300 ],
    [ static => nolabel => 1, content => q{
         <br>Contents (HTML and MultiMarkdown supported, which is
         <a href="https://daringfireball.net/projects/markdown/basics">Markdown</a>
         with some <a href="http://fletcher.github.io/MultiMarkdown-5/syntax.html">extensions</a>).} ],
    [ textarea => short => 'content', name => 'Content', rows => 50, cols => 90, nolabel => 1 ],
  ]);
  $self->htmlFooter;
}

1;
