package VNDB::Config;

use strict;
use warnings;
use Exporter 'import';
our @EXPORT = ('config');

my $ROOT = $INC{'VNDB/Config.pm'} =~ s{/lib/VNDB/Config\.pm$}{}r;

# Default config options
my $config = {
    url             => 'http://localhost:3000',

    tuwf => {
        db_login      => [ 'dbi:Pg:dbname=vndb', 'vndb_site', undef ],
        cookie_prefix => 'vndb_',
    },

    skin_default      => 'angel',
    placeholder_img   => 'http://s.vndb.org/s/angel/bg.jpg', # Used in the og:image meta tag
    scrypt_args       => [ 65536, 8, 1 ], # N, r, p
    scrypt_salt       => 'another-random-string',
    form_salt         => 'a-private-string-here',
    source_url        => 'https://code.blicky.net/yorhel/vndb',
    admin_email       => 'contact@vndb.org',
    login_throttle    => [ 24*3600/10, 24*3600 ], # interval between attempts, max burst (10 a day)
    board_edit_time   => 7*24*3600, # Time after which posts become immutable
    poll_options      => 20, # max number of options in discussion board polls
    graphviz_path     => '/usr/bin/dot',
    trace_log         => 0,

    dlsite_url   => 'https://www.dlsite.com/%s/work/=/product_id/%%s.html',
    denpa_url    => 'https://denpasoft.com/products/%s',
    jlist_url    => 'https://www.jlist.com/%s',
    jbox_url     => 'https://www.jbox.com/%s',
    mg_r18_url   => 'https://www.mangagamer.com/r18/detail.php?product_code=%d',
    mg_main_url  => 'https://www.mangagamer.com/detail.php?product_code=%d',

    Multi => {
        Core        => {},
        Feed        => {},
        Maintenance => {},
    },
};


my $config_file = do $ROOT.'/data/conf.pl';
my $config_merged;

sub config {
    $config_merged ||= do {
        my $c = $config;
        $c->{$_} = $config_file->{$_} for grep !/^(Multi|tuwf)$/, keys %$config_file;
        $c->{Multi}{$_} = $config_file->{Multi}{$_} for keys %{ $config_file->{Multi} || {} };
        $c->{tuwf}{$_}  = $config_file->{tuwf}{$_}  for keys %{ $config_file->{tuwf}  || {} };

        $c->{url_static} ||= $c->{url};
        $c->{version} ||= `git -C "$ROOT" describe` =~ s/\-g[0-9a-f]+$//rg =~ s/\r?\n//rg;
        $c->{root} = $ROOT;
        $c->{Multi}{Core}{log_level} ||= 'debug';
        $c->{Multi}{Core}{log_dir}   ||= $ROOT.'/data/log';
        $c
    };
    $config_merged
}

1;

