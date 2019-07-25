{
    # Canonical URL of this site
    url          => 'http://localhost:3000',
    # And of the static files (may be the same as the above url)
    url_static   => 'http://localhost:3000',

    # TUWF configuration options, see the TUWF::set() documentation for options.
    tuwf => {
        db_login    => [ 'dbi:Pg:dbname=vndb', 'vndb_site', 'vndb_site' ],
        xml_pretty  => 0,
        log_queries => 0,
        debug       => 1,
        cookie_defaults => { domain => 'localhost', path => '/' },
        mail_sendmail => 'log',
    },

    # Configuration of the authentication module (VNDB::Auth)
    auth => {
        csrf_key    => '<some unique string>',
        scrypt_salt => '<another unique string>',
    },

    # Uncomment if you want to test password strength against a dictionary. See
    # lib/PWLookup.pm for instructions on how to create the database file.
    #password_db => 'data/passwords.dat',
}
