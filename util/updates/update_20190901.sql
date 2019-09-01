ALTER TABLE releases      ADD COLUMN l_egs      integer NOT NULL DEFAULT 0;
ALTER TABLE releases      ADD COLUMN l_erotrail integer NOT NULL DEFAULT 0;
ALTER TABLE releases_hist ADD COLUMN l_egs      integer NOT NULL DEFAULT 0;
ALTER TABLE releases_hist ADD COLUMN l_erotrail integer NOT NULL DEFAULT 0;

\i util/sql/editfunc.sql
