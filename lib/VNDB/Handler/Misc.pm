
package VNDB::Handler::Misc;


use strict;
use warnings;
use TUWF ':html', ':xml', 'uri_escape';
use VNDB::Func;
use VNDB::Types;


TUWF::register(
  qr{},                               \&homepage,
  qr{nospam},                         \&nospam,
  qr{xml/prefs\.xml},                 \&prefs,
  qr{opensearch\.xml},                \&opensearch,

  # redirects for old URLs
  qr{u([1-9]\d*)/tags}, sub { $_[0]->resRedirect("/g/links?u=$_[1]", 'perm') },
  qr{(.*[^/]+)/+}, sub { $_[0]->resRedirect("/$_[1]", 'perm') },
  qr{([pv])},      sub { $_[0]->resRedirect("/$_[1]/all", 'perm') },
  qr{v/search},    sub { $_[0]->resRedirect("/v/all?q=".uri_escape($_[0]->reqGet('q')||''), 'perm') },
  qr{notes},       sub { $_[0]->resRedirect('/d8', 'perm') },
  qr{faq},         sub { $_[0]->resRedirect('/d6', 'perm') },
  qr{v([1-9]\d*)/(?:stats|scr)},
    sub { $_[0]->resRedirect("/v$_[1]", 'perm') },
  qr{u/list(/[a-z0]|/all)?},
    sub { my $l = defined $_[1] ? $_[1] : '/all'; $_[0]->resRedirect("/u$l", 'perm') },
);


sub homepage {
  my $self = shift;

  my $title = 'The Visual Novel Database';
  my $desc = 'VNDB.org strives to be a comprehensive database for information about visual novels.';

  my $metadata = {
    'og:type' => 'website',
    'og:title' => $title,
    'og:description' => $desc,
  };

  $self->htmlHeader(title => $title, feeds => 1, metadata => $metadata);

  div class => 'mainbox';
   h1 $title;
   p class => 'description';
    txt $desc;
    br;
    txt 'This website is built as a wiki, meaning that anyone can freely add'
      .' and contribute information to the database, allowing us to create the'
      .' largest, most accurate and most up-to-date visual novel database on the web.';
   end;

   # with filters applied it's signifcantly slower, so special-code the situations with and without filters
   my @vns;
   if($self->authPref('filter_vn')) {
     my $r = $self->filFetchDB(vn => undef, undef, {hasshot => 1, results => 4, sort => 'rand'});
     @vns = map $_->{id}, @$r;
   }
   my $scr = $self->dbScreenshotRandom(@vns);
   p class => 'screenshots';
    for (@$scr) {
      my($w, $h) = imgsize($_->{width}, $_->{height}, @{$self->{scr_size}});
      a href => "/v$_->{vid}", title => $_->{title};
       img src => imgurl(st => $_->{scr}), alt => $_->{title}, width => $w, height => $h;
      end;
    }
   end;
  end 'div';

  table class => 'mainbox threelayout';
   Tr;

    # Recent changes
    td;
     h1;
      a href => '/hist', 'Recent Changes'; txt ' ';
      a href => '/feeds/changes.atom'; cssicon 'feed', 'Atom Feed'; end;
     end;
     my $changes = $self->dbRevisionGet(results => 10, auto => 1);
     ul;
      for (@$changes) {
        li;
         txt "$_->{type}:";
         a href => "/$_->{type}$_->{itemid}.$_->{rev}", title => $_->{ioriginal}||$_->{ititle}, shorten $_->{ititle}, 33;
         lit " by ";
         VNWeb::HTML::user_($_);
        end;
      }
     end;
    end 'td';

    # Announcements
    td;
     my $an = $self->dbThreadGet(type => 'an', sort => 'id', reverse => 1, results => 2);
     h1;
      a href => '/t/an', 'Announcements'; txt ' ';
      a href => '/feeds/announcements.atom'; cssicon 'feed', 'Atom Feed'; end;
     end;
     for (@$an) {
       my $post = $self->dbPostGet(tid => $_->{id}, num => 1)->[0];
       h2;
        a href => "/t$_->{id}", $_->{title};
       end;
       p;
        lit bb2html $post->{msg}, 150;
       end;
     }
    end 'td';

    # Recent posts
    td;
     h1;
      a href => '/t/all', 'Recent Posts'; txt ' ';
      a href => '/feeds/posts.atom'; cssicon 'feed', 'Atom Feed'; end;
     end;
     my $posts = $self->dbThreadGet(what => 'lastpost boardtitles', results => 10, sort => 'lastpost', reverse => 1, notusers => 1);
     ul;
      for (@$posts) {
        my $boards = join ', ', map $BOARD_TYPE{$_->{type}}{txt}.($_->{iid}?' > '.$_->{title}:''), @{$_->{boards}};
        li;
         txt fmtage($_->{lastpost_date}).' ';
         a href => "/t$_->{id}.$_->{count}", title => "Posted in $boards", shorten $_->{title}, 25;
         lit ' by ';
         VNWeb::HTML::user_($_, 'lastpost_');
        end;
      }
     end;
    end 'td';

   end 'tr';
   Tr;

    # Random visual novels
    td;
     h1;
      a href => '/v/rand', 'Random visual novels';
     end;
     my $random = $self->filFetchDB(vn => undef, undef, {results => 10, sort => 'rand'});
     ul;
      for (@$random) {
        li;
         a href => "/v$_->{id}", title => $_->{original}||$_->{title}, shorten $_->{title}, 40;
        end;
      }
     end;
    end 'td';

    # Upcoming releases
    td;
     h1;
      a href => '/r?fil=released-0;o=a;s=released', 'Upcoming releases';
     end;
     my $upcoming = $self->filFetchDB(release => undef, undef, {results => 10, released => 0, what => 'platforms'});
     ul;
      for (@$upcoming) {
        li;
         lit fmtdatestr $_->{released};
         txt ' ';
         cssicon $_, $PLATFORM{$_} for (@{$_->{platforms}});
         cssicon "lang $_", $LANGUAGE{$_} for (@{$_->{languages}});
         txt ' ';
         a href => "/r$_->{id}", title => $_->{original}||$_->{title}, shorten $_->{title}, 30;
        end;
      }
     end;
    end 'td';

    # Just released
    td;
     h1;
      a href => '/r?fil=released-1;o=d;s=released', 'Just released';
     end;
     my $justrel = $self->filFetchDB(release => undef, undef, {results => 10, sort => 'released', reverse => 1, released => 1, what => 'platforms'});
     ul;
      for (@$justrel) {
        li;
         lit fmtdatestr $_->{released};
         txt ' ';
         cssicon $_, $PLATFORM{$_} for (@{$_->{platforms}});
         cssicon "lang $_", $LANGUAGE{$_} for (@{$_->{languages}});
         txt ' ';
         a href => "/r$_->{id}", title => $_->{original}||$_->{title}, shorten $_->{title}, 30;
        end;
      }
     end;
    end 'td';

   end 'tr';
  end 'table';

  $self->htmlFooter;
}


sub nospam {
  my $self = shift;
  $self->htmlHeader(title => 'Could not send form', noindex => 1);

  div class => 'mainbox';
   h1 'Could not send form';
   div class => 'warning';
    h2 'Error';
    p 'The form could not be sent, please make sure you have Javascript enabled in your browser.';
   end;
  end;

  $self->htmlFooter;
}


sub prefs {
  my $self = shift;
  return if !$self->authCheckCode;
  return $self->resNotFound if !$self->authInfo->{id};
  my $f = $self->formValidate(
    { get => 'key',   enum => [qw|filter_vn filter_release|] },
    { get => 'value', required => 0, maxlength => 2000 },
  );
  return $self->resNotFound if $f->{_err};
  $self->authPref($f->{key}, $f->{value});

  # doesn't really matter what we return, as long as it's XML
  $self->resHeader('Content-type' => 'text/xml');
  xml;
  tag 'done', '';
}


sub opensearch {
  my $self = shift;
  my $h = $self->reqBaseURI();
  $self->resHeader('Content-Type' => 'application/opensearchdescription+xml');
  xml;
  tag 'OpenSearchDescription',
    xmlns => 'http://a9.com/-/spec/opensearch/1.1/', 'xmlns:moz' => 'http://www.mozilla.org/2006/browser/search/';
   tag 'ShortName', 'VNDB';
   tag 'LongName', 'VNDB.org visual novel search';
   tag 'Description', 'Search visual vovels on VNDB.org';
   tag 'Image', width => 16, height => 16, type => 'image/x-icon', "$h/favicon.ico";
   tag 'Url', type => 'text/html', method => 'get', template => "$h/v/all?q={searchTerms}", undef;
   tag 'Url', type => 'application/opensearchdescription+xml', rel => 'self', template => "$h/opensearch.xml", undef;
   tag 'Query', role => 'example', searchTerms => 'Tsukihime', undef;
   tag 'moz:SearchForm', "$h/v/all";
  end 'OpenSearchDescription';
}


1;

