# The VNDB.org Source Code

## Quick and dirty setup using Docker

Setup:

```
  docker build -t vndb .
  docker volume create --name vndb-data
```

Run (will run on the foreground):

```
  docker run -ti --name vndb -p 3000:3000 -v vndb-data:/var/lib/postgresql -v "`pwd`":/var/www --rm vndb
```

While running, if you need another terminal into the container:

```
  docker exec -ti vndb bash                           # root shell
  docker exec -ti vndb su -l devuser                  # development shell
  docker exec -ti vndb su postgres -c psql            # postgres superuser shell
  docker exec -ti vndb su devuser -c 'psql -U vndb'   # postgres vndb shell
```


## Development database

There is a development database available for download at
[https://vndb.org/d8#3](https://vndb.org/d8#3).
When you first run the docker image, you will be asked whether you want to
download and import this database.  If you do not use docker, you can import
this database manually as follows:

- Follow the steps below to setup PostgreSQL and initialze the database
- Download and extract the development database
- psql -U vndb -f dump.sql


## Requirements (when not using Docker)

Global requirements:

- Linux, or an OS that resembles Linux. Chances are VNDB won't run on Windows.
- PostgreSQL 9.10 (older versions may work)
- perl 5.24 recommended, 5.10+ may also work

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
- Text::MultiMarkdown
- TUWF
- HTTP::Server::Simple

util/multi.pl (application server, optional):
- AnyEvent
- AnyEvent::Pg
- AnyEvent::IRC
- XML::Parser
- graphviz (/usr/bin/dot is used by default)


## Setup

- Make sure all the required dependencies (see above) are installed
- Create a suitable data/config.pl, using data/config_example.pl as base.
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

  # Now import the rest
  psql -U vndb -f util/sql/all.sql
```

- Update the vndb_site password in data/config.pl to whatever you set it in
  the previous step.
- (Optional) Import the "Development database" as explained above.
- Now simply run:

```
  util/vndb-dev-server.pl
```

## License

GNU AGPL, see COPYING file for details.
