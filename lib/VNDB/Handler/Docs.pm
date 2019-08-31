
package VNDB::Handler::Docs;


use strict;
use warnings;
use TUWF ':html';
use VNDB::Func;
use Text::MultiMarkdown 'markdown';


TUWF::register(
  qr{d([1-9]\d*)(?:\.([1-9]\d*))?} => \&page,
  qr{d([1-9]\d*)(?:\.([1-9]\d*))?/edit} => \&edit,
);


sub _html {
  my $content = shift;

  $content =~ s{^:MODERATORS:$}{
    my $l = tuwf->dbUserGet(results => 100, sort => 'id', notperm => tuwf->{default_perm}, what => 'extended');
    my $admin = 0;
    $admin |= $_ for values %{ tuwf->{permissions} };
    '<dl>'.join('', map {
      my $u = $_;
      my $p = $u->{perm} >= $admin ? 'admin' : join ', ', sort map +($u->{perm} &~ tuwf->{default_perm}) & tuwf->{permissions}{$_} ? $_ : (), keys %{ tuwf->{permissions} };
      $p ? sprintf('<dt><a href="/u%d">%s</a></dt><dd>%s</dd>', $_->{id}, $_->{username}, $p) : ()
    } @$l).'</dl>';
  }me;
  $content =~ s{^:SKINCONTRIB:$}{
    my %users;
    push @{$users{ tuwf->{skins}{$_}[1] }}, [ $_, tuwf->{skins}{$_}[0] ]
      for sort { tuwf->{skins}{$a}[0] cmp tuwf->{skins}{$b}[0] } keys %{ tuwf->{skins} };
    my $u = tuwf->dbUserGet(uid => [ keys %users ]);
    '<dl>'.join('', map sprintf('<dt><a href="/u%d">%s</a></dt><dd>%s</dd>',
      $_->{id}, $_->{username}, join(', ', map sprintf('<a href="?skin=%s">%s</a>', $_->[0], $_->[1]), @{$users{$_->{id}}})
    ), @$u).'</dl>';
  }me;

  my $html = markdown $content, {
    strip_metadata => 1,
    img_ids => 0,
    disable_footnotes => 1,
    disable_bibliography => 1,
  };

  # Number sections and turn them into links
  my($sec, $subsec) = (0,0);
  $html =~ s{<h([1-2])[^>]+>(.*?)</h\1>}{
    if($1 == 1) {
      $sec++;
      $subsec = 0;
      qq{<h3><a href="#$sec" name="$sec">$sec. $2</a></h3>}
    } elsif($1 == 2) {
      $subsec++;
      qq|<h4><a href="#$sec.$subsec" name="$sec.$subsec">$sec.$subsec. $2</a></h4>\n|
    }
  }ge;

  # Text::MultiMarkdown doesn't handle fenced code blocks properly. The
  # following solution breaks inline code blocks, but I don't use those anyway.
  $html =~ s/<code>/<pre>/g;
  $html =~ s#</code>#</pre>#g;

  $html
}


sub page {
  my($self, $id, $rev) = @_;

  my $method = $rev ? 'dbDocGetRev' : 'dbDocGet';
  my $d = $self->$method(id => $id, $rev ? ( rev => $rev ) : ())->[0];
  return $self->resNotFound if !$d->{id};

  $self->htmlHeader(title => $d->{title}, noindex => $rev);
  $self->htmlMainTabs(d => $d);
  return if $self->htmlHiddenMessage('d', $d);

  if($rev) {
    my $prev = $rev && $rev > 1 && $self->dbDocGetRev(id => $id, rev => $rev-1)->[0];
    $self->htmlRevision('d', $prev, $d,
      [ title   => 'Title',   diff => 1 ],
      [ content => 'Content', diff => qr/\s+/, short_diff => 1 ],
    );
  }

  div class => 'mainbox';
   h1 $d->{title};
   div class => 'docs';
    ul class => 'index';
     li; b 'Guidelines'; end;
     li; a href => '/d5',  'Editing Guidelines'; end;
     li; a href => '/d2',  'Visual Novels'; end;
     li; a href => '/d15', 'Special Games'; end;
     li; a href => '/d3',  'Releases'; end;
     li; a href => '/d4',  'Producers'; end;
     li; a href => '/d16', 'Staff'; end;
     li; a href => '/d12', 'Characters'; end;
     li; a href => '/d10', 'Tags & Traits'; end;
     li; a href => '/d13', 'Capturing Screenshots'; end;
     li; b 'About VNDB'; end;
     li; a href => '/d9',  'Discussion Board'; end;
     li; a href => '/d6',  'FAQ'; end;
     li; a href => '/d7',  'About Us'; end;
     li; a href => '/d17', 'Privacy Policy & Licensing'; end;
     li; a href => '/d11', 'Database API'; end;
     li; a href => '/d14', 'Database Dumps'; end;
     li; a href => '/d18', 'Database Querying'; end;
     li; a href => '/d8',  'Development'; end;
    end;
    lit _html $d->{content};
   end;
  end;
  $self->htmlFooter;
}


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
      lit _html $frm->{content};
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
