
package VNDB::Handler::Staff;

use strict;
use warnings;
use TUWF qw(:html :xml uri_escape xml_escape);
use VNDB::Func;
use VNDB::Types;
use List::Util qw(first);

TUWF::register(
  qr{s([1-9]\d*)(?:\.([1-9]\d*))?} => \&page,
  qr{s/([a-z0]|all)}               => \&list,
  qr{xml/staff\.xml}               => \&staffxml,
);


sub page {
  my($self, $id, $rev) = @_;

  my $method = $rev ? 'dbStaffGetRev' : 'dbStaffGet';
  my $s = $self->$method(
    id => $id,
    what => 'extended aliases roles',
    $rev ? ( rev => $rev ) : ()
  )->[0];
  return $self->resNotFound if !$s->{id};

  my $metadata = {
    'og:title' => $s->{name},
    'og:description' => bb2text $s->{desc},
  };

  $self->htmlHeader(title => $s->{name}, noindex => $rev, metadata => $metadata);
  $self->htmlMainTabs('s', $s) if $id;
  return if $self->htmlHiddenMessage('s', $s);

  if($rev) {
    my $prev = $rev && $rev > 1 && $self->dbStaffGetRev(id => $id, rev => $rev-1, what => 'extended aliases')->[0];
    $self->htmlRevision('s', $prev, $s,
      [ name      => 'Name (romaji)',    diff => 1 ],
      [ original  => 'Original name',    diff => 1 ],
      [ gender    => 'Gender',           serialize => sub { $GENDER{$_[0]} } ],
      [ lang      => 'Language',         serialize => sub { "$_[0] ($LANGUAGE{$_[0]})" } ],
      [ l_site    => 'Official page',    diff => 1 ],
      [ l_wp      => 'Wikipedia link',   htmlize => sub { $_[0] ? sprintf '<a href="http://en.wikipedia.org/wiki/%s">%1$s</a>', xml_escape $_[0] : '[empty]' }],
      [ l_wikidata=> 'Wikidata ID',      htmlize => sub { $_[0] ? sprintf '<a href="https://www.wikidata.org/wiki/Q%d">Q%1$d</a>', $_[0] : '[empty]' } ],
      [ l_twitter => 'Twitter account',  diff => 1 ],
      [ l_anidb   => 'AniDB creator ID', serialize => sub { $_[0] // '' } ],
      [ l_pixiv   => 'Pixiv',            htmlize => sub { $_[0] ? sprintf '<a href="https://www.pixiv.net/member.php?id=%d">%1$d</a>', $_[0] : '[empty]' } ],
      [ desc      => 'Description',      diff => qr/[ ,\n\.]/ ],
      [ aliases   => 'Aliases',          join => '<br />', split => sub {
        map xml_escape(sprintf('%s%s', $_->{name}, $_->{original} ? ' ('.$_->{original}.')' : '')), @{$_[0]};
      }],
    );
  }

  div class => 'mainbox staffpage';
   $self->htmlItemMessage('s', $s);
   h1 $s->{name};
   h2 class => 'alttitle', lang => $s->{lang}, $s->{original} if $s->{original};

   # info table
   table class => 'stripe';
    thead;
     Tr;
      td colspan => 2;
       b style => 'margin-right: 10px', $s->{name};
       b class => 'grayedout', style => 'margin-right: 10px', lang => $s->{lang}, $s->{original} if $s->{original};
       cssicon "gen $s->{gender}", $GENDER{$s->{gender}} if $s->{gender} ne 'unknown';
      end;
     end;
    end;
    Tr;
     td class => 'key', 'Language';
     td $LANGUAGE{$s->{lang}};
    end;
    if(@{$s->{aliases}}) {
      Tr;
       td class => 'key', @{$s->{aliases}} == 1 ? 'Alias' : 'Aliases';
       td;
        table class => 'aliases';
         for my $alias (@{$s->{aliases}}) {
           Tr class => 'nostripe';
            td $alias->{original} ? () : (colspan => 2), class => 'key';
             txt $alias->{name};
            end;
            td lang => $s->{lang}, $alias->{original} if $alias->{original};
           end;
         }
        end;
       end;
      end;
    }
    my $links = $self->entryLinks(s => $s);
    if(@$links) {
      Tr;
       td class => 'key', 'Links';
       td;
        for(@$links) {
          a href => $_->[1], $_->[0];
          br if $_ != $links->[$#$links];
        }
       end;
      end;
    }
   end 'table';

   # description
   p class => 'description';
    lit bb2html $s->{desc}, 0, 1;
   end;
  end;

  _roles($self, $s);
  _cast($self, $s);
  $self->htmlFooter;
}


sub _roles {
  my($self, $s) = @_;
  return if !@{$s->{roles}};

  h1 class => 'boxtitle', 'Credits';
  $self->htmlBrowse(
    items    => $s->{roles},
    class    => 'staffroles',
    header   => [
      [ 'Title' ],
      [ 'Released' ],
      [ 'Role' ],
      [ 'As' ],
      [ 'Note' ],
    ],
    row     => sub {
      my($r, $n, $l) = @_;
      Tr;
       td class => 'tc1'; a href => "/v$l->{vid}", title => $l->{t_original}||$l->{title}, shorten $l->{title}, 60; end;
       td class => 'tc2'; lit fmtdatestr $l->{c_released}; end;
       td class => 'tc3', $CREDIT_TYPE{$l->{role}};
       td class => 'tc4', title => $l->{original}||$l->{name}, $l->{name};
       td class => 'tc5', $l->{note};
      end;
    },
  );
}


sub _cast {
  my($self, $s) = @_;
  return if !@{$s->{cast}};

  h1 class => 'boxtitle', sprintf 'Voiced characters (%d)', scalar @{$s->{cast}};
  $self->htmlBrowse(
    items    => $s->{cast},
    class    => 'staffroles',
    header   => [
      [ 'Title' ],
      [ 'Released' ],
      [ 'Cast' ],
      [ 'As' ],
      [ 'Note' ],
    ],
    row     => sub {
      my($r, $n, $l) = @_;
      Tr;
       td class => 'tc1'; a href => "/v$l->{vid}", title => $l->{t_original}||$l->{title}, shorten $l->{title}, 60; end;
       td class => 'tc2'; lit fmtdatestr $l->{c_released}; end;
       td class => 'tc3'; a href => "/c$l->{cid}", title => $l->{c_original}, $l->{c_name}; end;
       td class => 'tc4', title => $l->{original}||$l->{name}, $l->{name};
       td class => 'tc5', $l->{note};
      end;
    },
  );
}


sub list {
  my ($self, $char) = @_;

  my $f = $self->formValidate(
    { get => 'p', required => 0, default => 1, template => 'page' },
    { get => 'q', required => 0, default => '' },
    { get => 'fil', required => 0, default => '' },
  );
  return $self->resNotFound if $f->{_err};

  my ($list, $np) = $self->filFetchDB(staff => $f->{fil}, {}, {
    $char ne 'all' ? ( char => $char ) : (),
    $f->{q} ? ($f->{q} =~ /^=(.+)$/ ? (exact => $1) : (search => $f->{q})) : (),
    results => 150,
    page => $f->{p}
  });

  return $self->resRedirect('/s'.$list->[0]{id}, 'temp')
    if $f->{q} && @$list && (!first { $_->{id} != $list->[0]{id} } @$list) && $f->{p} == 1 && !$f->{fil};
    # redirect to the staff page if all results refer to the same entry

  my $quri = join(';', $f->{q} ? 'q='.uri_escape($f->{q}) : (), $f->{fil} ? "fil=$f->{fil}" : ());
  $quri = '?'.$quri if $quri;
  my $pageurl = "/s/$char$quri";

  $self->htmlHeader(title => 'Browse staff');

  form action => '/s/all', 'accept-charset' => 'UTF-8', method => 'get';
   div class => 'mainbox';
    h1 'Browse staff';
    $self->htmlSearchBox('s', $f->{q});
    p class => 'browseopts';
    for ('all', 'a'..'z', 0) {
      a href => "/s/$_$quri", $_ eq $char ? (class => 'optselected') : (), $_ eq 'all' ? 'ALL' : $_ ? uc $_ : '#';
    }
    end;

    p class => 'filselect';
     a id => 'filselect', href => '#s';
      lit '<i>&#9656;</i> Filters<i></i>';
     end;
    end;
    input type => 'hidden', class => 'hidden', name => 'fil', id => 'fil', value => $f->{fil};
   end;
  end 'form';

  $self->htmlBrowseNavigate($pageurl, $f->{p}, $np, 't');
  div class => 'mainbox staffbrowse';
    h1 $f->{q} ? 'Search results' : 'Staff list';
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
            a href => "/s$list->[$_]{id}",
              title => $list->[$_]{original}, $list->[$_]{name};
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


sub staffxml {
  my $self = shift;

  my $f = $self->formValidate(
    { get => 'q', required => 0, maxlength => 500 },
    { get => 'id', required => 0, multi => 1, template => 'id' },
    { get => 'staffid', required => 0, default => 0 }, # The returned id = staff id when set, otherwise it's the alias id
    { get => 'r', required => 0, template => 'uint', min => 1, max => 50, default => 10 },
  );
  return $self->resNotFound if $f->{_err} || (!$f->{q} && !$f->{id} && !$f->{id}[0]);

  my($list, $np) = $self->dbStaffGet(
    !$f->{q} ? () : $f->{q} =~ /^s([1-9]\d*)/ ? (id => $1) : $f->{q} =~ /^=(.+)/ ? (exact => $1) : (search => $f->{q}, sort => 'search'),
    $f->{id} && $f->{id}[0] ? (id => $f->{id}) : (),
    results => $f->{r}, page => 1,
  );

  $self->resHeader('Content-type' => 'text/xml; charset=UTF-8');
  xml;
  tag 'staff', more => $np ? 'yes' : 'no';
   for(@$list) {
     tag 'item', sid => $_->{id}, id => $f->{staffid} ? $_->{id} : $_->{aid}, orig => $_->{original}, $_->{name};
   }
  end;
}

1;
