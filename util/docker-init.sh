#!/bin/bash

if ! test -f /var/vndb-docker-image; then
    echo "This script should only be run from within the VNDB docker container."
    echo "Check the README for instructions."
    exit 1
fi


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

    # So you can easily do a 'psql -U vndb'
    echo '*:*:*:vndb:vndb'              >/home/devuser/.pgpass
    echo '*:*:*:vndb_site:vndb_site'   >>/home/devuser/.pgpass
    echo '*:*:*:vndb_multi:vndb_multi' >>/home/devuser/.pgpass
    chown devuser /home/devuser/.pgpass
    chmod 600 /home/devuser/.pgpass
}


pg_start() {
    echo 'local all postgres peer' >/etc/postgresql/10/main/pg_hba.conf
    echo 'local all all md5'      >>/etc/postgresql/10/main/pg_hba.conf
    # I'm glad Ubuntu 18.04 still has an init script for this
    /etc/init.d/postgresql start
}


pg_init() {
    if test -f /var/lib/postgresql/vndb-init-done; then
        echo
        echo "Database initialization already done."
        echo
        return
    fi
    su postgres -c '/var/www/util/docker-init.sh pg_load_superuser'
    su devuser -c '/var/www/util/docker-init.sh pg_load_vndb'
    touch /var/lib/postgresql/vndb-init-done

    echo
    echo "Database initialization done!"
    echo
}

# Should run as the postgres user
pg_load_superuser() {
    psql -f /var/www/util/sql/superuser_init.sql
    echo "ALTER ROLE vndb       LOGIN PASSWORD 'vndb'"       | psql -U postgres
    echo "ALTER ROLE vndb_site  LOGIN PASSWORD 'vndb_site'"  | psql -U postgres
    echo "ALTER ROLE vndb_multi LOGIN PASSWORD 'vndb_multi'" | psql -U postgres
}

# Should run as devuser
pg_load_vndb() {
    cd /var/www
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
        curl https://s.vndb.org/devdump.tar.gz | tar -xzf-
        psql -U vndb -f dump.sql
    fi
}


# Should run as devuser
devshell() {
    cd /var/www
    util/vndb-dev-server.pl
    bash
}


case "$1" in
    '')
        mkdevuser
        pg_start
        pg_init
        exec su devuser -c '/var/www/util/docker-init.sh devshell'
        ;;
    pg_load_superuser)
        pg_load_superuser
        ;;
    pg_load_vndb)
        pg_load_vndb
        ;;
    devshell)
        devshell
        ;;
esac
