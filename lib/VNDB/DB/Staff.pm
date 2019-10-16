
package VNDB::DB::Staff;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw|dbStaffGet dbStaffGetRev|;

# options: results, page, id, aid, search, exact, truename, role, gender
# what: extended changes roles aliases
sub dbStaffGet {
  my $self = shift;
  my %o = (
    results => 10,
    page => 1,
    what => '',
    @_
  );
  my(@roles, $seiyuu);
  if(defined $o{role}) {
    if(ref $o{role}) {
      $seiyuu = grep /^seiyuu$/, @{$o{role}};
      @roles = grep !/^seiyuu$/, @{$o{role}};
    } else {
      $seiyuu = $o{role} eq 'seiyuu';
      @roles = $o{role} unless $seiyuu;
    }
  }

  $o{search} =~ s/%//g if $o{search};

  my %where = (
    !$o{id} ? ( 's.hidden = FALSE' => 1 ) : (),
    $o{id}  ? ( ref $o{id}  ? ('s.id IN(!l)'  => [$o{id}])  : ('s.id = ?' => $o{id}) ) : (),
    $o{aid} ? ( ref $o{aid} ? ('sa.aid IN(!l)' => [$o{aid}]) : ('sa.aid = ?' => $o{aid}) ) : (),
    $o{id} || $o{truename} ? ( 's.aid = sa.aid' => 1 ) : (),
    defined $o{gender} ? ( 's.gender IN(!l)' => [ ref $o{gender} ? $o{gender} : [$o{gender}] ]) : (),
    defined $o{lang}   ? ( 's.lang IN(!l)'   => [ ref $o{lang}   ? $o{lang}   : [$o{lang}]   ]) : (),
    defined $o{role} ? (
      '('.join(' OR ',
        @roles ? ( 'EXISTS(SELECT 1 FROM vn_staff vs JOIN vn v ON v.id = vs.id WHERE vs.aid = sa.aid AND vs.role IN(!l) AND NOT v.hidden)' ) : (),
        $seiyuu ? ( 'EXISTS(SELECT 1 FROM vn_seiyuu vsy JOIN vn v ON v.id = vsy.id WHERE vsy.aid = sa.aid AND NOT v.hidden)' ) : ()
      ).')' => ( @roles ? [ \@roles ] : 1 ),
    ) : (),
    $o{exact} ? ( '(lower(sa.name) = lower(?) OR lower(sa.original) = lower(?))' => [ ($o{exact}) x 2 ] ) : (),
    $o{search} ?
      $o{search} =~ /[\x{3000}-\x{9fff}\x{ff00}-\x{ff9f}]/ ?
        # match against 'original' column only if search string contains any
        # japanese character.
        # note: more precise regex would be /[\p{Hiragana}\p{Katakana}\p{Han}]/
        ( q|(sa.original LIKE ? OR translate(sa.original,' ','') LIKE ?)| => [ '%'.$o{search}.'%', ($o{search} =~ s/\s+//gr).'%' ] ) :
        ( '(sa.name ILIKE ? OR sa.original ILIKE ?)' => [ map '%'.$o{search}.'%', 1..2 ] ) : (),
    $o{char} ? ( 'LOWER(SUBSTR(sa.name, 1, 1)) = ?' => $o{char} ) : (),
    defined $o{char} && !$o{char} ?
      ( '(ASCII(sa.name) < 97 OR ASCII(sa.name) > 122) AND (ASCII(sa.name) < 65 OR ASCII(sa.name) > 90)' => 1 ) : (),
  );

  my $select = 's.id, sa.aid, sa.name, sa.original, s.gender, s.lang';
  $select .= ', s.desc, s.l_wp, s.l_site, s.l_twitter, s.l_anidb, s.l_wikidata, s.l_pixiv, s.hidden, s.locked' if $o{what} =~ /extended/;

  my($order, @order) = ('sa.name');
  if($o{sort} && $o{sort} eq 'search') {
    $order = 'least(substr_score(sa.name, ?), substr_score(sa.original, ?)), sa.name';
    @order = ($o{search}) x 2;
  }

  my($r, $np) = $self->dbPage(\%o, qq|
    SELECT !s
      FROM staff s
      JOIN staff_alias sa ON sa.id = s.id
      !W
      ORDER BY $order|,
    $select, \%where, @order
  );

  return _enrich($self, $r, $np, 0, $o{what});
}


sub dbStaffGetRev {
  my $self = shift;
  my %o = (what => '', @_);

  $o{rev} ||= $self->dbRow('SELECT MAX(rev) AS rev FROM changes WHERE type = \'s\' AND itemid = ?', $o{id})->{rev};

  my $select = 'c.itemid AS id, sa.aid, sa.name, sa.original, s.gender, s.lang';
  $select .= ', extract(\'epoch\' from c.added) as added, c.comments, c.rev, c.ihid, c.ilock, '.VNWeb::DB::sql_user();
  $select .= ', c.id AS cid, NOT EXISTS(SELECT 1 FROM changes c2 WHERE c2.type = c.type AND c2.itemid = c.itemid AND c2.rev = c.rev+1) AS lastrev';
  $select .= ', s.desc, s.l_wp, s.l_site, s.l_twitter, s.l_anidb, s.l_wikidata, s.l_pixiv, so.hidden, so.locked' if $o{what} =~ /extended/;

  my $r = $self->dbAll(q|
    SELECT !s
      FROM changes c
      JOIN staff so ON so.id = c.itemid
      JOIN staff_hist s ON s.chid = c.id
      JOIN staff_alias_hist sa ON sa.chid = c.id AND s.aid = sa.aid
      JOIN users u ON u.id = c.requester
      WHERE c.type = 's' AND c.itemid = ? AND c.rev = ?|,
    $select, $o{id}, $o{rev}
  );

  return _enrich($self, $r, 0, 1, $o{what});
}


sub _enrich {
  my($self, $r, $np, $rev, $what) = @_;

  # Role info is linked to VN revisions, so is independent of the selected staff revision
  if(@$r && $what =~ /roles/) {
    my %r = map {
      $_->{roles} = [];
      $_->{cast} = [];
      ($_->{id}, $_);
    } @$r;

    push @{$r{ delete $_->{id} }{roles}}, $_ for (@{$self->dbAll(q|
      SELECT sa.id, sa.aid, v.id AS vid, sa.name, sa.original, v.c_released, v.title, v.original AS t_original, vs.role, vs.note
        FROM vn_staff vs
        JOIN vn v ON v.id = vs.id
        JOIN staff_alias sa ON vs.aid = sa.aid
        WHERE sa.id IN(!l) AND NOT v.hidden
        ORDER BY v.c_released ASC, v.title ASC, vs.role ASC|, [ keys %r ]
    )});
    push @{$r{ delete $_->{id} }{cast}}, $_ for (@{$self->dbAll(q|
      SELECT sa.id, sa.aid, v.id AS vid, sa.name, sa.original, v.c_released, v.title, v.original AS t_original, c.id AS cid, c.name AS c_name, c.original AS c_original, vs.note
        FROM vn_seiyuu vs
        JOIN vn v ON v.id = vs.id
        JOIN chars c ON c.id = vs.cid
        JOIN staff_alias sa ON vs.aid = sa.aid
        WHERE sa.id IN(!l) AND NOT v.hidden
        ORDER BY v.c_released ASC, v.title ASC|, [ keys %r ]
    )});
  }

  if(@$r && $what =~ /aliases/) {
    my ($col, $hist, $colname) = $rev ? ('cid', '_hist', 'chid') : ('id', '', 'id');
    my %r = map {
      $_->{aliases} = [];
      ($_->{$col}, $_);
    } @$r;

    push @{$r{ delete $_->{xid} }{aliases}}, $_ for (@{$self->dbAll("
      SELECT s.$colname AS xid, sa.aid, sa.name, sa.original
        FROM staff_alias$hist sa
        JOIN staff$hist s ON s.$colname = sa.$colname
        WHERE s.$colname IN(!l) AND s.aid <> sa.aid
        ORDER BY sa.name ASC", [ keys %r ]
    )});
  }

  return wantarray ? ($r, $np) : $r;
}

1;
