package VNWeb::HTML;

use v5.26;
use warnings;
use utf8;
use Algorithm::Diff::XS 'sdiff', 'compact_diff';
use Encode 'encode_utf8', 'decode_utf8';
use JSON::XS;
use TUWF ':html5_', 'uri_escape', 'html_escape', 'mkclass';
use Exporter 'import';
use POSIX 'ceil';
use JSON::XS;
use VNDB::Config;
use VNDB::BBCode;
use VNWeb::Auth;
use VNWeb::Validation;
use VNWeb::DB;
use VNDB::Func 'fmtdate';

our @EXPORT = qw/
    clearfloat_
    debug_
    join_
    user_
    elm_
    framework_
    revision_
    paginate_
/;



# Ugly hack to move rendering down below the float object.
sub clearfloat_ { div_ class => 'clearfloat', '' }


# Throw any data structure on the page for inspection.
sub debug_ {
    return if !tuwf->debug;
    # This provides a nice JSON browser in FF, not sure how other browsers render it.
    my $data = uri_escape(JSON::XS->new->canonical->encode($_[0]));
    a_ style => 'margin: 0 5px', title => 'Debug', href => 'data:application/json,'.$data, ' ⚙ ';
}


# Similar to join($sep, map $f->(), @list), but works for HTML generation functions.
#   join_ ', ', sub { a_ href => '#', $_ }, @list;
#   join_ \&br_, \&txt_, @list;
sub join_($&@) {
    my($sep, $f, @list) = @_;
    for my $i (0..$#list) {
        ref $sep ? $sep->() : txt_ $sep if $i > 0;
        local $_ = $list[$i];
        $f->();
    }
}


# Display a user link.
sub user_ {
    my($uid, $username) = @_;
    return lit_ '[deleted]' if !$uid;
    a_ href => "/u$uid", $username;
}


# Instantiate an Elm module
sub elm_($$$) {
    my($mod, $schema, $data) = @_;
    div_ 'data-elm-module' => 'DocEdit',
         'data-elm-flags' => JSON::XS->new->encode($schema->analyze->coerce_for_json($data, unknown => 'remove')), '';
}



sub _sanitize_css {
    # This function is attempting to do the impossible: Sanitize user provided
    # CSS against various attacks.  I'm not expecting this to be bullet-proof.
    # This function doesn't bother with HTML injection as the output will go
    # through xml_escape(). Fortunately, we also have CSP in place to mitigate
    # some problems if they arise, but I'd rather not rely on it.
    # I'd *love* to disable support for external url()'s, but unfortunately
    # many people use that to load images. I'm afraid the only way to work
    # around that is to fetch and cache those URLs on the server.
    local $_ = $_[0];
    s/\\//g; # Get rid of backslashes, could be used to bypass the other regexes.
    s/@(import|charset|font-face)[^\n\;]*.//ig;
    s/javascript\s*://ig; # Not sure 'javascript:' URLs do anything, but just in case.
    s/expression\s*\(//ig; # An old IE thing I guess.
    s/binding\s*://ig; # Definitely don't want bindings.
    $_;
}


sub _head_ {
    my $o = shift;
    my $skin = tuwf->reqGet('skin') || auth->pref('skin') || config->{skin_default};
    $skin = config->{skin_default} if !tuwf->{skins}{$skin};

    title_ $o->{title}.' | vndb';
    link_ rel => 'shortcut icon', href => '/favicon.ico', type => 'image/x-icon';
    link_ rel => 'stylesheet', href => config->{url_static}.'/s/'.$skin.'/style.css?'.config->{version}, type => 'text/css', media => 'all';
    link_ rel => 'search', type => 'application/opensearchdescription+xml', title => 'VNDB VN Search', href => tuwf->reqBaseURI().'/opensearch.xml';
    style_ type => 'text/css', _sanitize_css(auth->pref('customcss')) if auth->pref('customcss');
    if($o->{feeds}) {
        link_ rel => 'alternate', type => 'application/atom+xml', href => "/feeds/announcements.atom", title => 'Site Announcements';
        link_ rel => 'alternate', type => 'application/atom+xml', href => "/feeds/changes.atom",       title => 'Recent Changes';
        link_ rel => 'alternate', type => 'application/atom+xml', href => "/feeds/posts.atom",         title => 'Recent Posts';
    }
    meta_ name => 'csrf-token', content => auth->csrftoken;
    meta_ name => 'robots', content => 'noindex' if defined $o->{index} && !$o->{index};

    # Opengraph metadata
    if($o->{og}) {
        $o->{og}{site_name} ||= 'The Visual Novel Database';
        $o->{og}{type}      ||= 'object';
        $o->{og}{image}     ||= 'https://s.vndb.org/s/angel/bg.jpg'; # TODO: Something better
        $o->{og}{url}       ||= tuwf->reqURI;
        $o->{og}{title}     ||= $o->{title};
        meta_ property => "og:$_", content => ($o->{og}{$_} =~ s/\n/ /gr) for sort keys $o->{og}->%*;
    }
}


sub _menu_ {
    my $o = shift;
    div_ class => 'menubox', sub {
        h2_ 'Menu';
        div_ sub {
            a_ href => '/',      'Home'; br_;
            a_ href => '/v/all', 'Visual novels'; br_;
            b_ class => 'grayedout', '> '; a_ href => '/g', 'Tags'; br_;
            a_ href => '/r',     'Releases'; br_;
            a_ href => '/p/all', 'Producers'; br_;
            a_ href => '/s/all', 'Staff'; br_;
            a_ href => '/c/all', 'Characters'; br_;
            b_ class => 'grayedout', '> '; a_ href => '/i', 'Traits'; br_;
            a_ href => '/u/all', 'Users'; br_;
            a_ href => '/hist',  'Recent changes'; br_;
            a_ href => '/t',     'Discussion board'; br_;
            a_ href => '/d6',    'FAQ'; br_;
            a_ href => '/v/rand','Random visual novel'; br_;
            a_ href => '/d11',   'API'; lit_ ' - ';
            a_ href => '/d14',   'Dumps'; lit_ ' - ';
            a_ href => '/d18',   'Query';
        };
        form_ action => '/v/all', method => 'get', id => 'search', sub {
            fieldset_ sub {
                legend_ 'Search';
                input_ type => 'text', class => 'text', id => 'sq', name => 'sq', value => $o->{search}||'', placeholder => 'search';
                input_ type => 'submit', class => 'submit', value => 'Search';
            }
        }
    };

    div_ class => 'menubox', sub {
        my $uid = sprintf '/u%d', auth->uid;
        my $nc = auth && tuwf->dbVali('SELECT count(*) FROM notifications WHERE uid =', \auth->uid, 'AND read IS NULL');
        h2_ sub { a_ href => $uid, ucfirst auth->username };
        div_ sub {
            a_ href => "$uid/edit", 'My Profile'; br_;
            a_ href => "$uid/list", 'My Visual Novel List'; br_;
            a_ href => "$uid/votes",'My Votes'; br_;
            a_ href => "$uid/wish", 'My Wishlist'; br_;
            a_ href => "$uid/notifies", $nc ? (class => 'notifyget') : (), 'My Notifications'.($nc?" ($nc)":''); br_;
            a_ href => "$uid/hist", 'My Recent Changes'; br_;
            a_ href => '/g/links?u='.auth->uid, 'My Tags'; br_;
            br_;
            if(auth->permEdit) {
                a_ href => '/v/add', 'Add Visual Novel'; br_;
                a_ href => '/p/add', 'Add Producer'; br_;
                a_ href => '/s/new', 'Add Staff'; br_;
                a_ href => '/c/new', 'Add Character'; br_;
            }
            br_;
            a_ href => "$uid/logout", 'Logout';
        }
    } if auth;

    div_ class => 'menubox', sub {
        h2_ 'User menu';
        div_ sub {
            my $ref = uri_escape tuwf->reqPath().tuwf->reqQuery();
            a_ href => "/u/login?ref=$ref", 'Login'; br_;
            a_ href => '/u/newpass', 'Password reset'; br_;
            a_ href => '/u/register', 'Register'; br_;
        }
    } if !auth;

    div_ class => 'menubox', sub {
        h2_ 'Database Statistics';
        div_ sub {
            dl_ sub {
                dt_ 'Visual Novels'; dd_ tuwf->{stats}{vn};
                dt_ sub { b_ class => 'grayedout', '> '; lit_ 'Tags' };
                                     dd_ tuwf->{stats}{tags};
                dt_ 'Releases';      dd_ tuwf->{stats}{releases};
                dt_ 'Producers';     dd_ tuwf->{stats}{producers};
                dt_ 'Staff';         dd_ tuwf->{stats}{staff};
                dt_ 'Characters';    dd_ tuwf->{stats}{chars};
                dt_ sub { b_ class => 'grayedout', '> '; lit_ 'Traits' };
                                     dd_ tuwf->{stats}{traits};
            };
            clearfloat_;
        }
    };
}


sub _footer_ {
    my $q = tuwf->dbRow('SELECT vid, quote FROM quotes ORDER BY RANDOM() LIMIT 1');
    if($q && $q->{vid}) {
        lit_ '"';
        a_ href => "/v$q->{vid}", style => 'text-decoration: none', $q->{quote};
        txt_ '"';
        br_;
    }
    txt_ sprintf 'vndb %s | ', config->{version};
    a_ href => '/d7', 'about us';
    lit_ ' | ';
    a_ href => 'irc://irc.synirc.net/vndb', '#vndb';
    lit_ ' | ';
    a_ href => sprintf('mailto:%s', config->{admin_email}), config->{admin_email};
    lit_ ' | ';
    a_ href => config->{source_url}, 'source';

    if(tuwf->debug) {
        lit_ ' | ';
        tuwf->dbCommit; # Hack to measure the commit time

        my $sql = uri_escape join "\n", map {
            my($sql, $params, $time) = @$_;
            sprintf "  [%6.2fms] %s | %s", $time*1000, $sql,
            join ', ', map "$_:".DBI::neat($params->{$_}),
            sort { $a =~ /^[0-9]+$/ && $b =~ /^[0-9]+$/ ? $a <=> $b : $a cmp $b }
            keys %$params;
        } tuwf->{_TUWF}{DB}{queries}->@*;
        a_ href => 'data:text/plain,'.$sql, 'SQL';
        lit_ ' | ';

        my $modules = uri_escape join "\n", sort keys %INC;
        a_ href => 'data:text/plain,'.$modules, 'Modules';
    }
}


sub _maintabs_ {
    my $opt = shift;
    my($t, $o, $sel) = @{$opt}{qw/type dbobj tab/};
    return if !$t || !$o;
    return if $t eq 'g' && !auth->permTagmod;

    my $id = $t.$o->{id};

    my sub t {
        my($tabname, $url, $text) = @_;
        li_ mkclass(tabselected => $tabname eq ($sel||'')), sub {
            a_ href => $url, $text;
        };
    };

    ul_ class => 'maintabs', sub {
        t hist => "/$id/hist", 'history' if $t =~ /[uvrpcsd]/;

        if($t =~ /[uvp]/) {
            my $cnt = tuwf->dbVali(q{
                SELECT COUNT(*)
                  FROM threads_boards tb
                  JOIN threads t ON t.id = tb.tid
                 WHERE}, { 'tb.type' => $t, 'tb.iid' => $o->{id}, 't.hidden' => 0, 't.private' => 0 });
            t disc => "/t/$id", "discussions ($cnt)";
        };
        t posts => "/$id/posts", 'posts' if $t eq 'u';

        do {
            t wish  => "/$id/wish", 'wishlist';
            t votes => "/$id/votes", 'votes';
            t list  => "/$id/list", 'list';
        } if $t eq 'u' && (
            auth->permUsermod || (auth && auth->uid == $o->{id})
            || !(exists $o->{hide_list}
                ? $o->{hide_list}
                : tuwf->dbVali('SELECT value FROM users_prefs WHERE', { uid => $o->{id}, key => 'hide_list' }))
        );

        t tagmod => "/$id/tagmod", 'modify tags' if $t eq 'v' && auth->permTag && !$o->{entry_hidden};
        t copy => "/$id/copy", 'copy' if $t =~ /[rc]/ && can_edit $t, $o;
        t edit => "/$id/edit", 'edit' if can_edit $t, $o;
        t del => "/$id/del", 'remove' if $t eq 'u' && auth && auth->uid == 2;
        t releases => "/$id/releases", 'releases' if $t eq 'v';

        t rgraph => "/$id/rg", 'relations'
            if $t =~ /[vp]/ && (exists $o->{rgraph} ? $o->{rgraph}
                : tuwf->dbVali('SELECT rgraph FROM', $t eq 'v' ? 'vn' : 'producers', 'WHERE id =', \$o->{id}));

        t '' => "/$id", $id;
    }
}


# Returns 1 if the page contents should be hidden.
sub _hidden_msg_ {
    my $o = shift;

    die "Can't use hiddenmsg on an object that is missing 'entry_hidden'" if !exists $o->{dbobj}{entry_hidden};
    return 0 if !$o->{dbobj}{entry_hidden};

    my $msg = tuwf->dbVali(
        'SELECT comments
           FROM changes
          WHERE', { type => $o->{type}, itemid => $o->{dbobj}{id} },
         'ORDER BY id DESC LIMIT 1'
    );
    my $board = $o->{type} =~ /[vp]/ ? $o->{type}.$o->{dbobj}{id} : 'db'; # TODO: Link to VN board for characters and releases?
    div_ class => 'mainbox', sub {
        h1_ $o->{title};
        div_ class => 'warning', sub {
            h2_ 'Item deleted';
            p_ sub {
                txt_ 'This item has been deleted from the database. You may file a request on the ';
                a_ href => "/t/$board", "discussion board";
                txt_ ' if you believe that this entry should be restored.';
                br_;
                br_;
                lit_ bb2html $msg;
            }
        }
    };
    !auth->permDbmod # dbmods can still see the page
}


# Options:
#   title      => $title
#   index      => 1/0, default 1
#   feeds      => 1/0
#   search     => $query
#   og         => { opengraph metadata }
#   type       => Database entry type (used for the main tabs & hidden message)
#   dbobj      => Database entry object (used for the main tabs & hidden message)
#                 Recognized object fields: id, entry_hidden, entry_locked
#   tab        => Current tab, or empty for the main tab
#   hiddenmsg  => 1/0, if true and dbobj is 'hidden', a message will be displayed
#                      and the content function will not be called.
#   sub { content }
sub framework_ {
    my $cont = pop;
    my %o = @_;

    html_ lang => 'en', sub {
        head_ sub { _head_ \%o };
        body_ sub {
            div_ id => 'bgright', ' ';
            div_ id => 'header', sub { h1_ sub { a_ href => '/', 'the visual novel database' } };
            div_ id => 'menulist', sub { _menu_ \%o };
            div_ id => 'maincontent', sub {
                _maintabs_ \%o;
                $cont->() unless $o{hiddenmsg} && _hidden_msg_ \%o;
                div_ id => 'footer', \&_footer_;
            };
            script_ type => 'application/javascript', src => config->{url_static}.'/f/v2rw.js', '';
        }
    }
}




sub _revision_header_ {
    my($type, $obj) = @_;
    b_ "Revision $obj->{chrev}";
    if(auth) {
        lit_ ' (';
        a_ href => "/$type$obj->{id}.$obj->{chrev}/edit", $obj->{chrev} == $obj->{maxrev} ? 'edit' : 'revert to';
        if($obj->{rev_requester}) {
            lit_ ' / ';
            a_ href => "/t/u$obj->{rev_requester}/new?title=Regarding%20$type$obj->{id}.$obj->{chrev}", 'msg user';
        }
        lit_ ')';
    }
    br_;
    lit_ 'By ';
    user_ @{$obj}{'rev_requester', 'rev_username'};
    lit_ ' on ';
    txt_ fmtdate $obj->{rev_added}, 'full';
}


sub _revision_fmtval_ {
    my($opt, $val) = @_;
    return i_ '[empty]' if !defined $val || !length $val;
    return lit_ html_escape $val if !$opt->{fmt};
    return txt_ $val ? 'True' : 'False' if $opt->{fmt} eq 'bool';
    local $_ = $val;
    $opt->{fmt}->();
}


sub _revision_fmtcol_ {
    my($opt, $i, $l) = @_;

    my $ctx = 100; # Number of characters of context in textual diffs
    my sub sep_ { b_ class => 'standout', '<...>' }; # Context separator

    td_ class => 'tcval', sub {
        join_ $opt->{join}||\&br_, sub {
            my($ch, $old, $new, $diff) = @$_;
            my $val = $_->[$i];

            if($diff) {
                my $lastchunk = int (($#$diff-2)/2);
                for my $n (0..$lastchunk) {
                    my $a = decode_utf8 join '', @{$old}[ $diff->[$n*2]   .. $diff->[$n*2+2]-1 ];
                    my $b = decode_utf8 join '', @{$new}[ $diff->[$n*2+1] .. $diff->[$n*2+3]-1 ];

                    # Difference, highlight and display in full
                    if($n % 2) {
                        b_ class => $i == 1 ? 'diff_del' : 'diff_add', sub { lit_ html_escape $i == 1 ? $a : $b };
                    # Short context, display in full
                    } elsif(length $a < $ctx*3) {
                        lit_ html_escape $a;
                    # Longer context, abbreviate
                    } elsif($n == 0) {
                        sep_; br_; lit_ html_escape substr $a, -$ctx;
                    } elsif($n == $lastchunk) {
                        lit_ html_escape substr $a, 0, $ctx; br_; sep_;
                    } else {
                        lit_ html_escape substr $a, 0, $ctx;
                        br_; br_; sep_; br_; br_;
                        lit_ html_escape substr $a, -$ctx;
                    }
                }

            } elsif(@$l > 2 && $i == 2 && ($ch eq '+' || $ch eq 'c')) {
                b_ class => 'diff_add', sub { _revision_fmtval_ $opt, $val }
            } elsif(@$l > 2 && $i == 1 && ($ch eq '-' || $ch eq 'c')) {
                b_ class => 'diff_del', sub { _revision_fmtval_ $opt, $val }
            } elsif($ch eq 'c' || $ch eq 'u') {
                _revision_fmtval_ $opt, $val;
            }
        }, @$l;
    };
}


sub _revision_diff_ {
    my($type, $old, $new, $field, $name, %opt) = @_;

    # First do a diff on the raw field elements.
    # (if the field is a scalar, it's considered a single element and the diff just tests equality)
    my @old = ref $old->{$field} eq 'ARRAY' ? $old->{$field}->@* : ($old->{$field});
    my @new = ref $new->{$field} eq 'ARRAY' ? $new->{$field}->@* : ($new->{$field});

    my $JS = JSON::XS->new->utf8->allow_nonref;
    my $l = sdiff \@old, \@new, sub { $JS->encode($_[0]) };
    return if !grep $_->[0] ne 'u', @$l;

    # Now check if we should do a textual diff on the changed items.
    for my $item (@$l) {
        last if $opt{fmt};
        next if $item->[0] ne 'c' || ref $item->[1] || ref $item->[2];
        next if !defined $item->[1] || !defined $item->[2];
        next if length $item->[1] < 10 || length $item->[2] < 10;

        # Do a word-based diff if this is a large chunk of text, otherwise character-based.
        my $split = length $item->[1] > 1024 ? qr/([ ,\n]+)/ : qr//;
        $item->[1] = [map encode_utf8($_), split $split, $item->[1]];
        $item->[2] = [map encode_utf8($_), split $split, $item->[2]];
        $item->[3] = compact_diff $item->[1], $item->[2];
    }

    tr_ sub {
        td_ $name;
        _revision_fmtcol_ \%opt, 1, $l;
        _revision_fmtcol_ \%opt, 2, $l;
    }
}


sub _revision_cmp_ {
    my($type, $old, $new, @fields) = @_;

    table_ class => 'stripe', sub {
        thead_ sub {
            tr_ sub {
                td_ ' ';
                td_ sub { _revision_header_ $type, $old };
                td_ sub { _revision_header_ $type, $new };
            };
            tr_ sub {
                td_ ' ';
                td_ colspan => 2, sub {
                    b_ "Edit summary for revision $new->{chrev}";
                    br_;
                    br_;
                    lit_ bb2html $new->{rev_comments}||'-';
                };
            };
        };
        _revision_diff_ $type, $old, $new, @$_ for(
            [ hidden => 'Hidden', fmt => 'bool' ],
            [ locked => 'Locked', fmt => 'bool' ],
            @fields,
        );
    };
}


# Revision info box.
#
# Arguments: $type, $object, \&enrich_for_diff, @fields
#
# The given $object is assumed to originate from VNWeb::DB::db_entry() and
# should have the 'id', 'hidden', 'locked', 'chrev' and 'maxrev' fields in
# addition to those specified in @fields.
#
# \&enrich_for_diff is a subroutine that is given an earlier revision returned
# by db_entry() and should enrich this object with information necessary for
# diffing. $object is assumed to have already been enriched in this way (it is
# assumed that a page will need to fetch and enrich such an $object for its own
# display purposes anyway).
#
# @fields is a list of arrayrefs with the following form:
#
#   [ field_name, display_name, %options ]
#
# Options:
#   fmt     => 'bool'||sub {$_}  - Formatting function for individual values.
#                 If not given, the field is rendered as plain text and changes are highlighted with a diff.
#   join    => sub{}             - HTML to join multi-value fields, defaults to \&br_.
sub revision_ {
    my($type, $new, $enrich, @fields) = @_;

    my $old = $new->{chrev} == 1 ? undef : db_entry $type, $new->{id}, $new->{chrev} - 1;
    $enrich->($old) if $old;

    enrich_merge chid => sql(
        'SELECT c.id AS chid, c.comments as rev_comments,', sql_totime('c.added'), 'as rev_added
              , c.requester as rev_requester, u.username as rev_username
           FROM changes c LEFT JOIN users u ON u.id = c.requester
          WHERE c.id IN'),
        $new, $old||();

    div_ class => 'mainbox revision', sub {
        h1_ "Revision $new->{chrev}";

        a_ class => 'prev', href => sprintf('/%s%d.%d', $type, $new->{id}, $new->{chrev}-1), '<- earlier revision' if $new->{chrev} > 1;
        a_ class => 'next', href => sprintf('/%s%d.%d', $type, $new->{id}, $new->{chrev}+1), 'later revision ->' if $new->{chrev} < $new->{maxrev};
        p_ class => 'center', sub { a_ href => "/$type$new->{id}", $type.$new->{id} };

        div_ class => 'rev', sub {
            _revision_header_ $type, $new;
            br_;
            b_ 'Edit summary';
            br_; br_;
            lit_ bb2html $new->{rev_comments}||'-';
        } if !$old;

        _revision_cmp_ $type, $old, $new, @fields if $old;
    };
}


# Creates next/previous buttons (tabs), if needed.
# Arguments:
#   url generator (code reference that takes $_ and returns a url for that page).
#   current page number (1..n),
#   nextpage (0/1 or, if the full count is known: [$total, $perpage]),
#   alignment (t/b)
sub paginate_ {
    my($url, $p, $np, $al) = @_;
    my($cnt, $pp) = ref($np) ? @$np : ($p+$np, 1);
    return if $p == 1 && $cnt <= $pp;

    my sub tab_ {
        my($left, $page, $label) = @_;
        li_ mkclass(left => $left), sub {
            local $_ = $page;
            my $u = $url->();
            a_ href => $u, $label;
        }
    }
    my sub ell_ {
        my($left) = @_;
        li_ mkclass(ellipsis => 1, left => $left), sub { b_ '⋯' };
    }
    my $nc = 5; # max. number of buttons on each side

    ul_ class => 'maintabs browsetabs ' . ($al eq 't' ? 'notfirst' : 'bottom'), sub {
        $p > 2     and ref $np and tab_ 1, 1, '« first';
        $p > $nc+1 and ref $np and ell_ 1;
        $p > $_    and ref $np and tab_ 1, $p-$_, $p-$_ for (reverse 2..($nc>$p-2?$p-2:$nc-1));
        $p > 1                 and tab_ 1, $p-1, '‹ previous';

        my $l = ceil($cnt/$pp)-$p+1;
        $l > 2     and tab_ 0, $l+$p-1, 'last »';
        $l > $nc+1 and ell_ 0;
        $l > $_    and tab_ 0, $p+$_, $p+$_ for (reverse 2..($nc>$l-2?$l-2:$nc-1));
        $l > 1     and tab_ 0, $p+1, 'next ›';
    }
}

1;
