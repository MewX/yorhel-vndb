
package VNDB::Handler::Producers;

use strict;
use warnings;
use TUWF ':html', ':xml', 'xml_escape', 'html_escape';
use VNDB::Func;
use VNDB::Types;


TUWF::register(
  qr{p([1-9]\d*)/rg}               => \&rg,
  qr{p([1-9]\d*)(?:\.([1-9]\d*))?} => \&page,
  qr{p/add}                        => \&addform,
  qr{p(?:([1-9]\d*)(?:\.([1-9]\d*))?/edit|/new)}
    => \&edit,
  qr{p/([a-z0]|all)}               => \&list,
  qr{xml/producers\.xml}           => \&pxml,
);


sub rg {
  my($self, $pid) = @_;

  my $p = $self->dbProducerGet(id => $pid, what => 'relgraph')->[0];
  return $self->resNotFound if !$p->{id} || !$p->{rgraph};

  my $title = "Relation graph for $p->{name}";
  return if $self->htmlRGHeader($title, 'p', $p);

  $p->{svg} =~ s/id="node_p$pid"/id="graph_current"/;

  div class => 'mainbox';
   h1 $title;
   p class => 'center';
    lit $p->{svg};
   end;
  end;
  $self->htmlFooter;
}


sub page {
  my($self, $pid, $rev) = @_;

  my $method = $rev ? 'dbProducerGetRev' : 'dbProducerGet';
  my $p = $self->$method(
    id => $pid,
    what => 'extended relations',
    $rev ? ( rev => $rev ) : ()
  )->[0];
  return $self->resNotFound if !$p->{id};

  my $metadata = {
    'og:title' => $p->{name},
    'og:description' => bb2text $p->{desc},
  };

  $self->htmlHeader(title => $p->{name}, noindex => $rev, metadata => $metadata);
  $self->htmlMainTabs(p => $p);
  return if $self->htmlHiddenMessage('p', $p);

  if($rev) {
    my $prev = $rev && $rev > 1 && $self->dbProducerGetRev(id => $pid, rev => $rev-1, what => 'extended relations')->[0];
    $self->htmlRevision('p', $prev, $p,
      [ type      => 'Type',          serialize => sub { $PRODUCER_TYPE{$_[0]} } ],
      [ name      => 'Name (romaji)', diff => 1 ],
      [ original  => 'Original name', diff => 1 ],
      [ alias     => 'Aliases',       diff => qr/[ ,\n\.]/ ],
      [ lang      => 'Language',      serialize => sub { "$_[0] ($LANGUAGE{$_[0]})" } ],
      [ website   => 'Website',       diff => 1 ],
      [ l_wp      => 'Wikipedia link',htmlize => sub {
        $_[0] ? sprintf '<a href="http://en.wikipedia.org/wiki/%s">%1$s</a>', xml_escape $_[0] : '[empty]'
      }],
      [ l_wikidata=> 'Wikidata ID', htmlize => sub { $_[0] ? sprintf '<a href="https://www.wikidata.org/wiki/Q%d">Q%1$d</a>', $_[0] : '[empty]' } ],
      [ desc      => 'Description', diff => qr/[ ,\n\.]/ ],
      [ relations => 'Relations',   join => '<br />', split => sub {
        my @r = map sprintf('%s: <a href="/p%d" title="%s">%s</a>',
          $PRODUCER_RELATION{$_->{relation}}{txt}, $_->{id}, xml_escape($_->{original}||$_->{name}), xml_escape shorten $_->{name}, 40
        ), sort { $a->{id} <=> $b->{id} } @{$_[0]};
        return @r ? @r : ('[empty]');
      }],
    );
  }

  div class => 'mainbox';
   $self->htmlItemMessage('p', $p);
   h1 $p->{name};
   h2 class => 'alttitle', $p->{original} if $p->{original};
   p class => 'center';
    txt "$LANGUAGE{$p->{lang}} $PRODUCER_TYPE{$p->{type}}";
    if($p->{alias}) {
      (my $alias = $p->{alias}) =~ s/\n/, /g;
      br;
      txt "a.k.a. $alias";
    }

    my $links = $self->entryLinks(p => $p);
    br if @$links;
    for(@$links) {
      a href => $_->[1], $_->[0];
      txt ' - ' if $_ ne $links->[$#$links];
    }
   end 'p';

   if(@{$p->{relations}}) {
     my %rel;
     push @{$rel{$_->{relation}}}, $_
       for (sort { $a->{name} cmp $b->{name} } @{$p->{relations}});
     p class => 'center';
      br;
      for my $r (keys %PRODUCER_RELATION) {
        next if !$rel{$r};
        txt $PRODUCER_RELATION{$r}{txt}.': ';
        for (@{$rel{$r}}) {
          a href => "/p$_->{id}", title => $_->{original}||$_->{name}, shorten $_->{name}, 40;
          txt ', ' if $_ ne $rel{$r}[$#{$rel{$r}}];
        }
        br;
      }
     end 'p';
   }

   if($p->{desc}) {
     p class => 'description';
      lit bb2html $p->{desc};
     end;
   }
  end 'div';

  _releases($self, $p);

  $self->htmlFooter;
}

sub _releases {
  my($self, $p) = @_;

  # prodpage_(dev|pub)
  my $r = $self->dbReleaseGet(pid => $p->{id}, results => 999, what => 'vn platforms links');
  div class => 'mainbox';
   a href => '#', id => 'expandprodrel', 'collapse';
   h1 'Releases';
   if(!@$r) {
     p 'We have currently no visual novels by this producer.';
     end;
     return;
   }

   my %vn; # key = vid, value = [ $r1, $r2, $r3, .. ]
   my @vn; # $vn objects in order of first release
   for my $rel (@$r) {
     for my $v (@{$rel->{vn}}) {
       push @vn, $v if !$vn{$v->{vid}};
       push @{$vn{$v->{vid}}}, $rel;
     }
   }

   table id => 'prodrel';
    for my $v (@vn) {
      Tr class => 'vn';
       td colspan => 6;
        i; lit fmtdatestr $vn{$v->{vid}}[0]{released}; end;
        a href => "/v$v->{vid}", title => $v->{original}, $v->{title};
        span '('.join(', ',
           (grep($_->{developer}, @{$vn{$v->{vid}}}) ? 'developer' : ()),
           (grep($_->{publisher}, @{$vn{$v->{vid}}}) ? 'publisher' : ())
        ).')';
       end;
      end;
      for my $rel (@{$vn{$v->{vid}}}) {
        Tr class => 'rel';
         td class => 'tc1'; lit fmtdatestr $rel->{released}; end;
         td class => 'tc2', $rel->{minage} < 0 ? '' : minage $rel->{minage};
         td class => 'tc3';
          for (sort @{$rel->{platforms}}) {
            next if $_ eq 'oth';
            cssicon $_, $PLATFORM{$_};
          }
          cssicon "lang $_", $LANGUAGE{$_} for (@{$rel->{languages}});
          cssicon "rt$rel->{type}", $rel->{type};
         end;
         td class => 'tc4';
          a href => "/r$rel->{id}", title => $rel->{original}||$rel->{title}, $rel->{title};
          b class => 'grayedout', ' (patch)' if $rel->{patch};
         end;
         td class => 'tc5', join ', ',
           ($rel->{developer} ? 'developer' : ()), ($rel->{publisher} ? 'publisher' : ());
         td class => 'tc6';
          $self->releaseExtLinks($rel);
         end;
        end 'tr';
      }
    }
   end 'table';
  end 'div';
}


sub addform {
  my $self = shift;
  return $self->htmlDenied if !$self->authCan('edit');

  my $frm;
  my $l = [];
  if($self->reqMethod eq 'POST') {
    return if !$self->authCheckCode;
    $frm = $self->formValidate(
      { post => 'name',          maxlength => 200 },
      { post => 'original',      required  => 0, maxlength => 200,  default => '' },
      { post => 'alias',         required  => 0, maxlength => 500,  default => '' },
      { post => 'continue_ign',required => 0 },
    );

    # look for duplicates
    if(!$frm->{_err} && !$frm->{continue_ign}) {
      $l = $self->dbProducerGet(search => $frm->{name}, what => 'extended', results => 50, inc_hidden => 1);
      push @$l, @{$self->dbProducerGet(search => $frm->{original}, what => 'extended', results => 50, inc_hidden => 1)} if $frm->{original};
      $_ && push @$l, @{$self->dbProducerGet(search => $_, what => 'extended', results => 50, inc_hidden => 1)} for(split /\n/, $frm->{alias});
      my %ids = map +($_->{id}, $_), @$l;
      $l = [ map $ids{$_}, sort { $ids{$a}{name} cmp $ids{$b}{name} } keys %ids ];
    }

    return edit($self, undef, undef, 1) if !@$l && !$frm->{_err};
  }

  $self->htmlHeader(title => 'Add a new producer', noindex => 1);
  if(@$l) {
    div class => 'mainbox';
     h1 'Possible duplicates found';
     div class => 'warning';
      p;
       txt 'The following is a list of producers that match the name(s) you gave.'
         .' Please check this list to avoid creating a duplicate producer entry.'
         .' Be especially wary of items that have been deleted! To see why an entry has been deleted, click on its title.';
       br; br;
       txt 'To add the producer anyway, hit the "Continue and ignore duplicates" button below.';
      end;
     end;
     ul;
      for(@$l) {
        li;
         a href => "/p$_->{id}", title => $_->{original}||$_->{name}, "p$_->{id}: ".shorten($_->{name}, 50);
         b class => 'standout', ' deleted' if $_->{hidden};
        end;
      }
     end;
    end 'div';
  }

  $self->htmlForm({ frm => $frm, action => '/p/add', continue => @$l ? 2 : 1 },
  vn_add => [ 'Add a new producer',
    [ input  => name => 'Name (romaji)', short => 'name' ],
    [ input  => name => 'Original name', short => 'original' ],
    [ static => content => 'The original name of the producer, leave blank if it is already in the Latin alphabet.' ],
    [ textarea => short => 'alias', name => 'Aliases', rows => 4 ],
    [ static => content => '(Un)official aliases, separated by a newline.' ],
  ]);
  $self->htmlFooter;
}


# pid as argument = edit producer
# no arguments = add new producer
sub edit {
  my($self, $pid, $rev, $nosubmit) = @_;

  my $p = $pid && $self->dbProducerGetRev(id => $pid, what => 'extended relations', rev => $rev)->[0];
  return $self->resNotFound if $pid && !$p->{id};
  $rev = undef if !$p || $p->{lastrev};

  return $self->htmlDenied if !$self->authCan('edit')
    || $pid && (($p->{locked} || $p->{hidden}) && !$self->authCan('dbmod'));

  my %b4 = !$pid ? () : (
    (map { $_ => $p->{$_} } qw|type name original lang website l_wikidata desc alias ihid ilock|),
    prodrelations => join('|||', map $_->{relation}.','.$_->{id}.','.$_->{name}, sort { $a->{id} <=> $b->{id} } @{$p->{relations}}),
  );
  my $frm;

  if($self->reqMethod eq 'POST') {
    return if !$nosubmit && !$self->authCheckCode;
    $frm = $self->formValidate(
      { post => 'type',          required  => !$nosubmit, enum => [ keys %PRODUCER_TYPE ] },
      { post => 'name',          maxlength => 200 },
      { post => 'original',      required  => 0, maxlength => 200,  default => '' },
      { post => 'alias',         required  => 0, maxlength => 500,  default => '' },
      { post => 'lang',          required  => !$nosubmit, enum => [ keys %LANGUAGE ] },
      { post => 'website',       required  => 0, maxlength => 250,  default => '', template => 'weburl' },
      { post => 'l_wikidata',    required  => 0, template => 'wikidata' },
      { post => 'desc',          required  => 0, maxlength => 5000, default => '' },
      { post => 'prodrelations', required  => 0, maxlength => 5000, default => '' },
      { post => 'editsum',       required  => !$nosubmit, template => 'editsum' },
      { post => 'ihid',          required  => 0 },
      { post => 'ilock',         required  => 0 },
    );
    $frm->{original} = '' if $frm->{original} eq $frm->{name};
    if(!$nosubmit && !$frm->{_err}) {
      # parse
      my $relations = [ map { /^([a-z]+),([0-9]+),(.+)$/ && (!$pid || $2 != $pid) ? [ $1, $2, $3 ] : () } split /\|\|\|/, $frm->{prodrelations} ];

      # normalize
      $frm->{ihid} = $frm->{ihid}?1:0;
      $frm->{ilock} = $frm->{ilock}?1:0;
      $frm->{desc} = $self->bbSubstLinks($frm->{desc});
      $relations = [] if $frm->{ihid};
      $frm->{prodrelations} = join '|||', map $_->[0].','.$_->[1].','.$_->[2], sort { $a->[1] <=> $b->[1]} @{$relations};

      return $self->resRedirect("/p$pid", 'post')
        if $pid && !grep +(($frm->{$_}//'') ne ($b4{$_}//'')), keys %b4;

      $frm->{relations} = $relations;
      my $nrev = $self->dbItemEdit(p => $pid||undef, $pid ? $p->{rev} : undef, %$frm);

      # update reverse relations
      if(!$pid && $#$relations >= 0 || $pid && $frm->{prodrelations} ne $b4{prodrelations}) {
        my %old = $pid ? (map { $_->{id} => $_->{relation} } @{$p->{relations}}) : ();
        my %new = map { $_->[1] => $_->[0] } @$relations;
        _updreverse($self, \%old, \%new, $nrev->{itemid}, $nrev->{rev});
      }

      return $self->resRedirect("/p$nrev->{itemid}.$nrev->{rev}", 'post');
    }
  }

  !defined $frm->{$_} && ($frm->{$_} = $b4{$_}) for keys %b4;
  $frm->{lang} = 'ja' if !$pid && !defined $frm->{lang};
  $frm->{editsum} = sprintf 'Reverted to revision p%d.%d', $pid, $rev if $rev && !defined $frm->{editsum};

  my $title = $pid ? "Edit $p->{name}" : 'Add new producer';
  $self->htmlHeader(title => $title, noindex => 1);
  $self->htmlMainTabs('p', $p, 'edit') if $pid;
  $self->htmlEditMessage('p', $p, $title);
  $self->htmlForm({ frm => $frm, action => $pid ? "/p$pid/edit" : '/p/new', editsum => 1 },
  'pedit_geninfo' => [ 'General info',
    [ select => name => 'Type', short => 'type',
      options => [ map [ $_, $PRODUCER_TYPE{$_} ], keys %PRODUCER_TYPE ] ],
    [ input  => name => 'Name (romaji)', short => 'name' ],
    [ input  => name => 'Original name', short => 'original' ],
    [ static => content => 'The original name of the producer, leave blank if it is already in the Latin alphabet.' ],
    [ textarea => short => 'alias', name => 'Aliases', rows => 4 ],
    [ static => content => '(Un)official aliases, separated by a newline.' ],
    [ select => name => 'Primary language', short => 'lang',
      options => [ map [ $_, "$LANGUAGE{$_} ($_)" ], sort { $LANGUAGE{$a} cmp $LANGUAGE{$b} } keys %LANGUAGE ] ],
    [ input  => name => 'Website', short => 'website' ],
    [ input  => short => 'l_wikidata',name => 'Wikidata ID',
        value => $frm->{l_wikidata} ? "Q$frm->{l_wikidata}" : '',
        post  => qq{ (<a href="$self->{url_static}/f/wikidata.png">How to find this</a>)}
    ],
    [ text   => name => 'Description<br /><b class="standout">English please!</b>', short => 'desc', rows => 6 ],
  ], 'pedit_rel' => [ 'Relations',
    [ hidden   => short => 'prodrelations' ],
    [ static   => nolabel => 1, content => sub {
      h2 'Selected producers';
      table;
       tbody id => 'relation_tbl';
        # to be filled using javascript
       end;
      end;

      h2 'Add producer';
      table;
       Tr id => 'relation_new';
        td class => 'tc_prod';
         input type => 'text', class => 'text';
        end;
        td class => 'tc_rel';
         Select;
          option value => $_, $PRODUCER_RELATION{$_}{txt}
            for (keys %PRODUCER_RELATION);
         end;
        end;
        td class => 'tc_add';
         a href => '#', 'add';
        end;
       end;
      end 'table';
    }],
  ]);
  $self->htmlFooter;
}

sub _updreverse {
  my($self, $old, $new, $pid, $rev) = @_;
  my %upd;

  # compare %old and %new
  for (keys %$old, keys %$new) {
    if(exists $$old{$_} and !exists $$new{$_}) {
      $upd{$_} = undef;
    } elsif((!exists $$old{$_} and exists $$new{$_}) || ($$old{$_} ne $$new{$_})) {
      $upd{$_} = $PRODUCER_RELATION{$$new{$_}}{reverse};
    }
  }
  return if !keys %upd;

  # edit all related producers
  for my $i (keys %upd) {
    my $r = $self->dbProducerGetRev(id => $i, what => 'relations')->[0];
    my @newrel = map $_->{id} != $pid ? [ $_->{relation}, $_->{id} ] : (), @{$r->{relations}};
    push @newrel, [ $upd{$i}, $pid ] if $upd{$i};
    $self->dbItemEdit(p => $i, $r->{rev},
      relations => \@newrel,
      editsum => "Reverse relation update caused by revision p$pid.$rev",
      uid => 1,
    );
  }
}


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

