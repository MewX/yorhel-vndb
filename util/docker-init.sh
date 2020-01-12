#!/bin/sh

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
        addgroup devgroup
        adduser -s /bin/sh devuser
    else
        addgroup -g $USER_GID devgroup
        adduser -s /bin/sh -u $USER_UID -G devgroup -D devuser
    fi
    install -d -o devuser -g devgroup /run/postgresql
}


# Should run as devuser
pg_start() {
    if [ ! -d /var/www/data/docker-pg/12 ]; then
        mkdir -p /var/www/data/docker-pg/12
        initdb -D /var/www/data/docker-pg/12 --locale en_US.UTF-8 -A trust
    fi
    pg_ctl -D /var/www/data/docker-pg/12 -l /var/www/data/docker-pg/12/logfile start

    cd /var/www
    if test -f data/docker-pg/vndb-init-done; then
        echo
        echo "Database initialization already done."
        echo
        return
    fi

    echo "============================================================="
    echo
    echo "Database has not been initialized yet, doing that now."
    echo "If you want to have some data to play around with,"
    echo "I can download and install a development database for you."
    echo "For information, see https://vndb.org/d8#3"
    echo "(Warning: This will also write images to static/)"
    echo
    echo "Enter n to setup an empty database, y to download the dev database."
    [ -f dump.sql ] && echo "  Or e to import the existing dump.sql."
    read -p "Choice: " opt

    make util/sql/editfunc.sql
    psql postgres -f util/sql/superuser_init.sql
    echo "ALTER ROLE vndb       LOGIN" | psql postgres
    echo "ALTER ROLE vndb_site  LOGIN" | psql postgres
    echo "ALTER ROLE vndb_multi LOGIN" | psql postgres

    if [ $opt = e ]
    then
        psql -U vndb -f dump.sql
    elif [ $opt = y ]
    then
        curl -L https://dl.vndb.org/dump/vndb-dev-latest.tar.gz | tar -xzf-
        psql -U vndb -f dump.sql
        rm dump.sql
    else
        psql -U vndb -f util/sql/all.sql
    fi

    touch data/docker-pg/vndb-init-done

    echo
    echo "Database initialization done!"
    echo
}


# Should run as devuser
devshell() {
    cd /var/www
    util/vndb-dev-server.pl
    sh
}


case "$1" in
    '')
        mkdevuser
        su devuser -c '/var/www/util/docker-init.sh pg_start'
        exec su devuser -c '/var/www/util/docker-init.sh devshell'
        ;;
    pg_start)
        pg_start
        ;;
    devshell)
        devshell
        ;;
esac
