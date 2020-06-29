
package VNDB::Handler::VNEdit;

use strict;
use warnings;
use TUWF ':html', ':xml';
use Image::Magick;
use VNDB::Func;
use VNDB::Types;


TUWF::register(
  qr{old/v(?:([1-9]\d*)(?:\.([1-9]\d*))?/edit|/new)}
    => \&edit,
  qr{old/v/add}            => \&addform,
  qr{xml/vn\.xml}          => \&vnxml,
  qr{xml/screenshots\.xml} => \&scrxml,
);


sub addform {
  my $self = shift;
  return $self->htmlDenied if !$self->authCan('edit');

  my $frm;
  my $l = [];
  if($self->reqMethod eq 'POST') {
    return if !$self->authCheckCode;
    $frm = $self->formValidate(
      { post => 'title',       maxlength => 250 },
      { post => 'original',    required => 0, maxlength => 250, default => '' },
      { post => 'alias',       required => 0, maxlength => 500, default => '' },
      { post => 'continue_ign',required => 0 },
    );

    # look for duplicates
    if(!$frm->{_err} && !$frm->{continue_ign}) {
      $l = $self->dbVNGet(search => $frm->{title}, what => 'changes', results => 50, inc_hidden => 1);
      push @$l, @{$self->dbVNGet(search => $frm->{original}, what => 'changes', results => 50, inc_hidden => 1)} if $frm->{original};
      $_ && push @$l, @{$self->dbVNGet(search => $_, what => 'changes', results => 50, inc_hidden => 1)} for(split /\n/, $frm->{alias});
      my %ids = map +($_->{id}, $_), @$l;
      $l = [ map $ids{$_}, sort { $ids{$a}{title} cmp $ids{$b}{title} } keys %ids ];
    }

    return edit($self, undef, undef, 1) if !@$l && !$frm->{_err};
  }

  $self->htmlHeader(title => 'Add a new visual novel', noindex => 1);
  if(@$l) {
    div class => 'mainbox';
     h1 'Possible duplicates found';
     div class => 'warning';
      p;
       txt 'The following is a list of visual novels that match the title(s) you gave.'
         .' Please check this list to avoid creating a duplicate visual novel entry.'
         .' Be especially wary of items that have been deleted! To see why an entry has been deleted, click on its title.';
       br; br;
       txt 'To add the visual novel anyway, hit the "Continue and ignore duplicates" button below.';
      end;
     end;
     ul;
      for(@$l) {
        li;
         a href => "/v$_->{id}", title => $_->{original}||$_->{title}, "v$_->{id}: ".shorten($_->{title}, 50);
         b class => 'standout', ' deleted' if $_->{hidden};
        end;
      }
     end;
    end 'div';
  }

  $self->htmlForm({ frm => $frm, action => '/old/v/add', continue => @$l ? 2 : 1 },
  vn_add => [ 'Add a new visual novel',
    [ input    => short => 'title',     name => 'Title (romaji)', width => 450 ],
    [ input    => short => 'original',  name => 'Original title', width => 450 ],
    [ static   => content => 'The original title of this visual novel, leave blank if it already is in the Latin alphabet.' ],
    [ textarea => short => 'alias',     name => 'Aliases', rows => 4 ],
    [ static   => content => 'List of alternative titles or abbreviations. One line for each alias.' ],
  ]);
  $self->htmlFooter;
}


sub edit {
  my($self, $vid, $rev, $nosubmit) = @_;

  my $v = $vid && $self->dbVNGetRev(id => $vid, what => 'extended screenshots relations anime staff seiyuu changes', $rev ? (rev => $rev) : ())->[0];
  return $self->resNotFound if $vid && !$v->{id};
  $rev = undef if !$vid || $v->{lastrev};

  return $self->htmlDenied if !$self->authCan('edit')
    || $vid && (($v->{locked} || $v->{hidden}) && !$self->authCan('dbmod'));

  my $r = $v ? $self->dbReleaseGet(vid => $v->{id}) : [];
  my $chars = $v ? $self->dbCharGet(vid => $v->{id}, results => 500) : [];

  my %b4 = !$vid ? () : (
    (map { $_ => $v->{$_} } qw|title original desc alias length l_renai l_wikidata image img_nsfw ihid ilock|),
    credits => [
      map { my $c = $_; +{ map { $_ => $c->{$_} } qw|aid role note| } }
      sort { $a->{aid} <=> $b->{aid} || $a->{role} cmp $b->{role} } @{$v->{credits}}
    ],
    seiyuu => [
      map { my $c = $_; +{ map { $_ => $c->{$_} } qw|aid cid note| } }
      sort { $a->{aid} <=> $b->{aid} || $a->{cid} <=> $b->{cid} } @{$v->{seiyuu}}
    ],
    anime => join(' ', sort { $a <=> $b } map $_->{id}, @{$v->{anime}}),
    vnrelations => join('|||', map $_->{relation}.','.$_->{id}.','.($_->{official}?1:0).','.$_->{title}, sort { $a->{id} <=> $b->{id} } @{$v->{relations}}),
    screenshots => [
      map +{ id => $_->{id}, nsfw => $_->{nsfw}?1:0, rid => $_->{rid} },
      sort { $a->{id} <=> $b->{id} } @{$v->{screenshots}}
    ]
  );

  my $frm;
  if($self->reqMethod eq 'POST') {
    return if !$nosubmit && !$self->authCheckCode;
    $frm = $self->formValidate(
      { post => 'title',       maxlength => 250 },
      { post => 'original',    required => 0, maxlength => 250, default => '' },
      { post => 'alias',       required => 0, maxlength => 500, default => '' },
      { post => 'desc',        required => 0, default => '', maxlength => 10240 },
      { post => 'length',      required => 0, default => 0,  enum => [ keys %VN_LENGTH ] },
      { post => 'l_renai',     required => 0, default => '', maxlength => 100 },
      { post => 'l_wikidata',  required => 0, template => 'wikidata' },
      { post => 'anime',       required => 0, default => '' },
      { post => 'image',       required => 0, default => 0,  template => 'id' },
      { post => 'img_nsfw',    required => 0, default => 0 },
      { post => 'credits', required => 0, template => 'json', json_unique => ['aid','role'], json_sort => ['aid','role'], json_fields => [
        { field => 'aid',  required => 1, template => 'id' },
        { field => 'role', required => 1, enum => [ keys %CREDIT_TYPE ] },
        { field => 'note', required => 0, maxlength => 250, default => '' },
      ]},
      { post => 'seiyuu', required => 0, template => 'json', json_unique => ['aid','cid'], json_sort => ['aid','cid'], json_fields => [
        { field => 'aid',  required => 1, template => 'id' },
        { field => 'cid',  required => 1, template => 'id' },
        { field => 'note', required => 0, maxlength => 250, default => '' },
      ]},
      { post => 'vnrelations', required => 0, default => '', maxlength => 5000 },
      { post => 'screenshots', required => 0, template => 'json', json_maxitems => 10, json_unique => 'id', json_sort => 'id', json_fields => [
        { field => 'id',   required => 1, template => 'id' },
        { field => 'rid',  required => 1, template => 'id' },
        { field => 'nsfw', required => 1, template => 'uint', enum => [0,1] },
      ]},
      { post => 'editsum',     required => !$nosubmit, template => 'editsum' },
      { post => 'ihid',        required => 0 },
      { post => 'ilock',       required => 0 },
    );
    $frm->{original} = '' if $frm->{original} eq $frm->{title};

    # handle image upload
    $frm->{image} = _uploadimage($self, $frm) if !$nosubmit;

    if(!$nosubmit && !$frm->{_err}) {
      # normalize aliases
      $frm->{alias} = join "\n", map { s/^ +//g; s/ +$//g; $_?($_):() } split /\n/, $frm->{alias};
      # throw error on duplicate/existing aliases
      my %alias = map +(lc($_),1), $frm->{title}, $frm->{original}, map +($_->{title}, $_->{original}), @$r;
      my @e = map $alias{ lc($_) }++ ? "Duplicate alias '$_', or the alias is already used as a release title" : (), split /\n/, $frm->{alias};
      $frm->{_err} = \@e if @e;
    }
    if(!$nosubmit && !$frm->{_err}) {
      # parse and re-sort fields that have multiple representations of the same information
      my $anime = { map +($_=>1), grep /^[0-9]+$/, split /[ ,]+/, $frm->{anime} };
      my $relations = [ map { /^([a-z]+),([0-9]+),([01]),(.+)$/ && (!$vid || $2 != $vid) ? [ $1, $2, $3, $4 ] : () } split /\|\|\|/, $frm->{vnrelations} ];

      # Ensure submitted alias / character IDs exist within database
      my @alist = map $_->{aid}, @{$frm->{credits}}, @{$frm->{seiyuu}};
      my %staff = @alist ? map +($_->{aid}, 1), @{$self->dbStaffGet(aid => \@alist, results => 200)} : ();
      my %vn_chars = map +($_->{id} => 1), @$chars;
      $frm->{credits} = [ grep $staff{$_->{aid}}, @{$frm->{credits}} ];
      $frm->{seiyuu} = [ grep $staff{$_->{aid}} && $vn_chars{$_->{cid}}, @$chars ? @{$frm->{seiyuu}} : () ];

      $frm->{ihid} = $frm->{ihid}?1:0;
      $frm->{ilock} = $frm->{ilock}?1:0;
      $frm->{desc} = $self->bbSubstLinks($frm->{desc});
      $relations = [] if $frm->{ihid};
      $frm->{anime} = join ' ', sort { $a <=> $b } keys %$anime;
      $frm->{vnrelations} = join '|||', map $_->[0].','.$_->[1].','.($_->[2]?1:0).','.$_->[3], sort { $a->[1] <=> $b->[1]} @{$relations};
      $frm->{img_nsfw} = $frm->{img_nsfw} ? 1 : 0;
      $frm->{screenshots} = [ sort { $a->{id} <=> $b->{id} } @{$frm->{screenshots}} ];

      # nothing changed? just redirect
      return $self->resRedirect("/v$vid", 'post') if $vid && !form_compare(\%b4, $frm);

      # perform the edit/add
      my $nrev = $self->dbItemEdit(v => $vid ? ($v->{id}, $v->{rev}) : (undef, undef),
        (map { $_ => $frm->{$_} } qw|title original image alias desc length l_renai l_wikidata editsum img_nsfw ihid ilock credits seiyuu screenshots|),
        anime => [ keys %$anime ],
        relations => $relations,
      );

      # update reverse relations & relation graph
      if(!$vid && $#$relations >= 0 || $vid && $frm->{vnrelations} ne $b4{vnrelations}) {
        my %old = $vid ? (map +($_->{id} => [ $_->{relation}, $_->{official} ]), @{$v->{relations}}) : ();
        my %new = map +($_->[1] => [ $_->[0], $_->[2] ]), @$relations;
        _updreverse($self, \%old, \%new, $nrev->{itemid}, $nrev->{rev});
      }

      return $self->resRedirect("/v$nrev->{itemid}.$nrev->{rev}", 'post');
    }
  }

  !exists $frm->{$_} && ($frm->{$_} = $b4{$_}) for (keys %b4);
  $frm->{editsum} = sprintf 'Reverted to revision v%d.%d', $vid, $rev if $rev && !defined $frm->{editsum};

  my $title = $vid ? "Edit $v->{title}" : 'Add a new visual novel';
  $self->htmlHeader(title => $title, noindex => 1);
  $self->htmlMainTabs('v', $v, 'edit') if $vid;
  $self->htmlEditMessage('v', $v, $title);
  _form($self, $v, $frm, $r, $chars);
  $self->htmlFooter;
}


sub _uploadimage {
  my($self, $frm) = @_;

  if($frm->{_err} || !$self->reqPost('img')) {
    return 0 if !$frm->{image};
    push @{$frm->{_err}}, 'No image with that ID' if !-s imgpath(cv => $frm->{image});
    return $frm->{image};
  }

  # perform some elementary checks
  my $imgdata = $self->reqUploadRaw('img');
  $frm->{_err} = [ 'Image must be in JPEG or PNG format' ] if $imgdata !~ /^(\xff\xd8|\x89\x50)/; # JPG or PNG headers
  $frm->{_err} = [ 'Image is too large, only 5MB allowed' ] if length($imgdata) > 5*1024*1024;
  return undef if $frm->{_err};

  # resize/compress
  my $im = Image::Magick->new;
  $im->BlobToImage($imgdata);
  $im->Set(magick => 'JPEG');
  my($ow, $oh) = ($im->Get('width'), $im->Get('height'));
  my($nw, $nh) = imgsize($ow, $oh, @{$self->{cv_size}});
  $im->Set(background => '#ffffff');
  $im->Set(alpha => 'Remove');
  if($ow != $nw || $oh != $nh) {
    $im->GaussianBlur(geometry => '0.5x0.5');
    $im->Resize(width => $nw, height => $nh);
    $im->UnsharpMask(radius => 0, sigma => 0.75, amount => 0.75, threshold => 0.008);
  }
  $im->Set(quality => 90);

  # Get ID and save
  my $imgid = $self->dbImageAdd(cv => $nw, $nh);
  my $fn = imgpath(cv => $imgid);
  $im->Write($fn);
  chmod 0666, $fn;

  return $imgid;
}


sub _form {
  my($self, $v, $frm, $r, $chars) = @_;
  $self->htmlForm({ frm => $frm, action => $v ? "/old/v$v->{id}/edit" : '/old/v/new', editsum => 1, upload => 1 },
  vn_geninfo => [ 'General info',
    [ input    => short => 'title',     name => 'Title (romaji)', width => 450 ],
    [ input    => short => 'original',  name => 'Original title', width => 450 ],
    [ static   => content => 'The original title of this visual novel, leave blank if it already is in the Latin alphabet.' ],
    [ textarea => short => 'alias',     name => 'Aliases', rows => 4 ],
    [ static   => content =>
        'List of alternative titles or abbreviations. One line for each alias.'
       .' Can include both official (japanese/english) titles and unofficial titles used around net.<br />'
       .' Titles that are listed in the releases should not be added here!' ],
    [ textarea => short => 'desc',      name => 'Description<br /><b class="standout">English please!</b>', rows => 10 ],
    [ static   => content =>
        'Short description of the main story. Please do not include spoilers, and don\'t forget to list'
       .' the source in case you didn\'t write the description yourself. Formatting codes are allowed.' ],
    [ select   => short => 'length',    name => 'Length', options =>
      [ map [ $_ => fmtvnlen $_, 1 ], keys %VN_LENGTH ] ],

    [ input    => short => 'l_wikidata',name => 'Wikidata ID',
        pre   => 'https://www.wikidata.org/wiki/',
        value => $frm->{l_wikidata} ? "Q$frm->{l_wikidata}" : '',
        post  => qq{ (<a href="$self->{url_static}/f/wikidata.png">How to find this</a>)}
    ],
    [ input    => short => 'l_renai',   name => 'Renai.us link', pre => 'http://renai.us/game/', post => '.shtml' ],

    [ input    => short => 'anime',     name => 'Anime' ],
    [ static   => content =>
        'Whitespace separated list of <a href="http://anidb.net/">AniDB</a> anime IDs.'
       .' E.g. "1015 3348" will add <a href="http://anidb.net/a1015">Shingetsutan Tsukihime</a>'
       .' and <a href="http://anidb.net/a3348">Fate/stay night</a> as related anime.<br />'
       .' Note: It can take a few minutes for the anime titles to appear on the VN page.' ],
  ],

  vn_img => [ 'Image', [ static => nolabel => 1, content => sub {
    div class => 'img';
     p 'No image uploaded yet' if !$frm->{image};
     img src => imgurl(cv => $frm->{image}) if $frm->{image};
    end;

    div;
     h2 'Image ID';
     input type => 'text', class => 'text', name => 'image', id => 'image', value => $frm->{image}||'';
     p 'Use a VN image that is already on the server. Set to \'0\' to remove the current image.';
     br; br;

     h2 'Upload new image';
     input type => 'file', class => 'text', name => 'img', id => 'img';
     p 'Preferably the cover of the CD/DVD/package. Image must be in JPEG or PNG format'
      .' and at most 5MB. Images larger than 256x400 will automatically be resized.';
     br; br; br;

     h2 'NSFW';
     input type => 'checkbox', class => 'checkbox', id => 'img_nsfw', name => 'img_nsfw',
       $frm->{img_nsfw} ? (checked => 'checked') : ();
     label class => 'checkbox', for => 'img_nsfw', 'Not Safe For Work';
     p 'Please check this option if the image contains nudity, gore, or is otherwise not safe in a work-friendly environment.';
    end 'div';
  }]],

  vn_staff => [ 'Staff',
    [ json   => short => 'credits' ],
    [ static => nolabel => 1, content => sub {
      # propagate staff ids and names to javascript
      my @alist = map $_->{aid}, @{$frm->{credits}}, @{$frm->{seiyuu}};
      script_json staffdata => {
         map +($_->{aid}, {id => $_->{id}, aid => $_->{aid}, name => $_->{name}}),
         @alist ? @{$self->dbStaffGet(aid => \@alist, results => 200)} : ()
      };
      div class => 'warning';
       lit 'Please check the <a href="/d2#3">staff editing guidelines</a>. You can'
         .' <a href="/s/new">create a new staff entry</a> if it is not in the database yet,'
         .' but please <a href="/s/all">check for aliasses first</a>.';
      end;
      br;
      table; tbody id => 'credits_tbl';
       Tr id => 'credits_loading'; td colspan => '4', 'Loading...'; end;
      end; end;
      h2 'Add staff';
      table; Tr;
       td class => 'tc_staff';
        input id => 'credit_input', type => 'text', class => 'text', style => 'width: 300px'; end;
       td colspan => 3, '';
      end; end;
  }]],

  # Cast tab is only shown for VNs with some characters listed.
  # There's no way to add voice actors in new VN edits since character list
  # would be empty anyway.
  @{$chars} ? (vn_cast => [ 'Cast',
    [ json   => short => 'seiyuu' ],
    [ static => nolabel => 1, content => sub {
      table; tbody id => 'cast_tbl';
       Tr id => 'cast_loading'; td colspan => '4', 'Loading...'; end;
      end; end;
      h2 'Add cast';
      table; Tr;
       td class => 'tc_char';
        Select id =>'cast_chars';
         option value => '', 'Select character';
         for my $i (0..$#$chars) {
           my($name, $id) = @{$chars->[$i]}{qw|name id|};
           # append character IDs to coinciding names
           # (assume dbCharGet sorted characters by name)
           $name .= ' - c'.$id if $name eq ($chars->[$i+1]{name}//'')
                               .. $name ne ($chars->[$i+1]{name}//'');
           option value => $id, $name;
         }
        end;
        txt ' voiced by';
       end;
       td class => 'tc_staff';
        input id => 'cast_input', type => 'text', class => 'text', style => 'width: 300px';
       end;
       td colspan => 2, '';
      end; end;
    }]]) : (),

  vn_rel => [ 'Relations',
    [ hidden   => short => 'vnrelations' ],
    [ static   => nolabel => 1, content => sub {
      h2 'Selected relations';
      table;
       tbody id => 'relation_tbl';
        # to be filled using javascript
       end;
      end;

      h2 'Add relation';
      table;
       Tr id => 'relation_new';
        td class => 'tc_vn';
         input type => 'text', class => 'text';
        end;
        td class => 'tc_rel';
         txt 'is an ';
         input type => 'checkbox', id => 'official', checked => 'checked';
         label for => 'official', 'official';
         Select;
          option value => $_, $VN_RELATION{$_}{txt}
            for (keys %VN_RELATION);
         end;
         txt ' of';
        end;
        td class => 'tc_title', $v ? $v->{title} : '';
        td class => 'tc_add';
         a href => '#', 'add';
        end;
       end;
      end 'table';
    }],
  ],

  vn_scr => [ 'Screenshots', !@$r ? (
    [ static => nolabel => 1, content => 'No releases in the database yet. Screenshots can only be uploaded after a release has been added.' ],
  ) : (
    [ json   => short => 'screenshots' ],
    [ static => nolabel => 1, content => sub {
      my @scr = map $_->{id}, @{$frm->{screenshots}};
      my %scr = map +($_->{id}, [ $_->{width}, $_->{height}]), @scr ? @{$self->dbScreenshotGet(\@scr)} : ();
      my @rels = map [ $_->{id}, sprintf '[%s] %s (r%d)', join(',', @{$_->{languages}}), $_->{title}, $_->{id} ], @$r;
      script_json screendata => {
        size => \%scr,
        rel => \@rels,
        staticurl => $self->{url_static},
      };
      div class => 'warning';
       lit 'Please keep the following in mind when uploading screenshots:<br />'
          .'- Screenshots have to be in the native resolution of the game,<br />'
          .'- Remove any window borders and make sure the image is unmarked,<br />'
          .'- Don\'t only upload event CGs.<br />'
          .'Please read the <a href="/d2#6">guidelines</a> for more information.<br />'
          .'Make sure to submit the form after the upload has finished!';
      end;
      br;
      table class => 'stripe';
       tbody id => 'scr_table', '';
      end;
    }],
  )]

  );
}


# Update reverse relations and regenerate relation graph
# Arguments: %old. %new, vid, rev
#  %old,%new -> { vid => [ relation, official ], .. }
#    from the perspective of vid
#  rev is of the related edit
sub _updreverse {
  my($self, $old, $new, $vid, $rev) = @_;
  my %upd;

  # compare %old and %new
  for (keys %$old, keys %$new) {
    if(exists $$old{$_} and !exists $$new{$_}) {
      $upd{$_} = undef;
    } elsif((!exists $$old{$_} and exists $$new{$_}) || ($$old{$_}[0] ne $$new{$_}[0] || !$$old{$_}[1] != !$$new{$_}[1])) {
      $upd{$_} = [ $VN_RELATION{ $$new{$_}[0] }{reverse}, $$new{$_}[1] ];
    }
  }
  return if !keys %upd;

  # edit all related VNs
  for my $i (keys %upd) {
    my $r = $self->dbVNGetRev(id => $i, what => 'relations')->[0];
    my @newrel = map $_->{id} != $vid ? [ $_->{relation}, $_->{id}, $_->{official} ] : (), @{$r->{relations}};
    push @newrel, [ $upd{$i}[0], $vid, $upd{$i}[1] ] if $upd{$i};
    $self->dbItemEdit(v => $r->{id}, $r->{rev},
      relations => \@newrel,
      editsum => "Reverse relation update caused by revision v$vid.$rev",
      uid => 1, # Multi
    );
  }
}


# peforms a (simple) search and returns the results in XML format
sub vnxml {
  my $self = shift;

  my $q = $self->formValidate({ get => 'q', maxlength => 500 });
  return $self->resNotFound if $q->{_err};
  $q = $q->{q};

  my($list, $np) = $self->dbVNGet(
    $q =~ /^v([1-9]\d*)/ ? (id => $1) : (search => $q),
    results => 10,
    page => 1,
  );

  $self->resHeader('Content-type' => 'text/xml; charset=UTF-8');
  xml;
  tag 'vns', more => $np ? 'yes' : 'no', query => $q;
   for(@$list) {
     tag 'item', id => $_->{id}, $_->{title};
   }
  end;
}


# handles uploading screenshots and fetching information about them
sub scrxml {
  my $self = shift;
  return $self->htmlDenied if !$self->authCan('edit') || $self->reqMethod ne 'POST';

  # upload new screenshot
  my $id = 0;
  my $imgdata = $self->reqUploadRaw('file');
  $id = -2 if !$imgdata;
  $id = -1 if !$id && $imgdata !~ /^(\xff\xd8|\x89\x50)/; # JPG or PNG headers

  # no error? process it
  my($ow, $oh);
  if(!$id) {
    my $im = Image::Magick->new;
    $im->BlobToImage($imgdata);
    $im->Set(background => '#000000');
    $im->Set(alpha => 'Remove');
    $im->Set(magick => 'JPEG');
    $im->Set(quality => 90);
    ($ow, $oh) = ($im->Get('width'), $im->Get('height'));

    $id = $self->dbImageAdd(sf => $ow, $oh);
    my $fn = imgpath(sf => $id);
    $im->Write($fn);
    chmod 0666, $fn;

    # thumbnail
    my($nw, $nh) = imgsize($ow, $oh, @{$self->{scr_size}});
    $im->Thumbnail(width => $nw, height => $nh);
    $im->Set(quality => 90);
    $fn = imgpath(st => $id);
    $im->Write($fn);
    chmod 0666, $fn;
  }

  $self->resHeader('Content-type' => 'text/xml; charset=UTF-8');
  xml;
  tag 'image', id => $id, $id > 0 ? (width => $ow, height => $oh) : (), undef;
}


1;

