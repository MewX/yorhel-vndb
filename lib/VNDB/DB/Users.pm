
package VNDB::DB::Users;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw|
  dbUserGet
|;


# %options->{ uid results page what }
# what: pubskin
# sort: username registered votes changes tags
sub dbUserGet {
  my $s = shift;
  my %o = (
    page => 1,
    results => 10,
    what => '',
    @_
  );

  my %where = (
    $o{uid} && !ref($o{uid}) ? (
      'id = ?' => $o{uid} ) : (),
    $o{uid} && ref($o{uid}) ? (
      'id IN(!l)' => [ $o{uid} ]) : (),
  );

  my @select = (
    qw|id username c_votes c_changes c_tags hide_list|,
    VNWeb::DB::sql_user(), # XXX: This duplicates id and username, but updating all the code isn't going to be easy
    q|extract('epoch' from registered) as registered|,
    $o{what} =~ /pubskin/ ? qw|pubskin_can pubskin_enabled customcss skin| : (),
  );

  my($r, $np) = $s->dbPage(\%o, q|
    SELECT !s
      FROM users u
      !W
      ORDER BY id DESC|,
    join(', ', @select), \%where
  );

  return wantarray ? ($r, $np) : $r;
}

1;

