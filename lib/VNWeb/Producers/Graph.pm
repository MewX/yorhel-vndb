package VNWeb::Producers::Graph;

use VNWeb::Prelude;
use AnyEvent::Util;
use TUWF::XML 'xml_escape';
use Encode 'encode_utf8', 'decode_utf8';


# Given a starting ID, an array of {id0,id1} relation hashes and a number of
# nodes to be included, returns a hash of (id=>{id, distance, rels}) nodes.
#
# This is basically a breath-first search that prioritizes nodes with fewer
# relations.  Direct relations with the starting node are always included,
# regardless of $num.
sub gen_nodes {
    my($id, $rel, $num) = @_;

    my %rels;
    push $rels{$_->{id0}}->@*, $_->{id1} for @$rel;

    my %nodes;
    my sub add {
        my($n, $dist) = @_;
        if(!$nodes{$n}) {
            $nodes{$n} = { id => $n, rels => $rels{$n}, distance => $dist };
            $num--;
        }
    }

    my @q = ([$id,0]);
    while(@q && ($num > 0 || $q[0][1] <= 1)) {
        my($n, $dist) = shift(@q)->@*;
        add $n, $dist++;
        push @q, map [$_, $dist], sort { $rels{$a}->@* <=> $rels{$b}->@* } grep !$nodes{$_}, $rels{$n}->@*;
    }

    \%nodes;
}


sub dot2svg {
    my($dot) = @_;

    $dot = encode_utf8 $dot;
    local $SIG{CHLD} = undef; # Fixed in TUWF 4d8a59cc1dfb5f919298ee495b8865f7872f6cbb
    my $e = run_cmd([config->{graphviz_path},'-Tsvg'], '<', \$dot, '>', \my $out, '2>', \my $err)->recv;
    warn "graphviz STDERR: $err\n" if chomp $err;
    $e and die "Failed to run graphviz";

    # - Remove <?xml> declaration and <!DOCTYPE> (not compatible with embedding in HTML5)
    # - Remove comments (unused)
    # - Remove <title> elements (unused)
    # - Remove first <polygon> element (emulates a background color)
    # - Replace stroke and fill attributes with classes (so that coloring is done in CSS)
    # (I used to have an implementation based on XML::Parser, but regexes are so much faster...)
    decode_utf8($out)
        =~ s/<\?xml.+?\?>//r
        =~ s/<!DOCTYPE[^>]*>//r
        =~ s/<!--.*?-->//srg
        =~ s/<title>.+?<\/title>//gr
        =~ s/<polygon.+?\/>//r
        =~ s/(?:stroke|fill)="([^"]+)"/$1 eq '#111111' ? 'class="border"' : $1 eq '#222222' ? 'class="nodebg"' : ''/egr;
}


sub gen_dot {
    my($rel, $nodes, $params) = @_;

    # Attempt to figure out a good 'rankdir' to minimize the width of the
    # graph. Ideally we'd just generate two graphs and pick the least wide one,
    # but that's way too slow. Graphviz tends to put adjacent nodes next to
    # each other, so going for the LR (left-right) rank order tends to work
    # better with large fan-out, while TB (top-bottom) often results in less
    # wide graphs for large depths.
    #my $max_distance = max map $_->{distance}, values %$nodes;
    my $max_fanout = max map scalar grep($nodes->{$_}, $_->{rels}->@*), values %$nodes;
    my $rankdir = $max_fanout > 6 ? 'LR' : 'TB';

    my $dot =
        qq|graph rgraph {\n|.
        qq|\trankdir=$rankdir\n|.
        qq|\tnodesep=0.1\n|.
        qq|\tnode [ fontname = "Arial", shape = "plaintext", fontsize = 8, color = "#111111" ]\n|.
        qq|\tedge [ labeldistance = 2.5, labelangle = -20, labeljust = 1, minlen = 2, dir = "both",|.
        qq| fontname = "Arial", fontsize = 7, arrowsize = 0.7, color = "#111111" ]\n|;

    for my $n (sort { $a->{id} <=> $b->{id} } values %$nodes) {
        my $name = xml_escape shorten $n->{name}, 27;
        my $tooltip = $n->{name} =~ s/\\/\\\\/rg =~ s/"/\\"/rg =~ s/&/&amp;/rg;
        my $nodeid = $n->{distance} == 0 ? 'id = "graph_current", ' : '';
        $dot .=
            qq|\tn$n->{id} [ $nodeid URL = "/p$n->{id}", tooltip = "$tooltip", label=<|.
            qq|<TABLE CELLSPACING="0" CELLPADDING="2" BORDER="0" CELLBORDER="1" BGCOLOR="#222222">|.
            qq|<TR><TD COLSPAN="2" ALIGN="CENTER" CELLPADDING="3"><FONT POINT-SIZE="9">  $name  </FONT></TD></TR>|.
            qq|<TR><TD ALIGN="CENTER"> $LANGUAGE{$n->{lang}} </TD><TD ALIGN="CENTER"> $PRODUCER_TYPE{$n->{type}} </TD></TR>|.
            qq|</TABLE>> ]\n|;

        my $notshown = grep !$nodes->{$_}, $n->{rels}->@*;
        $dot .=
            qq|\tns$n->{id} [ URL = "/p$n->{id}/rg$params", label="$notshown more..." ]\n|.
            qq|\tn$n->{id} -- ns$n->{id} [ dir = "forward", style = "dashed" ]\n|
            if $notshown;
    }

    for (grep $_->{id0} < $_->{id1} && $nodes->{$_->{id0}} && $nodes->{$_->{id1}}, @$rel) {
        my $lbl1 = $PRODUCER_RELATION{$_->{relation}}{txt};
        my $lbl2 = $PRODUCER_RELATION{ $PRODUCER_RELATION{$_->{relation}}{reverse} }{txt};
        $dot .= "\tn$_->{id0} -- n$_->{id1} [".($lbl1 eq $lbl2 ? qq{label="$lbl1"} : qq{headlabel="$lbl1", taillabel="$lbl2"})."]\n";
    }

    $dot .= "}\n";
    $dot
}


TUWF::get qr{/$RE{pid}/rg}, sub {
    my $id = tuwf->capture(1);
    my $num = tuwf->validate(get => num => { uint => 1, onerror => 15 })->data;
    my $p = tuwf->dbRowi('SELECT id, name, original, hidden AS entry_hidden, locked AS entry_locked FROM producers WHERE id =', \$id);

    # Big list of { id0, id1, relation } hashes.
    # Each relation is included twice, with id0 and id1 reversed.
    my $rel = tuwf->dbAlli(q{
        WITH RECURSIVE rel(id0, id1, relation) AS (
            SELECT id, pid, relation FROM producers_relations WHERE id =}, \$id, q{
            UNION
            SELECT id, pid, pr.relation FROM producers_relations pr JOIN rel r ON pr.id = r.id1
        ) SELECT * FROM rel ORDER BY id0
    });
    return tuwf->resNotFound if !@$rel;

    # Fetch the nodes
    my $nodes = gen_nodes $id, $rel, $num;
    enrich_merge id => 'SELECT id, name, lang, type FROM producers WHERE id IN', values %$nodes;

    my $total_nodes = keys { map +($_->{id0},1), @$rel }->%*;
    my $visible_nodes = keys %$nodes;

    framework_ title => "Relations for $p->{name}", type => 'p', dbobj => $p, tab => 'rg',
    sub {
        div_ class => 'mainbox', sub {
            h1_ "Relations for $p->{name}";
            p_ sub {
                txt_ sprintf "Displaying %d out of %d related producers.", $visible_nodes, $total_nodes;
                br_;
                txt_ "Adjust graph size: ";
                join_ ', ', sub {
                    if($_ == min $num, $total_nodes) {
                        txt_ $_ ;
                    } else {
                        a_ href => "/p$id/rg?num=$_", $_;
                    }
                }, grep($_ < $total_nodes, 10, 15, 25, 50, 75, 100, 150, 250, 500, 750, 1000), $total_nodes;
                txt_ '.';
            } if $total_nodes > 10;
            p_ class => 'center', sub { lit_ dot2svg gen_dot $rel, $nodes, $num == 15 ? '' : "?num=$num" };
            debug_ +{ nodes => $nodes, rel => $rel };
        }
    };
};

1;
