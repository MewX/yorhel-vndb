package VNDB;

# This file is used to override config options in global.pl.
# You can override anything you want.

%O = (
  %O,
  db_login      => [ 'dbi:Pg:dbname=vndb', 'vndb_site', 'vndb_site' ],
  #logfile       => $ROOT.'/err.log',
  xml_pretty    => 0,
  log_queries   => 0,
  debug         => 1,
  cookie_defaults => { domain => 'localhost', path => '/' },
  mail_sendmail => 'log',
);

%S = (
  %S,
  url          => 'http://localhost:3000',
  url_static   => 'http://localhost:3000',
  form_salt    => '<some unique string>',
  scrypt_salt  => '<another unique string>',
  # Uncomment if you want to test password strength against a dictionary. See
  # lib/PWLookup.pm for instructions on how to create the database file.
  #password_db => $ROOT.'/data/passwords.dat',
);

$M{db_login} = { dbname => 'vndb', user => 'vndb_multi', password => 'vndb_multi' };

# Uncomment to enable certain features of Multi

#$M{modules}{API} = {};
#$M{modules}{APIDump} = {};

#$M{modules}{IRC} = {
#  nick    => 'MyVNDBBot',
#  server  => 'irc.synirc.net',
#  channels => [ '#vndb' ],
#  pass    => '<nickserv-password>',
#  masters => [ 'yorhel!~Ayo@your.hell' ],
#};


# Uncomment to generate an extra small icons.png
# (note: using zopflipng or pngcrush with the slow option is *really* slow, but compresses awesomely)
#$SPRITEGEN{crush} = '/usr/bin/pngcrush -q';
#$SPRITEGEN{crush} = '/usr/bin/zopflipng -m --lossy_transparent';
#$SPRITEGEN{slow} = 1;
