
package VNDB::Util::LayoutHTML;

use strict;
use warnings;
use TUWF ':html';
use VNWeb::HTML;
use Exporter 'import';

our @EXPORT = qw|htmlHeader htmlFooter|;

sub htmlHeader { # %options->{ title, noindex, search, feeds, metadata }
  my($self, %o) = @_;
  %VNWeb::HTML::pagevars = ();

  $o{og} = $o{metadata} ? +{ map +(s/og://r, $o{metadata}{$_}), keys $o{metadata}->%* } : undef;
  $o{index} = !$o{noindex};

  html lang => 'en';
   head sub { VNWeb::HTML::_head_(\%o) };
   body;
    div id => 'bgright', ' ';
    div id => 'header', sub { h1 sub { a href => '/', 'the visual novel database' } };
    div id => 'menulist', sub { VNWeb::HTML::_menu_(\%o) };
    div id => 'maincontent';
}


sub htmlFooter { # %options => { pref_code => 1 }
  my($self, %o) = @_;
     div id => 'footer', sub { VNWeb::HTML::_footer_ };
    end 'div'; # maincontent

    # Abuse an empty noscript tag for the formcode to update a preference setting, if the page requires one.
    noscript id => 'pref_code', title => $self->authGetCode('/xml/prefs.xml'), ''
      if $o{pref_code} && $self->authInfo->{id};
    script type => 'text/javascript', src => $self->{url_static}.'/f/vndb.js?'.$self->{version}, '';
    VNWeb::HTML::v2rwjs_() if $o{v2rwjs};
   end 'body';
  end 'html';
}

1;
