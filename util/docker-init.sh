#!/bin/bash

if ! test -f /var/vndb-docker-image; then
    echo "This script should only be run from within the VNDB docker container."
    echo "Check the README for instructions."
    exit 1
fi


# Should run as root
mkdevuser() {
    # Create a new user with the same UID and GID as the owner of the VNDB
    # directory. This allows for convenient exchange of files without worrying
    # about permission stuff.
    # If the owner is root, we're probably running under Docker for Mac or
    # similar and don't need to match UID/GID. See https://vndb.org/t9959 #38
    # to #44.
    USER_UID=`stat -c '%u' /var/www`
    USER_GID=`stat -c '%g' /var/www`
    if test $USER_UID -eq 0; then
        groupadd devgroup
        useradd -m -s /bin/bash devuser
    else
        groupadd -g $USER_GID devgroup
        useradd -u $USER_UID -g $USER_GID -m -s /bin/bash devuser
    fi

    echo 'LANG=en_US.UTF-8' >>/home/devuser/.profile
    echo 'export LANG'      >>/home/devuser/.profile
    chown devuser:devgroup -R /var/run/postgresql/
}


# Should run as devuser
pg_start() {
    if [ ! -d /var/www/data/docker-pg/10 ]; then
        mkdir -p /var/www/data/docker-pg/10
        /usr/lib/postgresql/10/bin/pg_ctl initdb -D /var/www/data/docker-pg/10
    fi
    echo 'local all all trust' >/var/www/data/docker-pg/10/pg_hba.conf
    /usr/lib/postgresql/10/bin/pg_ctl -D /var/www/data/docker-pg/10 -l /var/www/data/docker-pg/10/logfile start

    cd /var/www
    if test -f data/docker-pg/vndb-init-done; then
        echo
        echo "Database initialization already done."
        echo
        return
    fi

    psql postgres -f util/sql/superuser_init.sql
    echo "ALTER ROLE vndb       LOGIN" | psql postgres
    echo "ALTER ROLE vndb_site  LOGIN" | psql postgres
    echo "ALTER ROLE vndb_multi LOGIN" | psql postgres

    make util/sql/editfunc.sql
    psql -U vndb -f util/sql/all.sql

    echo
    echo "You now have a functional, but empty, database."
    echo "If you want to have some data to play around with,"
    echo "I can download and install a development database for you."
    echo "For information, see https://vndb.org/d8#3"
    echo "(Warning: This will also write images to static/)"
    echo
    echo "Enter n to keep an empty database, y to download the dev database."
    read -p "Choice: " opt
    if [[ $opt =~ ^[Yy] ]]
    then
        curl -L https://dl.vndb.org/dump/vndb-dev-latest.tar.gz | tar -xzf-
        psql -U vndb -f dump.sql
        rm dump.sql
    fi

    touch data/docker-pg/vndb-init-done

    echo
    echo "Database initialization done!"
    echo
}


# Should run as devuser
devshell() {
    cd /var/www
    util/vndb-dev-server.pl $1
    bash
}


case "$1" in
    '')
        mkdevuser
        su devuser -c '/var/www/util/docker-init.sh pg_start'
        exec su devuser -c '/var/www/util/docker-init.sh devshell'
        ;;
    3)
        mkdevuser
        su devuser -c '/var/www/util/docker-init.sh pg_start'
        exec su devuser -c '/var/www/util/docker-init.sh devshell 3'
        ;;
    pg_start)
        pg_start
        ;;
    devshell)
        devshell $2
        ;;
esac
