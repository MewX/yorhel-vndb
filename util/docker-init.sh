#!/bin/sh

if ! test -f /var/vndb-docker-image; then
    echo "This script should only be run from within the VNDB docker container."
    echo "Check the README for instructions."
    exit 1
fi


mkdevuser() {
    # Create a new user with the same UID and GID as the owner of the VNDB
    # directory. This allows for convenient exchange of files without worrying
    # about permission stuff.
    USER_UID=`stat -c '%u' /var/www`
    USER_GID=`stat -c '%g' /var/www`
    groupadd -g $USER_GID devgroup
    useradd -u $USER_UID -g $USER_GID -m -s /bin/bash devuser

    # So you can easily do a 'psql -U vndb'
    echo '*:*:*:vndb:vndb'              >/home/devuser/.pgpass
    echo '*:*:*:vndb_site:vndb_site'   >>/home/devuser/.pgpass
    echo '*:*:*:vndb_multi:vndb_multi' >>/home/devuser/.pgpass
    chown devuser /home/devuser/.pgpass
    chmod 600 /home/devuser/.pgpass
}


pg_start() {
    echo 'local all postgres peer' >/etc/postgresql/9.6/main/pg_hba.conf
    echo 'local all all md5'      >>/etc/postgresql/9.6/main/pg_hba.conf
    # I'm glad Ubuntu 17.10 still has an init script for this
    /etc/init.d/postgresql start
}


pg_init() {
    if test -f /var/lib/postgresql/vndb-init-done; then
        echo
        echo "Database initialization already done."
        echo "Run the following as root to bypass this check:"
        echo "  rm /var/lib/postgresql/vndb-init-done"
        echo
        return
    fi
    su postgres -c '/var/www/util/docker-init.sh pg_load_superuser'
    su devuser -c '/var/www/util/docker-init.sh pg_load_vndb'
    su postgres -c '/var/www/util/docker-init.sh pg_load_devdb'
    touch /var/lib/postgresql/vndb-init-done
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
}

# Should be run as the postgres user
pg_load_devdb() {
    psql vndb -1f /var/www/util/sql/devdb.sql
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
    pg_load_devdb)
        pg_load_devdb
        ;;
    devshell)
        devshell
        ;;
esac
