{
    # Canonical URL of this site
    url          => 'http://localhost:3000',
    # And of the static files (leave unset to use `url`)
    #url_static   => 'http://localhost:3000',

    # Salt used to generate the CSRF tokens
    form_salt   => '<some unique string>',
    # Global salt used to hash user passwords (used in addition to a user-specific salt)
    scrypt_salt => '<another unique string>',

    # TUWF configuration options, see the TUWF::set() documentation for options.
    tuwf => {
        db_login        => [ 'dbi:Pg:dbname=vndb', 'vndb_site', 'vndb_site' ],
        xml_pretty      => 0,
        log_queries     => 0,
        debug           => 1,
        cookie_defaults => { domain => 'localhost', path => '/' },
        mail_sendmail   => 'log',
    },

    # Uncomment if you want to test password strength against a dictionary. See
    # lib/PWLookup.pm for instructions on how to create the database file.
    #password_db => 'data/passwords.dat',

    # Options for Multi, the background server.
    Multi => {
        # Each module in lib/Multi/ can be enabled and configured here.
        Core => {
            db_login => { dbname => 'vndb', user => 'vndb_multi', password => 'vndb_multi' },
        },
        #API => {},
        #IRC => {
        #    nick      => 'MyVNDBBot',
        #    server    => 'irc.synirc.net',
        #    channels  => [ '#vndb' ],
        #    pass      => '<nickserv-password>',
        #    masters   => [ 'yorhel!~Ayo@your.hell' ],
        #},
    },
}
