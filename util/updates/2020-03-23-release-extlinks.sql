ALTER TABLE releases      ADD COLUMN l_toranoana bigint NOT NULL DEFAULT 0;
ALTER TABLE releases_hist ADD COLUMN l_toranoana bigint NOT NULL DEFAULT 0;
ALTER TABLE releases      ADD COLUMN l_melonjp integer NOT NULL DEFAULT 0;
ALTER TABLE releases_hist ADD COLUMN l_melonjp integer NOT NULL DEFAULT 0;
ALTER TABLE releases      ADD COLUMN l_gamejolt integer NOT NULL DEFAULT 0;
ALTER TABLE releases_hist ADD COLUMN l_gamejolt integer NOT NULL DEFAULT 0;
ALTER TABLE releases      ADD COLUMN l_nutaku text NOT NULL DEFAULT '';
ALTER TABLE releases_hist ADD COLUMN l_nutaku text NOT NULL DEFAULT '';
\i util/sql/editfunc.sql
