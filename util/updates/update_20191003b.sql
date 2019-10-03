ALTER TABLE sessions RENAME COLUMN lastused TO expires;
UPDATE sessions SET expires = expires + '1 month'::interval;
ALTER TABLE sessions ALTER COLUMN expires DROP DEFAULT;

DROP FUNCTION user_isloggedin(integer, bytea);
DROP FUNCTION user_update_lastused(integer, bytea);

\i util/sql/func.sql
