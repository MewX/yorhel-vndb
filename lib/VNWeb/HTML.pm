package VNWeb::HTML;

use v5.26;
use warnings;
use utf8;
use Algorithm::Diff::XS 'sdiff', 'compact_diff';
use Encode 'encode_utf8', 'decode_utf8';
use JSON::XS;
use TUWF ':html5_', 'uri_escape', 'html_escape', 'mkclass';
use Exporter 'import';
use POSIX 'ceil', 'strftime';
use Carp 'croak';
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
    user_ user_displayname
    rdate rdate_
    spoil_
    elm_
    framework_
    revision_
    paginate_
    sortable_
    searchbox_
    itemmsg_
    editmsg_
/;


# Ugly hack to move rendering down below the float object.
sub clearfloat_ { div_ class => 'clearfloat', '' }


# Throw any data structure on the page for inspection.
sub debug_ {
    return if !tuwf->debug;
    # This provides a nice JSON browser in FF, not sure how other browsers render it.
    my $data = uri_escape(JSON::XS->new->canonical->allow_nonref->encode($_[0]));
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


# Display a user link, the given object must have the columns as fetched using DB::sql_user().
# Args: $object, $prefix, $capital
sub user_ {
    my $obj = shift;
    my $prefix = shift||'user_';
    my $capital = shift;
    my sub f($) { $obj->{"${prefix}$_[0]"} }

    return b_ class => 'grayedout', 'anonymous' if !f 'id';
    my $fancy = !(auth->pref('nodistract_can') && auth->pref('nodistract_nofancy'));
    my $uniname = f 'uniname_can' && f 'uniname';
    a_ href => '/u'.f('id'),
        $fancy && $uniname ? (title => f('name'), $uniname) :
        (!$fancy && $uniname ? (title => $uniname) : (), $capital ? ucfirst f 'name' : f 'name');
    txt_ '⭐' if $fancy && f 'support_can' && f 'support_enabled';
}


# Similar to user_(), but just returns a string. Mainly for use in titles.
sub user_displayname {
    my $obj = shift;
    my $prefix = shift||'user_';
    my sub f($) { $obj->{"${prefix}$_[0]"} }

    return 'anonymous' if !f 'id';
    my $fancy = !(auth->pref('nodistract_can') && auth->pref('nodistract_nofancy'));
    $fancy && f 'uniname_can' && f 'uniname' ? f 'uniname' : f 'name'
}


# Format a release date as a string.
sub rdate {
    my($y, $m, $d) = ($1, $2, $3) if sprintf('%08d', shift||0) =~ /^([0-9]{4})([0-9]{2})([0-9]{2})$/;
    $y ==    0 ? 'unknown' :
    $y == 9999 ? 'TBA' :
    $m ==   99 ? sprintf('%04d', $y) :
    $d ==   99 ? sprintf('%04d-%02d', $y, $m) :
                 sprintf('%04d-%02d-%02d', $y, $m, $d);
}

# Display a release date.
sub rdate_ {
    my $str = rdate $_[0];
    $_[0] > strftime('%Y%m%d', gmtime) ? b_ class => 'future', $str : txt_ $str;
}


# Spoiler indication supscript (used for tags & traits)
sub spoil_ {
    sup_ title => 'Minor spoiler', 'S' if $_[0] == 1;
    sup_ title => 'Major spoiler', class => 'standout', 'S' if $_[0] == 2;
}


# Instantiate an Elm module.
# $schema can be set to the string 'raw' to encode the JSON directly, without a normalizing through a schema.
sub elm_ {
    my($mod, $schema, $data, $placeholder) = @_;
    die "Elm data without a schema" if defined $data && !defined $schema;
    push tuwf->req->{pagevars}{elm}->@*, [ $mod, $data ? ($schema eq 'raw' ? $data : $schema->analyze->coerce_for_json($data, unknown => 'remove')) : () ];
    div_ id => sprintf('elm%d', $#{ tuwf->req->{pagevars}{elm} }), $placeholder//'';
}



sub _sanitize_css {
    # This function is attempting to do the impossible: Sanitize user provided
    # CSS against various attacks.  I'm not expecting this to be bullet-proof.
    # Fortunately, we also have CSP in place to mitigate some problems if they
    # arise, but I'd rather not rely on it.  I'd *love* to disable support for
    # external url()'s, but unfortunately many people use that to load images.
    # I'm afraid the only way to work around that is to fetch and cache those
    # URLs on the server.
    local $_ = $_[0];
    s/\\//g; # Get rid of backslashes, could be used to bypass the other regexes.
    s/@(import|charset|font-face)[^\n\;]*.//ig;
    s/javascript\s*://ig; # Not sure 'javascript:' URLs do anything, but just in case.
    s/expression\s*\(//ig; # An old IE thing I guess.
    s/binding\s*://ig; # Definitely don't want bindings.
    s/&/&amp;/g;
    s/</&lt;/g;
    $_;
}


sub _head_ {
    my $o = shift;

    my $fancy = !(auth->pref('nodistract_can') && auth->pref('nodistract_nofancy'));
    my $pubskin = $fancy && $o->{type} && $o->{type} eq 'u' && $o->{dbobj} ? tuwf->dbRowi(
        'SELECT customcss, skin FROM users WHERE pubskin_can AND pubskin_enabled AND id =', \$o->{dbobj}{id}
    ) : {};
    my $skin = tuwf->reqGet('skin') || $pubskin->{skin} || auth->pref('skin') || '';
    $skin = config->{skin_default} if !tuwf->{skins}{$skin};
    my $customcss = $pubskin->{customcss} || auth->pref('customcss');

    meta_ charset => 'utf-8';
    title_ $o->{title}.' | vndb';
    base_ href => tuwf->reqURI();
    link_ rel => 'shortcut icon', href => '/favicon.ico', type => 'image/x-icon';
    link_ rel => 'stylesheet', href => config->{url_static}.'/s/'.$skin.'/style.css?'.config->{version}, type => 'text/css', media => 'all';
    link_ rel => 'search', type => 'application/opensearchdescription+xml', title => 'VNDB VN Search', href => tuwf->reqBaseURI().'/opensearch.xml';
    style_ type => 'text/css', sub { lit_ _sanitize_css $customcss } if $customcss;
    if($o->{feeds}) {
        link_ rel => 'alternate', type => 'application/atom+xml', href => "/feeds/announcements.atom", title => 'Site Announcements';
        link_ rel => 'alternate', type => 'application/atom+xml', href => "/feeds/changes.atom",       title => 'Recent Changes';
        link_ rel => 'alternate', type => 'application/atom+xml', href => "/feeds/posts.atom",         title => 'Recent Posts';
    }
    meta_ name => 'csrf-token', content => auth->csrftoken;
    meta_ name => 'robots', content => 'noindex' if !$o->{index} || tuwf->reqGet('view');

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

    div_ id => 'support', sub {
        a_ href => 'https://www.patreon.com/vndb', id => 'patreon', sub {
            img_ src => config->{url_static}.'/f/patreon.png', alt => 'Support VNDB on Patreon', width => 160, height => 38;
        };
        a_ href => 'https://www.subscribestar.com/vndb', id => 'subscribestar', sub {
            img_ src => config->{url_static}.'/f/subscribestar.png', alt => 'Support VNDB on SubscribeStar', width => 160, height => 38;
        };
    } if !(auth->pref('nodistract_can') && auth->pref('nodistract_noads'));

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
        my $support_opt = auth->pref('nodistract_can') || auth->pref('support_can') || auth->pref('uniname_can') || auth->pref('pubskin_can');
        h2_ sub { user_ auth->user, 'user_', 1 };
        div_ sub {
            a_ href => "$uid/edit", 'My Profile'; txt_ '⭐' if $support_opt && !auth->pref('nodistract_nofancy'); br_;
            a_ href => "$uid/ulist?vnlist=1", 'My Visual Novel List'; br_;
            a_ href => "$uid/ulist?votes=1",'My Votes'; br_;
            a_ href => "$uid/ulist?wishlist=1", 'My Wishlist'; br_;
            a_ href => "$uid/notifies", $nc ? (class => 'notifyget') : (), 'My Notifications'.($nc?" ($nc)":''); br_;
            a_ href => "$uid/hist", 'My Recent Changes'; br_;
            a_ href => '/g/links?u='.auth->uid, 'My Tags'; br_;
            br_;
            if(auth->permImgvote) {
                a_ href => '/img/vote', 'Image Flagging'; br_;
            }
            if(auth->permEdit) {
                a_ href => '/v/add', 'Add Visual Novel'; br_;
                a_ href => '/p/add', 'Add Producer'; br_;
                a_ href => '/s/new', 'Add Staff'; br_;
            }
            if(auth->isMod) {
                my $stats = tuwf->dbRowi("SELECT
                    (SELECT count(*) FROM reports WHERE status = 'new') as new,
                    (SELECT count(*) FROM reports WHERE status = 'new' AND date > (SELECT last_reports FROM users WHERE id =", \auth->uid, ")) AS unseen,
                    (SELECT count(*) FROM reports WHERE lastmod > (SELECT last_reports FROM users WHERE id =", \auth->uid, ")) AS upd
                ");
                a_ $stats->{unseen} ? (class => 'standout') : (), href => '/report/list?status=new', sprintf 'Reports %d/%d', $stats->{unseen}, $stats->{new};
                b_ class => 'grayedout', ' | ';
                a_ href => '/report/list?s=lastmod', sprintf '%d upd', $stats->{upd};
                br_;
            }
            br_;
            form_ action => "$uid/logout", method => 'post', sub {
                input_ type => 'hidden', class => 'hidden', name => 'csrf', value => auth->csrftoken;
                input_ type => 'submit', class => 'logout', value => 'Logout';
            };
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
                my %stats = map +($_->{section}, $_->{count}), tuwf->dbAll('SELECT * FROM stats_cache')->@*;
                dt_ 'Visual Novels'; dd_ $stats{vn};
                dt_ sub { b_ class => 'grayedout', '> '; lit_ 'Tags' };
                                     dd_ $stats{tags};
                dt_ 'Releases';      dd_ $stats{releases};
                dt_ 'Producers';     dd_ $stats{producers};
                dt_ 'Staff';         dd_ $stats{staff};
                dt_ 'Characters';    dd_ $stats{chars};
                dt_ sub { b_ class => 'grayedout', '> '; lit_ 'Traits' };
                                     dd_ $stats{traits};
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
    a_ href => config->{source_url}, config->{version};
    txt_ ' | ';
    a_ href => '/d7', 'about us';
    lit_ ' | ';
    a_ href => 'irc://irc.synirc.net/vndb', '#vndb';
    lit_ ' | ';
    a_ href => sprintf('mailto:%s', config->{admin_email}), config->{admin_email};

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
        lit_ ' | ';
        debug_ tuwf->req->{pagevars};
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

    div_ class => 'maintabs right', sub {
        ul_ sub {
            t '' => "/$id", $id;

            t rg => "/$id/rg", 'relations'
                if $t =~ /[vp]/ && tuwf->dbVali('SELECT 1 FROM', $t eq 'v' ? 'vn_relations' : 'producers_relations', 'WHERE id =', \$o->{id}, 'LIMIT 1');

            t releases => "/$id/releases", 'releases' if $t eq 'v';
            t edit => "/$id/edit", 'edit' if can_edit $t, $o;
            t copy => "/$id/copy", 'copy' if $t =~ /[rc]/ && can_edit $t, $o;
            t tagmod => "/$id/tagmod", 'modify tags' if $t eq 'v' && auth->permTag && !$o->{entry_hidden};

            do {
                t list  => "/$id/ulist?vnlist=1", 'list';
                t votes => "/$id/ulist?votes=1", 'votes';
                t wish  => "/$id/ulist?wishlist=1", 'wishlist';
                t posts => "/$id/posts", 'posts';
            } if $t eq 'u';

            if($t =~ /[uvp]/) {
                my $cnt = tuwf->dbVali(q{
                    SELECT COUNT(*)
                    FROM threads_boards tb
                    JOIN threads t ON t.id = tb.tid
                    WHERE tb.type =}, \$t, 'AND tb.iid =', \$o->{id}, 'AND', VNWeb::Discussions::Lib::sql_visible_threads());
                t disc => "/t/$id", "discussions ($cnt)";
            };

            t hist => "/$id/hist", 'history' if $t =~ /[uvrpcsd]/;
        }
    }
}


# Attempt to figure out the board id from a database entry ($type, $dbobj) combination
sub _board_id {
    my($type, $obj) = @_;
    $type =~ /[vp]/ ? $type.$obj->{id} :
       $type eq 'r' && $obj->{vn}->@*  ? 'v'.$obj->{vn}[0]{vid} :
       $type eq 'c' && $obj->{vns}->@* ? 'v'.$obj->{vns}[0]{vid} : 'db';
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
    div_ class => 'mainbox', sub {
        h1_ $o->{title};
        div_ class => 'warning', sub {
            h2_ 'Item deleted';
            p_ sub {
                txt_ 'This item has been deleted from the database. You may file a request on the ';
                a_ href => '/t/'._board_id($o->{type}, $o->{dbobj}), "discussion board";
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
#   index      => 1/0, default 0
#   feeds      => 1/0
#   js         => 1/0, set to 1 to ensure 'plain.js' is included on the page even if no elm_() modules are loaded.
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
    tuwf->req->{pagevars} = { $o{pagevars}->%* } if $o{pagevars};

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
            script_ type => 'application/json', id => 'pagevars', sub {
                # Escaping rules for a JSON <script> context are kinda weird, but more efficient than regular xml_escape().
                lit_(JSON::XS->new->canonical->encode(tuwf->req->{pagevars}) =~ s{</}{<\\/}rg =~ s/<!--/<\\u0021--/rg);
            } if keys tuwf->req->{pagevars}->%*;
            script_ type => 'application/javascript', src => config->{url_static}.'/f/elm.js?'.config->{version}, '' if tuwf->req->{pagevars}{elm};
            script_ type => 'application/javascript', src => config->{url_static}.'/f/plain.js?'.config->{version}, '' if $o{js} || tuwf->req->{pagevars}{elm};
        }
    }
}




sub _revision_header_ {
    my($type, $obj) = @_;
    b_ "Revision $obj->{chrev}";
    debug_ $obj;
    if(auth) {
        lit_ ' (';
        a_ href => "/$type$obj->{id}.$obj->{chrev}/edit", $obj->{chrev} == $obj->{maxrev} ? 'edit' : 'revert to';
        if($obj->{rev_user_id}) {
            lit_ ' / ';
            a_ href => "/t/u$obj->{rev_user_id}/new?title=Regarding%20$type$obj->{id}.$obj->{chrev}", 'msg user';
        }
        lit_ ')';
    }
    br_;
    lit_ 'By ';
    user_ $obj, 'rev_user_';
    lit_ ' on ';
    txt_ fmtdate $obj->{rev_added}, 'full';
}


sub _revision_fmtval_ {
    my($opt, $val, $obj) = @_;
    return i_ '[empty]' if !defined $val || !length $val || (defined $opt->{empty} && $val eq $opt->{empty});
    return lit_ html_escape $val if !$opt->{fmt};
    if(ref $opt->{fmt} eq 'HASH') {
        my $h = $opt->{fmt}{$val};
        return txt_ ref $h eq 'HASH' ? $h->{txt} : $h || '[unknown]';
    }
    return txt_ $val ? 'True' : 'False' if $opt->{fmt} eq 'bool';
    local $_ = $val;
    $opt->{fmt}->($obj);
}


sub _revision_fmtcol_ {
    my($opt, $i, $l, $obj) = @_;

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

            } elsif(@$l > 1 && $i == 2 && ($ch eq '+' || $ch eq 'c')) {
                b_ class => 'diff_add', sub { _revision_fmtval_ $opt, $val, $obj }
            } elsif(@$l > 1 && $i == 1 && ($ch eq '-' || $ch eq 'c')) {
                b_ class => 'diff_del', sub { _revision_fmtval_ $opt, $val, $obj }
            } elsif($ch eq 'c' || $ch eq 'u' || @$l == 1) {
                _revision_fmtval_ $opt, $val, $obj;
            }
        }, @$l;
    };
}


# Recursively stringify scalars. This is generally a no-op, except when
# serializing the data structure to JSON this will cause all numbers to be
# formatted as strings.  Not very useful for data exchange, but this allows for
# creating proper canonicalized JSON where equivalent data structures serialize
# to the same string. (TODO: Might as well write a function that hashes
# recursive data structures and use that for comparison - a little bit more
# work but less magical)
sub _stringify_scalars_rec {
    defined($_[0]) && !ref $_[0] ? "$_[0]" :
            ref $_[0] eq 'HASH'  ? map _stringify_scalars_rec($_), values $_[0]->%* :
            ref $_[0] eq 'ARRAY' ? map _stringify_scalars_rec($_), $_[0]->@* : undef;
}

sub _revision_diff_ {
    my($type, $old, $new, $field, $name, %opt) = @_;

    # First do a diff on the raw field elements.
    # (if the field is a scalar, it's considered a single element and the diff just tests equality)
    my @old = ref $old->{$field} eq 'ARRAY' ? $old->{$field}->@* : ($old->{$field});
    my @new = ref $new->{$field} eq 'ARRAY' ? $new->{$field}->@* : ($new->{$field});

    my $JS = JSON::XS->new->utf8->canonical->allow_nonref;
    my $l = sdiff \@old, \@new, sub { _stringify_scalars_rec($_[0]); $JS->encode($_[0]) };
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
        _revision_fmtcol_ \%opt, 1, $l, $old;
        _revision_fmtcol_ \%opt, 2, $l, $new;
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
#   fmt     => 'bool'||\%HASH||sub {$_}  - Formatting function for individual values.
#                 If not given, the field is rendered as plain text and changes are highlighted with a diff.
#                 \%HASH -> Look the field up in the hash table (values should be string or {txt=>string}.
#                 sub($value) {$_} -> Custom formatting function, should output TUWF::XML data HTML.
#   join    => sub{}  - HTML to join multi-value fields, defaults to \&br_.
#   empty   => str    - What value should be considered "empty", e.g. (empty => 0) for integer fields.
#                 undef or empty string are always considered empty values.
sub revision_ {
    my($type, $new, $enrich, @fields) = @_;

    my $old = $new->{chrev} == 1 ? undef : db_entry $type, $new->{id}, $new->{chrev} - 1;
    $enrich->($old) if $old;

    enrich_merge chid => sql(
        'SELECT c.id AS chid, c.comments as rev_comments,', sql_totime('c.added'), 'as rev_added, ', sql_user('u', 'rev_user_'), '
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
#   url generator (code reference that takes ('p', $pagenumber) as arguments with $_=$pagenumber and returns a url for that page).
#   current page number (1..n),
#   nextpage (0/1 or, if the full count is known: [$total, $perpage]),
#   alignment (t/b)
#   func
sub paginate_ {
    my($url, $p, $np, $al, $fun) = @_;
    my($cnt, $pp) = ref($np) ? @$np : ($p+$np, 1);
    return if !$fun && $p == 1 && $cnt <= $pp;

    my sub tab_ {
        my($page, $label) = @_;
        li_ sub {
            local $_ = $page;
            my $u = $url->(p => $page);
            a_ href => $u, $label;
        }
    }
    my sub ell_ {
        my($left) = @_;
        li_ mkclass(ellipsis => 1, left => $left), sub { b_ '⋯' };
    }
    my $nc = 5; # max. number of buttons on each side

    div_ class => 'maintabs browsetabs '.($al eq 't' ? '' : 'bottom'), sub {
        ul_ sub {
            $p > 2     and ref $np and tab_ 1, '« first';
            $p > $nc+1 and ref $np and ell_;
            $p > $_    and ref $np and tab_ $p-$_, $p-$_ for (reverse 2..($nc>$p-2?$p-2:$nc-1));
            $p > 1                 and tab_ $p-1, '‹ previous';
        };

        $fun->() if $fun;

        ul_ sub {
            my $l = ceil($cnt/$pp)-$p+1;
            $l > 1     and tab_ $p+1, 'next ›';
            $l > $_    and tab_ $p+$_, $p+$_ for (2..($nc>$l-2?$l-2:$nc-1));
            $l > $nc+1 and ell_;
            $l > 2     and tab_ $l+$p-1, 'last »';
        };
    }
}


# Generate sort buttons for a table header. This function assumes that sorting
# options are given as query parameters: 's' for the $column_name to sort on
# and 'o' for order ('a'sc/'d'esc).
# Options: $column_title, $column_name, $opt, $url
# Where $url is a function that is given ('p', undef, 's', $column_name, 'o', $order) and returns a URL.
sub sortable_ {
    my($name, $opt, $url) = @_;
    $opt->{s} eq $name && $opt->{o} eq 'a' ? txt_ ' ▴' : a_ href => $url->(p => undef, s => $name, o => 'a'), ' ▴';
    $opt->{s} eq $name && $opt->{o} eq 'd' ? txt_  '▾' : a_ href => $url->(p => undef, s => $name, o => 'd'),  '▾';
}


sub searchbox_ {
      my($sel, $value) = @_;
      fieldset_ class => 'search', sub {
          p_ id => 'searchtabs', sub {
              a_ href => '/v/all', $sel eq 'v' ? (class => 'sel') : (), 'Visual novels';
              a_ href => '/r',     $sel eq 'r' ? (class => 'sel') : (), 'Releases';
              a_ href => '/p/all', $sel eq 'p' ? (class => 'sel') : (), 'Producers';
              a_ href => '/s/all', $sel eq 's' ? (class => 'sel') : (), 'Staff';
              a_ href => '/c/all', $sel eq 'c' ? (class => 'sel') : (), 'Characters';
              a_ href => '/g',     $sel eq 'g' ? (class => 'sel') : (), 'Tags';
              a_ href => '/i',     $sel eq 'i' ? (class => 'sel') : (), 'Traits';
              a_ href => '/u/all', $sel eq 'u' ? (class => 'sel') : (), 'Users';
          };
          input_ type => 'text', name => 'q', id => 'q', class => 'text', value => $value;
          input_ type => 'submit', class => 'submit', value => 'Search!';
      };
}


# Generate a message to display on an entry page to report the entry and to indicate it has been locked or the user can't edit it.
sub itemmsg_ {
    my($type, $obj) = @_;
    p_ class => 'itemmsg', sub {
        if($type ne 'd') {
            if($obj->{entry_locked}) {
                txt_ 'Locked for editing. ';
            } elsif(auth && !can_edit $type => $obj) {
                txt_ 'You can not edit this page. ';
            }
        }
        a_ href => "/report/$type$obj->{id}", 'Report an issue on this page.';
    };
}


# Generate the initial mainbox when adding or editing a database entry, with a
# friendly message pointing to the guidelines and stuff.
# Args: $type ('v','r', etc), $obj (from db_entry(), or undef for new page), $page_title, $is_this_a_copy?
sub editmsg_ {
    my($type, $obj, $title, $copy) = @_;
    my $typename   = {v => 'visual novel', r => 'release', p => 'producer', c => 'character', s => 'person'}->{$type};
    my $guidelines = {v => 2,              r => 3,         p => 4,          c => 12,          s => 16      }->{$type};
    croak "Unknown type: $type" if !$typename;

    div_ class => 'mainbox', sub {
        h1_ sub {
            txt_ $title;
            debug_ $obj if $obj;
        };
        if($copy) {
            div_ class => 'warning', sub {
                h2_ "You're not editing an entry!";
                p_ sub {;
                    txt_ "You're about to insert a new entry into the database with information based on ";
                    a_ href => "/$type$obj->{id}", "$type$obj->{id}";
                    txt_ '.';
                    br_;
                    txt_ "Hit the 'edit' tab on the right-top if you intended to edit the entry instead of creating a new one.";
                }
            }
        }
        # 'lastrev' is for compatibility with VNDB::*
        if($obj && ($obj->{maxrev} ? $obj->{maxrev} != $obj->{chrev} : !$obj->{lastrev})) {
            div_ class => 'warning', sub {
                h2_ 'Reverting';
                p_ "You are editing an old revision of this $typename. If you save it, all changes made after this revision will be reverted!";
            }
        }
        div_ class => 'notice', sub {
            h2_ 'Before editing:';
            ul_ sub {
                li_ sub {
                    txt_ 'Read the ';
                    a_ href=> "/d$guidelines", 'guidelines';
                    txt_ '!';
                };
                if($obj) {
                    li_ sub {
                        txt_ 'Check for any existing discussions on the ';
                        a_ href => '/t/'._board_id($type, $obj), 'discussion board';
                    };
                    # TODO: Include a list of the most recent edits in this page.
                    li_ sub {
                        txt_ 'Browse the ';
                        a_ href => "/$type$obj->{id}/hist", 'edit history';
                        txt_ ' for any recent changes related to what you want to change.';
                    };
                } elsif($type ne 'r') {
                    li_ sub {
                        a_ href => "/$type/all", 'Search the database';
                        txt_ " to see if we already have information about this $typename.";
                    }
                }
                li_ 'Fields marked with (*) may cause other fields to become (un)available depending on the selection.' if $type eq 'r';
            }
        };
    }
}

1;
