
package VNDB::DB::Staff;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw|dbStaffGet |;

# options: results, page, id, aid, search, exact, truename, role, gender
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

  return wantarray ? ($r, $np) : $r;
}


1;
