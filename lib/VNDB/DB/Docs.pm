
package VNDB::DB::Docs;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw|dbDocGet dbDocGetRev dbDocRevisionInsert|;


# Can only fetch a single document.
# $doc = $self->dbDocGet(id => $id);
sub dbDocGet {
  my $self = shift;
  my %o = @_;

  my $r = $self->dbAll('SELECT id, title, content FROM docs WHERE id = ?', $o{id});
  return wantarray ? ($r, 0) : $r;
}


# options: id, rev
sub dbDocGetRev {
  my $self = shift;
  my %o = @_;

  $o{rev} ||= $self->dbRow('SELECT MAX(rev) AS rev FROM changes WHERE type = \'d\' AND itemid = ?', $o{id})->{rev};

  my $r = $self->dbAll(q|
    SELECT de.id, d.title, d.content, de.hidden, de.locked,
           extract('epoch' from c.added) as added, c.requester, c.comments, u.username, c.rev, c.ihid, c.ilock, c.id AS cid,
           NOT EXISTS(SELECT 1 FROM changes c2 WHERE c2.type = c.type AND c2.itemid = c.itemid AND c2.rev = c.rev+1) AS lastrev
      FROM changes c
      JOIN docs de ON de.id = c.itemid
      JOIN docs_hist d ON d.chid = c.id
      JOIN users u ON u.id = c.requester
      WHERE c.type = 'd' AND c.itemid = ? AND c.rev = ?|,
     $o{id}, $o{rev}
  );
  return wantarray ? ($r, 0) : $r;
}


# Updates the edit_* tables, used from dbItemEdit()
# Arguments: { title content },
sub dbDocRevisionInsert {
  my($self, $o) = @_;
  my %set = map exists($o->{$_}) ? (qq|"$_" = ?|, $o->{$_}) : (), qw|title content|;
  $self->dbExec('UPDATE edit_docs !H', \%set) if keys %set;
}


1;
