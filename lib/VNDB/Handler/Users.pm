
package VNDB::Handler::Users;

use strict;
use warnings;
use TUWF ':html', 'xml_escape';
use VNDB::Func;
use VNDB::Types;
use VNWeb::Auth;
use POSIX 'floor';
use PWLookup;


TUWF::register(
  qr{u([1-9]\d*)/posts}       => \&posts,
  qr{u([1-9]\d*)/del(/[od])?} => \&delete,
  qr{u/(all|[0a-z])}          => \&list,
);


sub posts {
  my($self, $uid) = @_;

  # fetch user info
  my $u = $self->dbUserGet(uid => $uid, what => 'hide_list pubskin')->[0];
  return $self->resNotFound if !$u->{id};

  my $f = $self->formValidate(
    { get => 'p', required => 0, default => 1, template => 'page' }
  );
  return $self->resNotFound if $f->{_err};

  my($posts, $np) = $self->dbPostGet(uid => $uid, hide => 1, what => 'thread', page => $f->{p}, sort => 'date', reverse => 1);

  my $title = 'Posts made by '.VNWeb::HTML::user_displayname($u);
  $self->htmlHeader(title => $title, noindex => 1, pubskin => $u);
  $self->htmlMainTabs(u => $u, 'posts');
  div class => 'mainbox';
   h1 $title;
   if(!@$posts) {
     p VNWeb::HTML::user_displayname($u)." hasn't made any posts yet.";
   }
  end;

  $self->htmlBrowse(
    items    => $posts,
    class    => 'uposts',
    options  => $f,
    nextpage => $np,
    pageurl  => "/u$uid/posts",
    header   => [
      [ '' ],
      [ '' ],
      [ 'Date' ],
      [ 'Title' ],
    ],
    row     => sub {
      my($s, $n, $l) = @_;
      Tr;
       td class => 'tc1'; a href => "/t$l->{tid}.$l->{num}", 't'.$l->{tid}; end;
       td class => 'tc2'; a href => "/t$l->{tid}.$l->{num}", '.'.$l->{num}; end;
       td class => 'tc3', fmtdate $l->{date};
       td class => 'tc4';
        a href => "/t$l->{tid}.$l->{num}", $l->{title};
        b class => 'grayedout'; lit bb2html $l->{msg}, 150; end;
       end;
      end;
    },
  ) if @$posts;
  $self->htmlFooter;
}


sub delete {
  my($self, $uid, $act) = @_;
  return $self->htmlDenied if ($self->authInfo->{id}) != 2; # Yeah, yorhel-only function

  # rarely used admin function, won't really need translating

  # confirm
  if(!$act) {
    my $code = $self->authGetCode("/u$uid/del/o");
    my $u = $self->dbUserGet(uid => $uid, what => 'hide_list')->[0];
    return $self->resNotFound if !$u->{id};
    $self->htmlHeader(title => 'Delete user', noindex => 1);
    $self->htmlMainTabs('u', $u, 'del');
    div class => 'mainbox';
     div class => 'warning';
      h2 'Delete user';
      p;
       lit qq|Are you sure you want to remove <a href="/u$uid">$u->{username}</a>'s account?<br /><br />|
          .qq|<a href="/u$uid/del/o?formcode=$code">Yes, I'm not kidding!</a>|;
      end;
     end;
    end;
    $self->htmlFooter;
  }
  # delete
  elsif($act eq '/o') {
    return if !$self->authCheckCode;
    $self->dbUserDel($uid);
    $self->resRedirect("/u$uid/del/d", 'post');
  }
  # done
  elsif($act eq '/d') {
    $self->htmlHeader(title => 'Delete user', noindex => 1);
    div class => 'mainbox';
     div class => 'notice';
      p 'User deleted.';
     end;
    end;
    $self->htmlFooter;
  }
}


sub list {
  my($self, $char) = @_;

  my $f = $self->formValidate(
    { get => 's', required => 0, default => 'username', enum => [ qw|username registered votes changes tags| ] },
    { get => 'o', required => 0, default => 'a', enum => [ 'a','d' ] },
    { get => 'p', required => 0, default => 1, template => 'page' },
    { get => 'q', required => 0, default => '', maxlength => 50 },
  );
  return $self->resNotFound if $f->{_err};

  $self->htmlHeader(noindex => 1, title => 'Browse users');

  div class => 'mainbox';
   h1 'Browse users';
   form action => '/u/all', 'accept-charset' => 'UTF-8', method => 'get';
    $self->htmlSearchBox('u', $f->{q});
   end;
   p class => 'browseopts';
    for ('all', 'a'..'z', 0) {
      a href => "/u/$_", $_ eq $char ? (class => 'optselected') : (), $_ eq 'all' ? 'ALL' : $_ ? uc $_ : '#';
    }
   end;
  end;

  my($list, $np) = $self->dbUserGet(
    sort => $f->{s}, reverse => $f->{o} eq 'd',
    what => 'hide_list',
    $char ne 'all' ? (
      firstchar => $char ) : (),
    results => 50,
    page => $f->{p},
    search => $f->{q},
  );

  $self->htmlBrowse(
    items    => $list,
    options  => $f,
    nextpage => $np,
    pageurl  => "/u/$char?o=$f->{o};s=$f->{s};q=$f->{q}",
    sorturl  => "/u/$char?q=$f->{q}",
    header   => [
      [ 'Username',   'username'   ],
      [ 'Registered', 'registered' ],
      [ 'Votes',      'votes'      ],
      [ 'Edits',      'changes'    ],
      [ 'Tags',       'tags'       ],
    ],
    row     => sub {
      my($s, $n, $l) = @_;
      Tr;
       td class => 'tc1';
        VNWeb::HTML::user_($l);
       end;
       td class => 'tc2', fmtdate $l->{registered};
       td class => 'tc3'.($l->{hide_list} && $self->authCan('usermod') ? ' linethrough' : '');
        lit $l->{hide_list} && !$self->authCan('usermod') ? '-' : !$l->{c_votes} ? 0 :
          qq|<a href="/u$l->{id}/votes">$l->{c_votes}</a>|;
       end;
       td class => 'tc4';
        lit !$l->{c_changes} ? 0 : qq|<a href="/u$l->{id}/hist">$l->{c_changes}</a>|;
       end;
       td class => 'tc5';
        lit !$l->{c_tags} ? 0 : qq|<a href="/g/links?u=$l->{id}">$l->{c_tags}</a>|;
       end;
      end 'tr';
    },
  );
  $self->htmlFooter;
}


1;

