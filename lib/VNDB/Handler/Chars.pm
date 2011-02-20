
package VNDB::Handler::Chars;

use strict;
use warnings;
use TUWF ':html';
use VNDB::Func;


TUWF::register(
  qr{c([1-9]\d*)(?:\.([1-9]\d*))?} => \&page,
  qr{c(?:([1-9]\d*)(?:\.([1-9]\d*))?/edit|/new)}
    => \&edit,
);


sub page {
  my($self, $id, $rev) = @_;

  my $r = $self->dbCharGet(
    id => $id,
    what => 'extended traits'.($rev ? ' changes' : ''),
    $rev ? ( rev => $rev ) : ()
  )->[0];
  return $self->resNotFound if !$r->{id};

  $self->htmlHeader(title => $r->{name});
  $self->htmlMainTabs(c => $r);
  return if $self->htmlHiddenMessage('c', $r);

  if($rev) {
    my $prev = $rev && $rev > 1 && $self->dbCharGet(id => $id, rev => $rev-1, what => 'changes extended traits')->[0];
    $self->htmlRevision('c', $prev, $r,
      [ name      => diff => 1 ],
      [ original  => diff => 1 ],
      [ alias     => diff => qr/[ ,\n\.]/ ],
      [ desc      => diff => qr/[ ,\n\.]/ ],
      [ b_month   => serialize => sub { $_[0]||mt '_revision_empty' } ],
      [ b_day     => serialize => sub { $_[0]||mt '_revision_empty' } ],
      [ s_bust    => serialize => sub { $_[0]||mt '_revision_empty' } ],
      [ s_waist   => serialize => sub { $_[0]||mt '_revision_empty' } ],
      [ s_hip     => serialize => sub { $_[0]||mt '_revision_empty' } ],
      [ height    => serialize => sub { $_[0]||mt '_revision_empty' } ],
      [ weight    => serialize => sub { $_[0]||mt '_revision_empty' } ],
      [ bloodt    => serialize => sub { mt "_bloodt_$_[0]" } ],
      [ image     => htmlize => sub {
        return $_[0] > 0 ? sprintf '<img src="%s/ch/%02d/%d.jpg" />', $self->{url_static}, $_[0]%100, $_[0]
          : mt $_[0] < 0 ? '_chdiff_image_proc' : '_chdiff_image_none';
      }],
      [ traits    => join => '<br />', split => sub {
        map sprintf('%s<a href="/i%d">%s</a> (%s)', $_->{group}?qq|<b class="grayedout">$_->{groupname} / </b> |:'',
            $_->{tid}, $_->{name}, mt("_spoil_$_->{spoil}")),
          sort { ($a->{groupname}||$a->{name}) cmp ($b->{groupname}||$b->{name}) || $a->{name} cmp $b->{name} } @{$_[0]}
      }],
    );
  }

  div class => 'mainbox';
   $self->htmlItemMessage('c', $r);
   h1 $r->{name};
   h2 class => 'alttitle', $r->{original} if $r->{original};

   div class => 'chardetails';

    # image
    div class => 'charimg';
     if(!$r->{image}) {
       p mt '_charp_noimg';
     } elsif($r->{image} < 0) {
       p mt '_charp_imgproc';
     } else {
       img src => sprintf('%s/ch/%02d/%d.jpg', $self->{url_static}, $r->{image}%100, $r->{image}),
         alt => $r->{name} if $r->{image};
     }
    end 'div';

    # info table
    table;
     my $i = 0;
     Tr ++$i % 2 ? (class => 'odd') : ();
      td class => 'key', mt '_charp_name';
      td $r->{name};
     end;
     if($r->{original}) {
       Tr ++$i % 2 ? (class => 'odd') : ();
        td mt '_charp_original';
        td $r->{original};
       end;
     }
     if($r->{alias}) {
       $r->{alias} =~ s/\n/, /g;
       Tr ++$i % 2 ? (class => 'odd') : ();
        td mt '_charp_alias';
        td $r->{alias};
       end;
     }
     if($r->{height} || $r->{s_bust} || $r->{s_waist} || $r->{s_hip}) {
       Tr ++$i % 2 ? (class => 'odd') : ();
        td mt '_charp_meas';
        td join ', ',
          $r->{s_bust} || $r->{s_waist} || $r->{s_hip} ? mt('_charp_meas_bwh', $r->{s_bust}||'??', $r->{s_waist}||'??', $r->{s_hip}||'??') : (),
          $r->{height} ? mt('_charp_meas_h', $r->{height}) : ();
       end;
     }
     if($r->{weight}) {
       Tr ++$i % 2 ? (class => 'odd') : ();
        td mt '_charp_weight';
        td "$r->{weight} kg";
       end;
     }
     if($r->{b_month} && $r->{b_day}) {
       Tr ++$i % 2 ? (class => 'odd') : ();
        td mt '_charp_bday';
        td sprintf '%02d-%02d', $r->{b_month}, $r->{b_day};
       end;
     }
     if($r->{bloodt} ne 'unknown') {
       Tr ++$i % 2 ? (class => 'odd') : ();
        td mt '_charp_bloodt';
        td mt "_bloodt_$r->{bloodt}";
       end;
     }

     # traits
     # TODO: handle spoilers!
     my %groups;
     push @{$groups{ $_->{group}||$_->{tid} }}, $_ for(sort { $a->{name} cmp $b->{name} } @{$r->{traits}});
     for my $g (sort { ($groups{$a}[0]{groupname}||$groups{$a}[0]{name}) cmp ($groups{$a}[0]{groupname}||$groups{$a}[0]{name}) } keys %groups) {
       Tr ++$i % 2 ? (class => 'odd') : ();
        td; a href => '/i'.($groups{$g}[0]{group}||$groups{$g}[0]{tid}), $groups{$g}[0]{groupname} || $groups{$g}[0]{name}; end;
        td;
         for (@{$groups{$g}}) {
           txt ', ' if $_->{tid} != $groups{$g}[0]{tid};
           a href => "/i$_->{tid}", $_->{name};
         }
        end;
       end;
     }

     # description
     if($r->{desc}) {
       Tr;
        td class => 'chardesc', colspan => 2;
         h2 mt '_charp_description';
         p;
          lit bb2html $r->{desc};
         end;
        end;
       end;
     }

    end 'table';

   end;
   clearfloat;

  end;
  $self->htmlFooter;
}



sub edit {
  my($self, $id, $rev) = @_;

  my $r = $id && $self->dbCharGet(id => $id, what => 'changes extended traits', $rev ? (rev => $rev) : ())->[0];
  return $self->resNotFound if $id && !$r->{id};
  $rev = undef if !$r || $r->{cid} == $r->{latest};

  return $self->htmlDenied if !$self->authCan('charedit')
    || $id && ($r->{locked} && !$self->authCan('lock') || $r->{hidden} && !$self->authCan('del'));

  my %b4 = !$id ? () : (
    (map +($_ => $r->{$_}), qw|name original alias desc image ihid ilock s_bust s_waist s_hip height weight bloodt|),
    bday => $r->{b_month} ? sprintf('%02d-%02d', $r->{b_month}, $r->{b_day}) : '',
    traits => join(' ', map sprintf('%d-%d', $_->{tid}, $_->{spoil}), @{$r->{traits}}),
  );
  my $frm;

  if($self->reqMethod eq 'POST') {
    return if !$self->authCheckCode;
    $frm = $self->formValidate(
      { post => 'name',          maxlength => 200 },
      { post => 'original',      required  => 0, maxlength => 200,  default => '' },
      { post => 'alias',         required  => 0, maxlength => 500,  default => '' },
      { post => 'desc',          required  => 0, maxlength => 5000, default => '' },
      { post => 'image',         required  => 0, default => 0,  template => 'int' },
      { post => 'bday',          required  => 0, default => '', regex => [ qr/^\d{2}-\d{2}$/, mt('_chare_form_bday_err') ] },
      { post => 's_bust',        required  => 0, default => 0, template => 'int' },
      { post => 's_waist',       required  => 0, default => 0, template => 'int' },
      { post => 's_hip',         required  => 0, default => 0, template => 'int' },
      { post => 'height',        required  => 0, default => 0, template => 'int' },
      { post => 'weight',        required  => 0, default => 0, template => 'int' },
      { post => 'bloodt',        required  => 0, default => 'unknown', enum => $self->{blood_types} },
      { post => 'traits',        required  => 0, default => '', regex => [ qr/^(?:[1-9]\d*-[0-2])(?: +[1-9]\d*-[0-2])*$/, 'Incorrect trait format.' ] },
      { post => 'editsum',       required  => 0, maxlength => 5000 },
      { post => 'ihid',          required  => 0 },
      { post => 'ilock',         required  => 0 },
    );
    push @{$frm->{_err}}, 'badeditsum' if !$frm->{editsum} || lc($frm->{editsum}) eq lc($frm->{desc});

    # handle image upload
    $frm->{image} = _uploadimage($self, $r, $frm);

    if(!$frm->{_err}) {
      # parse and normalize
      my @traits = sort { $a->[0] <=> $b->[0] } map /^(\d+)-(\d+)$/&&[$1,$2], split / /, $frm->{traits};
      $frm->{traits} = join(' ', map sprintf('%d-%d', @$_), @traits);
      $frm->{ihid}   = $frm->{ihid} ?1:0;
      $frm->{ilock}  = $frm->{ilock}?1:0;

      # check for changes
      return $self->resRedirect("/c$id", 'post')
        if $id && !grep $frm->{$_} ne $b4{$_}, keys %b4;

      # modify for dbCharRevisionInsert
      ($frm->{b_month}, $frm->{b_day}) = delete($frm->{bday}) =~ /^(\d{2})-(\d{2})$/ ? ($1, $2) : (0, 0);
      $frm->{traits} = \@traits;

      my $nrev = $self->dbItemEdit(c => $id ? $r->{cid} : undef, %$frm);
      return $self->resRedirect("/c$nrev->{iid}.$nrev->{rev}", 'post');
    }
  }

  $frm->{$_} //= $b4{$_} for keys %b4;
  $frm->{editsum} //= sprintf 'Reverted to revision c%d.%d', $id, $rev if $rev;

  my $title = mt $r ? ('_chare_title_edit', $r->{name}) : '_chare_title_add';
  $self->htmlHeader(title => $title, noindex => 1);
  $self->htmlMainTabs('c', $r, 'edit') if $r;
  $self->htmlEditMessage('c', $r, $title);
  $self->htmlForm({ frm => $frm, action => $r ? "/c$id/edit" : '/c/new', editsum => 1, upload => 1 },
  chare_geninfo => [ mt('_chare_form_generalinfo'),
    [ input  => name => mt('_chare_form_name'), short => 'name' ],
    [ input  => name => mt('_chare_form_original'), short => 'original' ],
    [ static => content => mt('_chare_form_original_note') ],
    [ text   => name => mt('_chare_form_alias'), short => 'alias', rows => 3 ],
    [ static => content => mt('_chare_form_alias_note') ],
    [ text   => name => mt('_chare_form_desc').'<br /><b class="standout">'.mt('_inenglish').'</b>', short => 'desc', rows => 6 ],
    [ input  => name => mt('_chare_form_bday'),  short => 'bday',   width => 100, post => ' '.mt('_chare_form_bday_fmt')  ],
    [ input  => name => mt('_chare_form_bust'),  short => 's_bust', width => 50, post => ' cm' ],
    [ input  => name => mt('_chare_form_waist'), short => 's_waist',width => 50, post => ' cm'  ],
    [ input  => name => mt('_chare_form_hip'),   short => 's_hip',  width => 50, post => ' cm'  ],
    [ input  => name => mt('_chare_form_height'),short => 'height', width => 50, post => ' cm' ],
    [ input  => name => mt('_chare_form_weight'),short => 'weight', width => 50, post => ' kg' ],
    [ select => name => mt('_chare_form_bloodt'),short => 'bloodt', options => [
       map [ $_, mt("_bloodt_$_") ], @{$self->{blood_types}} ] ],
  ],

  chare_img => [ mt('_chare_image'), [ static => nolabel => 1, content => sub {
    div class => 'img';
     p mt '_chare_image_none' if !$frm->{image};
     p mt '_chare_image_processing' if $frm->{image} && $frm->{image} < 0;
     img src => sprintf("%s/ch/%02d/%d.jpg", $self->{url_static}, $frm->{image}%100, $frm->{image}) if $frm->{image} && $frm->{image} > 0;
    end;

    div;
     h2 mt '_chare_image_id';
     input type => 'text', class => 'text', name => 'image', id => 'image', value => $frm->{image};
     p mt '_chare_image_id_msg';
     br; br;

     h2 mt '_chare_image_upload';
     input type => 'file', class => 'text', name => 'img', id => 'img';
     p mt('_chare_image_upload_msg');
    end;
  }]],

  chare_traits => [ mt('_chare_traits'),
    [ input => name => 'Traits (test)', short => 'traits' ],
  ]);
  $self->htmlFooter;
}


sub _uploadimage {
  my($self, $c, $frm) = @_;
  return $c ? $frm->{image} : 0 if $frm->{_err} || !$self->reqPost('img');

  # perform some elementary checks
  my $imgdata = $self->reqUploadRaw('img');
  $frm->{_err} = [ 'noimage' ] if $imgdata !~ /^(\xff\xd8|\x89\x50)/; # JPG or PNG headers
  $frm->{_err} = [ 'toolarge' ] if length($imgdata) > 1024*1024;
  return undef if $frm->{_err};

  # get image ID and save it, to be processed by Multi
  my $imgid = $self->dbCharImageId;
  my $fn = sprintf '%s/static/ch/%02d/%d.jpg', $VNDB::ROOT, $imgid%100, $imgid;
  $self->reqSaveUpload('img', $fn);
  chmod 0666, $fn;

  return -1*$imgid;
}


1;

