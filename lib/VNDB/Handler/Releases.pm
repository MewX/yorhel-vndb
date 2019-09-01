
package VNDB::Handler::Releases;

use strict;
use warnings;
use TUWF ':html', ':xml', 'uri_escape', 'xml_escape';
use VNDB::Func;
use Exporter 'import';

our @EXPORT = ('releaseExtLinks');


TUWF::register(
  qr{r([1-9]\d*)(?:\.([1-9]\d*))?} => \&page,
  qr{(v)([1-9]\d*)/add}            => \&edit,
  qr{r}                            => \&browse,
  qr{r(?:([1-9]\d*)(?:\.([1-9]\d*))?/(edit|copy))}
    => \&edit,
  qr{r/engines}                    => \&engines,
  qr{xml/releases.xml}             => \&relxml,
  qr{xml/engines.xml}              => \&enginexml,
);


sub page {
  my($self, $rid, $rev) = @_;

  my $method = $rev ? 'dbReleaseGetRev' : 'dbReleaseGet';
  my $r = $self->$method(
    id => $rid,
    what => 'vn extended links producers platforms media',
    $rev ? (rev => $rev) : (),
  )->[0];
  return $self->resNotFound if !$r->{id};

  my $metadata = {
    'og:title' => $r->{title},
    'og:description' => bb2text $r->{notes},
  };

  $self->htmlHeader(title => $r->{title}, noindex => $rev, metadata => $metadata);
  $self->htmlMainTabs('r', $r);
  return if $self->htmlHiddenMessage('r', $r);

  if($rev) {
    my $prev = $rev && $rev > 1 && $self->dbReleaseGetRev(
      id => $rid, rev => $rev-1,
      what => 'vn extended links producers platforms media changes'
    )->[0];
    $self->htmlRevision('r', $prev, $r,
      [ vn         => 'Relations',       join => '<br />', split => sub {
        map sprintf('<a href="/v%d" title="%s">%s</a>', $_->{vid}, $_->{original}||$_->{title}, shorten $_->{title}, 50), @{$_[0]};
      } ],
      [ type       => 'Type' ],
      [ patch      => 'Patch',           serialize => sub { $_[0] ? 'Yes' : 'No' } ],
      [ freeware   => 'Freeware',        serialize => sub { $_[0] ? 'Yes' : 'No' } ],
      [ doujin     => 'Doujin',          serialize => sub { $_[0] ? 'Yes' : 'No' } ],
      [ uncensored => 'Uncensored',      serialize => sub { $_[0] ? 'Yes' : 'No' } ],
      [ title      => 'Title (romaji)',  diff => 1 ],
      [ original   => 'Original title',  diff => 1 ],
      [ gtin       => 'JAN/UPC/EAN',     serialize => sub { $_[0]||'[empty]' } ],
      [ catalog    => 'Catalog number',  serialize => sub { $_[0]||'[empty]' } ],
      [ languages  => 'Language',        join => ', ', split => sub { map $self->{languages}{$_}, @{$_[0]} } ],
      [ website    => 'Website' ],
      [ l_egs      => 'ErogameScape',    htmlize   => sub { $_[0] ? sprintf '<a href="https://erogamescape.dyndns.org/~ap2/ero/toukei_kaiseki/game.php?game=%d">%1$d</a>', $_[0] : '[empty]' } ],
      [ l_steam    => 'Steam AppId',     htmlize   => sub { $_[0] ? sprintf '<a href="https://store.steampowered.com/app/%d/">%1$d</a>', $_[0] : '[empty]' } ],
      [ l_dlsite   => 'DLsite (jpn)',    htmlize   => sub { $_[0] ? sprintf '<a href="'.sprintf($self->{dlsite_url}, 'home').'">%1$s</a>', $_[0] : '[empty]' } ],
      [ l_dlsiteen => 'DLsite (eng)',    htmlize   => sub { $_[0] ? sprintf '<a href="'.sprintf($self->{dlsite_url}, 'eng').'">%1$s</a>', $_[0] : '[empty]' } ],
      [ l_gog      => 'GOG.com',         htmlize   => sub { $_[0] ? sprintf '<a href="https://www.gog.com/game/%s">%1$s</a>', $_[0] : '[empty]' } ],
      [ l_denpa    => 'Denpasoft',       htmlize   => sub { $_[0] ? sprintf qq{<a href="$self->{denpa_url}">%1\$s</a>}, $_[0] : '[empty]' } ],
      [ l_jlist    => 'J-List',          htmlize   => sub { $_[0] ? sprintf qq{<a href="$self->{jlist_url}">%1\$s</a>}, $_[0] : '[empty]' } ],
      [ l_gyutto   => 'Gyutto',          htmlize   => sub { $_[0] ? sprintf '<a href="https://gyutto.com/i/item%d">%1$d</a>', $_[0] : '[empty]' } ],
      [ l_digiket  => 'Digiket',         htmlize   => sub { $_[0] ? sprintf '<a href="https://www.digiket.com/work/show/_data/ID=ITM%07d/">%1$d</a>', $_[0] : '[empty]' } ],
      [ l_melon    => 'Melonbooks',      htmlize   => sub { $_[0] ? sprintf '<a href="https://www.melonbooks.com/index.php?main_page=product_info&products_id=IT%010d">%1$d</a>', $_[0] : '[empty]' } ],
      [ l_mg       => 'MangaGamer',      htmlize   => sub { $_[0] ? sprintf qq{<a href="$self->{mg_r18_url}">%1\$d</a>}, $_[0] : '[empty]' } ],
      [ l_getchu   => 'Getchu',          htmlize   => sub { $_[0] ? sprintf '<a href="http://www.getchu.com/soft.phtml?id=%d">%1$d</a>', $_[0] : '[empty]' } ],
      [ l_getchudl => 'DL.Getchu',       htmlize   => sub { $_[0] ? sprintf '<a href="http://dl.getchu.com/i/item%d">%1$d</a>', $_[0] : '[empty]' } ],
      [ l_dmm      => 'DMM',             htmlize   => sub { $_[0] ? sprintf '<a href="https://%s">%1$s</a>', xml_escape $_[0] : '[empty]' } ],
      [ l_itch     => 'Itch.io',         htmlize   => sub { $_[0] ? sprintf '<a href="https://%s">%1$s</a>', xml_escape $_[0] : '[empty]' } ],
      [ l_jastusa  => 'JAST USA',        htmlize   => sub { $_[0] ? sprintf '<a href="https://jastusa.com/%s">%1$s</a>', xml_escape $_[0] : '[empty]' } ],
      [ released   => 'Release date',    htmlize   => \&fmtdatestr ],
      [ minage     => 'Age rating',      serialize => \&minage ],
      [ notes      => 'Notes',           diff => qr/[ ,\n\.]/ ],
      [ platforms  => 'Platforms',       join => ', ', split => sub { map $self->{platforms}{$_}, @{$_[0]} } ],
      [ media      => 'Media',           join => ', ', split => sub { map fmtmedia($_->{medium}, $_->{qty}), @{$_[0]} } ],
      [ resolution => 'Resolution',      serialize => sub { $self->{resolutions}{$_[0]}[0]; } ],
      [ voiced     => 'Voiced',          serialize => sub { $self->{voiced}[$_[0]] } ],
      [ ani_story  => 'Story animation', serialize => sub { $self->{animated}[$_[0]] } ],
      [ ani_ero    => 'Ero animation',   serialize => sub { $self->{animated}[$_[0]] } ],
      [ engine     => 'Engine' ],
      [ producers  => 'Producers',       join => '<br />', split => sub {
        map sprintf('<a href="/p%d" title="%s">%s</a> (%s)', $_->{id}, $_->{original}||$_->{name}, shorten($_->{name}, 50),
          join(', ', $_->{developer} ? 'developer' :(), $_->{publisher} ? 'publisher' :())
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
    td class => 'key', 'Relation';
    td;
     for (@{$r->{vn}}) {
       a href => "/v$_->{vid}", title => $_->{original}||$_->{title}, shorten $_->{title}, 60;
       br if $_ != $r->{vn}[$#{$r->{vn}}];
     }
    end;
   end;

   Tr;
    td 'Title';
    td $r->{title};
   end;

   if($r->{original}) {
     Tr;
      td 'Original title';
      td $r->{original};
     end;
   }

   Tr;
    td 'Type';
    td;
     cssicon "rt$r->{type}", $r->{type};
     txt sprintf ' %s%s', ucfirst($r->{type}), $r->{patch} ? ', patch' : '';
    end;
   end;

   Tr;
    td 'Language';
    td;
     for (@{$r->{languages}}) {
       cssicon "lang $_", $self->{languages}{$_};
       txt ' '.$self->{languages}{$_};
       br if $_ ne $r->{languages}[$#{$r->{languages}}];
     }
    end;
   end;

   Tr;
    td 'Publication';
    td join ', ',
      $r->{freeware} ? 'Freeware' : 'Non-free',
      $r->{patch} ? () : ($r->{doujin} ? 'doujin' : 'commercial');
   end;

   if(@{$r->{platforms}}) {
     Tr;
      td 'Platform'.(@{$r->{platforms}} == 1 ? '' : 's');
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
      td @{$r->{media}} == 1 ? 'Medium' : 'Media';
      td join ', ', map fmtmedia($_->{medium}, $_->{qty}), @{$r->{media}};
     end;
   }

   if($r->{resolution} ne 'unknown') {
     Tr;
      td 'Resolution';
      td $self->{resolutions}{$r->{resolution}}[0];
     end;
   }

   if($r->{voiced}) {
     Tr;
      td 'Voiced';
      td $self->{voiced}[$r->{voiced}];
     end;
   }

   if($r->{ani_story} || $r->{ani_ero}) {
     Tr;
      td 'Animation';
      td join ', ',
        $r->{ani_story} ? "Story: $self->{animated}[$r->{ani_story}]" : (),
        $r->{ani_ero}   ? "Ero scenes: $self->{animated}[$r->{ani_ero}]" : ();
     end;
   }

   if(length $r->{engine}) {
     Tr;
      td 'Engine';
      td; a href => '/r?fil='.fil_serialize({engine => $r->{engine}}), $r->{engine}; end;
     end;
   }

   Tr;
    td 'Released';
    td;
     lit fmtdatestr $r->{released};
    end;
   end;

   if($r->{minage} >= 0) {
     Tr;
      td 'Age rating';
      td minage $r->{minage};
     end;
   }

   if($r->{minage} == 18) {
     Tr;
      td 'Censoring';
      td $r->{uncensored} ? 'No optical censoring (e.g. mosaics)' : 'May include optical censoring (e.g. mosaics)';
     end;
   }

   for my $t (qw|developer publisher|) {
     my @prod = grep $_->{$t}, @{$r->{producers}};
     if(@prod) {
       Tr;
        td ucfirst($t).(@prod == 1 ? '' : 's');
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
      td gtintype($r->{gtin}) || 'GTIN';
      td $r->{gtin};
     end;
   }

   if($r->{catalog}) {
     Tr;
      td 'Catalog no.';
      td $r->{catalog};
     end;
   }

   my $links = $self->entryLinks(r => $r);
   if(@$links) {
     Tr;
      td 'Links';
      td;
       for(@$links) {
         a href => $_->[1], $_->[0];
         txt ', ' if $_ ne $links->[$#$links];
       }
      end;
     end;
   }

   if($self->authInfo->{id}) {
     my $rl = $self->dbRListGet(uid => $self->authInfo->{id}, rid => $r->{id})->[0];
     Tr;
      td 'User options';
      td;
       Select id => 'listsel', name => $self->authGetCode("/r$r->{id}/list");
        option value => -2, !$rl ? 'not on your list' : "Status: $self->{rlist_status}[$rl->{status}]";
        optgroup label => 'Set status';
         option value => $_, $self->{rlist_status}[$_]
           for (0..$#{$self->{rlist_status}});
        end;
        option value => -1, 'remove from list' if $rl;
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

  my $r = $rid && $self->dbReleaseGetRev(id => $rid, what => 'vn extended links producers platforms media', $rev ? (rev => $rev) : ())->[0];
  return $self->resNotFound if $rid && !$r->{id};
  $rev = undef if !$r || $r->{lastrev};

  my $v = $vid && $self->dbVNGet(id => $vid)->[0];
  return $self->resNotFound if $vid && !$v->{id};

  return $self->htmlDenied if !$self->authCan('edit')
    || $rid && (($r->{locked} || $r->{hidden}) && !$self->authCan('dbmod'));

  my $vn = $rid ? $r->{vn} : [{ vid => $vid, title => $v->{title} }];
  my %b4 = !$rid ? () : (
    (map { $_ => $r->{$_} } (qw|type title original languages website released minage
      notes platforms patch resolution voiced freeware doujin uncensored ani_story ani_ero engine ihid ilock|,
      $copy ? () : (qw|
        gtin catalog l_steam l_dlsite l_dlsiteen l_gog l_denpa l_jlist l_gyutto l_digiket l_melon l_mg l_getchu l_getchudl l_dmm l_itch l_jastusa l_egs
      |)
    )),
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
      { post => 'uncensored',required => 0, default => 0 },
      { post => 'title',     maxlength => 250 },
      { post => 'original',  required => 0, default => '', maxlength => 250 },
      { post => 'gtin',      required => 0, default => '0', template => 'gtin' },
      { post => 'catalog',   required => 0, default => '', maxlength => 50 },
      { post => 'languages', multi => 1, enum => [ keys %{$self->{languages}} ] },
      { post => 'website',   required => 0, default => '', maxlength => 250, template => 'weburl' },
      { post => 'l_steam',   required => 0, default => 0, template => 'uint' },
      { post => 'l_dlsite',  required => 0, default => '', regex => [ qr/^[VR]J[0-9]{6}$/, 'Invalid DLsite ID' ] },
      { post => 'l_dlsiteen',required => 0, default => '', regex => [ qr/^[VR]E[0-9]{6}$/, 'Invalid DLsite ID' ] },
      { post => 'l_gog',     required => 0, default => '', regex => [ qr/^[a-z0-9_]+$/, 'Invalid GOG.com ID' ] },
      { post => 'l_denpa',   required => 0, default => '', regex => [ qr/^[a-z0-9-]+$/, 'Invalid Denpasoft ID' ] },
      { post => 'l_jlist',   required => 0, default => '', regex => [ qr/^[a-z0-9-]+$/, 'Invalid J-List ID' ] },
      { post => 'l_gyutto',  required => 0, default => 0, template => 'uint' },
      { post => 'l_digiket', required => 0, default => 0, func => [ sub { $_[0] =~ s/^(?:ITM)?0+//; $_[0] =~ /^[0-9]+$/ }, 'Invalid Digiket ID' ] },
      { post => 'l_melon',   required => 0, default => 0, func => [ sub { $_[0] =~ s/^(?:IT)?0+//; $_[0] =~ /^[0-9]+$/ }, 'Invalid Melonbooks.com ID' ] },
      { post => 'l_mg',      required => 0, default => 0, template => 'uint' },
      { post => 'l_getchu',  required => 0, default => 0, template => 'uint' },
      { post => 'l_getchudl',required => 0, default => 0, template => 'uint' },
      { post => 'l_dmm',     required => 0, default => '', regex => [ qr{^(?:https?://)?(?:www|dlsoft)\.dmm\.(?:com|co\.jp)/}, 'Invalid DMM URL' ] },
      { post => 'l_itch',    required => 0, default => '', regex => [ qr{^(?:https?://)?([a-z0-9_-]+)\.itch\.io/([a-z0-9_-]+)$}, 'Invalid Itch.io URL' ] },
      { post => 'l_jastusa', required => 0, default => '', regex => [ qr/^[a-z0-9-]+$/, 'Invalid JAST USA ID' ] },
      { post => 'l_egs',     required => 0, default => 0, template => 'uint' },
      { post => 'released',  required => 0, default => 0, template => 'rdate' },
      { post => 'minage' ,   required => 0, default => -1, enum => $self->{age_ratings} },
      { post => 'notes',     required => 0, default => '', maxlength => 10240 },
      { post => 'platforms', required => 0, default => '', multi => 1, enum => [ keys %{$self->{platforms}} ] },
      { post => 'media',     required => 0, default => '' },
      { post => 'resolution',required => 0, default => 0, enum => [ keys %{$self->{resolutions}} ] },
      { post => 'voiced',    required => 0, default => 0, enum => [ 0..$#{$self->{voiced}} ] },
      { post => 'ani_story', required => 0, default => 0, enum => [ 0..$#{$self->{animated}} ] },
      { post => 'ani_ero',   required => 0, default => 0, enum => [ 0..$#{$self->{animated}} ] },
      { post => 'engine',    required => 0, default => '', maxlength => 50 },
      { post => 'engine_oth',required => 0, default => '', maxlength => 50 },
      { post => 'producers', required => 0, default => '' },
      { post => 'vn',        maxlength => 50000 },
      { post => 'editsum',   template => 'editsum' },
      { post => 'ihid',      required  => 0 },
      { post => 'ilock',     required  => 0 },
    );

    $frm->{engine} = $frm->{engine_oth} if $frm->{engine} eq '_other_';
    delete $frm->{engine_oth};

    $frm->{original} = '' if $frm->{original} eq $frm->{title};
    $frm->{l_dmm} =~ s{^https?://}{};
    $frm->{l_itch} =~ s{^https?://}{};

    push @{$frm->{_err}}, [ 'released', 'required', 1 ] if !$frm->{released};

    my($media, $producers, $new_vn);
    if(!$frm->{_err}) {
      # de-serialize
      $media     = [ map [ split / / ], split /,/, $frm->{media} ];
      $producers = [ map { /^([0-9]+),([1-3])/ ? [ $1, $2&1?1:0, $2&2?1:0] : () } split /\|\|\|/, $frm->{producers} ];
      $new_vn    = [ map { /^([0-9]+)/ ? $1 : () } split /\|\|\|/, $frm->{vn} ];
      $frm->{platforms} = [ grep $_, @{$frm->{platforms}} ];
      $frm->{$_} = $frm->{$_} ? 1 : 0 for (qw|patch freeware doujin uncensored ihid ilock|);

      # reset some fields when the patch flag is set
      if($frm->{patch}) {
        $frm->{doujin} = $frm->{voiced} = $frm->{ani_story} = $frm->{ani_ero} = 0;
        $frm->{resolution} = 'unknown';
        $frm->{engine} = '';
      }
      $frm->{uncensored} = 0 if $frm->{minage} != 18;

      my $same = $rid &&
          (join(',', sort @{$b4{platforms}}) eq join(',', sort @{$frm->{platforms}})) &&
          (join(',', map join(' ', @$_), sort { $a->[0] <=> $b->[0] }  @$producers) eq join(',', map sprintf('%d %d %d',$_->{id}, $_->{developer}?1:0, $_->{publisher}?1:0), sort { $a->{id} <=> $b->{id} } @{$r->{producers}})) &&
          (join(',', sort @$new_vn) eq join(',', sort map $_->{vid}, @$vn)) &&
          (join(',', sort @{$b4{languages}}) eq join(',', sort @{$frm->{languages}})) &&
          !grep !/^(platforms|producers|vn|languages)$/ && $frm->{$_} ne $b4{$_}, keys %b4;
      return $self->resRedirect("/r$rid", 'post') if !$copy && $same;
      $frm->{_err} = [ "No changes, please don't create an entry that is fully identical to another" ] if $copy && $same;
    }

    if(!$frm->{_err}) {
      my $nrev = $self->dbItemEdit(r => !$copy && $rid ? ($r->{id}, $r->{rev}) : (undef, undef),
        (map { $_ => $frm->{$_} } qw| type title original gtin catalog languages website released minage
          l_steam l_dlsite l_dlsiteen l_gog l_denpa l_jlist l_gyutto l_digiket l_melon l_mg l_getchu l_getchudl l_dmm l_itch l_jastusa l_egs
          notes platforms resolution editsum patch voiced freeware doujin uncensored ani_story ani_ero engine ihid ilock|),
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

  my $title = !$rid ? "Add release to $v->{title}" : $copy ? "Copy $r->{title}" : "Edit $r->{title}";
  $self->htmlHeader(title => $title, noindex => 1);
  $self->htmlMainTabs('r', $r, $copy ? 'copy' : 'edit') if $rid;
  $self->htmlMainTabs('v', $v, 'edit') if $vid;
  $self->htmlEditMessage('r', $r, $title, $copy);
  _listrel($self, $vid) if $vid && $self->reqMethod ne 'POST';
  _form($self, $r, $v, $frm, $copy);
  $self->htmlFooter;
}


sub _form {
  my($self, $r, $v, $frm, $copy) = @_;

  $self->htmlForm({ frm => $frm, action => $r ? "/r$r->{id}/".($copy ? 'copy' : 'edit') : "/v$v->{id}/add", editsum => 1 },
  rel_geninfo => [ 'General info',
    [ select => short => 'type',      name => 'Type',
      options => [ map [ $_, ucfirst $_ ], @{$self->{release_types}} ] ],
    [ check  => short => 'patch',     name => 'This release is a patch to another release.' ],
    [ check  => short => 'freeware',  name => 'Freeware (i.e. available at no cost)' ],
    [ check  => short => 'doujin',    name => 'Doujin (self-published, not by a company)' ],
    [ input  => short => 'title',     name => 'Title (romaji)',    width => 450 ],
    [ input  => short => 'original',  name => 'Original title', width => 450 ],
    [ static => content => 'The original title of this release, leave blank if it already is in the Latin alphabet.' ],
    [ select => short => 'languages', name => 'Language(s)', multi => 1,
      options => [ map [ $_, "$_ ($self->{languages}{$_})" ], keys %{$self->{languages}} ] ],
    [ input  => short => 'gtin',      name => 'JAN/UPC/EAN' ],
    [ input  => short => 'catalog',   name => 'Catalog number' ],
    [ input  => short => 'website',   name => 'Official website' ],
    [ date   => short => 'released',  name => 'Release date' ],
    [ static => content => 'Leave month or day blank if they are unknown' ],
    [ select => short => 'minage', name => 'Age rating',
      options => [ map [ $_, minage $_, 1 ], @{$self->{age_ratings}} ] ],
    [ check  => short => 'uncensored',name => 'No mosaic or other optical censoring (only check if this release has erotic content)' ],

    [ static => nolabel => 1, content => '<br><b>Links</b>' ],
    [ input  => short => 'l_egs',     name => 'ErogameScape', pre => 'erogamescape.dyndns.org/..?game=', width => 100 ],
    [ input  => short => 'l_steam',   name => 'Steam AppID', pre => 'store.steampowered.com/app/', width => 100 ],
    [ input  => short => 'l_jlist',   name => 'J-List', pre => 'www.jlist.com/', post => ' (the last part of the URL, e.g. "np004")', width => 100 ],
    [ input  => short => 'l_jastusa', name => 'JAST USA', pre => 'jastusa.com/' ],
    [ input  => short => 'l_mg',      name => 'MangaGamer', pre => 'mangagamer.com/..&product_code=', width => 100 ],
    [ input  => short => 'l_denpa',   name => 'Denpasoft', pre => 'denpasoft.com/products/' ],
    [ input  => short => 'l_gog',     name => 'GOG.com', pre => 'www.gog.com/game/' ],
    [ input  => short => 'l_itch',    name => 'Itch.io', post => ' (e.g. "author.itch.io/title")', width => 300 ],
    [ input  => short => 'l_dlsiteen',name => 'DLsite (eng)', pre => 'www.dlsite.com/../product_id/', post => ' e.g. "RE083922"', width => 100 ],
    [ input  => short => 'l_dlsite',  name => 'DLsite (jpn)', pre => 'www.dlsite.com/../product_id/', post => ' e.g. "RJ083922"', width => 100 ],
    [ input  => short => 'l_digiket', name => 'Digiket', pre => 'www.digiket.com/work/show/_data/ID=ITM', width => 100 ],
    [ input  => short => 'l_gyutto',  name => 'Gyutto', pre => 'gyutto.com/i/item', post => ' (item number)', width => 100 ],
    [ input  => short => 'l_getchudl',name => 'DL.Getchu', pre => 'dl.getchu.com/i/item', post => ' (item number)', width => 100 ],
    [ input  => short => 'l_getchu',  name => 'Getchu', pre => 'www.getchu.com/soft.phtml?id=', width => 100 ],
    [ input  => short => 'l_melon',   name => 'Melonbooks.com', pre => 'www.melonbooks.com/..&products_id=IT', width => 100 ],
    [ input  => short => 'l_dmm',     name => 'DMM', post => ' (full URL)' ],

    [ static => nolabel => 1, content => '<br>' ],
    [ textarea => short => 'notes', name => 'Notes<br /><b class="standout">English please!</b>' ],
    [ static => content =>
       'Miscellaneous notes/comments, information that does not fit in the above fields.'
      .' E.g.: Types of censoring or for which releases this patch applies.' ],
  ],

  rel_format => [ 'Format',
    [ select => short => 'resolution', name => 'Resolution', options => [
      map [ $_, @{$self->{resolutions}{$_}} ], keys %{$self->{resolutions}} ] ],
    [ static => label => 'Engine', content => sub {
      my $other = $frm->{engine} && !grep($_ eq $frm->{engine}, @{$self->{engines}});
      Select name => 'engine', id => 'engine', tabindex => 10;
       option value => $_, ($frm->{engine}||'') eq $_ ? (selected => 'selected') : (), $_ || 'Unknown'
         for ('', @{$self->{engines}});
       option value => '_other_', $other ? (selected => 'selected') : (), 'Other';
      end;
      input type => 'text', name => 'engine_oth', id => 'engine_oth', tabindex => 10, class => 'text '.($other ? '' : 'hidden'), value => $frm->{engine}||'';
    } ],
    [ static => content => 'Try to use a name from the <a href="/r/engines">engine list</a>.' ],
    [ select => short => 'voiced',     name => 'Voiced', options => [
      map [ $_, $self->{voiced}[$_] ], 0..$#{$self->{voiced}} ] ],
    [ select => short => 'ani_story',  name => 'Story animation', options => [
      map [ $_, $self->{animated}[$_] ], 0..$#{$self->{animated}} ] ],
    [ select => short => 'ani_ero',  name => 'Ero animation', options => [
      map [ $_, $_ ? $self->{animated}[$_] : 'Unknown / no ero scenes' ], 0..$#{$self->{animated}} ] ],
    [ static => content => 'Animation in erotic scenes, leave to unknown if there are no ero scenes.' ],
    [ hidden => short => 'media' ],
    [ static => nolabel => 1, content => sub {
      h2 'Platforms';
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

      h2 'Media';
      div id => 'media_div', '';
    }],
  ],

  rel_prod => [ 'Producers',
    [ hidden => short => 'producers' ],
    [ static => nolabel => 1, content => sub {
      h2 'Selected producers';
      table; tbody id => 'producer_tbl'; end; end;
      h2 'Add producer';
      table; Tr;
       td class => 'tc_name'; input id => 'producer_input', type => 'text', class => 'text'; end;
       td class => 'tc_role'; Select id => 'producer_role';
        option value => 1, 'Developer';
        option value => 2, selected => 'selected',  'Publisher';
        option value => 3, 'Both';
       end; end;
       td class => 'tc_add';  a id => 'producer_add', href => '#', 'add'; end;
      end; end 'table';
    }],
  ],

  rel_vn => [ 'Visual novels',
    [ hidden => short => 'vn' ],
    [ static => nolabel => 1, content => sub {
      h2 'Selected visual novels';
      table class => 'stripe'; tbody id => 'vn_tbl'; end; end;
      h2 'Add visual novel';
      div;
       input id => 'vn_input', type => 'text', class => 'text';
       a href => '#', id => 'vn_add', 'add';
      end;
    }],
  ],
  );
}

sub _listrel {
  my($self, $vid) = @_;
  my $l = $self->dbReleaseGet(vid => $vid, hidden_only => 1, results => 50);
  return if !@$l;
  div class => 'mainbox';
   h1 'Deleted releases';
   div class => 'warning';
    p q{This visual novel has releases that have been deleted before. Please
     review this list to make sure you're not adding a release that has already
     been deleted before.};
    br;
    ul;
     for(@$l) {
       li;
        txt '['.join(',', @{$_->{languages}}).'] ';
        a href => "/r$_->{id}", title => $_->{original}||$_->{title}, "$_->{title} (r$_->{id})";
       end;
     }
    end;
   end;
  end;
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

  $self->htmlHeader(title => 'Browse releases');

  form method => 'get', action => '/r', 'accept-charset' => 'UTF-8';
  div class => 'mainbox';
   h1 'Browse releases';
   $self->htmlSearchBox('r', $f->{q});
   p class => 'filselect';
    a id => 'filselect', href => '#r';
     lit '<i>&#9656;</i> Filters<i></i>';
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
      [ 'Released', 'released' ],
      [ 'Rating',   'minage' ],
      [ '',         '' ],
      [ 'Title',    'title' ],
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
     h1 'No results found';
     div class => 'notice';
      p;
       txt 'Sorry, couldn\'t find anything that comes through your filters. You might want to disable a few filters to get more results.';
       br; br;
       txt 'Also, keep in mind that we don\'t have all information about all releases.'
          .' So e.g. filtering on screen resolution will exclude all releases of which we don\'t know it\'s resolution,'
          .' even though it might in fact be in the resolution you\'re looking for.';
      end
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
  );
  return () if $f->{_err};
  $c{minage} = [ grep $_ >= 0 && ($f->{ma_m} ? $f->{ma_a} >= $_ : $f->{ma_a} <= $_), @{$self->{age_ratings}} ] if $f->{ma_a} || $f->{ma_m};
  $c{date_after} = $f->{mi}  if $f->{mi};
  $c{date_before} = $f->{ma} if $f->{ma} < 99990000;
  $c{plat} = $f->{pl}        if $f->{pl}[0];
  $c{lang} = $f->{ln}        if $f->{ln}[0];
  $c{med} = $f->{me}         if $f->{me}[0];
  $c{type} = $f->{tp}        if $f->{tp};
  $c{patch} = $f->{pa} == 2 ? 0 : 1 if $f->{pa};
  $c{freeware} = $f->{fw} == 2 ? 0 : 1 if $f->{fw};
  $c{doujin} = $f->{do} == 2 ? 0 : 1 if $f->{do};
  return %c;
}


sub engines {
  my $self = shift;
  my $lst = $self->dbReleaseEngines();
  $self->htmlHeader(title => 'Engine list', noindex => 1);

  div class => 'mainbox';
   h1 'Engine list';
   p;
    lit q{
     This is a list of all engines currently associated with releases. This
     list can be used as reference when filling out the engine field for a
     release and to find inconsistencies in the engine names. See the <a
     href="/d3#3">releases guidelines</a> for more information.
    };
   end;
   ul;
    for my $e (@$lst) {
      li;
       a href => '/r?fil='.fil_serialize({engine => $e->{engine}}), $e->{engine};
       b class => 'grayedout', " $e->{cnt}";
      end;
    }
   end;

  end;
}


sub relxml {
  my $self = shift;

  my $f = $self->formValidate(
    { get => 'v', required => 1, multi => 1, mincount => 1, template => 'id' }
  );
  return $self->resNotFound if $f->{_err};

  my $vns = $self->dbVNGet(id => $f->{v}, order => 'title', results => 100);
  my $rel = $self->dbReleaseGet(vid => $f->{v}, results => 100, what => 'vn');

  $self->resHeader('Content-type' => 'text/xml; charset=UTF-8');
  xml;
  tag 'vns';
   for my $v (@$vns) {
     tag 'vn', id => $v->{id}, title => $v->{title};
      tag 'release', id => $_->{id}, lang => join(',', @{$_->{languages}}), $_->{title}
        for (grep (grep $_->{vid} == $v->{id}, @{$_->{vn}}), @$rel);
     end;
   }
  end;
}


sub enginexml {
  my $self = shift;

  # The list of engines happens to be small enough for this to make sense, and
  # fetching all unique engines from the releases table also happens to be fast
  # enough right now, but this may need a separate cache or index in the future.
  my $lst = $self->dbReleaseEngines();

  my $f = $self->formValidate(
    { get => 'q', required => 1, maxlength => 500 },
  );
  return $self->resNotFound if $f->{_err};

  $self->resHeader('Content-type' => 'text/xml; charset=UTF-8');
  xml;
  tag 'engines';
   for(grep $_->{engine} =~ /\Q$f->{q}\E/i, @$lst) {
     tag 'item', count => $_->{cnt}, $_->{engine};
   }
  end;
}


# Generate the html for an 'external links' dropdown
sub releaseExtLinks {
  my($self, $r) = @_;
  my $links = $self->entryLinks(r => $r);
  my $has_dd = @$links > ($r->{website} ? 1 : 0);
  if(@$links) {
    a href => $r->{website}||'#', class => 'rllinks';
     txt scalar @$links if $has_dd;
     cssicon 'external', 'External link';
    end;
    if($has_dd) {
      ul class => 'hidden rllinks_dd';
       for (@$links) {
         li;
          a href => $_->[1];
           span $_->[2] if $_->[2];
           txt $_->[0];
          end;
         end;
       };
      end;
    }
  } else {
    txt ' ';
  }
}

1;

