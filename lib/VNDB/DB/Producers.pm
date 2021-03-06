
package VNDB::DB::Producers;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw|dbProducerGet dbProducerGetRev|;


# options: results, page, id, search, char, sort, inc_hidden
# what: extended relations
sub dbProducerGet {
  my $self = shift;
  my %o = (
    results => 10,
    page => 1,
    what => '',
    @_
  );

  $o{search} =~ s/%//g if $o{search};

  my %where = (
    !$o{id} && !$o{inc_hidden} ? (
      'p.hidden = FALSE' => 1 ) : (),
    $o{id} ? (
      'p.id IN(!l)' => [ ref $o{id} ? $o{id} : [$o{id}] ] ) : (),
    $o{search} ? (
      '(p.name ILIKE ? OR p.original ILIKE ? OR p.alias ILIKE ?)', [ map '%'.$o{search}.'%', 1..3 ] ) : (),
    $o{char} ? (
      'LOWER(SUBSTR(p.name, 1, 1)) = ?' => $o{char} ) : (),
    defined $o{char} && !$o{char} ? (
      '(ASCII(p.name) < 97 OR ASCII(p.name) > 122) AND (ASCII(p.name) < 65 OR ASCII(p.name) > 90)' => 1 ) : (),
  );

  my $select = 'p.id, p.type, p.name, p.original, p.lang';
  $select .= ', p.desc, p.alias, p.website, p.l_wp, p.l_wikidata, p.hidden, p.locked' if $o{what} =~ /extended/;

  my($order, @order) = ('p.name');
  if($o{sort} && $o{sort} eq 'search') {
    $order = 'least(substr_score(p.name, ?), substr_score(p.original, ?)), p.name';
    @order = ($o{search}) x 2;
  }

  my($r, $np) = $self->dbPage(\%o, qq|
    SELECT !s
      FROM producers p
      !W
      ORDER BY $order|,
    $select, \%where, @order
  );

  return _enrich($self, $r, $np, 0, $o{what});
}


# options: id, rev, what
# what: extended relations
sub dbProducerGetRev {
  my $self = shift;
  my %o = (what => '', @_);

  $o{rev} ||= $self->dbRow('SELECT MAX(rev) AS rev FROM changes WHERE type = \'p\' AND itemid = ?', $o{id})->{rev};

  my $select = 'c.itemid AS id, p.type, p.name, p.original, p.lang';
  $select .= ', extract(\'epoch\' from c.added) as added, c.comments, c.rev, c.ihid, c.ilock, '.VNWeb::DB::sql_user();
  $select .= ', c.id AS cid, NOT EXISTS(SELECT 1 FROM changes c2 WHERE c2.type = c.type AND c2.itemid = c.itemid AND c2.rev = c.rev+1) AS lastrev';
  $select .= ', p.desc, p.alias, p.website, p.l_wp, p.l_wikidata, po.hidden, po.locked' if $o{what} =~ /extended/;

  my $r = $self->dbAll(q|
    SELECT !s
      FROM changes c
      JOIN producers po ON po.id = c.itemid
      JOIN producers_hist p ON p.chid = c.id
      JOIN users u ON u.id = c.requester
      WHERE c.type = 'p' AND c.itemid = ? AND c.rev = ?|,
    $select, $o{id}, $o{rev}
  );

  return _enrich($self, $r, 0, 1, $o{what});
}


sub _enrich {
  my($self, $r, $np, $rev, $what) = @_;

  if(@$r && $what =~ /relations/) {
    my($col, $hist, $colname) = $rev ? ('cid', '_hist', 'chid') : ('id', '', 'id');
    my %r = map {
      $r->[$_]{relations} = [];
      ($r->[$_]{$col}, $_)
    } 0..$#$r;

    push @{$r->[$r{$_->{xid}}]{relations}}, $_ for(@{$self->dbAll(qq|
      SELECT rel.$colname AS xid, rel.pid AS id, rel.relation, p.name, p.original
        FROM producers_relations$hist rel
        JOIN producers p ON rel.pid = p.id
        WHERE rel.$colname IN(!l)|,
      [ keys %r ]
    )});
  }

  return wantarray ? ($r, $np) : $r;
}

1;

