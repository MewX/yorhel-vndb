package VNWeb::ULists::Export;

use TUWF::XML ':xml';
use VNWeb::Prelude;
use VNWeb::ULists::Lib;

# XXX: Reading someone's entire list into memory (multiple times even) is not
# the most efficient way to implement an export function. Might want to switch
# to an async background process for this to reduce the footprint of web
# workers.

sub data {
    my($uid) = @_;

    # We'd like ISO7601/RFC3339 timestamps in UTC with accuracy to the second.
    my sub tz { sql 'to_char(', $_[0], ' at time zone \'utc\',', \'YYYY-MM-DD"T"HH24:MM:SS"Z"', ') as', $_[1] }

    my $d = {
        'export-date' => tuwf->dbVali(select => tz('NOW()', 'now')),
        user   => tuwf->dbRowi('SELECT id, username as name FROM users WHERE id =', \$uid),
        labels => tuwf->dbAlli('SELECT id, label, private FROM ulist_labels WHERE uid =', \$uid, 'ORDER BY id'),
        vns    => tuwf->dbAlli('
            SELECT v.id, v.title, v.original, uv.vote, uv.started, uv.finished, uv.notes
                 , ', sql_comma(tz('uv.added', 'added'), tz('uv.lastmod', 'lastmod'), tz('uv.vote_date', 'vote_date')), '
              FROM ulist_vns uv
              JOIN vn v ON v.id = uv.vid
             WHERE uv.uid =', \$uid, '
             ORDER BY v.title')
    };
    enrich labels => id => vid => sub { sql '
        SELECT uvl.vid, ul.id, ul.label, ul.private
          FROM ulist_vns_labels uvl
          JOIN ulist_labels ul ON ul.id = uvl.lbl
         WHERE ul.uid =', \$uid, 'AND uvl.uid =', \$uid, '
         ORDER BY lbl'
    }, $d->{vns};
    enrich releases => id => vid => sub { sql '
        SELECT rv.vid, r.id, r.title, r.original, r.released, rl.status, ', tz('rl.added', 'added'), '
          FROM rlists rl
          JOIN releases r ON r.id = rl.rid
          JOIN releases_vn rv ON rv.id = rl.rid
         WHERE rl.uid =', \$uid, '
         ORDER BY r.released, r.id'
    }, $d->{vns};
    $d
}


sub filename {
    my($d, $ext) = @_;
    my $date = $d->{'export-date'} =~ s/[-TZ:]//rg;
    "vndb-list-export-$d->{user}{name}-$date.$ext"
}


TUWF::get qr{/$RE{uid}/list-export/xml}, sub {
    my $uid = tuwf->capture('id');
    return tuwf->resDenied if !ulists_own $uid;
    my $d = data $uid;
    return tuwf->resNotFound if !$d->{user}{id};

    tuwf->resHeader('Content-Disposition', sprintf 'attachment; filename="%s"', filename $d, 'xml');
    tuwf->resHeader('Content-Type', 'application/xml; charset=UTF-8');

    my $fd = tuwf->resFd;
    TUWF::XML->new(
        write  => sub { print $fd $_ for @_ },
        pretty => 2,
        default => 1,
    );
    xml;
    tag 'vndb-export' => version => '1.0', date => $d->{'export-date'}, sub {
        tag user => sub {
            tag name => $d->{user}{name};
            tag url => config->{url}.'/u'.$d->{user}{id};
        };
        tag labels => sub {
            tag label => id => $_->{id}, label => $_->{label}, private => $_->{private}?'true':'false', undef for $d->{labels}->@*;
        };
        tag vns => sub {
            tag vn => id => "v$_->{id}", private => grep(!$_->{private}, $_->{labels}->@*)?'false':'true', sub {
                tag title => length($_->{original}) ? (original => $_->{original}) : (), $_->{title};
                tag label => id => $_->{id}, label => $_->{label}, undef for $_->{labels}->@*;
                tag added => $_->{added};
                tag modified => $_->{lastmod} if $_->{added} ne $_->{lastmod};
                tag vote => timestamp => $_->{vote_date}, fmtvote $_->{vote} if $_->{vote};
                tag started => $_->{started} if $_->{started};
                tag finished => $_->{finished} if $_->{finished};
                tag notes => $_->{notes} if length $_->{notes};
                tag release => id => "r$_->{id}", sub {
                    tag title => length($_->{original}) ? (original => $_->{original}) : (), $_->{title};
                    tag 'release-date' => rdate $_->{released};
                    tag status => $RLIST_STATUS{$_->{status}};
                    tag added => $_->{added};
                } for $_->{releases}->@*;
            } for $d->{vns}->@*;
        };
    };
};

1;
