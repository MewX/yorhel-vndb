# The VNDB.org Source Code

## Quick and dirty setup using Docker

Setup:

```
  docker build -t vndb .
```

Run (will run on the foreground):

```
  docker run -ti --name vndb -p 3000:3000 -v "`pwd`":/var/www --rm vndb
```

If you need another terminal into the container while it's running:

```
  docker exec -ti vndb su -l devuser  # development shell (files are at /var/www)
  docker exec -ti vndb psql -U vndb   # postgres shell
```

To start Multi, the optional application server:

```
  docker exec -ti vndb su -l devuser -c 'make -C /var/www multi-restart'
```

It will run in the background for as long as the container is alive. Logs are
written to `data/log/multi.log`.

The PostgreSQL database will be stored in `data/docker-pg/` and the uploaded
files in `static/{ch,cv,sf,st}`. If you want to restart with a clean slate, you
can stop the container and run:

```
  # Might want to make a backup of these dirs first if you have any interesting data.
  rm -rf data/docker-pg static/{ch,cv,sf,st}
```


## Requirements (when not using Docker)

Global requirements:

- Linux, or an OS that resembles Linux. Chances are VNDB won't run on Windows.
- PostgreSQL 10 (older versions may work)
- perl 5.24 recommended, 5.10+ may also work
- Elm 0.19

**Perl modules** (core modules are not listed):

General:
- Crypt::ScryptKDF
- Crypt::URandom
- DBD::Pg
- DBI
- Image::Magick
- JSON::XS
- PerlIO::gzip
- Tie::IxHash

util/vndb.pl (the web backend):
- Algorithm::Diff::XS
- SQL::Interp
- Text::MultiMarkdown
- TUWF
- HTTP::Server::Simple

util/multi.pl (application server, optional):
- AnyEvent
- AnyEvent::Pg
- AnyEvent::IRC
- XML::Parser
- graphviz (/usr/bin/dot is used by default)


## Manual setup

- Make sure all the required dependencies (see above) are installed. Hint: See
  the Docker file for Ubuntu commands. For non-root setup: Use cpanm & local::lib.
- Run the build system:

```
  make
```

- Setup a PostgreSQL server and make sure you can login with some admin user
- Initialize the VNDB database (assuming 'postgres' is a superuser):

```
  # Create the database & roles
  psql -U postgres -f util/sql/superuser_init.sql

  # Set a password for each database role:
  echo "ALTER ROLE vndb       LOGIN PASSWORD 'pwd1'" | psql -U postgres
  echo "ALTER ROLE vndb_site  LOGIN PASSWORD 'pwd2'" | psql -U postgres
  echo "ALTER ROLE vndb_multi LOGIN PASSWORD 'pwd3'" | psql -U postgres

  # OPTION 1: Create an empty database:
  psql -U vndb -f util/sql/all.sql

  # OPTION 2: Import the development database (https://vndb.org/d8#3):
  curl -L https://dl.vndb.org/dump/vndb-dev-latest.tar.gz | tar -xzf-
  psql -U vndb -f dump.sql
  rm dump.sql
```

- Update `data/conf.pl` with the proper credentials for *vndb_site* and
  *vndb_multi*.
- Now simply run:

```
  util/vndb-dev-server.pl
```

- (Optional) To start Multi, the application server:

```
  make multi-restart
```


# Version 2 & 3

The VNDB website is being rewritten. The current active site is version 2, but
this repository also contains the code for the new (in progress) version 3. The
code is easy to identify, the following files are only used by version 3:

- `lib/VN3/`
- `css3/`
- `elm3/`
- `util/vndb3.pl`

To run version 3 instead of 2:

```
  # When not using Docker
  util/vndb-dev-server.pl 3
  
  # Or when using Docker, start the container as follows:
  docker run -ti --name vndb -p 3000:3000 -v "`pwd`":/var/www --rm vndb /var/www/util/docker-init.sh 3
```

# License

GNU AGPL, see COPYING file for details.
