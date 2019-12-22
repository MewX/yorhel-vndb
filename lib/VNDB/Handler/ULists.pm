
package VNDB::Handler::ULists;

use strict;
use warnings;
use TUWF ':html', ':xml';
use VNDB::Func;
use VNDB::Types;


TUWF::register(
  qr{v([1-9]\d*)/vote},  \&vnvote,
  qr{v([1-9]\d*)/wish},  \&vnwish,
  qr{v([1-9]\d*)/list},  \&vnlist_e,
  qr{r([1-9]\d*)/list},  \&rlist_e,
  qr{xml/rlist.xml},     \&rlist_e,
  qr{(u)([1-9]\d*)/votes}, \&votelist,
  qr{u([1-9]\d*)/wish},  \&wishlist,
  qr{u([1-9]\d*)/list},  \&vnlist,
);


sub vnvote {
  my($self, $id) = @_;

  my $uid = $self->authInfo->{id};
  return $self->htmlDenied() if !$uid;

  return if !$self->authCheckCode;
  my $f = $self->formValidate(
    { get => 'v', regex => qr/^(-1|([1-9]|10)(\.[0-9])?)$/ },
    { get => 'ref', required => 0, default => "/v$id" }
  );
  return $self->resNotFound if $f->{_err} || ($f->{v} != -1 && ($f->{v} > 10 || $f->{v} < 1));

  $self->dbVoteDel($uid, $id) if $f->{v} == -1;
  $self->dbVoteAdd($id, $uid, $f->{v}*10) if $f->{v} > 0;

  $self->resRedirect($f->{ref}, 'temp');
}


sub vnwish {
  my($self, $id) = @_;

  my $uid = $self->authInfo->{id};
  return $self->htmlDenied() if !$uid;

  return if !$self->authCheckCode;
  my $f = $self->formValidate(
    { get => 's', enum => [ -1, keys %WISHLIST_STATUS ] },
    { get => 'ref', required => 0, default => "/v$id" }
  );
  return $self->resNotFound if $f->{_err};

  $self->dbWishListDel($uid, $id) if $f->{s} == -1;
  $self->dbWishListAdd($id, $uid, $f->{s}) if $f->{s} != -1;

  $self->resRedirect($f->{ref}, 'temp');
}


sub vnlist_e {
  my($self, $id) = @_;

  my $uid = $self->authInfo->{id};
  return $self->htmlDenied() if !$uid;

  return if !$self->authCheckCode;
  my $f = $self->formValidate(
    { get => 'e', enum => [ -1, keys %VNLIST_STATUS ] },
    { get => 'ref', required => 0, default => "/v$id" }
  );
  return $self->resNotFound if $f->{_err};

  $self->dbVNListDel($uid, $id) if $f->{e} == -1;
  $self->dbVNListAdd($uid, $id, $f->{e}) if $f->{e} != -1;

  $self->resRedirect($f->{ref}, 'temp');
}


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


# XXX: $type eq 'v' is not used anymore.
sub votelist {
  my($self, $type, $id) = @_;

  my $obj = $type eq 'v' ? $self->dbVNGet(id => $id)->[0] : $self->dbUserGet(uid => $id, what => 'hide_list')->[0];
  return $self->resNotFound if !$obj->{id};

  my $own = $type eq 'u' && $self->authInfo->{id} && $self->authInfo->{id} == $id;
  return $self->resNotFound if $type eq 'u' && !$own && !(!$obj->{hide_list} || $self->authCan('usermod'));

  my $f = $self->formValidate(
    { get => 'p',  required => 0, default => 1, template => 'page' },
    { get => 'o',  required => 0, default => 'd', enum => ['a', 'd'] },
    { get => 's',  required => 0, default => 'date', enum => [qw|date title vote|] },
    { get => 'c',  required => 0, default => 'all', enum => [ 'all', 'a'..'z', 0 ] },
  );
  return $self->resNotFound if $f->{_err};

  if($own && $self->reqMethod eq 'POST') {
    return if !$self->authCheckCode;
    my $frm = $self->formValidate(
      { post => 'vid', required => 1, multi => 1, template => 'id' },
      { post => 'batchvotes', required => 1, regex => qr/^(-1|([1-9]|10)(\.[0-9])?)$/ },
    );
    my @vid = grep $_ && $_ > 0, @{$frm->{vid}};
    if(!$frm->{_err} && @vid && $frm->{batchvotes} > -2) {
      $self->dbVoteDel($id, \@vid) if $frm->{batchvotes} == -1;
      $self->dbVoteAdd(\@vid, $id, $frm->{batchvotes}*10) if $frm->{batchvotes} > 0;
    }
  }

  my($list, $np) = $self->dbVoteGet(
    $type.'id' => $id,
    what     => $type eq 'v' ? 'user hide_list' : 'vn',
    hide_ign => $type eq 'v',
    sort     => $f->{s} eq 'title' && $type eq 'v' ? 'username' : $f->{s},
    reverse  => $f->{o} eq 'd',
    results  => 50,
    page     => $f->{p},
    $type eq 'u' && $f->{c} ne 'all' ? (vn_char => $f->{c}) : (),
  );

  my $title = $type eq 'v' ? "Votes for $obj->{title}" : 'Votes by '.VNWeb::HTML::user_displayname($obj);
  $self->htmlHeader(noindex => 1, type => $type, dbobj => $obj, title => $title);
  $self->htmlMainTabs($type => $obj, 'votes');
  div class => 'mainbox';
   h1 $title;
   if($type eq 'u') {
     p class => 'browseopts';
      for ('all', 'a'..'z', 0) {
        a href => "/$type$id/votes?c=$_", $_ eq $f->{c} ? (class => 'optselected') : (), $_ eq 'all' ? 'ALL' : $_ ? uc $_ : '#';
      }
     end;
   }
   p 'No votes to list. :-(' if !@$list;
  end;

  if($own) {
    my $code = $self->authGetCode("/u$id/votes");
    form action => "/u$id/votes?formcode=$code;c=$f->{c};s=$f->{s};p=$f->{p}", method => 'post';
  }

  @$list && $self->htmlBrowse(
    class    => 'votelist',
    items    => $list,
    options  => $f,
    nextpage => $np,
    pageurl  => "/$type$id/votes?c=$f->{c};o=$f->{o};s=$f->{s}",
    sorturl  => "/$type$id/votes?c=$f->{c}",
    header   => [
      [ 'Cast',  'date'  ],
      [ 'Vote',  'vote'  ],
      [ $type eq 'v' ? 'User' : 'Visual novel', 'title' ],
    ],
    row      => sub {
      my($s, $n, $l) = @_;
      Tr;
       td class => 'tc1';
        input type => 'checkbox', name => 'vid', value => $l->{vid} if $own;
        txt ' '.fmtdate $l->{date};
       end;
       td class => 'tc2', fmtvote $l->{vote};
       td class => 'tc3';
        if($type eq 'u') {
          a href => "/v$l->{vid}", title => $l->{original}||$l->{title}, shorten $l->{title}, 100;
        } elsif($l->{hide_list}) {
          b class => 'grayedout', 'hidden';
        } else {
          VNWeb::HTML::user_($l);
        }
       end;
      end;
    },
    $own ? (footer => sub {
      Tr;
       td colspan => 3, class => 'tc1';
        input type => 'checkbox', class => 'checkall', name => 'vid', value => 0;
        txt ' ';
        Select name => 'batchvotes', id => 'batchvotes';
         option value => -2, '-- with selected --';
         optgroup label => 'Change vote';
          option value => $_, sprintf '%d (%s)', $_, fmtrating $_ for (reverse 1..10);
          option value => -3, 'Other';
         end;
         option value => -1, 'revoke';
        end;
       end;
      end 'tr';
    }) : (),
  );
  end if $own;
  $self->htmlFooter;
}


sub wishlist {
  my($self, $uid) = @_;

  my $own = $self->authInfo->{id} && $self->authInfo->{id} == $uid;
  my $u = $self->dbUserGet(uid => $uid, what => 'hide_list')->[0];
  return $self->resNotFound if !$u || !$own && !(!$u->{hide_list} || $self->authCan('usermod'));

  my $f = $self->formValidate(
    { get => 'p', required => 0, default => 1, template => 'page' },
    { get => 'o', required => 0, default => 'd', enum => [ 'a', 'd' ] },
    { get => 's', required => 0, default => 'wstat', enum => [qw|title added wstat|] },
    { get => 'f', required => 0, default => -1, enum => [ -1, keys %WISHLIST_STATUS ] },
  );
  return $self->resNotFound if $f->{_err};

  if($own && $self->reqMethod eq 'POST') {
    return if !$self->authCheckCode;
    my $frm = $self->formValidate(
      { post => 'sel', required => 0, default => 0, multi => 1, template => 'id' },
      { post => 'batchedit', required => 1, enum => [ -1, keys %WISHLIST_STATUS ] },
    );
    $frm->{sel} = [ grep $_, @{$frm->{sel}} ]; # weed out "select all" checkbox
    if(!$frm->{_err} && @{$frm->{sel}} && $frm->{sel}[0]) {
      $self->dbWishListDel($uid, $frm->{sel}) if $frm->{batchedit} == -1;
      $self->dbWishListAdd($frm->{sel}, $uid, $frm->{batchedit}) if $frm->{batchedit} >= 0;
    }
  }

  my($list, $np) = $self->dbWishListGet(
    uid => $uid,
    sort => $f->{s}, reverse => $f->{o} eq 'd',
    $f->{f} != -1 ? (wstat => $f->{f}) : (),
    what => 'vn',
    results => 50,
    page => $f->{p},
  );

  my $title = $own ? 'My wishlist' : VNWeb::HTML::user_displayname($u)."'s wishlist";
  $self->htmlHeader(title => $title, noindex => 1, type => 'u', dbobj => $u);
  $self->htmlMainTabs('u', $u, 'wish');
  div class => 'mainbox';
   h1 $title;
   if(!@$list && $f->{f} == -1) {
      p 'Wishlist empty...';
     end;
     return $self->htmlFooter;
   }
   p class => 'browseopts';
    a $f->{f} == $_ ? (class => 'optselected') : (), href => "/u$uid/wish?f=$_",
        $_ == -1 ? 'All priorities' : $WISHLIST_STATUS{$_}
      for (-1, keys %WISHLIST_STATUS);
   end;
  end 'div';

  if($own) {
    my $code = $self->authGetCode("/u$uid/wish");
    form action => "/u$uid/wish?formcode=$code;f=$f->{f};o=$f->{o};s=$f->{s};p=$f->{p}", method => 'post';
  }

  $self->htmlBrowse(
    class    => 'wishlist',
    items    => $list,
    nextpage => $np,
    options  => $f,
    pageurl  => "/u$uid/wish?f=$f->{f};o=$f->{o};s=$f->{s}",
    sorturl  => "/u$uid/wish?f=$f->{f}",
    header   => [
      [ 'Title' => 'title' ],
      [ 'Priority'  => 'wstat' ],
      [ 'Added' => 'added' ],
    ],
    row      => sub {
      my($s, $n, $i) = @_;
      Tr;
       td class => 'tc1';
        input type => 'checkbox', name => 'sel', value => $i->{vid}
          if $own;
        a href => "/v$i->{vid}", title => $i->{original}||$i->{title}, ' '.shorten $i->{title}, 70;
       end;
       td class => 'tc2', $WISHLIST_STATUS{$i->{wstat}};
       td class => 'tc3', fmtdate $i->{added}, 'compact';
      end;
    },
    $own ? (footer => sub {
      Tr;
       td colspan => 3;
        input type => 'checkbox', class => 'checkall', name => 'sel', value => 0;
        txt ' ';
        Select name => 'batchedit', id => 'batchedit';
         option '-- with selected --';
         optgroup label => 'Change priority';
          option value => $_, $WISHLIST_STATUS{$_}
            for (keys %WISHLIST_STATUS);
         end;
         option value => -1, 'remove from wishlist';
        end;
       end;
      end;
    }) : (),
  );
  end 'form' if $own;
  $self->htmlFooter;
}


sub vnlist {
  my($self, $uid) = @_;

  my $own = $self->authInfo->{id} && $self->authInfo->{id} == $uid;
  my $u = $self->dbUserGet(uid => $uid, what => 'hide_list')->[0];
  return $self->resNotFound if !$u || !$own && !(!$u->{hide_list} || $self->authCan('usermod'));

  my $f = $self->formValidate(
    { get => 'p',  required => 0, default => 1, template => 'page' },
    { get => 'o',  required => 0, default => 'a', enum => [ 'a', 'd' ] },
    { get => 's',  required => 0, default => 'title', enum => [ 'title', 'vote' ] },
    { get => 'c',  required => 0, default => 'all', enum => [ 'all', 'a'..'z', 0 ] },
    { get => 'v',  required => 0, default => 0, enum => [ -1..1  ] },
    { get => 't',  required => 0, default => -1, enum => [ -1, keys %VNLIST_STATUS ] },
  );
  return $self->resNotFound if $f->{_err};

  if($own && $self->reqMethod eq 'POST') {
    return if !$self->authCheckCode;
    my $frm = $self->formValidate(
      { post => 'vid', required => 0, default => 0, multi => 1, template => 'id' },
      { post => 'rid', required => 0, default => 0, multi => 1, template => 'id' },
      { post => 'not', required => 0, default => '', maxlength => 2000 },
      { post => 'vns', required => 1, enum => [ -2, -1, keys %VNLIST_STATUS, 999 ] },
      { post => 'rel', required => 1, enum => [ -2, -1, keys %RLIST_STATUS ] },
    );
    my @vid = grep $_ > 0, @{$frm->{vid}};
    my @rid = grep $_ > 0, @{$frm->{rid}};
    if(!$frm->{_err} && @vid && $frm->{vns} > -2) {
      $self->dbVNListDel($uid, \@vid) if $frm->{vns} == -1;
      $self->dbVNListAdd($uid, \@vid, $frm->{vns}) if $frm->{vns} >= 0 && $frm->{vns} < 999;
      $self->dbVNListAdd($uid, \@vid, undef, $frm->{not}) if $frm->{vns} == 999;
    }
    if(!$frm->{_err} && @rid && $frm->{rel} > -2) {
      $self->dbRListDel($uid, \@rid) if $frm->{rel} == -1;
      $self->dbRListAdd($uid, \@rid, $frm->{rel}) if $frm->{rel} >= 0;
    }
  }

  my($list, $np) = $self->dbVNListList(
    uid => $uid,
    results => 50,
    page => $f->{p},
    sort => $f->{s}, reverse => $f->{o} eq 'd',
    voted => $f->{v} == 0 ? undef : $f->{v} < 0 ? 0 : $f->{v},
    $f->{c} ne 'all' ? (char => $f->{c}) : (),
    $f->{t} >= 0 ? (status => $f->{t}) : (),
  );

  my $title = $own ? 'My visual novel list' : VNWeb::HTML::user_displayname($u)."'s visual novel list";
  $self->htmlHeader(title => $title, noindex => 1, type => 'u', dbobj => $u);
  $self->htmlMainTabs('u', $u, 'list');

  # url generator
  my $url = sub {
    my($n, $v) = @_;
    $n ||= '';
    local $_ = "/u$uid/list";
    $_ .= '?c='.($n eq 'c' ? $v : $f->{c});
    $_ .= ';v='.($n eq 'v' ? $v : $f->{v});
    $_ .= ';t='.($n eq 't' ? $v : $f->{t});
    if($n eq 'page') {
      $_ .= ';o='.($n eq 'o' ? $v : $f->{o});
      $_ .= ';s='.($n eq 's' ? $v : $f->{s});
    }
    return $_;
  };

  div class => 'mainbox';
   h1 $title;
   p class => 'browseopts';
    for ('all', 'a'..'z', 0) {
      a href => $url->(c => $_), $_ eq $f->{c} ? (class => 'optselected') : (), $_ eq 'all' ? 'ALL' : $_ ? uc $_ : '#';
    }
   end;
   p class => 'browseopts';
    a href => $url->(v =>  0),  0 == $f->{v} ? (class => 'optselected') : (), 'All';
    a href => $url->(v =>  1),  1 == $f->{v} ? (class => 'optselected') : (), 'Only voted';
    a href => $url->(v => -1), -1 == $f->{v} ? (class => 'optselected') : (), 'Hide voted';
   end;
   p class => 'browseopts';
    a href => $url->(t => -1), -1 == $f->{t} ? (class => 'optselected') : (), 'All';
    a href => $url->(t => $_), $_ == $f->{t} ? (class => 'optselected') : (), $VNLIST_STATUS{$_} for keys %VNLIST_STATUS;
   end;
  end 'div';

  _vnlist_browse($self, $own, $list, $np, $f, $url, $uid);
  $self->htmlFooter;
}

sub _vnlist_browse {
  my($self, $own, $list, $np, $f, $url, $uid) = @_;

  if($own) {
    form action => $url->(), method => 'post';
    input type => 'hidden', class => 'hidden', name => 'not', id => 'not', value => '';
    input type => 'hidden', class => 'hidden', name => 'formcode', id => 'formcode', value => $self->authGetCode("/u$uid/list");
  }

  $self->htmlBrowse(
    class    => 'rlist',
    items    => $list,
    nextpage => $np,
    options  => $f,
    sorturl  => $url->(),
    pageurl  => $url->('page'),
    header   => [
      [ '' ],
      sub { td class => 'tc2', id => 'expandall'; lit '&#9656;'; end; },
      [ 'Title' => 'title' ],
      [ '' ], [ '' ],
      [ 'Status' ],
      [ 'Releases*' ],
      [ 'Vote'  => 'vote'  ],
    ],
    row      => sub {
      my($s, $n, $i) = @_;
      Tr class => 'nostripe'.($n%2 ? ' odd' : '');
       td class => 'tc1'; input type => 'checkbox', name => 'vid', value => $i->{vid} if $own; end;
       if(@{$i->{rels}}) {
         td class => 'tc2 collapse_but', id => "vid$i->{vid}"; lit '&#9656;'; end;
       } else {
         td class => 'tc2', '';
       }
       td class => 'tc3_5', colspan => 3;
        a href => "/v$i->{vid}", title => $i->{original}||$i->{title}, shorten $i->{title}, 70;
        b class => 'grayedout', $i->{notes} if $i->{notes};
       end;
       td class => 'tc6', $i->{status} ? $VNLIST_STATUS{$i->{status}} : '';
       td class => 'tc7';
        my $obtained = grep $_->{status}==2, @{$i->{rels}};
        my $total = scalar @{$i->{rels}};
        my $txt = sprintf '%d/%d', $obtained, $total;
        $txt = qq|<b class="done">$txt</b>| if $total && $obtained == $total;
        $txt = qq|<b class="todo">$txt</b>| if $obtained < $total;
        lit $txt;
       end;
       td class => 'tc8', fmtvote $i->{vote};
      end 'tr';

      for (@{$i->{rels}}) {
        Tr class => "nostripe collapse relhid collapse_vid$i->{vid}".($n%2 ? ' odd':'');
         td class => 'tc1', '';
         td class => 'tc2';
          input type => 'checkbox', name => 'rid', value => $_->{rid} if $own;
         end;
         td class => 'tc3';
          lit fmtdatestr $_->{released};
         end;
         td class => 'tc4';
          cssicon "lang $_", $LANGUAGE{$_} for @{$_->{languages}};
          cssicon "rt$_->{type}", $_->{type};
         end;
         td class => 'tc5';
          a href => "/r$_->{rid}", title => $_->{original}||$_->{title}, shorten $_->{title}, 50;
         end;
         td class => 'tc6', $_->{status} ? $RLIST_STATUS{$_->{status}} : '';
         td class => 'tc7_8', colspan => 2, '';
        end 'tr';
      }
    },

    $own ? (footer => sub {
      Tr;
       td class => 'tc1'; input type => 'checkbox', name => 'vid', value => 0, class => 'checkall'; end;
       td class => 'tc2'; input type => 'checkbox', name => 'rid', value => 0, class => 'checkall'; end;
       td class => 'tc3_6', colspan => 4;
        Select id => 'vns', name => 'vns';
         option value => -2, '-- with selected VNs --';
         optgroup label => 'Change status';
          option value => $_, $VNLIST_STATUS{$_}
            for (keys %VNLIST_STATUS);
         end;
         option value => 999, 'Set note';
         option value => -1, 'remove from list';
        end;
        Select id => 'rel', name => 'rel';
         option value => -2, '-- with selected releases --';
         optgroup label => 'Change status';
          option value => $_, $RLIST_STATUS{$_}
            for (keys %RLIST_STATUS);
         end;
         option value => -1, 'remove from list';
        end;
        input type => 'submit', value => 'Update';
       end;
       td class => 'tc7_8', colspan => 2, '* Obtained/total';
      end 'tr';
    }) : (),
  );

  end 'form' if $own;
}

1;

