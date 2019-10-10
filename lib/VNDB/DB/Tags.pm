
package VNDB::DB::Tags;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw|dbTagGet dbTTTree dbTagEdit dbTagAdd dbTagMerge dbTagLinks dbTagLinkEdit dbTagStats dbTagWipeVotes|;


# %options->{ id noid name search state searchable applicable page results what sort reverse  }
# what: parents childs(n) aliases addedby
# sort: id name added items search
sub dbTagGet {
  my $self = shift;
  my %o = (
    page => 1,
    results => 10,
    what => '',
    @_
  );

  $o{search} =~ s/%//g if $o{search};

  my %where = (
    $o{id} ? (
      't.id IN(!l)' => [ ref $o{id} ? $o{id} : [$o{id}] ] ) : (),
    $o{noid} ? (
      't.id <> ?' => $o{noid} ) : (),
    $o{name} ? (
      't.id = (SELECT id FROM tags LEFT JOIN tags_aliases ON id = tag WHERE lower(name) = ? OR lower(alias) = ? LIMIT 1)' => [ lc $o{name}, lc $o{name} ]) : (),
    defined $o{state} && $o{state} != -1 ? (
      't.state = ?' => $o{state} ) : (),
    !defined $o{state} && !$o{id} && !$o{name} ? (
      't.state <> 1' => 1 ) : (),
    $o{search} ? (
      't.id IN (SELECT id FROM tags LEFT JOIN tags_aliases ON id = tag WHERE name ILIKE ? OR alias ILIKE ?)' => [ "%$o{search}%", "%$o{search}%" ] ) : (),
    defined $o{searchable} ? ('t.searchable = ?' => $o{searchable}?1:0 ) : (),
    defined $o{applicable} ? ('t.applicable = ?' => $o{applicable}?1:0 ) : (),
  );
  my @select = (
    qw|t.id t.searchable t.applicable t.name t.description t.state t.cat t.c_items t.defaultspoil|,
    q|extract('epoch' from t.added) as added|,
    $o{what} =~ /addedby/ ? (VNWeb::DB::sql_user()) : (),
  );
  my @join = $o{what} =~ /addedby/ ? 'JOIN users u ON u.id = t.addedby' : ();

  my $order = sprintf {
    id    => 't.id %s',
    name  => 't.name %s',
    added => 't.added %s',
    items => 't.c_items %s',
    search=> 'substr_score(t.name, ?) ASC, t.name %s',  # Assigning a matching score for aliases is also possible, but more involved
  }->{ $o{sort}||'id' }, $o{reverse} ? 'DESC' : 'ASC';
  my @order = $o{sort} && $o{sort} eq 'search' ? ($o{search}) : ();


  my($r, $np) = $self->dbPage(\%o, qq|
    SELECT !s
      FROM tags t
      !s
      !W
      ORDER BY $order|,
    join(', ', @select), join(' ', @join), \%where, @order
  );

  if(@$r && $o{what} =~ /aliases/) {
    my %r = map {
      $_->{aliases} = [];
      ($_->{id}, $_->{aliases})
    } @$r;

    push @{$r{$_->{tag}}}, $_->{alias} for (@{$self->dbAll(q|
      SELECT tag, alias FROM tags_aliases WHERE tag IN(!l)|, [ keys %r ]
    )});
  }

  if($o{what} =~ /parents\((\d+)\)/) {
    $_->{parents} = $self->dbTTTree(tag => $_->{id}, $1, 1) for(@$r);
  }

  if($o{what} =~ /childs\((\d+)\)/) {
    $_->{childs} = $self->dbTTTree(tag => $_->{id}, $1) for(@$r);
  }

  return wantarray ? ($r, $np) : $r;
}


# Walks the tag/trait tree
#  type = tag | trait
#  id = tag to start with, or 0 to start with top-level tags
#  lvl = max. recursion level
#  back = false for parent->child, true for child->parent
# Returns: [ { id, name, c_items, sub => [ { id, name, c_items, sub => [..] }, .. ] }, .. ]
sub dbTTTree {
  my($self, $type, $id, $lvl, $back) = @_;
  $lvl ||= 15;
  my $xtra = $type eq 'trait' ? ', "order"' : '';
  my $xtra2 = $type eq 'trait' ? ', t."order"' : '';
  my $r = $self->dbAll(qq|
    WITH RECURSIVE thetree(lvl, id, parent, name, c_items) AS (
        SELECT ?::integer, id, 0, name, c_items$xtra
        FROM ${type}s
        !W
      UNION ALL
        SELECT tt.lvl-1, t.id, tt.id, t.name, t.c_items$xtra2
        FROM thetree tt
        JOIN ${type}s_parents tp ON !s
        JOIN ${type}s t ON !s
        WHERE tt.lvl > 0
          AND t.state = 2
    ) SELECT DISTINCT id, parent, name, c_items$xtra FROM thetree ORDER BY name|, $lvl,
    $id ? {'id = ?' => $id} : {"NOT EXISTS(SELECT 1 FROM ${type}s_parents WHERE $type = id)" => 1, 'state = 2' => 1},
    !$back ? ('tp.parent = tt.id', "t.id = tp.$type") : ("tp.$type = tt.id", 't.id = tp.parent')
  );

  my %pars; # parent-id -> [ child-object, .. ]
  push @{$pars{$_->{parent}}}, $_ for(@$r);
  $_->{'sub'} = $pars{$_->{id}} || [] for(@$r);
  my @r = grep !delete($_->{parent}), @$r;
  return $id ? $r[0]{'sub'} : \@r;
}


# args: tag id, %options->{ columns in the tags table + parents + aliases }
sub dbTagEdit {
  my($self, $id, %o) = @_;

  $self->dbExec('UPDATE tags !H WHERE id = ?', {
    $o{upddate} ? ('added = NOW()' => 1) : (),
    map exists($o{$_}) ? ("$_ = ?" => $o{$_}) : (), qw|name searchable applicable description state cat defaultspoil|
  }, $id);
  if($o{aliases}) {
    $self->dbExec('DELETE FROM tags_aliases WHERE tag = ?', $id);
    $self->dbExec('INSERT INTO tags_aliases (tag, alias) VALUES (?, ?)', $id, $_) for (@{$o{aliases}});
  }
  if($o{parents}) {
    $self->dbExec('DELETE FROM tags_parents WHERE tag = ?', $id);
    $self->dbExec('INSERT INTO tags_parents (tag, parent) VALUES (?, ?)', $id, $_) for(@{$o{parents}});
  }
}


# same args as dbTagEdit, without the first tag id
# returns the id of the new tag
sub dbTagAdd {
  my($self, %o) = @_;
  my $id = $self->dbRow('INSERT INTO tags (name, searchable, applicable, description, state, cat, defaultspoil, addedby) VALUES (!l, ?) RETURNING id',
    [ map $o{$_}, qw|name searchable applicable description state cat defaultspoil| ], $o{addedby}||$self->authInfo->{id}
  )->{id};
  $self->dbExec('INSERT INTO tags_parents (tag, parent) VALUES (?, ?)', $id, $_) for(@{$o{parents}});
  $self->dbExec('INSERT INTO tags_aliases (tag, alias) VALUES (?, ?)', $id, $_) for (@{$o{aliases}});
  return $id;
}


sub dbTagMerge {
  my($self, $id, @merge) = @_;
  $self->dbExec(q|
    DELETE FROM tags_vn tv
          WHERE tag IN(!l)
            AND EXISTS(SELECT 1 FROM tags_vn ti WHERE ti.tag = ? AND ti.uid = tv.uid AND ti.vid = tv.vid)|, \@merge, $id);
  $self->dbExec('UPDATE tags_vn SET tag = ? WHERE tag IN(!l)', $id, \@merge);
  $self->dbExec('UPDATE tags_aliases SET tag = ? WHERE tag IN(!l)', $id, \@merge);
  $self->dbExec('INSERT INTO tags_aliases (tag, alias) VALUES (?, ?)', $id, $_->{name})
    for (@{$self->dbAll('SELECT name FROM tags WHERE id IN(!l)', \@merge)});
  $self->dbExec('DELETE FROM tags_parents WHERE tag IN(!l)', \@merge);
  $self->dbExec('DELETE FROM tags WHERE id IN(!l)', \@merge);
}


# Directly fetch rows from tags_vn
# Options: vid uid tag page results what sort reverse
# What: details
sub dbTagLinks {
  my($self, %o) = @_;
  $o{results} ||= 999;
  $o{page}    ||= 1;
  $o{what}    ||= '';

  my %where = (
    $o{vid} ? ('tv.vid = ?' => $o{vid}) : (),
    $o{uid} ? ('tv.uid = ?' => $o{uid}) : (),
    $o{tag} ? ('tv.tag = ?' => $o{tag}) : (),
  );

  my @select = (
    qw|tv.tag tv.vid tv.uid tv.vote tv.spoiler tv.ignore|, "EXTRACT('epoch' from tv.date) AS date",
    $o{what} =~ /details/ ? (qw|v.title t.name|, VNWeb::DB::sql_user()) : (),
  );

  my @join = $o{what} =~ /details/ ? (
    'JOIN vn v ON v.id = tv.vid',
    'JOIN users u ON u.id = tv.uid',
    'JOIN tags t ON t.id = tv.tag'
  ) : ();

  my $order = !$o{sort} ? '' : 'ORDER BY '.{
    username => 'u.username',
    date     => 'tv.date',
    title    => 'v.title',
    tag      => 't.name',
  }->{$o{sort}}.($o{reverse} ? ' DESC' : ' ASC');

  my($r, $np) = $self->dbPage(\%o,
    'SELECT !s FROM tags_vn tv !s !W !s',
    join(', ', @select), join(' ', @join), \%where, $order
  );
  return wantarray ? ($r, $np) : $r;
}


# Change a user's tags for a VN entry
sub dbTagLinkEdit {
  my($self, $uid, $vid, $insert, $update, $delete, $overrule) = @_;

  # overrule
  # 1. set ignore flag for everyone except $uid
  $self->dbExec('UPDATE tags_vn SET ignore = ? WHERE tag = ? AND vid = ? AND uid <> ?',
    $overrule->{$_}?1:0, $_, $vid, $uid) for(keys %$overrule);
  # 2. make sure $uid isn't ignored when others are set to ignore
  #    (this happens when a mod takes over an other mods' overrule)
  $self->dbExec('UPDATE tags_vn SET ignore = false WHERE tag = ? AND vid = ? AND uid = ?',
    $_, $vid, $uid) for(grep $overrule->{$_}, keys %$overrule);

  # delete
  $self->dbExec('DELETE FROM tags_vn WHERE vid = ? AND uid = ? AND tag IN(!l)',
    $vid, $uid, [ keys %$delete ]) if keys %$delete;

  # insert
  my $val = join ',', map '(?,?,?,?,?,?)', keys %$insert;
  $self->dbExec("INSERT INTO tags_vn (tag, vid, uid, vote, spoiler, ignore) VALUES $val", map
      +($_, $vid, $uid, $insert->{$_}[0], $insert->{$_}[1]<0?undef:$insert->{$_}[1], $insert->{$_}[2]?1:0),
    keys %$insert) if keys %$insert;

  # update
  $self->dbExec('UPDATE tags_vn SET vote = ?, spoiler = ?, date = NOW() WHERE tag = ? AND vid = ? AND uid = ?',
    $update->{$_}[0], $update->{$_}[1]<0?undef:$update->{$_}[1], $_, $vid, $uid) for (keys %$update);

  # Update cache
  $self->dbExec('SELECT tag_vn_calc(?)', $vid);
}


# Fetch all tags related to a VN
# Argument: %options->{ vid minrating state results what page sort reverse }
# sort: name, rating
sub dbTagStats {
  my($self, %o) = @_;
  $o{results} ||= 10;
  $o{page}  ||= 1;

  my $rating = 'avg(CASE WHEN tv.ignore THEN NULL ELSE tv.vote END)';
  my $order = sprintf {
    name => 't.name %s',
    rating => "$rating %s",
  }->{ $o{sort}||'name' }, $o{reverse} ? 'DESC' : 'ASC';

  my %where = (
      'tv.vid = ?' => $o{vid},
      defined $o{state} ? ('t.state = ?', $o{state}) : (),
  );

  my($r, $np) = $self->dbPage(\%o, qq|
    SELECT t.id, t.name, t.cat, count(*) as cnt, $rating as rating,
        COALESCE(avg(CASE WHEN tv.ignore THEN NULL ELSE tv.spoiler END), t.defaultspoil) as spoiler,
        bool_or(tv.ignore) AS overruled
      FROM tags t
      JOIN tags_vn tv ON tv.tag = t.id
      !W
      GROUP BY t.id, t.name, t.cat
      !s
      ORDER BY !s|,
    \%where, defined $o{minrating} ? "HAVING $rating > $o{minrating}" : '', $order
  );

  return wantarray ? ($r, $np) : $r;
}


# Deletes all votes on a tag.
sub dbTagWipeVotes {
  $_[0]->dbExec('DELETE FROM tags_vn WHERE tag = ?', $_[1])
}

1;

