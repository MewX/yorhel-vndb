#!/usr/bin/perl

# This is a test & benchmark script for VNDB::BBCode.
# Call without arguments to run the test, with any argument to run the benchmark.

use strict;
use warnings;
use Cwd 'abs_path';
use Test::More;
use Benchmark 'timethese';

our($ROOT, %S);
BEGIN { ($ROOT = abs_path $0) =~ s{/util/bbcode-test\.pl$}{}; }
use lib "$ROOT/lib";
use VNDB::BBCode qw/bb2html bb2text/;


my @tests = (
  '',
  '',
  '',

  '[From [url=http://www.dlSITE.com/eng/]DLsite English[/url]]',
  '[From <a href="http://www.dlSITE.com/eng/" rel="nofollow">DLsite English</a>]',
  '[From DLsite English]',

  '[url=http://example.com/]some url[/url]',
  '<a href="http://example.com/" rel="nofollow">some url</a>',
  'some url',

  '[quote]some quote[/quote]',
  '<div class="quote">some quote</div>',
  'some quote',

  "[code]some code\n\nalso newlines;[/code]",
  '<pre>some code<br><br>also newlines;</pre>',
  "some code\n\nalso newlines;",

  '[spoiler]some spoiler[/spoiler]',
  '<b class="spoiler">some spoiler</b>',
  '',

  '[b][i][u][s]Formatting![/s][/u][/i][/b]',
  '<b><em><span class="underline"><s>Formatting!</s></span></em></b>',
  'Formatting!',

  "[raw][quote]not parsed\n[url=https://vndb.org/]valid url[/url]\n[url=asdf]invalid url[/url][/quote][/raw]",
  "[quote]not parsed<br>[url=https://vndb.org/]valid url[/url]<br>[url=asdf]invalid url[/url][/quote]",
  "[quote]not parsed\n[url=https://vndb.org/]valid url[/url]\n[url=asdf]invalid url[/url][/quote]",

  '[quote]basic [spoiler]single[/spoiler]-line [spoiler][url=/g]tag[/url] nesting [raw](without [url=/v3333]special[/url] cases)[/raw][/spoiler][/quote]',
  '<div class="quote">basic <b class="spoiler">single</b>-line <b class="spoiler"><a href="/g" rel="nofollow">tag</a> nesting (without [url=/v3333]special[/url] cases)</b></div>',
  'basic -line ',

  '[quote][b]more [spoiler]nesting [code]mkay?',
  '<div class="quote"><b>more <b class="spoiler">nesting [code]mkay?</b></b></div>',
  'more ',

  '[url=/v][b]does not work here[/b][/url]',
  '<a href="/v" rel="nofollow">[b]does not work here[/b]</a>',
  '[b]does not work here[/b]',

  '[s] v5 [url=/p1]x[/url] [/s]',
  '<s> <a href="/v5">v5</a> <a href="/p1" rel="nofollow">x</a> </s>',
  ' v5 x ',

  "[quote]rmnewline after closing tag[/quote]\n",
  '<div class="quote">rmnewline after closing tag</div>',
  "rmnewline after closing tag\n",

  '[url=/v19]some vndb url[/url]',
  '<a href="/v19" rel="nofollow">some vndb url</a>',
  'some vndb url',

  "quite\n\n\n\n\n\n\na\n\n\n\n\n            lot             of\n\n\n\nunneeded             whitespace",
  'quite<br><br>a<br><br> lot of<br><br><br><br>unneeded whitespace',
  "quite\n\n\n\n\n\n\na\n\n\n\n\n            lot             of\n\n\n\nunneeded             whitespace",

  "[quote]\nsimple\nrmnewline\ntest\n[/quote]",
  '<div class="quote">simple<br>rmnewline<br>test<br></div>',
  "\nsimple\nrmnewline\ntest\n",

  # the new implementation doesn't special-case [code], as the first newline shouldn't matter either way
  "[quote]\n\nhello, rmnewline test[code]\n#!/bin/sh\n\nfunction random_username() {\n    </dev/urandom tr -cd 'a-zA-Z0-9' | dd bs=1 count=16 2>/dev/null\n}\n[/code]\nsome text after the code tag\n[/quote]\n\n[spoiler]\nsome newlined spoiler\n[/spoiler]",
  '<div class="quote"><br>hello, rmnewline test<pre>#!/bin/sh<br><br>function random_username() {<br>    &lt;/dev/urandom tr -cd \'a-zA-Z0-9\' | dd bs=1 count=16 2&gt;/dev/null<br>}<br></pre>some text after the code tag<br></div><br><b class="spoiler"><br>some newlined spoiler<br></b>',
  "\n\nhello, rmnewline test\n#!/bin/sh\n\nfunction random_username() {\n    </dev/urandom tr -cd 'a-zA-Z0-9' | dd bs=1 count=16 2>/dev/null\n}\n\nsome text after the code tag\n\n\n",

  "[quote]\n[raw]\nrmnewline test with made-up elements\n[/raw]\nwelp\n[dumbtag]\nnone\n[/dumbtag]\n[/quote]",
  '<div class="quote"><br>rmnewline test with made-up elements<br><br>welp<br>[dumbtag]<br>none<br>[/dumbtag]<br></div>',
  "\n\nrmnewline test with made-up elements\n\nwelp\n[dumbtag]\nnone\n[/dumbtag]\n",

  '[url=http://example.com/]markup in [raw][url][/raw][/url]',
  '<a href="http://example.com/" rel="nofollow">markup in [url]</a>',
  "markup in [url]",

  '[url=http://192.168.1.1/some/path]ipv4 address in [url][/url]',
  '<a href="http://192.168.1.1/some/path" rel="nofollow">ipv4 address in [url]</a>',
  'ipv4 address in [url]',

  'http://192.168.1.1/some/path (literal ipv4 address)',
  '<a href="http://192.168.1.1/some/path" rel="nofollow">link</a> (literal ipv4 address)',
  'http://192.168.1.1/some/path (literal ipv4 address)',

  '[url=http://192.168.1.1:8080/some/path]ipv4 address (port included) in [url][/url]',
  '<a href="http://192.168.1.1:8080/some/path" rel="nofollow">ipv4 address (port included) in [url]</a>',
  'ipv4 address (port included) in [url]',

  'http://192.168.1.1:8080/some/path (literal ipv4 address, port included)',
  '<a href="http://192.168.1.1:8080/some/path" rel="nofollow">link</a> (literal ipv4 address, port included)',
  'http://192.168.1.1:8080/some/path (literal ipv4 address, port included)',

  '[Quote]non-lowercase tags [SpOILER]here[/sPOilER][/qUOTe]',
  '<div class="quote">non-lowercase tags <b class="spoiler">here</b></div>',
  'non-lowercase tags ',

  'some text [spoiler]with (v17) tags[/spoiler] and internal ids such as s1',
  'some text <b class="spoiler">with (<a href="/v17">v17</a>) tags</b> and internal ids such as <a href="/s1">s1</a>',
  'some text  and internal ids such as s1',

  'r12.1 v6.3 s1.2',
  '<a href="/r12.1">r12.1</a> <a href="/v6.3">v6.3</a> <a href="/s1.2">s1.2</a>',
  'r12.1 v6.3 s1.2',

  'd3 d1.3 d2#4 d5#6.7',
  '<a href="/d3">d3</a> <a href="/d1.3">d1.3</a> <a href="/d2#4">d2#4</a> <a href="/d5#6.7">d5#6.7</a>',
  'd3 d1.3 d2#4 d5#6.7',

  'v17 text dds16v21 more text1 v9 _d5_ d3-',
  '<a href="/v17">v17</a> text dds16v21 more text1 <a href="/v9">v9</a> _d5_ d3-',
  'v17 text dds16v21 more text1 v9 _d5_ d3-',

  # https://vndb.org/t2520.233
  '[From[url=http://densetsu.com/display.php?id=468&style=alphabetical] Anime Densetsu[/url]]',
  '[From<a href="http://densetsu.com/display.php?id=468&amp;style=alphabetical" rel="nofollow"> Anime Densetsu</a>]',
  '[From Anime Densetsu]',

  # Not sure what to do here
  #'http://some[raw].pointlessly[/raw].unusual.domain/',
  #'<a href="http://some.pointlessly.unusual.domain/" rel="nofollow">link</a>',

  #'[url=http://some[raw].pointlessly[/raw].unusual.domain/]hi[/url]',
  #'<a href="http://some[raw].pointlessly[/raw].unusual.domain/" rel="nofollow">hi</a>',

  '<tag>html escapes (&)</tag>',
  '&lt;tag&gt;html escapes (&amp;)&lt;/tag&gt;',
  '<tag>html escapes (&)</tag>',

  '[spoiler]stray open tag',
  '<b class="spoiler">stray open tag</b>',
  '',

  # TODO: This isn't ideal
  '[quote][spoiler]stray open tag (nested)[/quote]',
  '<div class="quote"><b class="spoiler">stray open tag (nested)[/quote]</b></div>',
  '',

  '[quote][spoiler]two stray open tags',
  '<div class="quote"><b class="spoiler">two stray open tags</b></div>',
  '',

  "[url=https://cat.xyz/]that's [spoiler]some [quote]uncommon[/quote][/spoiler] combination[/url]",
  '<a href="https://cat.xyz/" rel="nofollow">that\'s [spoiler]some [quote]uncommon[/quote][/spoiler] combination</a>',
  "that's [spoiler]some [quote]uncommon[/quote][/spoiler] combination",

  # > I don't see anyone using IPv6 URLs anytime soon, so I'm not worried too either way.
  #'[url=http://[fedc:ba98:7654:3210:fedc:ba98:7654:3210]/some/path]ipv6 address in [url][/url]',
  #'<a href="http://[fedc:ba98:7654:3210:fedc:ba98:7654:3210]/some/path" rel="nofollow">ipv6 address in [url]</a>',

  #'http://[fedc:ba98:7654:3210:fedc:ba98:7654:3210]/some/path (literal ipv6 address)',
  #'<a href="http://[fedc:ba98:7654:3210:fedc:ba98:7654:3210]/some/path" rel="nofollow">link</a> (literal ipv6 address)',

  # test shortening
  [ "[url=https://cat.xyz/]that's [spoiler]some [quote]uncommon[/quote][/spoiler] combination[/url]", 10 ],
  '<a href="https://cat.xyz/" rel="nofollow">that\'s </a>',
  "that's [spoiler]some [quote]uncommon[/quote][/spoiler] combination",

  [ "A https://blicky.net/ only takes 4 characters", 8 ],
  'A <a href="https://blicky.net/" rel="nofollow">link</a>',
  "A https://blicky.net/ only takes 4 characters",
);


# output should be the same as the input
my @invalid_syntax = (
  '[url="http://example.com/"]invalid argument to the "url" tag[/url]',
  '[url=nicetext]simpler invalid param[/url]',
  '[url]empty "url" tag[/url]',
  '[tag]custom tag[/tag]',
  # https://vndb.org/t2520.231
  'pov1',
);


# Chaining all the parse() raw arguments should generate the same string as the input
sub identity {
  my $ret = '';
  VNDB::BBCode::parse $_[0], sub {
    $ret .= $_[0];
  };
  $ret;
}


sub test {
  push @tests, map +($_,$_,$_), @invalid_syntax;
  plan tests => scalar @tests;

  while(@tests) {
    my $input = shift @tests;
    my $html  = shift @tests;
    my $plain = shift @tests;
    my @arg = ref $input ? @$input : ($input);
    (my $msg = $arg[0]) =~ s/\n/\\n/g;
    is identity($arg[0]), $arg[0], "id: $msg";
    is bb2html(@arg),     $html,   "html: $msg";
    is bb2text($arg[0]),  $plain,  "plain: $msg";
  }
}


# Performance comparison with old implementation
sub bench {
    my $plain = "This isn't a terribly interesting [string]. "x1000;
    my $short = "Nobody ev3r v10 uses v5 so s1 many [url=https://blicky.net/]x[raw]y[/raw][/url] tags. ";
    my $heavy = $short x100;
    timethese(0, {
      short => sub { bb2html($short) },
      plain => sub { bb2html($plain) },
      heavy => sub { bb2html($heavy) },
    });
    # old:
    #   heavy:  3 wallclock secs ( 3.15 usr +  0.00 sys =  3.15 CPU) @ 357.46/s (n=1126)
    #   plain:  3 wallclock secs ( 3.20 usr +  0.00 sys =  3.20 CPU) @ 130.00/s (n=416)
    #   short:  3 wallclock secs ( 3.17 usr +  0.00 sys =  3.17 CPU) @ 31420.82/s (n=99604)
    # new:
    #   heavy:  3 wallclock secs ( 3.23 usr +  0.00 sys =  3.23 CPU) @ 242.11/s (n=782)
    #   plain:  3 wallclock secs ( 3.12 usr +  0.00 sys =  3.12 CPU) @ 124.04/s (n=387)
    #   short:  3 wallclock secs ( 3.18 usr +  0.00 sys =  3.18 CPU) @ 21018.55/s (n=66839)
    # That's a bit of a performance hit, but should still be fast enough.
}

test if !@ARGV;
bench if @ARGV;
