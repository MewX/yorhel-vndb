package VNWeb::Discussions::Board;

use VNWeb::Prelude;
use VNWeb::Discussions::Lib;


TUWF::get qr{/t/(all|$BOARD_RE)}, sub {
    my($type, $id) = tuwf->capture(1) =~ /^([^0-9]+)([0-9]*)$/;

    my $page = tuwf->validate(get => p => { upage => 1 })->data;

    my $obj = $id ? dbobj $type, $id : undef;
    return tuwf->resNotFound if $id && !$obj->{id};

    my $ititle = $obj && ($obj->{title} || user_displayname $obj);
    my $title = $obj ? "Related discussions for $ititle" : $type eq 'all' ? 'All boards' : $BOARD_TYPE{$type}{txt};
    my $createurl = '/t/'.($id ? $type.$id : $type eq 'db' ? 'db' : 'ge').'/new';

    framework_ title => $title, type => $type, dbobj => $obj, tab => 'disc',
    sub {
        div_ class => 'mainbox', sub {
            h1_ $title;
            boardtypes_ $type;
            boardsearch_ $type if !$id;
            p_ class => 'center', sub {
                a_ href => $createurl, 'Start a new thread';
            } if can_edit t => {};
        };

        threadlist_
            where    => $type ne 'all' && sql('t.id IN(SELECT tid FROM threads_boards WHERE type =', \$type, $id ? ('AND iid =', \$id) : (), ')'),
            boards   => $type ne 'all' && sql('NOT (tb.type =', \$type, 'AND tb.iid =', \($id||0), ')'),
            results  => 50,
            sort     => $type eq 'an' ? 't.id DESC' : undef,
            page     => $page,
            paginate => sub { "?p=$_" }
        or div_ class => 'mainbox', sub {
            h1_ 'An empty board';
            p_ class => 'center', sub {
                txt_ "Nobody's started a discussion on this board yet. Why not ";
                a_ href => $createurl, 'create a new thread';
                txt_ ' yourself?';
            }
        }
    };
};

1;
