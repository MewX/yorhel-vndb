
package VNDB::Handler::Releases;

use strict;
use warnings;
use TUWF ':html', ':xml', 'uri_escape';
use VNDB::Func;
use VNDB::Types;
use Exporter 'import';

our @EXPORT = ('releaseExtLinks');


TUWF::register(
  qr{(v)([1-9]\d*)/add}            => \&edit,
  qr{r}                            => \&browse,
  qr{r(?:([1-9]\d*)(?:\.([1-9]\d*))?/(edit|copy))}
    => \&edit,
  qr{r/engines}                    => \&engines,
  qr{xml/releases.xml}             => \&relxml,
  qr{xml/engines.xml}              => \&enginexml,
);


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
        gtin catalog l_steam l_dlsite l_dlsiteen l_gog l_denpa l_jlist l_digiket l_melon l_mg l_getchu l_getchudl l_itch l_jastusa l_egs l_erotrail
      |)
    )),
    $copy ? () : (
      l_gyutto => join(' ', sort @{$r->{l_gyutto}}),
      l_dmm    => join(' ', sort @{$r->{l_dmm}}),
    ),
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
    my $dmm_re = qr{(?:https?://)?(?:www|dlsoft)\.dmm\.(?:com|co\.jp)/[^\s]+};
    $frm = $self->formValidate(
      { post => 'type',      enum => [ keys %RELEASE_TYPE ] },
      { post => 'patch',     required => 0, default => 0 },
      { post => 'freeware',  required => 0, default => 0 },
      { post => 'doujin',    required => 0, default => 0 },
      { post => 'uncensored',required => 0, default => 0 },
      { post => 'title',     maxlength => 250 },
      { post => 'original',  required => 0, default => '', maxlength => 250 },
      { post => 'gtin',      required => 0, default => '0', template => 'gtin' },
      { post => 'catalog',   required => 0, default => '', maxlength => 50 },
      { post => 'languages', multi => 1, enum => [ keys %LANGUAGE ] },
      { post => 'website',   required => 0, default => '', maxlength => 250, template => 'weburl' },
      { post => 'l_steam',   required => 0, default => 0, template => 'uint' },
      { post => 'l_dlsite',  required => 0, default => '', regex => [ qr/^[VR]J[0-9]{6}$/, 'Invalid DLsite ID' ] },
      { post => 'l_dlsiteen',required => 0, default => '', regex => [ qr/^[VR]E[0-9]{6}$/, 'Invalid DLsite ID' ] },
      { post => 'l_gog',     required => 0, default => '', regex => [ qr/^[a-z0-9_]+$/, 'Invalid GOG.com ID' ] },
      { post => 'l_denpa',   required => 0, default => '', regex => [ qr/^[a-z0-9-]+$/, 'Invalid Denpasoft ID' ] },
      { post => 'l_jlist',   required => 0, default => '', regex => [ qr/^[a-z0-9-]+$/, 'Invalid J-List ID' ] },
      { post => 'l_gyutto',  required => 0, default => '', regex => [ qr/^([0-9]+(\s+[0-9]+)*)?$/, 'Invalid Gyutto id' ] },
      { post => 'l_digiket', required => 0, default => 0, func => [ sub { $_[0] =~ s/^(?:ITM)?0+//; $_[0] =~ /^[0-9]+$/ }, 'Invalid Digiket ID' ] },
      { post => 'l_melon',   required => 0, default => 0, func => [ sub { $_[0] =~ s/^(?:IT)?0+//; $_[0] =~ /^[0-9]+$/ }, 'Invalid Melonbooks.com ID' ] },
      { post => 'l_mg',      required => 0, default => 0, template => 'uint' },
      { post => 'l_getchu',  required => 0, default => 0, template => 'uint' },
      { post => 'l_getchudl',required => 0, default => 0, template => 'uint' },
      { post => 'l_dmm',     required => 0, default => '', regex => [ qr/^($dmm_re(\s+$dmm_re)*)?$/, 'Invalid DMM URL' ] },
      { post => 'l_itch',    required => 0, default => '', regex => [ qr{^(?:https?://)?([a-z0-9_-]+)\.itch\.io/([a-z0-9_-]+)$}, 'Invalid Itch.io URL' ] },
      { post => 'l_jastusa', required => 0, default => '', regex => [ qr/^[a-z0-9-]+$/, 'Invalid JAST USA ID' ] },
      { post => 'l_egs',     required => 0, default => 0, template => 'uint' },
      { post => 'l_erotrail',required => 0, default => 0, template => 'uint' },
      { post => 'released',  required => 0, default => 0, template => 'rdate' },
      { post => 'minage' ,   required => 0, default => -1, enum => [ keys %AGE_RATING ] },
      { post => 'notes',     required => 0, default => '', maxlength => 10240 },
      { post => 'platforms', required => 0, default => '', multi => 1, enum => [ keys %PLATFORM ] },
      { post => 'media',     required => 0, default => '' },
      { post => 'resolution',required => 0, default => 0, enum => [ keys %RESOLUTION ] },
      { post => 'voiced',    required => 0, default => 0, enum => [ keys %VOICED ] },
      { post => 'ani_story', required => 0, default => 0, enum => [ keys %ANIMATED ] },
      { post => 'ani_ero',   required => 0, default => 0, enum => [ keys %ANIMATED ] },
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

    my $l_dmm    = [ split /\s+/, $frm->{l_dmm} ];
    my $l_gyutto = [ split /\s+/, $frm->{l_gyutto} ];

    $frm->{original} = '' if $frm->{original} eq $frm->{title};
    $_ =~ s{^https?://}{} for @$l_dmm;
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
      $frm->{l_dmm}    = join ' ', sort @$l_dmm;
      $frm->{l_gyutto} = join ' ', sort @$l_gyutto;

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
          l_steam l_dlsite l_dlsiteen l_gog l_denpa l_jlist l_digiket l_melon l_mg l_getchu l_getchudl l_itch l_jastusa l_egs l_erotrail
          notes platforms resolution editsum patch voiced freeware doujin uncensored ani_story ani_ero engine ihid ilock|),
        l_gyutto  => $l_gyutto,
        l_dmm     => $l_dmm,
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
      options => [ map [ $_, $RELEASE_TYPE{$_} ], keys %RELEASE_TYPE ] ],
    [ check  => short => 'patch',     name => 'This release is a patch to another release.' ],
    [ check  => short => 'freeware',  name => 'Freeware (i.e. available at no cost)' ],
    [ check  => short => 'doujin',    name => 'Doujin (self-published, not by a company)' ],
    [ input  => short => 'title',     name => 'Title (romaji)',    width => 450 ],
    [ input  => short => 'original',  name => 'Original title', width => 450 ],
    [ static => content => 'The original title of this release, leave blank if it already is in the Latin alphabet.' ],
    [ select => short => 'languages', name => 'Language(s)', multi => 1, size => 10,
      options => [ map [ $_, "$LANGUAGE{$_} ($_)" ], sort { $LANGUAGE{$a} cmp $LANGUAGE{$b} } keys %LANGUAGE ] ],
    [ input  => short => 'gtin',      name => 'JAN/UPC/EAN' ],
    [ input  => short => 'catalog',   name => 'Catalog number' ],
    [ input  => short => 'website',   name => 'Official website' ],
    [ date   => short => 'released',  name => 'Release date' ],
    [ static => content => 'Leave month or day blank if they are unknown' ],
    [ select => short => 'minage', name => 'Age rating',
      options => [ map [ $_, minage $_, 1 ], keys %AGE_RATING ] ],
    [ check  => short => 'uncensored',name => 'No mosaic or other optical censoring (only check if this release has erotic content)' ],

    [ static => nolabel => 1, content => '<br><b>Links</b>' ],
    [ input  => short => 'l_egs',     name => 'ErogameScape', pre => 'erogamescape.dyndns.org/..?game=', width => 100 ],
    [ input  => short => 'l_erotrail',name => 'ErogeTrailers', pre => 'erogetrailers.com/soft/', width => 100 ],
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
    [ input  => short => 'l_gyutto',  name => 'Gyutto', pre => 'gyutto.com/i/item', post => ' (item number, space separated)', width => 100 ],
    [ input  => short => 'l_getchudl',name => 'DL.Getchu', pre => 'dl.getchu.com/i/item', post => ' (item number)', width => 100 ],
    [ input  => short => 'l_getchu',  name => 'Getchu', pre => 'www.getchu.com/soft.phtml?id=', width => 100 ],
    [ input  => short => 'l_melon',   name => 'Melonbooks.com', pre => 'www.melonbooks.com/..&products_id=IT', width => 100 ],
    [ input  => short => 'l_dmm',     name => 'DMM', post => ' (full URL, space separated)', width => 400 ],

    [ static => nolabel => 1, content => '<br>' ],
    [ textarea => short => 'notes', name => 'Notes<br /><b class="standout">English please!</b>' ],
    [ static => content =>
       'Miscellaneous notes/comments, information that does not fit in the above fields.'
      .' E.g.: Types of censoring or for which releases this patch applies.' ],
  ],

  rel_format => [ 'Format',
    [ select => short => 'resolution', name => 'Resolution', options => [
      map [ $_, $RESOLUTION{$_}{txt}, $RESOLUTION{$_}{cat} ], keys %RESOLUTION ] ],
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
      map [ $_, $VOICED{$_}{txt} ], keys %VOICED ] ],
    [ select => short => 'ani_story',  name => 'Story animation', options => [
      map [ $_, $ANIMATED{$_}{txt} ], keys %ANIMATED ] ],
    [ select => short => 'ani_ero',  name => 'Ero animation', options => [
      map [ $_, $_ ? $ANIMATED{$_}{txt} : 'Unknown / no ero scenes' ], keys %ANIMATED ] ],
    [ static => content => 'Animation in erotic scenes, leave to unknown if there are no ero scenes.' ],
    [ hidden => short => 'media' ],
    [ static => nolabel => 1, content => sub {
      h2 'Platforms';
      div class => 'platforms';
       for my $p (sort keys %PLATFORM) {
         span;
          input type => 'checkbox', name => 'platforms', value => $p, id => $p,
            $frm->{platforms} && grep($_ eq $p, @{$frm->{platforms}}) ? (checked => 'checked') : ();
          label for => $p;
           cssicon $p, $PLATFORM{$p};
           txt ' '.$PLATFORM{$p};;
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
        $_ ne 'oth' && cssicon $_, $PLATFORM{$_} for (@{$l->{platforms}});
        cssicon "lang $_", $LANGUAGE{$_} for (@{$l->{languages}});
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
    { get => 'ln', required => 0, multi => 1, default => '', enum => [ keys %LANGUAGE ] },
    { get => 'pl', required => 0, multi => 1, default => '', enum => [ keys %PLATFORM ] },
    { get => 'me', required => 0, multi => 1, default => '', enum => [ keys %MEDIUM ] },
    { get => 'tp', required => 0, default => '', enum => [ '', keys %RELEASE_TYPE ] },
    { get => 'pa', required => 0, default => 0, enum => [ 0..2 ] },
    { get => 'fw', required => 0, default => 0, enum => [ 0..2 ] },
    { get => 'do', required => 0, default => 0, enum => [ 0..2 ] },
    { get => 'ma_m', required => 0, default => 0, enum => [ 0, 1 ] },
    { get => 'ma_a', required => 0, default => 0, enum => [ keys %AGE_RATING ] },
    { get => 'mi', required => 0, default => 0, template => 'uint' },
    { get => 'ma', required => 0, default => 99999999, template => 'uint' },
  );
  return () if $f->{_err};
  $c{minage} = [ grep $_ >= 0 && ($f->{ma_m} ? $f->{ma_a} >= $_ : $f->{ma_a} <= $_), keys %AGE_RATING ] if $f->{ma_a} || $f->{ma_m};
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
   for(grep $lst->[$_]{engine} =~ /\Q$f->{q}\E/i, 0..$#$lst) {
     tag 'item', count => $lst->[$_]{cnt}, id => $_+1, $lst->[$_]{engine};
   }
  end;
}


# Generate the html for an 'external links' dropdown, assumes enrich_extlinks() has already been called on this object.
sub releaseExtLinks {
  my($self, $r) = @_;
  my $has_dd = $r->{extlinks}->@* > ($r->{website} ? 1 : 0);
  if($r->{extlinks}->@*) {
    a href => $r->{website}||'#', class => 'rllinks';
     txt scalar $r->{extlinks}->@* if $has_dd;
     cssicon 'external', 'External link';
    end;
    if($has_dd) {
      ul class => 'hidden rllinks_dd';
       for ($r->{extlinks}->@*) {
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

