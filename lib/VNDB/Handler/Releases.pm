
package VNDB::Handler::Releases;

use strict;
use warnings;
use TUWF ':html', ':xml', 'uri_escape';
use VNDB::Func;


TUWF::register(
  qr{r([1-9]\d*)(?:\.([1-9]\d*))?} => \&page,
  qr{(v)([1-9]\d*)/add}            => \&edit,
  qr{r}                            => \&browse,
  qr{r(?:([1-9]\d*)(?:\.([1-9]\d*))?/(edit|copy))}
    => \&edit,
  qr{xml/releases.xml}             => \&relxml,
);


sub page {
  my($self, $rid, $rev) = @_;

  my $method = $rev ? 'dbReleaseGetRev' : 'dbReleaseGet';
  my $r = $self->$method(
    id => $rid,
    what => 'vn extended producers platforms media',
    $rev ? (rev => $rev) : (),
  )->[0];
  return $self->resNotFound if !$r->{id};

  $self->htmlHeader(title => $r->{title}, noindex => $rev);
  $self->htmlMainTabs('r', $r);
  return if $self->htmlHiddenMessage('r', $r);

  if($rev) {
    my $prev = $rev && $rev > 1 && $self->dbReleaseGetRev(
      id => $rid, rev => $rev-1,
      what => 'vn extended producers platforms media changes'
    )->[0];
    $self->htmlRevision('r', $prev, $r,
      [ vn         => join => '<br />', split => sub {
        map sprintf('<a href="/v%d" title="%s">%s</a>', $_->{vid}, $_->{original}||$_->{title}, shorten $_->{title}, 50), @{$_[0]};
      } ],
      [ 'type' ],
      [ patch      => serialize => sub { mt $_[0] ? '_revision_yes' : '_revision_no' } ],
      [ freeware   => serialize => sub { mt $_[0] ? '_revision_yes' : '_revision_no' } ],
      [ doujin     => serialize => sub { mt $_[0] ? '_revision_yes' : '_revision_no' } ],
      [ title      => diff => 1 ],
      [ original   => diff => 1 ],
      [ gtin       => serialize => sub { $_[0]||mt '_revision_empty' } ],
      [ catalog    => serialize => sub { $_[0]||mt '_revision_empty' } ],
      [ languages  => join => ', ', split => sub { map $self->{languages}{$_}, @{$_[0]} } ],
      [ 'website' ],
      [ released   => htmlize   => \&fmtdatestr ],
      [ minage     => serialize => \&minage ],
      [ notes      => diff => qr/[ ,\n\.]/ ],
      [ platforms  => join => ', ', split => sub { map $self->{platforms}{$_}, @{$_[0]} } ],
      [ media      => join => ', ', split => sub { map fmtmedia($_->{medium}, $_->{qty}), @{$_[0]} } ],
      [ resolution => serialize => sub { $self->{resolutions}[$_[0]][0]; } ],
      [ voiced     => serialize => sub { $self->{voiced}[$_[0]] } ],
      [ ani_story  => serialize => sub { $self->{animated}[$_[0]] } ],
      [ ani_ero    => serialize => sub { $self->{animated}[$_[0]] } ],
      [ producers  => join => '<br />', split => sub {
        map sprintf('<a href="/p%d" title="%s">%s</a> (%s)', $_->{id}, $_->{original}||$_->{name}, shorten($_->{name}, 50),
          join(', ', $_->{developer} ? mt '_reldiff_developer' :(), $_->{publisher} ? mt '_reldiff_publisher' :())
        ), @{$_[0]};
      } ],
    );
  }

  div class => 'mainbox release';
   $self->htmlItemMessage('r', $r);
   h1 $r->{title};
   h2 class => 'alttitle', $r->{original} if $r->{original};

   _infotable($self, $r);

   if($r->{notes}) {
     p class => 'description';
      lit bb2html $r->{notes};
     end;
   }

  end;
  $self->htmlFooter;
}


sub _infotable {
  my($self, $r) = @_;
  table class => 'stripe';

   Tr;
    td class => 'key', mt '_relinfo_vnrel';
    td;
     for (@{$r->{vn}}) {
       a href => "/v$_->{vid}", title => $_->{original}||$_->{title}, shorten $_->{title}, 60;
       br if $_ != $r->{vn}[$#{$r->{vn}}];
     }
    end;
   end;

   Tr;
    td mt '_relinfo_title';
    td $r->{title};
   end;

   if($r->{original}) {
     Tr;
      td mt '_relinfo_original';
      td $r->{original};
     end;
   }

   Tr;
    td mt '_relinfo_type';
    td;
     cssicon "rt$r->{type}", $r->{type};
     txt ' '.mt '_relinfo_type_format', ucfirst($r->{type}), $r->{patch}?1:0;
    end;
   end;

   Tr;
    td mt '_relinfo_lang';
    td;
     for (@{$r->{languages}}) {
       cssicon "lang $_", $self->{languages}{$_};
       txt ' '.$self->{languages}{$_};
       br if $_ ne $r->{languages}[$#{$r->{languages}}];
     }
    end;
   end;

   Tr;
    td mt '_relinfo_publication';
    td mt $r->{patch} ? '_relinfo_pub_patch' : '_relinfo_pub_nopatch', $r->{freeware}?0:1, $r->{doujin}?0:1;
   end;

   if(@{$r->{platforms}}) {
     Tr;
      td mt '_relinfo_platform', scalar @{$r->{platforms}};
      td;
       for(@{$r->{platforms}}) {
         cssicon $_, $self->{platforms}{$_};
         txt ' '.$self->{platforms}{$_};
         br if $_ ne $r->{platforms}[$#{$r->{platforms}}];
       }
      end;
     end;
   }

   if(@{$r->{media}}) {
     Tr;
      td mt '_relinfo_media', scalar @{$r->{media}};
      td join ', ', map fmtmedia($_->{medium}, $_->{qty}), @{$r->{media}};
     end;
   }

   if($r->{resolution}) {
     Tr;
      td mt '_relinfo_resolution';
      td $self->{resolutions}[$r->{resolution}][0];
     end;
   }

   if($r->{voiced}) {
     Tr;
      td mt '_relinfo_voiced';
      td $self->{voiced}[$r->{voiced}];
     end;
   }

   if($r->{ani_story} || $r->{ani_ero}) {
     Tr;
      td mt '_relinfo_ani';
      td join ', ',
        $r->{ani_story} ? mt('_relinfo_ani_story', $self->{animated}[$r->{ani_story}]):(),
        $r->{ani_ero}   ? mt('_relinfo_ani_ero',   $self->{animated}[$r->{ani_ero}]  ):();
     end;
   }

   Tr;
    td mt '_relinfo_released';
    td;
     lit fmtdatestr $r->{released};
    end;
   end;

   if($r->{minage} >= 0) {
     Tr;
      td mt '_relinfo_minage';
      td minage $r->{minage};
     end;
   }

   for my $t (qw|developer publisher|) {
     my @prod = grep $_->{$t}, @{$r->{producers}};
     if(@prod) {
       Tr;
        td mt "_relinfo_$t", scalar @prod;
        td;
         for (@prod) {
           a href => "/p$_->{id}", title => $_->{original}||$_->{name}, shorten $_->{name}, 60;
           br if $_ != $prod[$#prod];
         }
        end;
       end;
     }
   }

   if($r->{gtin}) {
     Tr;
      td gtintype $r->{gtin};
      td $r->{gtin};
     end;
   }

   if($r->{catalog}) {
     Tr;
      td mt '_relinfo_catalog';
      td $r->{catalog};
     end;
   }

   if($r->{website}) {
     Tr;
      td mt '_relinfo_links';
      td;
       a href => $r->{website}, rel => 'nofollow', mt '_relinfo_website';
      end;
     end;
   }

   if($self->authInfo->{id}) {
     my $rl = $self->dbRListGet(uid => $self->authInfo->{id}, rid => $r->{id})->[0];
     Tr;
      td mt '_relinfo_user';
      td;
       Select id => 'listsel', name => $self->authGetCode("/r$r->{id}/list");
        option value => -2, 
          mt !$rl ? '_relinfo_user_notlist' : ('_relinfo_user_inlist', $self->{rlist_status}[$rl->{status}]);
        optgroup label => mt '_relinfo_user_setstatus';
         option value => $_, $self->{rlist_status}[$_]
           for (0..$#{$self->{rlist_status}});
        end;
        option value => -1, mt '_relinfo_user_del' if $rl;
       end;
      end;
     end 'tr';
   }

  end 'table';
}


# rid = \d   -> edit/copy release
# rid = 'v'  -> add release to VN with id $rev
sub edit {
  my($self, $rid, $rev, $copy) = @_;

  my $vid = 0;
  $copy = $rev && $rev eq 'copy' || $copy && $copy eq 'copy';
  $rev = undef if defined $rev && $rev !~ /^\d+$/;
  if($rid eq 'v') {
    $vid = $rev;
    $rev = undef;
    $rid = 0;
  }

  my $r = $rid && $self->dbReleaseGetRev(id => $rid, what => 'vn extended producers platforms media', $rev ? (rev => $rev) : ())->[0];
  return $self->resNotFound if $rid && !$r->{id};
  $rev = undef if !$r || $r->{lastrev};

  my $v = $vid && $self->dbVNGet(id => $vid)->[0];
  return $self->resNotFound if $vid && !$v->{id};

  return $self->htmlDenied if !$self->authCan('edit')
    || $rid && (($r->{locked} || $r->{hidden}) && !$self->authCan('dbmod'));

  my $vn = $rid ? $r->{vn} : [{ vid => $vid, title => $v->{title} }];
  my %b4 = !$rid ? () : (
    (map { $_ => $r->{$_} } qw|type title original gtin catalog languages website released minage
      notes platforms patch resolution voiced freeware doujin ani_story ani_ero ihid ilock|),
    media     => join(',',   sort map "$_->{medium} $_->{qty}", @{$r->{media}}),
    producers => join('|||', map
      sprintf('%d,%d,%s', $_->{id}, ($_->{developer}?1:0)+($_->{publisher}?2:0), $_->{name}),
      sort { $a->{id} <=> $b->{id} } @{$r->{producers}}
    ),
  );
  gtintype($b4{gtin}) if $b4{gtin}; # normalize gtin code
  $b4{vn} = join('|||', map "$_->{vid},$_->{title}", @$vn);
  my $frm;

  if($self->reqMethod eq 'POST') {
    return if !$self->authCheckCode;
    $frm = $self->formValidate(
      { post => 'type',      enum => $self->{release_types} },
      { post => 'patch',     required => 0, default => 0 },
      { post => 'freeware',  required => 0, default => 0 },
      { post => 'doujin',    required => 0, default => 0 },
      { post => 'title',     maxlength => 250 },
      { post => 'original',  required => 0, default => '', maxlength => 250 },
      { post => 'gtin',      required => 0, default => '0', template => 'gtin' },
      { post => 'catalog',   required => 0, default => '', maxlength => 50 },
      { post => 'languages', multi => 1, enum => [ keys %{$self->{languages}} ] },
      { post => 'website',   required => 0, default => '', maxlength => 250, template => 'weburl' },
      { post => 'released',  required => 0, default => 0, template => 'uint' },
      { post => 'minage' ,   required => 0, default => -1, enum => $self->{age_ratings} },
      { post => 'notes',     required => 0, default => '', maxlength => 10240 },
      { post => 'platforms', required => 0, default => '', multi => 1, enum => [ keys %{$self->{platforms}} ] },
      { post => 'media',     required => 0, default => '' },
      { post => 'resolution',required => 0, default => 0, enum => [ 0..$#{$self->{resolutions}} ] },
      { post => 'voiced',    required => 0, default => 0, enum => [ 0..$#{$self->{voiced}} ] },
      { post => 'ani_story', required => 0, default => 0, enum => [ 0..$#{$self->{animated}} ] },
      { post => 'ani_ero',   required => 0, default => 0, enum => [ 0..$#{$self->{animated}} ] },
      { post => 'producers', required => 0, default => '' },
      { post => 'vn',        maxlength => 50000 },
      { post => 'editsum',   template => 'editsum' },
      { post => 'ihid',      required  => 0 },
      { post => 'ilock',     required  => 0 },
    );

    push @{$frm->{_err}}, [ 'released', 'required', 1 ] if !$frm->{released};

    my($media, $producers, $new_vn);
    if(!$frm->{_err}) {
      # de-serialize
      $media     = [ map [ split / / ], split /,/, $frm->{media} ];
      $producers = [ map { /^([0-9]+),([1-3])/ ? [ $1, $2&1?1:0, $2&2?1:0] : () } split /\|\|\|/, $frm->{producers} ];
      $new_vn    = [ map { /^([0-9]+)/ ? $1 : () } split /\|\|\|/, $frm->{vn} ];
      $frm->{platforms} = [ grep $_, @{$frm->{platforms}} ];
      $frm->{$_} = $frm->{$_} ? 1 : 0 for (qw|patch freeware doujin ihid ilock|);

      # reset some fields when the patch flag is set
      $frm->{doujin} = $frm->{resolution} = $frm->{voiced} = $frm->{ani_story} = $frm->{ani_ero} = 0 if $frm->{patch};

      my $same = $rid &&
          (join(',', sort @{$b4{platforms}}) eq join(',', sort @{$frm->{platforms}})) &&
          (join(',', map join(' ', @$_), sort { $a->[0] <=> $b->[0] }  @$producers) eq join(',', map sprintf('%d %d %d',$_->{id}, $_->{developer}?1:0, $_->{publisher}?1:0), sort { $a->{id} <=> $b->{id} } @{$r->{producers}})) &&
          (join(',', sort @$new_vn) eq join(',', sort map $_->{vid}, @$vn)) &&
          (join(',', sort @{$b4{languages}}) eq join(',', sort @{$frm->{languages}})) &&
          !grep !/^(platforms|producers|vn|languages)$/ && $frm->{$_} ne $b4{$_}, keys %b4;
      return $self->resRedirect("/r$rid", 'post') if !$copy && $same;
      $frm->{_err} = [ 'nochanges' ] if $copy && $same;
    }

    if(!$frm->{_err}) {
      my $nrev = $self->dbItemEdit(r => !$copy && $rid ? ($r->{id}, $r->{rev}) : (undef, undef),
        (map { $_ => $frm->{$_} } qw| type title original gtin catalog languages website released minage
          notes platforms resolution editsum patch voiced freeware doujin ani_story ani_ero ihid ilock|),
        vn        => $new_vn,
        producers => $producers,
        media     => $media,
      );

      return $self->resRedirect("/r$nrev->{itemid}.$nrev->{rev}", 'post');
    }
  }

  !defined $frm->{$_} && ($frm->{$_} = $b4{$_}) for keys %b4;
  $frm->{languages} = ['ja'] if !$rid && !defined $frm->{languages};
  $frm->{editsum} = sprintf 'Reverted to revision r%d.%d', $rid, $rev if !$copy && $rev && !defined $frm->{editsum};
  $frm->{editsum} = sprintf 'New release based on r%d.%d', $rid, $r->{rev} if $copy && !defined $frm->{editsum};
  $frm->{title} = $v->{title} if !defined $frm->{title} && !$r;
  $frm->{original} = $v->{original} if !defined $frm->{original} && !$r;

  my $title = mt $rid ? ($copy ? '_redit_title_copy' : '_redit_title_edit', $r->{title}) : ('_redit_title_add', $v->{title});
  $self->htmlHeader(title => $title, noindex => 1);
  $self->htmlMainTabs('r', $r, $copy ? 'copy' : 'edit') if $rid;
  $self->htmlMainTabs('v', $v, 'edit') if $vid;
  $self->htmlEditMessage('r', $r, $title, $copy);
  _form($self, $r, $v, $frm, $copy);
  $self->htmlFooter;
}


sub _form {
  my($self, $r, $v, $frm, $copy) = @_;

  $self->htmlForm({ frm => $frm, action => $r ? "/r$r->{id}/".($copy ? 'copy' : 'edit') : "/v$v->{id}/add", editsum => 1 },
  rel_geninfo => [ mt('_redit_form_geninfo'),
    [ select => short => 'type',      name => mt('_redit_form_type'),
      options => [ map [ $_, $_ ], @{$self->{release_types}} ] ],
    [ check  => short => 'patch',     name => mt('_redit_form_patch') ],
    [ check  => short => 'freeware',  name => mt('_redit_form_freeware') ],
    [ check  => short => 'doujin',    name => mt('_redit_form_doujin') ],
    [ input  => short => 'title',     name => mt('_redit_form_title'),    width => 450 ],
    [ input  => short => 'original',  name => mt('_redit_form_original'), width => 450 ],
    [ static => content => mt '_redit_form_original_note' ],
    [ select => short => 'languages', name => mt('_redit_form_languages'), multi => 1,
      options => [ map [ $_, "$_ ($self->{languages}{$_})" ], keys %{$self->{languages}} ] ],
    [ input  => short => 'gtin',      name => mt('_redit_form_gtin') ],
    [ input  => short => 'catalog',   name => mt('_redit_form_catalog') ],
    [ input  => short => 'website',   name => mt('_redit_form_website') ],
    [ date   => short => 'released',  name => mt('_redit_form_released') ],
    [ static => content => mt('_redit_form_released_note') ],
    [ select => short => 'minage', name => mt('_redit_form_minage'),
      options => [ map [ $_, minage $_, 1 ], @{$self->{age_ratings}} ] ],
    [ textarea => short => 'notes', name => mt('_redit_form_notes').'<br /><b class="standout">'.mt('_inenglish').'</b>' ],
    [ static => content => mt('_redit_form_notes_note') ],
  ],

  rel_format => [ mt('_redit_form_format'),
    [ select => short => 'resolution', name => mt('_redit_form_resolution'), options => [
      map [ $_, @{$self->{resolutions}[$_]} ], 0..$#{$self->{resolutions}} ] ],
    [ select => short => 'voiced',     name => mt('_redit_form_voiced'), options => [
      map [ $_, $self->{voiced}[$_] ], 0..$#{$self->{voiced}} ] ],
    [ select => short => 'ani_story',  name => mt('_redit_form_ani_story'), options => [
      map [ $_, $self->{animated}[$_] ], 0..$#{$self->{animated}} ] ],
    [ select => short => 'ani_ero',  name => mt('_redit_form_ani_ero'), options => [
      map [ $_, $_ ? $self->{animated}[$_] : mt('_redit_form_ani_ero_none') ], 0..$#{$self->{animated}} ] ],
    [ static => content => mt('_redit_form_ani_ero_note') ],
    [ hidden => short => 'media' ],
    [ static => nolabel => 1, content => sub {
      h2 mt '_redit_form_platforms';
      div class => 'platforms';
       for my $p (sort keys %{$self->{platforms}}) {
         span;
          input type => 'checkbox', name => 'platforms', value => $p, id => $p,
            $frm->{platforms} && grep($_ eq $p, @{$frm->{platforms}}) ? (checked => 'checked') : ();
          label for => $p;
           cssicon $p, $self->{platforms}{$p};
           txt ' '.$self->{platforms}{$p};;
          end;
         end;
       }
      end;

      h2 mt '_redit_form_media';
      div id => 'media_div', '';
    }],
  ],

  rel_prod => [ mt('_redit_form_prod'),
    [ hidden => short => 'producers' ],
    [ static => nolabel => 1, content => sub {
      h2 mt('_redit_form_prod_sel');
      table; tbody id => 'producer_tbl'; end; end;
      h2 mt('_redit_form_prod_add');
      table; Tr;
       td class => 'tc_name'; input id => 'producer_input', type => 'text', class => 'text'; end;
       td class => 'tc_role'; Select id => 'producer_role';
        option value => 1, mt '_redit_form_prod_dev';
        option value => 2, selected => 'selected',  mt '_redit_form_prod_pub';
        option value => 3, mt '_redit_form_prod_both';
       end; end;
       td class => 'tc_add';  a id => 'producer_add', href => '#', mt '_js_add'; end;
      end; end 'table';
    }],
  ],

  rel_vn => [ mt('_redit_form_vn'),
    [ hidden => short => 'vn' ],
    [ static => nolabel => 1, content => sub {
      h2 mt('_redit_form_vn_sel');
      table class => 'stripe'; tbody id => 'vn_tbl'; end; end;
      h2 mt('_redit_form_vn_add');
      div;
       input id => 'vn_input', type => 'text', class => 'text';
       a href => '#', id => 'vn_add', mt '_js_add';
      end;
    }],
  ],
  );
}


sub browse {
  my $self = shift;

  my $f = $self->formValidate(
    { get => 'p',  required => 0, default => 1, template => 'page' },
    { get => 'o',  required => 0, default => 'a', enum => ['a', 'd'] },
    { get => 'q',  required => 0, default => '', maxlength => 500 },
    { get => 's',  required => 0, default => 'title', enum => [qw|released minage title|] },
    { get => 'fil',required => 0 },
  );
  return $self->resNotFound if $f->{_err};
  $f->{fil} //= $self->authPref('filter_release');

  my %compat = _fil_compat($self);
  my($list, $np) = !$f->{q} && !$f->{fil} && !keys %compat ? ([], 0) : $self->filFetchDB(release => $f->{fil}, \%compat, {
    sort => $f->{s}, reverse => $f->{o} eq 'd',
    page => $f->{p},
    results => 50,
    what => 'platforms',
    $f->{q} ? ( search => $f->{q} ) : (),
  });

  $self->htmlHeader(title => mt('_rbrowse_title'));

  form method => 'get', action => '/r', 'accept-charset' => 'UTF-8';
  div class => 'mainbox';
   h1 mt '_rbrowse_title';
   $self->htmlSearchBox('r', $f->{q});
   p class => 'filselect';
    a id => 'filselect', href => '#r';
     lit '<i>&#9656;</i> '.mt('_js_fil_filters').'<i></i>';
    end;
   end;
   input type => 'hidden', class => 'hidden', name => 'fil', id => 'fil', value => $f->{fil};
  end;
  end 'form';

  my $uri = sprintf '/r?q=%s;fil=%s', uri_escape($f->{q}), $f->{fil};
  $self->htmlBrowse(
    class    => 'relbrowse',
    items    => $list,
    options  => $f,
    nextpage => $np,
    pageurl  => "$uri;s=$f->{s};o=$f->{o}",
    sorturl  => $uri,
    header   => [
      [ mt('_rbrowse_col_released'), 'released' ],
      [ mt('_rbrowse_col_minage'),   'minage' ],
      [ '',         '' ],
      [ mt('_rbrowse_col_title'),    'title' ],
    ],
    row      => sub {
      my($s, $n, $l) = @_;
      Tr;
       td class => 'tc1';
        lit fmtdatestr $l->{released};
       end;
       td class => 'tc2', $l->{minage} < 0 ? '' : minage $l->{minage};
       td class => 'tc3';
        $_ ne 'oth' && cssicon $_, $self->{platforms}{$_} for (@{$l->{platforms}});
        cssicon "lang $_", $self->{languages}{$_} for (@{$l->{languages}});
        cssicon "rt$l->{type}", $l->{type};
       end;
       td class => 'tc4';
        a href => "/r$l->{id}", title => $l->{original}||$l->{title}, shorten $l->{title}, 90;
        b class => 'grayedout', ' (patch)' if $l->{patch};
       end;
      end 'tr';
    },
  ) if @$list;
  if(($f->{q} || $f->{fil}) && !@$list) {
    div class => 'mainbox';
     h1 mt '_rbrowse_noresults_title';
     div class => 'notice';
      p mt '_rbrowse_noresults_msg';
     end;
    end;
  }
  $self->htmlFooter(pref_code => 1);
}


# provide compatibility with old URLs
sub _fil_compat {
  my $self = shift;
  my %c;
  my $f = $self->formValidate(
    { get => 'ln', required => 0, multi => 1, default => '', enum => [ keys %{$self->{languages}} ] },
    { get => 'pl', required => 0, multi => 1, default => '', enum => [ keys %{$self->{platforms}} ] },
    { get => 'me', required => 0, multi => 1, default => '', enum => [ keys %{$self->{media}} ] },
    { get => 'tp', required => 0, default => '', enum => [ '', @{$self->{release_types}} ] },
    { get => 'pa', required => 0, default => 0, enum => [ 0..2 ] },
    { get => 'fw', required => 0, default => 0, enum => [ 0..2 ] },
    { get => 'do', required => 0, default => 0, enum => [ 0..2 ] },
    { get => 'ma_m', required => 0, default => 0, enum => [ 0, 1 ] },
    { get => 'ma_a', required => 0, default => 0, enum => $self->{age_ratings} },
    { get => 'mi', required => 0, default => 0, template => 'uint' },
    { get => 'ma', required => 0, default => 99999999, template => 'uint' },
    { get => 're', required => 0, multi => 1, default => 0, enum => [ 1..$#{$self->{resolutions}} ] },
  );
  return () if $f->{_err};
  $c{minage} = [ grep $_ >= 0 && ($f->{ma_m} ? $f->{ma_a} >= $_ : $f->{ma_a} <= $_), @{$self->{age_ratings}} ] if $f->{ma_a} || $f->{ma_m};
  $c{date_after} = $f->{mi}  if $f->{mi};
  $c{date_before} = $f->{ma} if $f->{ma} < 99990000;
  $c{plat} = $f->{pl}        if $f->{pl}[0];
  $c{lang} = $f->{ln}        if $f->{ln}[0];
  $c{med} = $f->{me}         if $f->{me}[0];
  $c{resolution} = $f->{re}  if $f->{re}[0];
  $c{type} = $f->{tp}        if $f->{tp};
  $c{patch} = $f->{pa} == 2 ? 0 : 1 if $f->{pa};
  $c{freeware} = $f->{fw} == 2 ? 0 : 1 if $f->{fw};
  $c{doujin} = $f->{do} == 2 ? 0 : 1 if $f->{do};
  return %c;
}


sub relxml {
  my $self = shift;

  my $f = $self->formValidate(
    { get => 'v', required => 1, multi => 1, mincount => 1, template => 'id' }
  );
  return $self->resNotFound if $f->{_err};

  my $list = $self->dbReleaseGet(vid => $f->{v}, results => 100, what => 'vn');
  my %vns = map +($_,0), @{$f->{v}};
  for my $r (@$list) {
    for my $v (@{$r->{vn}}) {
      next if !exists $vns{$v->{vid}};
      $vns{$v->{vid}} = [ $v ] if !$vns{$v->{vid}};
      push @{$vns{$v->{vid}}}, $r;
    }
  }
  !$vns{$_} && delete $vns{$_} for(keys %vns);
  $self->resHeader('Content-type' => 'text/xml; charset=UTF-8');
  xml;
  tag 'vns';
   for (sort { $a->[0]{title} cmp $b->[0]{title} } values %vns) {
     next if !$_;
     my $v = shift @$_;
     tag 'vn', id => $v->{vid}, title => $v->{title};
      tag 'release', id => $_->{id}, lang => join(',', @{$_->{languages}}), $_->{title}
        for (@$_);
     end;
   }
  end;
}


1;

