
package VNDB::Util::CommonHTML;

use strict;
use warnings;
use Exporter 'import';
use VNDB::Func;

our @EXPORT = qw|
  htmlMainTabs htmlDenied htmlSearchBox
|;


# generates the "main tabs". These are the commonly used tabs for
# 'objects', i.e. VN/producer/release entries and users
# Arguments: u/v/r/p/g/i/c/d, object, currently selected item (empty=main)
sub htmlMainTabs {
  my($self, $type, $obj, $sel) = @_;
  $obj->{entry_hidden} = $obj->{hidden};
  $obj->{entry_locked} = $obj->{locked};
  VNWeb::HTML::_maintabs_({ type => $type, dbobj => $obj, tab => $sel||''});
}


# generates a full error page, including header and footer
sub htmlDenied { shift->resDenied }


sub htmlSearchBox {
  shift; VNWeb::HTML::searchbox_(@_);
}


1;
