ALTER TABLE releases      ADD COLUMN l_jastusa text NOT NULL DEFAULT '';
ALTER TABLE releases_hist ADD COLUMN l_jastusa text NOT NULL DEFAULT '';

\i util/sql/editfunc.sql
