
package VNDB::Handler::VNPage;

use strict;
use warnings;
use TUWF ':html', 'xml_escape';
use VNDB::Func;
use VNDB::Types;
use VNDB::ExtLinks;
use List::Util 'min';
use POSIX 'strftime';


TUWF::register(
  qr{v/rand}                        => \&rand,
  qr{v([1-9]\d*)/releases}          => \&releases,
  qr{v([1-9]\d*)/(chars)}           => \&page,
  qr{v([1-9]\d*)/staff}             => sub { $_[0]->resRedirect("/v$_[1]#staff") },
  qr{v([1-9]\d*)(?:\.([1-9]\d*))?}  => \&page,
);


sub rand {
  my $self = shift;
  $self->resRedirect('/v'.$self->filFetchDB(vn => undef, undef, {results => 1, sort => 'rand'})->[0]{id}, 'temp');
}


# Description of each column, field:
#   id:            Identifier used in URLs
#   sort_field:    Name of the field when sorting
#   what:          Required dbReleaseGet 'what' flag
#   column_string: String to use as column header
#   column_width:  Maximum width (in pixels) of the column in 'restricted width' mode
#   button_string: String to use for the hide/unhide button
#   na_for_patch:  When the field is N/A for patch releases
#   default:       Set when it's visible by default
#   has_data:      Subroutine called with a release object, should return true if the release has data for the column
#   draw:          Subroutine called with a release object, should draw its column contents
my @rel_cols = (
  {    # Title
    id            => 'tit',
    sort_field    => 'title',
    column_string => 'Title',
    draw          => sub { a href => "/r$_[0]{id}", shorten $_[0]{title}, 60 },
  }, { # Type
    id            => 'typ',
    sort_field    => 'type',
    button_string => 'Type',
    default       => 1,
    draw          => sub { cssicon "rt$_[0]{type}", $_[0]{type}; txt '(patch)' if $_[0]{patch} },
  }, { # Languages
    id            => 'lan',
    button_string => 'Language',
    default       => 1,
    has_data      => sub { !!@{$_[0]{languages}} },
    draw          => sub {
      for(@{$_[0]{languages}}) {
        cssicon "lang $_", $LANGUAGE{$_};
        br if $_ ne $_[0]{languages}[$#{$_[0]{languages}}];
      }
    },
  }, { # Publication
    id            => 'pub',
    sort_field    => 'publication',
    column_string => 'Publication',
    column_width  => 70,
    button_string => 'Publication',
    default       => 1,
    what          => 'extended',
    draw          => sub { txt join ', ', $_[0]{freeware} ? 'Freeware' : 'Non-free', $_[0]{patch} ? () : ($_[0]{doujin} ? 'doujin' : 'commercial') },
  }, { # Platforms
    id             => 'pla',
    button_string => 'Platforms',
    default       => 1,
    what          => 'platforms',
    has_data      => sub { !!@{$_[0]{platforms}} },
    draw          => sub {
      for(@{$_[0]{platforms}}) {
        cssicon $_, $PLATFORM{$_};
        br if $_ ne $_[0]{platforms}[$#{$_[0]{platforms}}];
      }
      txt 'Unknown' if !@{$_[0]{platforms}};
    },
  }, { # Media
    id            => 'med',
    column_string => 'Media',
    button_string => 'Media',
    what          => 'media',
    has_data      => sub { !!@{$_[0]{media}} },
    draw          => sub {
      for(@{$_[0]{media}}) {
        txt fmtmedia($_->{medium}, $_->{qty});
        br if $_ ne $_[0]{media}[$#{$_[0]{media}}];
      }
      txt 'Unknown' if !@{$_[0]{media}};
    },
  }, { # Resolution
    id            => 'res',
    sort_field    => 'resolution',
    column_string => 'Resolution',
    button_string => 'Resolution',
    na_for_patch  => 1,
    default       => 1,
    what          => 'extended',
    has_data      => sub { $_[0]{resolution} ne 'unknown' },
    draw          => sub {
      txt $_[0]{resolution} eq 'unknown' ? 'Unknown' : $RESOLUTION{$_[0]{resolution}}{txt};
    },
  }, { # Voiced
    id            => 'voi',
    sort_field    => 'voiced',
    column_string => 'Voiced',
    column_width  => 70,
    button_string => 'Voiced',
    na_for_patch  => 1,
    default       => 1,
    what          => 'extended',
    has_data      => sub { !!$_[0]{voiced} },
    draw          => sub { txt $VOICED{$_[0]{voiced}}{txt} },
  }, { # Animation
    id            => 'ani',
    sort_field    => 'ani_ero',
    column_string => 'Animation',
    column_width  => 110,
    button_string => 'Animation',
    na_for_patch  => '1',
    what          => 'extended',
    has_data      => sub { !!($_[0]{ani_story} || $_[0]{ani_ero}) },
    draw          => sub {
      txt join ', ',
        $_[0]{ani_story} ? "Story: $ANIMATED{$_[0]{ani_story}}{txt}"   :(),
        $_[0]{ani_ero}   ? "Ero scenes: $ANIMATED{$_[0]{ani_ero}}{txt}":();
      txt 'Unknown' if !$_[0]{ani_story} && !$_[0]{ani_ero};
    },
  }, { # Released
    id            => 'rel',
    sort_field    => 'released',
    column_string => 'Released',
    button_string => 'Released',
    default       => 1,
    draw          => sub { lit fmtdatestr $_[0]{released} },
  }, { # Age rating
    id            => 'min',
    sort_field    => 'minage',
    button_string => 'Age rating',
    default       => 1,
    has_data      => sub { $_[0]{minage} != -1 },
    draw          => sub { txt minage $_[0]{minage} },
  }, { # Notes
    id            => 'not',
    sort_field    => 'notes',
    column_string => 'Notes',
    column_width  => 400,
    button_string => 'Notes',
    default       => 1,
    what          => 'extended',
    has_data      => sub { !!$_[0]{notes} },
    draw          => sub { lit bb2html $_[0]{notes} },
  }
);


sub releases {
  my($self, $vid) = @_;

  my $v = $self->dbVNGet(id => $vid)->[0];
  return $self->resNotFound if !$v->{id};

  my $title = "Releases for $v->{title}";
  $self->htmlHeader(title => $title);
  $self->htmlMainTabs('v', $v, 'releases');

  my $f = $self->formValidate(
    map({ get => $_->{id}, required => 0, default => $_->{default}||0, enum => [0,1] }, grep $_->{button_string}, @rel_cols),
    { get => 'cw',   required => 0, default => 0, enum => [0,1] },
    { get => 'o',    required => 0, default => 0, enum => [0,1] },
    { get => 's',    required => 0, default => 'released', enum => [ map $_->{sort_field}, grep $_->{sort_field}, @rel_cols ]},
    { get => 'os',   required => 0, default => 'all',      enum => [ 'all', keys %PLATFORM ] },
    { get => 'lang', required => 0, default => 'all',      enum => [ 'all', keys %LANGUAGE ] },
  );
  return $self->resNotFound if $f->{_err};

  # Get the release info
  my %what = map +($_->{what}, 1), grep $_->{what} && $f->{$_->{id}}, @rel_cols;
  my $r = $self->dbReleaseGet(vid => $vid, what => join(' ', keys %what), sort => $f->{s}, reverse => $f->{o}, results => 200);

  # url generator
  my $url = sub {
    my %u = (%$f, @_);
    return "/v$vid/releases?".join(';', map "$_=$u{$_}", sort keys %u);
  };

  div class => 'mainbox releases_compare';
   h1 $title;

   if(!@$r) {
     td 'We don\'t have any information about releases of this visual novel yet...';
   } else {
     _releases_buttons($self, $f, $url, $r);
   }
  end 'div';

  _releases_table($self, $f, $url, $r) if @$r;
  $self->htmlFooter;
}


sub _releases_buttons {
  my($self, $f, $url, $r) = @_;

  # Column visibility
  p class => 'browseopts';
   a href => $url->($_->{id}, $f->{$_->{id}} ? 0 : 1), $f->{$_->{id}} ? (class => 'optselected') : (), $_->{button_string}
     for (grep $_->{button_string}, @rel_cols);
  end;

  # Misc options
  my $all_selected   = !grep $_->{button_string} && !$f->{$_->{id}}, @rel_cols;
  my $all_unselected = !grep $_->{button_string} &&  $f->{$_->{id}}, @rel_cols;
  my $all_url = sub { $url->(map +($_->{id},$_[0]), grep $_->{button_string}, @rel_cols); };
  p class => 'browseopts';
   a href => $all_url->(1),                  $all_selected   ? (class => 'optselected') : (), 'All on';
   a href => $all_url->(0),                  $all_unselected ? (class => 'optselected') : (), 'All off';
   a href => $url->('cw', $f->{cw} ? 0 : 1), $f->{cw}        ? (class => 'optselected') : (), 'Restrict column width';
  end;

  # Platform/language filters
  my $plat_lang_draw = sub {
    my($row, $option, $txt, $csscat) = @_;
    my %opts = map +($_,1), map @{$_->{$row}}, @$r;
    return if !keys %opts;
    p class => 'browseopts';
     for('all', sort keys %opts) {
       a href => $url->($option, $_), $_ eq $f->{$option} ? (class => 'optselected') : ();
        $_ eq 'all' ? txt 'All' : cssicon "$csscat $_", $txt->{$_};
       end 'a';
     }
    end 'p';
  };
  $plat_lang_draw->('platforms', 'os',  \%PLATFORM, '')     if $f->{pla};
  $plat_lang_draw->('languages', 'lang',\%LANGUAGE, 'lang') if $f->{lan};
}


sub _releases_table {
  my($self, $f, $url, $r) = @_;

  # Apply language and platform filters
  my @r = grep +
    ($f->{os}   eq 'all' || ($_->{platforms} && grep $_ eq $f->{os}, @{$_->{platforms}})) &&
    ($f->{lang} eq 'all' || ($_->{languages} && grep $_ eq $f->{lang}, @{$_->{languages}})), @$r;

  # Figure out which columns to display
  my @col;
  for my $c (@rel_cols) {
    next if $c->{button_string} && !$f->{$c->{id}}; # Hidden by settings
    push @col, $c if !@r || !$c->{has_data} || grep $c->{has_data}->($_), @r; # Must have relevant data
  }

  div class => 'mainbox releases_compare';
   table;

    thead;
     Tr;
      for my $c (@col) {
        td class => 'key';
         txt $c->{column_string} if $c->{column_string};
         for($c->{sort_field} ? (0,1) : ()) {
           my $active = $f->{s} eq $c->{sort_field} && !$f->{o} == !$_;
           a href => $url->(o => $_, s => $c->{sort_field}) if !$active;
            lit $_ ? "\x{25BE}" : "\x{25B4}";
           end 'a' if !$active;
         }
        end 'td';
      }
     end 'tr';
    end 'thead';

    for my $r (@r) {
      Tr;
       # Combine "N/A for patches" columns
       my $cspan = 1;
       for my $c (0..$#col) {
         if($r->{patch} && $col[$c]{na_for_patch} && $c < $#col && $col[$c+1]{na_for_patch}) {
           $cspan++;
           next;
         }
         td $cspan > 1 ? (colspan => $cspan) : (),
            $col[$c]{column_width} && $f->{cw} ? (style => "max-width: $col[$c]{column_width}px") : ();
          if($r->{patch} && $col[$c]{na_for_patch}) {
            txt 'NA for patches';
          } else {
            $col[$c]{draw}->($r);
          }
         end;
         $cspan = 1;
       }
      end;
    }
   end 'table';
  end 'div';
}


sub page {
  my($self, $vid, $rev) = @_;

  my $char = $rev && $rev eq 'chars';
  $rev = undef if $char;

  my $method = $rev ? 'dbVNGetRev' : 'dbVNGet';
  my $v = $self->$method(
    id => $vid,
    what => 'extended anime relations screenshots rating ranking staff'.($rev ? ' seiyuu' : ''),
    $rev ? (rev => $rev) : (),
  )->[0];
  return $self->resNotFound if !$v->{id};

  my $r = $self->dbReleaseGet(vid => $vid, what => 'extended links vns producers platforms media', results => 200);

  enrich_extlinks v => $v;
  enrich_extlinks r => $r;

  my $metadata = {
    'og:title' => $v->{title},
    'og:description' => bb2text $v->{desc},
  };

  if($v->{image} && !$v->{img_nsfw}) {
    $metadata->{'og:image'} = imgurl(cv => $v->{image});
  } elsif(my ($ss) = grep !$_->{nsfw}, @{$v->{screenshots}}) {
    $metadata->{'og:image'} = imgurl(st => $ss->{id});
  }

  $self->htmlHeader(title => $v->{title}, noindex => $rev, metadata => $metadata);
  $self->htmlMainTabs('v', $v);
  return if $self->htmlHiddenMessage('v', $v);

  _revision($self, $v, $rev);

  div class => 'mainbox';
   $self->htmlItemMessage('v', $v);
   h1 $v->{title};
   h2 class => 'alttitle', lang_attr($v->{c_olang}), $v->{original} if $v->{original};

   div class => 'vndetails';

    # image
    div class => 'vnimg';
     if(!$v->{image}) {
       p 'No image uploaded yet';
     } else {
       if($v->{img_nsfw}) {
         p class => 'nsfw_pic';
          input id => 'nsfw_chk', type => 'checkbox', class => 'visuallyhidden', $self->authPref('show_nsfw') ? (checked => 'checked') : ();
          label for => 'nsfw_chk';
           span id => 'nsfw_show';
            txt 'This image has been flagged as Not Safe For Work.';
            br; br;
            span class => 'fake_link', 'Show me anyway';
            br; br;
            txt '(This warning can be disabled in your account)';
           end;
           span id => 'nsfw_hid';
            img src => imgurl(cv => $v->{image}), alt => $v->{title};
            i 'Flagged as NSFW';
           end;
          end;
         end;
       } else {
         img src => imgurl(cv => $v->{image}), alt => $v->{title};
       }
     }
    end 'div'; # /vnimg

    # general info
    table class => 'stripe';
     Tr;
      td class => 'key', 'Title';
      td $v->{title};
     end;
     if($v->{original}) {
       Tr;
        td 'Original title';
        td lang_attr($v->{c_olang}), $v->{original};
       end;
     }
     if($v->{alias}) {
       $v->{alias} =~ s/\n/, /g;
       Tr;
        td 'Aliases';
        td $v->{alias};
       end;
     }
     if($v->{length}) {
       Tr;
        td 'Length';
        td fmtvnlen $v->{length}, 1;
       end;
     }

     _producers($self, $r);
     _relations($self, $v) if @{$v->{relations}};

     if($v->{extlinks}->@*) {
       Tr;
        td 'Links';
        td;
         for($v->{extlinks}->@*) {
           a href => $_->[1], $_->[0];
           txt ', ' if $_ ne $v->{extlinks}[$#{$v->{extlinks}}];
         }
        end;
       end;
     }
     _affiliate_links($self, $r);

     _anime($self, $v) if @{$v->{anime}};

     _useroptions($self, $v, $r) if $self->authInfo->{id};

     Tr class => 'nostripe';
      td class => 'vndesc', colspan => 2;
       h2 'Description';
       p;
        lit $v->{desc} ? bb2html $v->{desc} : '-';
       end;
      end;
     end;

    end 'table';
   end 'div';
   div class => 'clearfloat', style => 'height: 5px', ''; # otherwise the tabs below aren't positioned correctly

   # tags
   my $t = $self->dbTagStats(vid => $v->{id}, sort => 'rating', reverse => 1, minrating => 0, results => 999, state => 2);
   if(@$t) {
     div id => 'tagops';
      for (keys %TAG_CATEGORY) {
        input id => "cat_$_", type => 'checkbox', class => 'visuallyhidden',
          ($self->authInfo->{id} ? $self->authPref("tags_$_") : $_ ne 'ero') ? (checked => 'checked') : ();
        label for => "cat_$_", lc $TAG_CATEGORY{$_};
      }
      my $spoiler = $self->authPref('spoilers') || 0;
      input id => 'tag_spoil_none', type => 'radio', class => 'visuallyhidden', name => 'tag_spoiler', $spoiler == 0 ? (checked => 'checked') : ();
      label for => 'tag_spoil_none', class => 'sec', lc 'Hide spoilers';
      input id => 'tag_spoil_some', type => 'radio', class => 'visuallyhidden', name => 'tag_spoiler', $spoiler == 1 ? (checked => 'checked') : ();
      label for => 'tag_spoil_some', lc 'Show minor spoilers';
      input id => 'tag_spoil_all', type => 'radio', class => 'visuallyhidden', name => 'tag_spoiler', $spoiler == 2 ? (checked => 'checked') : ();
      label for => 'tag_spoil_all', lc 'Spoil me!';

      input id => 'tag_toggle_summary', type => 'radio', class => 'visuallyhidden', name => 'tag_all', $self->authPref('tags_all') ? () : (checked => 'checked');
      label for => 'tag_toggle_summary', class => 'sec', lc 'summary';
      input id => 'tag_toggle_all', type => 'radio', class => 'visuallyhidden', name => 'tag_all', $self->authPref('tags_all') ? (checked => 'checked') : ();
      label for => 'tag_toggle_all', class => 'lst', lc 'all';
      div id => 'vntags';
       my %counts = ();
       for (@$t) {
         my $cnt0 = $counts{$_->{cat} . '0'} || 0;
         my $cnt1 = $counts{$_->{cat} . '1'} || 0;
         my $cnt2 = $counts{$_->{cat} . '2'} || 0;
         my $spoil = $_->{spoiler} > 1.3 ? 2 : $_->{spoiler} > 0.4 ? 1 : 0;
         SWITCH: {
           $counts{$_->{cat} . '2'} = ++$cnt2;
           if ($spoil == 2) { last SWITCH; }
           $counts{$_->{cat} . '1'} = ++$cnt1;
           if ($spoil == 1) { last SWITCH; }
           $counts{$_->{cat} . '0'} = ++$cnt0;
         }
         my $cut = $cnt0 > 15 ? ' cut cut2 cut1 cut0' : ($cnt1 > 15 ? ' cut cut2 cut1' : ($cnt2 > 15 ? ' cut cut2' : ''));
         span class => sprintf 'tagspl%d cat_%s%s', $spoil, $_->{cat}, $cut;
          a href => "/g$_->{id}", style => sprintf('font-size: %dpx', $_->{rating}*3.5+6), $_->{name};
          b class => 'grayedout', sprintf ' %.1f', $_->{rating};
         end;
         txt ' ';
       }
      end;
     end;
   }
  end 'div'; # /mainbox

  my $chars = $self->dbCharGet(vid => $v->{id}, what => "seiyuu vns($v->{id})".($char ? ' extended traits' : ''), results => 500);
  if(@$chars || $self->authCan('edit')) {
    clearfloat; # fix tabs placement when tags are hidden
    div class => 'maintabs';
     ul;
      if(@$chars) {
        li class => (!$char ? ' tabselected' : ''); a href => "/v$v->{id}#main", name => 'main', 'main'; end;
        li class => ($char  ? ' tabselected' : ''); a href => "/v$v->{id}/chars#chars", name => 'chars', 'characters'; end;
      }
     end;
     ul;
      if($self->authCan('edit')) {
        li; a href => "/v$v->{id}/add", 'add release'; end;
        li; a href => "/c/new?vid=$v->{id}", 'add character'; end;
      }
     end;
    end;
  }

  if($char) {
    _chars($self, $chars, $v);
  } else {
    _releases($self, $v, $r);
    _staff($self, $v);
    _charsum($self, $chars, $v);
    _stats($self, $v);
    _screenshots($self, $v, $r) if @{$v->{screenshots}};
  }

  $self->htmlFooter(v2rwjs => $self->authInfo->{id});
}


sub _revision {
  my($self, $v, $rev) = @_;
  return if !$rev;

  my $prev = $rev && $rev > 1 && $self->dbVNGetRev(
    id => $v->{id}, rev => $rev-1, what => 'extended anime relations screenshots staff seiyuu'
  )->[0];

  $self->htmlRevision('v', $prev, $v,
    [ title       => 'Title (romaji)', diff => 1 ],
    [ original    => 'Original title', diff => 1 ],
    [ alias       => 'Alias',          diff => qr/[ ,\n\.]/ ],
    [ desc        => 'Description',    diff => qr/[ ,\n\.]/ ],
    [ length      => 'Length',         serialize => sub { fmtvnlen $_[0] } ],
    [ l_wp        => 'Wikipedia link', htmlize => sub {
      $_[0] ? sprintf '<a href="http://en.wikipedia.org/wiki/%s">%1$s</a>', xml_escape $_[0] : '[empty]'
    }],
    [ l_wikidata  => 'Wikidata ID', htmlize => sub { $_[0] ? sprintf '<a href="https://www.wikidata.org/wiki/Q%d">Q%1$d</a>', $_[0] : '[empty]' } ],
    [ l_encubed   => 'Encubed tag', htmlize => sub {
      $_[0] ? sprintf '<a href="http://novelnews.net/tag/%s/">%1$s</a>', xml_escape $_[0] : '[empty]'
    }],
    [ l_renai     => 'Renai.us link', htmlize => sub {
      $_[0] ? sprintf '<a href="https://renai.us/game/%s">%1$s</a>', xml_escape $_[0] : '[empty]'
    }],
    [ credits     => 'Credits', join => '<br />', split => sub {
      my @r = map sprintf('<a href="/s%d" title="%s">%s</a> [%s]%s', $_->{id},
          xml_escape($_->{original}||$_->{name}), xml_escape($_->{name}), xml_escape($CREDIT_TYPE{$_->{role}}),
          $_->{note} ? ' ['.xml_escape($_->{note}).']' : ''),
        sort { $a->{id} <=> $b->{id} || $a->{role} cmp $b->{role} } @{$_[0]};
      return @r ? @r : ('[empty]');
    }],
    [ seiyuu      => 'Seiyuu', join => '<br />', split => sub {
      my @r = map sprintf('<a href="/s%d" title="%s">%s</a> as <a href="/c%d">%s</a>%s',
          $_->{id}, xml_escape($_->{original}||$_->{name}), xml_escape($_->{name}), $_->{cid}, xml_escape($_->{cname}),
          $_->{note} ? ' ['.xml_escape($_->{note}).']' : ''),
        sort { $a->{id} <=> $b->{id} || $a->{cid} <=> $b->{cid} || $a->{note} cmp $b->{note} } @{$_[0]};
      return @r ? @r : ('[empty]');
    }],
    [ relations   => 'Relations', join => '<br />', split => sub {
      my @r = map sprintf('[%s] %s: <a href="/v%d" title="%s">%s</a>',
        $_->{official} ? 'official' : 'unofficial', $VN_RELATION{$_->{relation}}{txt},
        $_->{id}, xml_escape($_->{original}||$_->{title}), xml_escape shorten $_->{title}, 40
      ), sort { $a->{id} <=> $b->{id} } @{$_[0]};
      return @r ? @r : ('[empty]');
    }],
    [ anime       => 'Anime', join => ', ', split => sub {
      my @r = map sprintf('<a href="http://anidb.net/a%d">a%1$d</a>', $_->{id}), sort { $a->{id} <=> $b->{id} } @{$_[0]};
      return @r ? @r : ('[empty]');
    }],
    [ screenshots => 'Screenshots', join => '<br />', split => sub {
      my @r = map sprintf('[%s] <a href="%s" data-iv="%dx%d">%d</a> (%s)',
        $_->{rid} ? qq|<a href="/r$_->{rid}">r$_->{rid}</a>| : 'no release',
        imgurl(sf => $_->{id}), $_->{width}, $_->{height}, $_->{id},
        $_->{nsfw} ? 'Not safe' : 'Safe'
      ), @{$_[0]};
      return @r ? @r : ('[empty]');
    }],
    [ image       => 'Image', htmlize => sub {
      my $url = imgurl(cv => $_[0]);
      if($_[0]) {
        return $_[1]->{img_nsfw} && !$self->authPref('show_nsfw') ? "<a href=\"$url\">(NSFW)</a>" : "<img src=\"$url\" />";
      } else {
        return 'No image';
      }
    }],
    [ img_nsfw    => 'Image NSFW', serialize => sub { $_[0] ? 'Not safe' : 'Safe' } ],
  );
}


sub _producers {
  my($self, $r) = @_;

  my %lang;
  my @lang = grep !$lang{$_}++, map @{$_->{languages}}, @$r;

  if(grep $_->{developer}, map @{$_->{producers}}, @$r) {
    my %dev = map $_->{developer} ? ($_->{id} => $_) : (), map @{$_->{producers}}, @$r;
    my @dev = sort { $a->{name} cmp $b->{name} } values %dev;
    Tr;
     td 'Developer';
     td;
      for (@dev) {
        a href => "/p$_->{id}", title => $_->{original}||$_->{name}, shorten $_->{name}, 30;
        txt ' & ' if $_ != $dev[$#dev];
      }
     end;
    end;
  }

  if(grep $_->{publisher}, map @{$_->{producers}}, @$r) {
    Tr;
     td 'Publishers';
     td;
      for my $l (@lang) {
        my %p = map $_->{publisher} ? ($_->{id} => $_) : (), map @{$_->{producers}}, grep grep($_ eq $l, @{$_->{languages}}), @$r;
        my @p = sort { $a->{name} cmp $b->{name} } values %p;
        next if !@p;
        cssicon "lang $l", $LANGUAGE{$l};
        for (@p) {
          a href => "/p$_->{id}", title => $_->{original}||$_->{name}, shorten $_->{name}, 30;
          txt ' & ' if $_ != $p[$#p];
        }
        br;
      }
     end;
    end 'tr';
  }
}


sub _relations {
  my($self, $v) = @_;

  my %rel;
  push @{$rel{$_->{relation}}}, $_
    for (sort { $a->{title} cmp $b->{title} } @{$v->{relations}});


  Tr;
   td 'Relations';
   td class => 'relations';
    dl;
     for(sort keys %rel) {
       dt $VN_RELATION{$_}{txt};
       dd;
        for (@{$rel{$_}}) {
          b class => 'grayedout', '[unofficial] ' if !$_->{official};
          a href => "/v$_->{id}", title => $_->{original}||$_->{title}, shorten $_->{title}, 40;
          br;
        }
       end;
     }
    end;
   end;
  end 'tr';
}


sub _anime {
  my($self, $v) = @_;

  Tr;
   td 'Related anime';
   td class => 'anime';
    for (sort { ($a->{year}||9999) <=> ($b->{year}||9999) } @{$v->{anime}}) {
      if(!$_->{lastfetch} || !$_->{year} || !$_->{title_romaji}) {
        b;
         lit sprintf '[no information available at this time: <a href="http://anidb.net/a%d">%1$d</a>]', $_->{id};
        end;
      } else {
        b;
         txt '[';
         a href => "http://anidb.net/a$_->{id}", title => 'AniDB', 'DB';
         # AnimeNFO links seem to be broken at the moment. TODO: Completely remove?
         #if($_->{nfo_id}) {
         #  txt '-';
         #  a href => "http://animenfo.com/animetitle,$_->{nfo_id},a.html", title => 'AnimeNFO', 'NFO';
         #}
         if($_->{ann_id}) {
           txt '-';
           a href => "http://www.animenewsnetwork.com/encyclopedia/anime.php?id=$_->{ann_id}", title => 'Anime News Network', 'ANN';
         }
         txt '] ';
        end;
        abbr title => $_->{title_kanji}||$_->{title_romaji}, shorten $_->{title_romaji}, 50;
        b ' ('.(defined $_->{type} ? $ANIME_TYPE{$_->{type}}{txt}.', ' : '').$_->{year}.')';
        br;
      }
    }
   end;
  end 'tr';
}


sub _useroptions {
  my($self, $v, $r) = @_;

  # Voting option is hidden if nothing has been released yet
  my $minreleased = min grep $_, map $_->{released}, @$r;

  my $labels = tuwf->dbAlli(
    'SELECT l.id, l.label, l.private, uvl.vid IS NOT NULL as assigned
       FROM ulist_labels l
       LEFT JOIN ulist_vns_labels uvl ON uvl.uid = l.uid AND uvl.lbl = l.id AND uvl.vid =', \$v->{id}, '
      WHERE l.uid =', \$self->authInfo->{id},  '
      ORDER BY CASE WHEN l.id < 10 THEN l.id ELSE 10 END, l.label'
  );
  my $lst = tuwf->dbRowi('SELECT vid, vote FROM ulist_vns WHERE uid =', \$self->authInfo->{id}, 'AND vid =', \$v->{id});

  Tr class => 'nostripe';
   td colspan => 2;
    VNWeb::HTML::elm_('UList.VNPage', undef, {
      uid      => 1*$self->authInfo->{id},
      vid      => 1*$v->{id},
      onlist   => $lst->{vid}?\1:\0,
      canvote  => $minreleased && $minreleased < strftime('%Y%m%d', gmtime) ? \1 : \0,
      vote     => fmtvote($lst->{vote}).'',
      labels   => [ map +{ id => 1*$_->{id}, label => $_->{label}, private => $_->{private}?\1:\0 }, @$labels ],
      selected => [ map $_->{id}, grep $_->{assigned}, @$labels ],
    });
   end;
  end;
}


sub _affiliate_links {
  my($self, $r) = @_;

  # If the same shop link has been added to multiple releases, use the 'first' matching type in this list.
  my @type = ('bundle', '', 'partial', 'trial', 'patch');

  # url => [$title, $url, $price, $type]
  my %links;
  for my $rel (@$r) {
    my $type =   $rel->{patch} ? 4 :
       $rel->{type} eq 'trial' ? 3 :
     $rel->{type} eq 'partial' ? 2 :
             @{$rel->{vn}} > 1 ? 0 : 1;

    for my $l (grep $_->[2], $rel->{extlinks}->@*) {
      $links{$l->[1]} = [ @$l, min $type, $links{$l->[1]}[3]||9 ];
    }
  }
  return if !keys %links;

  use utf8;
  Tr id => 'buynow';
   td 'Shops';
   td;
    for my $l (sort { $a->[0] cmp $b->[0] || $a->[2] cmp $b->[2] } values %links) {
      b class => 'standout', '» ';
      a href => $l->[1];
       txt $l->[2];
       b class => 'grayedout', " @ ";
       txt $l->[0];
       b class => 'grayedout', " ($type[$l->[3]])" if $l->[3] != 1;
      end;
      br;
    }
   end;
  end;
}


sub _releases {
  my($self, $v, $r) = @_;

  div class => 'mainbox releases';
   h1 'Releases';
   if(!@$r) {
     p 'We don\'t have any information about releases of this visual novel yet...';
     end;
     return;
   }

   if($self->authInfo->{id}) {
     my $l = $self->dbRListGet(uid => $self->authInfo->{id}, rid => [map $_->{id}, @$r]);
     for my $i (@$l) {
       [grep $i->{rid} == $_->{id}, @$r]->[0]{ulist} = $i;
     }
     div id => 'vnrlist_code', class => 'hidden', $self->authGetCode('/xml/rlist.xml');
   }

   my %lang;
   my @lang = grep !$lang{$_}++, map @{$_->{languages}}, @$r;

   table;
    for my $l (@lang) {
      Tr class => 'lang';
       td colspan => 7;
        cssicon "lang $l", $LANGUAGE{$l};
        txt $LANGUAGE{$l};
       end;
      end;
      for my $rel (grep grep($_ eq $l, @{$_->{languages}}), @$r) {
        Tr;
         td class => 'tc1'; lit fmtdatestr $rel->{released}; end;
         td class => 'tc2', $rel->{minage} < 0 ? '' : minage $rel->{minage};
         td class => 'tc3';
          for (sort @{$rel->{platforms}}) {
            next if $_ eq 'oth';
            cssicon $_, $PLATFORM{$_};
          }
          cssicon "rt$rel->{type}", $rel->{type};
         end;
         td class => 'tc4';
          a href => "/r$rel->{id}", title => $rel->{original}||$rel->{title}, $rel->{title};
          b class => 'grayedout', ' (patch)' if $rel->{patch};
         end;

         td class => 'tc_icons';
          _release_icons($self, $rel);
         end;

         td class => 'tc5';
          if($self->authInfo->{id}) {
            a href => "/r$rel->{id}", id => "rlsel_$rel->{id}", class => 'vnrlsel',
             $rel->{ulist} ? $RLIST_STATUS{ $rel->{ulist}{status} } : '--';
          } else {
            txt ' ';
          }
         end;
         td class => 'tc6';
          $self->releaseExtLinks($rel);
         end;
        end 'tr';
      }
    }
   end 'table';
  end 'div';
}


# Creates an small sized img inside an abbr tag. Used for per-release information icons.
sub _release_icon {
  my($class, $title, $img) = @_;
  abbr class => "release_icons_container release_icon_$class", title => $title;
   img src=> "$TUWF::OBJ->{url_static}/f/$img.svg", class => "release_icons", alt => $title;
  end;
}

sub _release_icons {
  my($self, $rel) = @_;

  # Voice column
  my $voice = $rel->{voiced};
  _release_icon $VOICED{$voice}{icon}, $VOICED{$voice}{txt}, 'voiced' if $voice;

  # Animations columns
  my $story_anim = $rel->{ani_story};
  _release_icon $ANIMATED{$story_anim}{story_icon}, "Story: $ANIMATED{$story_anim}{txt}", 'story_animated' if $story_anim;

  my $ero_anim = $rel->{ani_ero};
  _release_icon $ANIMATED{$ero_anim}{ero_icon}, "Ero: $ANIMATED{$ero_anim}{txt}", 'ero_animated' if $ero_anim;

  # Cost column
  _release_icon 'freeware', 'Freeware', 'free' if $rel->{freeware};
  _release_icon 'nonfree', 'Non-free', 'nonfree' unless $rel->{freeware};

  # Publisher type column
  if(!$rel->{patch}) {
    _release_icon 'doujin', 'Doujin', 'doujin' if $rel->{doujin};
    _release_icon 'commercial', 'Commercial', 'commercial' unless $rel->{doujin};
  }

  # Resolution column
  my $resolution = $rel->{resolution};
  if($resolution ne 'unknown') {
    my $resolution_type = $resolution eq 'nonstandard' ? 'custom' : $RESOLUTION{$resolution}{cat} eq 'widescreen' ? '16-9' : '4-3';
    # Ugly workaround: PC-98 has non-square pixels, thus not widescreen
    $resolution_type = '4-3' if $resolution_type eq '16-9' && grep $_ eq 'p98', @{$rel->{platforms}};
    _release_icon "res$resolution_type", $RESOLUTION{$resolution}{txt}, "resolution_$resolution_type";
  }

  # Media column
  if(@{$rel->{media}}) {
    my $icon = $MEDIUM{ $rel->{media}[0]{medium} }{icon};
    my $media_detail = join ', ', map fmtmedia($_->{medium}, $_->{qty}), @{$rel->{media}};
    _release_icon $icon, $media_detail, $icon;
  }

  _release_icon 'uncensor', 'Uncensored', 'uncensor' if $rel->{uncensored};

  # Notes column
  _release_icon 'notes', bb2text($rel->{notes}), 'notes' if $rel->{notes};
}


sub _screenshots {
  my($self, $v, $r) = @_;

  input id => 'nsfwhide_chk', type => 'checkbox', class => 'visuallyhidden', $self->authPref('show_nsfw') ? (checked => 'checked') : ();
  div class => 'mainbox', id => 'screenshots';

   if(grep $_->{nsfw}, @{$v->{screenshots}}) {
     p class => 'nsfwtoggle';
      txt 'Showing ';
      i id => 'nsfwshown', scalar grep(!$_->{nsfw}, @{$v->{screenshots}});
      span class => 'nsfw', scalar @{$v->{screenshots}};
      txt sprintf ' out of %d screenshot%s. ', scalar @{$v->{screenshots}}, @{$v->{screenshots}} == 1 ? '' : 's';
      label for => 'nsfwhide_chk', class => 'fake_link', 'show/hide NSFW';
     end;
   }

   h1 'Screenshots';

   for my $rel (@$r) {
     my @scr = grep $_->{rid} && $rel->{id} == $_->{rid}, @{$v->{screenshots}};
     next if !@scr;
     p class => 'rel';
      cssicon "lang $_", $LANGUAGE{$_} for (@{$rel->{languages}});
      cssicon $_, $PLATFORM{$_} for (@{$rel->{platforms}});
      a href => "/r$rel->{id}", $rel->{title};
     end;
     div class => 'scr';
      for (@scr) {
        my($w, $h) = imgsize($_->{width}, $_->{height}, @{$self->{scr_size}});
        a href => imgurl(sf => $_->{id}),
          class => sprintf('scrlnk%s', $_->{nsfw} ? ' nsfw':''),
          'data-iv' => "$_->{width}x$_->{height}:scr";
         img src => imgurl(st => $_->{id}),
           width => $w, height => $h, alt => "Screenshot #$_->{id}";
        end;
      }
     end;
   }
  end 'div';
}


sub _stats {
  my($self, $v) = @_;

  my $stats = $self->dbVoteStats(vid => $v->{id}, 1);
  div class => 'mainbox';
   h1 'User stats';
   if(!grep $_->[0] > 0, @$stats) {
     p 'Nobody has voted on this visual novel yet...';
   } else {
     $self->htmlVoteStats(v => $v, $stats);
   }
  end;
}


sub _charspoillvl {
  my($vid, $c) = @_;
  my $minspoil = 5;
  $minspoil = $_->{vid} == $vid && $_->{spoil} < $minspoil ? $_->{spoil} : $minspoil
    for(@{$c->{vns}});
  return $minspoil;
}


sub _chars {
  my($self, $l, $v) = @_;
  return if !@$l;
  my %done;
  my %rol;
  for my $r (keys %CHAR_ROLE) {
    $rol{$r} = [ grep grep($_->{role} eq $r, @{$_->{vns}}) && !$done{$_->{id}}++, @$l ];
  }
  div class => 'charops', id => 'charops';
   $self->charOps(1, 'chars');
   for my $r (keys %CHAR_ROLE) {
     next if !@{$rol{$r}};
     div class => 'mainbox';
      h1 $CHAR_ROLE{$r}{ @{$rol{$r}} > 1 ? 'plural' : 'txt' };
      $self->charTable($_, 1, $_ != $rol{$r}[0], 1, _charspoillvl $v->{id}, $_) for (@{$rol{$r}});
     end;
   }
  end;
}


sub _charsum {
  my($self, $l, $v) = @_;
  return if !@$l;

  my(@l, %done, $has_spoilers);
  for my $r (keys %CHAR_ROLE) {
    last if $r eq 'appears';
    for (grep grep($_->{role} eq $r, @{$_->{vns}}) && !$done{$_->{id}}++, @$l) {
      $_->{role} = $r;
      $has_spoilers = $has_spoilers || _charspoillvl $v->{id}, $_;
      push @l, $_;
    }
  }

  div class => 'mainbox charsum summarize charops', 'data-summarize-height' => 200, id => 'charops';
   $self->charOps(0, 'charsum') if $has_spoilers;
   h1 'Character summary';
   div class => 'charsum_list';
    for my $c (@l) {
      div class => 'charsum_bubble'.($has_spoilers ? ' '.charspoil(_charspoillvl $v->{id}, $c) : '');
       div class => 'name';
        i $CHAR_ROLE{$c->{role}}{txt};
        cssicon "gen $c->{gender}", $GENDER{$c->{gender}} if $c->{gender} ne 'unknown';
        a href => "/c$c->{id}", title => $c->{original}||$c->{name}, $c->{name};
       end;
       if(@{$c->{seiyuu}}) {
         div class => 'actor';
          txt 'Voiced by';
          @{$c->{seiyuu}} > 1 ? br : txt ' ';
          for my $s (sort { $a->{name} cmp $b->{name} } @{$c->{seiyuu}}) {
            a href => "/s$s->{sid}", title => $s->{original}||$s->{name}, $s->{name};
            b class => 'grayedout', $s->{note} if $s->{note};
            br;
          }
         end;
       }
      end;
    }
   end;
  end;
}


sub _staff {
  my ($self, $v) = @_;
  return if !@{$v->{credits}};

  div class => 'mainbox staff summarize', 'data-summarize-height' => 200, id => 'staff';
   h1 'Staff';
   for my $r (keys %CREDIT_TYPE) {
     my @s = grep $_->{role} eq $r, @{$v->{credits}};
     next if !@s;
     ul;
      li; b $CREDIT_TYPE{$r}; end;
      for(@s) {
        li;
         a href => "/s$_->{id}", title => $_->{original}||$_->{name}, $_->{name};
         b class => 'grayedout', $_->{note} if $_->{note};
        end;
      }
     end;
   }
   clearfloat;
  end;
}

1;

