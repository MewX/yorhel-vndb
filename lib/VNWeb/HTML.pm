package VNWeb::HTML;

use v5.24;
use warnings;
use TUWF ':html5_', 'uri_escape';
use Exporter 'import';
use JSON::XS;

our @EXPORT = qw/
    clearfloat_
    debug_
    framework_
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


sub _head_ {
    my $o = shift;
    my $skin = tuwf->reqGet('skin') || tuwf->authPref('skin') || tuwf->{skin_default};
    $skin = tuwf->{skin_default} if !tuwf->{skins}{$skin};

    title_ $o->{title}.' | vndb';
    link_ rel => 'shortcut icon', href => '/favicon.ico', type => 'image/x-icon';
    link_ rel => 'stylesheet', href => tuwf->{url_static}.'/s/'.$skin.'/style.css?'.tuwf->{version}, type => 'text/css', media => 'all';
    link_ rel => 'search', type => 'application/opensearchdescription+xml', title => 'VNDB VN Search', href => tuwf->reqBaseURI().'/opensearch.xml';
    style_ type => 'text/css', tuwf->authPref('customcss') =~ s/\n/ /rg if tuwf->authPref('customcss');
    if($o->{feeds}) {
        link_ rel => 'alternate', type => 'application/atom+xml', href => "/feeds/announcements.atom", title => 'Site Announcements';
        link_ rel => 'alternate', type => 'application/atom+xml', href => "/feeds/changes.atom",       title => 'Recent Changes';
        link_ rel => 'alternate', type => 'application/atom+xml', href => "/feeds/posts.atom",         title => 'Recent Posts';
    }
    meta_ name => 'robots', content => 'noindex, follow' if $o->{noindex};

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
            a_ href => '/v/rand','Random visual novel';
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
        my $uid = sprintf '/u%d', tuwf->authInfo->{id};
        my $nc = tuwf->authInfo->{notifycount};
        h2_ sub { a_ href => $uid, ucfirst tuwf->authInfo->{username} };
        div_ sub {
            a_ href => "$uid/edit", 'My Profile'; br_;
            a_ href => "$uid/list", 'My Visual Novel List'; br_;
            a_ href => "$uid/votes",'My Votes'; br_;
            a_ href => "$uid/wish", 'My Wishlist'; br_;
            a_ href => "$uid/notifies", $nc ? (class => 'notifyget') : (), 'My Notifications'.($nc?" ($nc)":''); br_;
            a_ href => "$uid/hist", 'My Recent Changes'; br_;
            a_ href => '/g/links?u='.tuwf->authInfo->{id}, 'My Tags'; br_;
            br_;
            if(tuwf->authCan('edit')) {
                a_ href => '/v/add', 'Add Visual Novel'; br_;
                a_ href => '/p/add', 'Add Producer'; br_;
                a_ href => '/s/new', 'Add Staff'; br_;
                a_ href => '/c/new', 'Add Character'; br_;
            }
            br_;
            a_ href => "$uid/logout", 'Logout';
        }
    } if tuwf->authInfo->{id};

    div_ class => 'menubox', sub {
        h2_ 'User menu';
        div_ sub {
            my $ref = uri_escape tuwf->reqPath().tuwf->reqQuery();
            a_ href => "/u/login?ref=$ref", 'Login'; br_;
            a_ href => '/u/newpass', 'Password reset'; br_;
            a_ href => '/u/register', 'Register'; br_;
        }
    } if !tuwf->authInfo->{id};

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
    txt_ sprintf 'vndb %s | ', tuwf->{version};
    a_ href => '/d7', 'about us';
    lit_ ' | ';
    a_ href => 'irc://irc.synirc.net/vndb', '#vndb';
    lit_ ' | ';
    a_ href => sprintf('mailto:%s', tuwf->{admin_email}), tuwf->{admin_email};
    lit_ ' | ';
    a_ href => tuwf->{source_url}, 'source';

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


# Options:
#   title   => $title
#   noindex => 1/0
#   feeds   => 1/0
#   search  => $query
#   og      => { opengraph metadata }
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
            div_ id => 'maincontent', $cont;
            div_ id => 'footer', sub { _footer_ };
        };
    }
}

1;
