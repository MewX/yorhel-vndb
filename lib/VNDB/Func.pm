
package VNDB::Func;

use strict;
use warnings;
use TUWF ':html', 'kv_validate', 'xml_escape';
use Exporter 'import';
use POSIX 'strftime', 'ceil', 'floor';
use JSON::XS;
use VNDBUtil;
use VNDB::Types;
use VNDB::BBCode;
our @EXPORT = (@VNDBUtil::EXPORT, 'bb2html', 'bb2text', qw|
  clearfloat cssicon tagscore minage fil_parse fil_serialize parenttags
  childtags charspoil imgpath imgurl
  fmtvote fmtmedia fmtvnlen fmtage fmtdatestr fmtdate fmtuser fmtrating fmtspoil
  json_encode json_decode script_json
  form_compare
|);


# three ways to represent the same information
our $fil_escape = '_ !"#$%&\'()*+,-./:;<=>?@[\]^`{}~';
our @fil_escape = split //, $fil_escape;
our %fil_escape = map +($fil_escape[$_], sprintf '%02d', $_), 0..$#fil_escape;


# Clears a float, to make sure boxes always have the correct height
sub clearfloat {
  div class => 'clearfloat', '';
}


# Draws a CSS icon, arguments: class, title
sub cssicon {
  abbr class => "icons $_[0]", title => $_[1];
   lit '&#xa0;';
  end;
}


# Tag score in html tags, argument: score, users
sub tagscore {
  my $s = shift;
  div class => 'taglvl', style => sprintf('width: %.0fpx', ($s-floor($s))*10), ' ' if $s < 0 && $s-floor($s) > 0;
  for(-3..3) {
    div(class => "taglvl taglvl0", sprintf '%.1f', $s), next if !$_;
    if($_ < 0) {
      if($s > 0 || floor($s) > $_) {
        div class => "taglvl taglvl$_", ' ';
      } elsif(floor($s) != $_) {
        div class => "taglvl taglvl$_ taglvlsel", ' ';
      } else {
        div class => "taglvl taglvl$_ taglvlsel", style => sprintf('width: %.0fpx', 10-($s-$_)*10), ' ';
      }
    } else {
      if($s < 0 || ceil($s) < $_) {
        div class => "taglvl taglvl$_", ' ';
      } elsif(ceil($s) != $_) {
        div class => "taglvl taglvl$_ taglvlsel", ' ';
      } else {
        div class => "taglvl taglvl$_ taglvlsel", style => sprintf('width: %.0fpx', 10-($_-$s)*10), ' ';
      }
    }
  }
  div class => 'taglvl', style => sprintf('width: %.0fpx', (ceil($s)-$s)*10), ' ' if $s > 0 && ceil($s)-$s > 0;
}


sub minage {
  my($a, $ex) = @_;
  $a = $AGE_RATING{$a};
  $ex && $a->{ex} ? "$a->{txt} (e.g. $a->{ex})" : $a->{txt}
}


# arguments: $filter_string, @allowed_keys
sub fil_parse {
  my $str = shift;
  my %keys = map +($_,1), @_;
  my %r;
  for (split /\./, $str) {
    next if !/^([a-z0-9_]+)-([a-zA-Z0-9_~\x81-\x{ffffff}]+)$/ || !$keys{$1};
    my($f, $v) = ($1, $2);
    my @v = split /~/, $v;
    s/_([0-9]{2})/$1 > $#fil_escape ? '' : $fil_escape[$1]/eg for(@v);
    $r{$f} = @v > 1 ? \@v : $v[0]
  }
  return \%r;
}


sub fil_serialize {
  my $fil = shift;
  my $e = qr/([\Q$fil_escape\E])/;
  return join '.', map {
    my @v = ref $fil->{$_} ? @{$fil->{$_}} : ($fil->{$_});
    s/$e/_$fil_escape{$1}/g for(@v);
    $_.'-'.join '~', @v
  } grep defined($fil->{$_}), keys %$fil;
}


# generates a parent tags/traits listing
sub parenttags {
  my($t, $index, $type) = @_;
  p;
   my @p = _parenttags(@{$t->{parents}});
   for my $p (@p ? @p : []) {
     a href => "/$type", $index;
     for (reverse @$p) {
       txt ' > ';
       a href => "/$type$_->{id}", $_->{name};
     }
     txt " > $t->{name}";
     br;
   }
  end 'p';
}

# arg: tag/trait hashref
# returns: [ [ tag1, tag2, tag3 ], [ tag1, tag2, tag5 ] ]
sub _parenttags {
  my @r;
  for my $t (@_) {
    for (@{$t->{'sub'}}) {
      push @r, [ $t, @$_ ] for _parenttags($_);
    }
    push @r, [$t] if !@{$t->{'sub'}};
  }
  return @r;
}


# a child tags/traits box
sub childtags {
  my($self, $title, $type, $t, $order) = @_;

  div class => 'mainbox';
   h1 $title;
   ul class => 'tagtree';
    for my $p (sort { !$order ? @{$b->{'sub'}} <=> @{$a->{'sub'}} : $a->{$order} <=> $b->{$order} } @{$t->{childs}}) {
      li;
       a href => "/$type$p->{id}", $p->{name};
       b class => 'grayedout', " ($p->{c_items})" if $p->{c_items};
       end, next if !@{$p->{'sub'}};
       ul;
        for (0..$#{$p->{'sub'}}) {
          last if $_ >= 5 && @{$p->{'sub'}} > 6;
          li;
           txt '> ';
           a href => "/$type$p->{sub}[$_]{id}", $p->{'sub'}[$_]{name};
           b class => 'grayedout', " ($p->{sub}[$_]{c_items})" if $p->{'sub'}[$_]{c_items};
          end;
        }
        if(@{$p->{'sub'}} > 6) {
          my $c = @{$p->{'sub'}}-5;
          li;
           txt '> ';
           a href => "/$type$p->{id}", style => 'font-style: italic',
             sprintf '%d more %s%s', $c, $type eq 'g' ? 'tag' : 'trait', $c==1 ? '' : 's';
          end;
        }
       end;
      end 'li';
    }
   end 'ul';
   clearfloat;
   br;
  end 'div';
}


# generates the class elements for character spoiler hiding
sub charspoil {
  return "charspoil charspoil_$_[0]";
}


# generates a local path to an image in static/
sub imgpath { # <type>, <id>
  return sprintf '%s/static/%s/%02d/%d.jpg', $TUWF::OBJ->{root}, $_[0], $_[1]%100, $_[1];
}


# generates a URL for an image in static/
sub imgurl {
  return sprintf '%s/%s/%02d/%d.jpg', $TUWF::OBJ->{url_static}, $_[0], $_[1]%100, $_[1];
}


# Formats a vote number.
sub fmtvote {
  return !$_[0] ? '-' : $_[0] % 10 == 0 ? $_[0]/10 : sprintf '%.1f', $_[0]/10;
}

# Formats a media string ("1 CD", "2 CDs", "Internet download", etc)
sub fmtmedia {
  my($med, $qty) = @_;
  $med = $MEDIUM{$med};
  join ' ',
    ($med->{qty} ? ($qty) : ()),
    $med->{ $med->{qty} && $qty > 1 ? 'plural' : 'txt' };
}

# Formats a VN length (xtra = 1 for time indication, 2 for examples)
sub fmtvnlen {
  my($len, $xtra) = @_;
  $len = $VN_LENGTH{$len};
  $len->{txt}.
    ($xtra && $xtra == 1 && $len->{time} ? " ($len->{time})" : '').
    ($xtra && $xtra == 2 && $len->{example} ? " ($len->{example})" : '');
}

# Formats a UNIX timestamp as a '<number> <unit> ago' string
sub fmtage {
  my $a = time-shift;
  my($t, $single, $plural) =
    $a > 60*60*24*365*2       ? ( $a/60/60/24/365,      'year',  'years'  ) :
    $a > 60*60*24*(365/12)*2  ? ( $a/60/60/24/(365/12), 'month', 'months' ) :
    $a > 60*60*24*7*2         ? ( $a/60/60/24/7,        'week',  'weeks'  ) :
    $a > 60*60*24*2           ? ( $a/60/60/24,          'day',   'days'   ) :
    $a > 60*60*2              ? ( $a/60/60,             'hour',  'hours'  ) :
    $a > 60*2                 ? ( $a/60,                'min',   'min'    ) :
                                ( $a,                   'sec',   'sec'    );
  $t = sprintf '%d', $t;
  sprintf '%d %s ago', $t, $t == 1 ? $single : $plural;
}

# argument: database release date format (yyyymmdd)
#  y = 0000 -> unknown
#  y = 9999 -> TBA
#  m = 99   -> month+day unknown
#  d = 99   -> day unknown
# return value: (unknown|TBA|yyyy|yyyy-mm|yyyy-mm-dd)
#  if date > now: <b class="future">str</b>
sub fmtdatestr {
  my $date = sprintf '%08d', shift||0;
  my $future = $date > strftime '%Y%m%d', gmtime;
  my($y, $m, $d) = ($1, $2, $3) if $date =~ /^([0-9]{4})([0-9]{2})([0-9]{2})$/;

  my $str = $y == 0 ? 'unknown' : $y == 9999 ? 'TBA' :
    $m == 99 ? sprintf('%04d', $y) :
    $d == 99 ? sprintf('%04d-%02d', $y, $m) :
               sprintf('%04d-%02d-%02d', $y, $m, $d);

  return $str if !$future;
  return qq|<b class="future">$str</b>|;
}

# argument: unix timestamp and optional format (compact/full)
sub fmtdate {
  my($t, $f) = @_;
  return strftime '%Y-%m-%d', gmtime $t if !$f || $f eq 'compact';
  return strftime '%Y-%m-%d at %R', gmtime $t;
}

# Arguments: (uid, username), or a hashref containing that info
sub fmtuser {
  my($id,$n) = ref($_[0]) eq 'HASH' ? ($_[0]{uid}||$_[0]{requester}, $_[0]{username}) : @_;
  return !$id ? '[deleted]' : sprintf '<a href="/u%d">%s</a>', $id, xml_escape $n;
}

# Turn a (natural number) vote into a rating indication
sub fmtrating {
  ['worst ever',
   'awful',
   'bad',
   'weak',
   'so-so',
   'decent',
   'good',
   'very good',
   'excellent',
   'masterpiece']->[shift()-1];
}

# Turn a spoiler level into a string
sub fmtspoil {
  ['neutral',
   'no spoiler',
   'minor spoiler',
   'major spoiler']->[shift()+1];
}



# JSON::XS::encode_json converts input to utf8, whereas the below functions
# operate on wide character strings. Canonicalization is enabled to allow for
# proper comparison of serialized objects.
my $JSON = JSON::XS->new;
$JSON->canonical(1);

sub json_encode ($) {
  $JSON->encode(@_);
}

sub json_decode ($) {
  $JSON->decode(@_);
}

# Insert JSON-encoded data as script, arguments: id, object
sub script_json {
  script id => $_[0], type => 'application/json';
   my $js = json_encode $_[1];
   $js =~ s/</\\u003C/g; # escape HTML tags like </script> and <!--
   lit $js;
  end;
}



# Compare the keys in %$old with the keys in %$new. Returns 1 if a difference was found, 0 otherwise.
sub form_compare {
  my($old, $new) = @_;
  for my $k (keys %$old) {
    my($o, $n) = ($old->{$k}, $new->{$k});
    return 1 if defined $n ne defined $o || ref $o ne ref $n;
    if(!defined $o) {
      # must be equivalent
    } elsif(!ref $o) {
      return 1 if $o ne $n;
    } else { # 'json' template
      return 1 if @$o != @$n;
      return 1 if grep form_compare($o->[$_], $n->[$_]), 0..$#$o;
    }
  }
  return 0;
}

1;

