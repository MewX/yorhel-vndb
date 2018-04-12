#!/bin/sh

# This script generates util/sql/devdb.sql from the current DB. It assumes that
# the DB is accessible through a passwordless 'psql -U vndb'.

# WARNING: This script will throw away sessions and IP addresses from the DB!

psql -U vndb -c 'TRUNCATE sessions'
psql -U vndb -c "UPDATE users SET ip = '0.0.0.0'"
psql -U vndb -c "UPDATE changes SET ip = '0.0.0.0'"

cat <<'EOF' >util/sql/devdb.sql
-- See the README for instructions.
-- This file was automatically generated by util/gendevdb.sh.

SET CONSTRAINTS ALL DEFERRED;
-- Hack to disable triggers
SET session_replication_role = replica;
EOF

psql -U vndb -qAtc \
    "SELECT 'TRUNCATE TABLE ' || string_agg(oid::regclass::text, ', ') || ' CASCADE;'
      FROM pg_class WHERE relkind = 'r' AND relnamespace = 'public'::regnamespace"\
    >>util/sql/devdb.sql

pg_dump -U vndb --data-only | grep -Ev '^(--( .*|$))?$' >>util/sql/devdb.sql