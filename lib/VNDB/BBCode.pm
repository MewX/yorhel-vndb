package VNDB::BBCode;

use strict;
use warnings;
use Exporter 'import';
use TUWF::XML 'xml_escape';

our @EXPORT = qw/bb2html/;

# Supported BBCode:
#  [spoiler] .. [/spoiler]
#  [quote] .. [/quote]
#  [code] .. [/code]
#  [url=..] [/url]
#  [raw] .. [/raw]
#  link: http://../
#  dblink: v#, v#.#, d#.#.#
#
# Permitted nesting of formatting codes:
#  spoiler -> url, raw, link, dblink
#  quote   -> anything
#  code    -> nothing
#  url     -> raw
#  raw     -> nothing


# State action function usage:
#   _state_action \@stack, $match, $char_pre, $char_post
# Returns: ($token, @arg) on successful parse, () otherwise.

# Trivial open and close actions
sub _spoiler_start { if(lc$_[1] eq '[spoiler]')  { push @{$_[0]}, 'spoiler'; ('spoiler_start') } else { () } }
sub _quote_start   { if(lc$_[1] eq '[quote]')    { push @{$_[0]}, 'quote';   ('quote_start')   } else { () } }
sub _code_start    { if(lc$_[1] eq '[code]')     { push @{$_[0]}, 'code';    ('code_start')    } else { () } }
sub _raw_start     { if(lc$_[1] eq '[raw]')      { push @{$_[0]}, 'raw';     ('raw_start')     } else { () } }
sub _spoiler_end   { if(lc$_[1] eq '[/spoiler]') { pop  @{$_[0]}; ('spoiler_end') } else { () } }
sub _quote_end     { if(lc$_[1] eq '[/quote]'  ) { pop  @{$_[0]}; ('quote_end'  ) } else { () } }
sub _code_end      { if(lc$_[1] eq '[/code]'   ) { pop  @{$_[0]}; ('code_end'   ) } else { () } }
sub _raw_end       { if(lc$_[1] eq '[/raw]'    ) { pop  @{$_[0]}; ('raw_end'    ) } else { () } }
sub _url_end       { if(lc$_[1] eq '[/url]'    ) { pop  @{$_[0]}; ('url_end'    ) } else { () } }

sub _url_start {
  if($_[1] =~ m{^\[url=((https?://|/)[^\]>]+)\]$}i) {
    push @{$_[0]}, 'url';
    (url_start => $1)
  } else { () }
}

sub _link {
  my(undef, $match, $char_pre, $char_post) = @_;

  # Tags arent links
  return () if $match =~ /^\[/;

  # URLs (already "validated" in the parsing regex)
  return ('link') if $match =~ /^[hf]t/;

  # Now we're left with various forms of IDs, just need to make sure it's not surrounded by word characters
  return ('dblink') if $char_pre !~ /\w/ && $char_post !~ /\w/;

  ();
}


# Permitted actions to take in each state. The actions are run in order, if
# none succeed then the token is passed through as text.
# The "current state" is the most recent tag in the stack, or '' if no tags are open.
my %STATE = (
  ''      => [                \&_link, \&_url_start, \&_raw_start, \&_spoiler_start, \&_quote_start, \&_code_start],
  spoiler => [\&_spoiler_end, \&_link, \&_url_start, \&_raw_start],
  quote   => [\&_quote_end,   \&_link, \&_url_start, \&_raw_start, \&_spoiler_start, \&_quote_start, \&_code_start],
  code    => [\&_code_end     ],
  url     => [\&_url_end,     \&_raw_start],
  raw     => [\&_raw_end      ],
);


# Usage:
#
#   parse $input, sub {
#     my($raw, $token, @arg) = @_;
#     return 1; # to continue processing, 0 to stop. (Note that _close tokens may still follow after stopping)
#   };
#
#   $raw   = the raw part that has been parsed
#   $token = name of the parsed bbcode token, with some special cases (see below)
#   @arg   = $token-specific arguments.
#
# Tags:
#   text           -> literal text, $raw is the text to display
#   spoiler_start  -> start a spoiler
#   spoiler_end    -> end
#   quote_start    -> start a quote
#   quote_end      -> end
#   code_start     -> code block
#   code_end       -> end
#   url_start      -> [url=..], $arg[0] contains the url
#   url_end        -> [/url]
#   raw_start      -> [raw]
#   raw_end        -> [/raw]
#   link           -> http://.../, $raw is the link
#   dblink         -> v123, t13.1, etc. $raw is the dblink
#
# This function will ensure correct nesting of _start and _end tokens.
sub parse {
  my($raw, $sub) = @_;
  $raw =~ s/\r//g;
  return if !$raw && $raw ne '0';

  my $last = 0;
  my @stack;

  while($raw =~ m{(?:
    \[[^\s\]]+\]                            |  # tag
    d[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*  |  # d#.#.#
    [tdvprcs][1-9][0-9]*\.[1-9][0-9]*       |  # v#.#
    [tdvprcsugi][1-9][0-9]*                 |  # v#
    (?:https?|ftp)://[^><"\n\s\]\[]+[\d\w=/-]  # link
  )}xg) {
    my $token = $&;
    my $pre = substr $raw, $last, (pos($raw)-length($&))-$last;
    my $char_pre = $last ? substr $raw, pos($raw)-length($&)-1, 1 : '';
    $last = pos $raw;
    my $char_post = substr $raw, $last, 1;

    # Pass through the unformatted text before the match
    $sub->($pre, 'text') || goto FINAL if length $pre;

    # Call the state functions. Arguments to these functions are implicitely
    # passed through @_, which avoids allocating a new stack for each function
    # call.
    my $state = $STATE{ $stack[$#stack]||'' };
    my @ret;
    @_ = (\@stack, $token, $char_pre, $char_post);
    for(@$state) {
      @ret = &$_;
      last if @ret;
    }
    $sub->($token, @ret ? @ret : ('text')) || goto FINAL;
  }

  $sub->(substr($raw, $last), 'text') if $last < length $raw;

FINAL:
  # Close all tags. This code is a bit of a hack, as it bypasses the state actions.
  $sub->('', "${_}_end") for reverse @stack;
}


sub bb2html {
  my($input, $maxlength, $charspoil) = @_;

  my $incode = 0;
  my $rmnewline = 0;
  my $length = 0;
  my $ret = '';

  # escapes, returns string, and takes care of $length and $maxlength; also
  # takes care to remove newlines and double spaces when necessary
  my $e = sub {
    local $_ = shift;

    s/^\n//         if $rmnewline && $rmnewline--;
    s/\n{5,}/\n\n/g if !$incode;
    s/  +/ /g       if !$incode;
    $length += length $_;
    if($maxlength && $length > $maxlength) {
      $_ = substr($_, 0, $maxlength-$length);
      s/\W+\w*$//; # cleanly cut off on word boundary
    }
    s/&/&amp;/g;
    s/>/&gt;/g;
    s/</&lt;/g;
    s/\n/<br>/g if !$maxlength;
    s/\n/ /g       if $maxlength;
    $_;
  };

  parse $input, sub {
    my($raw, $tag, @arg) = @_;

    #$ret .= "$tag {$raw}\n";
    #return 1;

    if($tag eq 'text') {
      $ret .= $e->($raw);

    } elsif($tag eq 'spoiler_start') {
      $ret .= !$charspoil
        ? '<b class="spoiler">'
        : '<b class="grayedout charspoil charspoil_-1">&lt;hidden by spoiler settings&gt;</b><span class="charspoil charspoil_2 hidden">';
    } elsif($tag eq 'spoiler_end') {
      $ret .= !$charspoil ? '</b>' : '</span>';

    } elsif($tag eq 'quote_start') {
      $ret .= '<div class="quote">' if !$maxlength;
      $rmnewline = 1;
    } elsif($tag eq 'quote_end') {
      $ret .= '</div>' if !$maxlength;
      $rmnewline = 1;

    } elsif($tag eq 'code_start') {
      $ret .= '<pre>' if !$maxlength;
      $rmnewline = 1;
      $incode = 1;
    } elsif($tag eq 'code_end') {
      $ret .= '</pre>' if !$maxlength;
      $rmnewline = 1;
      $incode = 0;

    } elsif($tag eq 'url_start') {
      $ret .= sprintf '<a href="%s" rel="nofollow">', xml_escape($arg[0]);
    } elsif($tag eq 'url_end') {
      $ret .= '</a>';

    } elsif($tag eq 'link') {
      $ret .= sprintf '<a href="%s" rel="nofollow">%s</a>', xml_escape($raw), $e->('link');

    } elsif($tag eq 'dblink') {
      (my $link = $raw) =~ s/^d(\d+)\.(\d+)\.(\d+)$/d$1#$2.$3/;
      $ret .= sprintf '<a href="/%s">%s</a>', $link, $e->($raw);
    }

    !$maxlength || $length < $maxlength;
  };
  $ret;
}

1;
