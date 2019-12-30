
package VNDB::DB::ULists;

use strict;
use warnings;
use Exporter 'import';


our @EXPORT = qw|
  dbRListGet dbRListAdd dbRListDel
  dbVoteStats
|;


# Options: uid rid
sub dbRListGet {
  my($self, %o) = @_;

  my %where = (
    'uid = ?' => $o{uid},
    $o{rid} ? ('rid IN(!l)' => [ ref $o{rid} ? $o{rid} : [$o{rid}] ]) : (),
  );

  return $self->dbAll(q|
    SELECT uid, rid, status
      FROM rlists
      !W|,
    \%where
  );
}


# Arguments: uid rid status
# rid can be an arrayref only when the rows are already present, in which case an update is done
sub dbRListAdd {
  my($self, $uid, $rid, $stat) = @_;
    $self->dbExec(
      'UPDATE rlists SET status = ? WHERE uid = ? AND rid IN(!l)',
      $stat, $uid, ref($rid) ? $rid : [ $rid ]
    )
  ||
    $self->dbExec(
      'INSERT INTO rlists (uid, rid, status) VALUES(?, ?, ?)',
      $uid, $rid, $stat
    );
}


# Arguments: uid, rid
sub dbRListDel {
  my($self, $uid, $rid) = @_;
  $self->dbExec(
    'DELETE FROM rlists WHERE uid = ? AND rid IN(!l)',
    $uid, ref($rid) ? $rid : [ $rid ]
  );
}


# Arguments: 'vid', id
# Returns an arrayref with 10 elements containing the [ count(vote), sum(vote) ]
#   for votes in the range of ($index+0.5) .. ($index+1.4)
sub dbVoteStats {
  my($self, $col, $id, $ign) = @_;
  my $r = [ map [0,0], 0..9 ];
  $r->[$_->{idx}] = [ $_->{votes}, $_->{total} ] for (@{$self->dbAll(q|
      SELECT (vote::numeric/10)::int-1 AS idx, COUNT(vote) as votes, SUM(vote) AS total
        FROM ulist_vns uv
       WHERE uv.vote IS NOT NULL AND NOT EXISTS(SELECT 1 FROM users u WHERE u.id = uv.uid AND u.ign_votes)
         AND uv.vid = ?
       GROUP BY (vote::numeric/10)::int|,
    $id
  )});
  return $r;
}

1;

