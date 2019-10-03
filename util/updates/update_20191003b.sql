-- lastused -> expires
ALTER TABLE sessions RENAME COLUMN lastused TO expires;
UPDATE sessions SET expires = expires + '1 month'::interval;
ALTER TABLE sessions ALTER COLUMN expires DROP DEFAULT;

-- Support different session types
CREATE TYPE session_type      AS ENUM ('web', 'pass', 'mail');
ALTER TABLE sessions ADD COLUMN type session_type NOT NULL DEFAULT 'web';
ALTER TABLE sessions ALTER COLUMN type DROP DEFAULT;
ALTER TABLE sessions ADD COLUMN mail text;

DROP FUNCTION user_isloggedin(integer, bytea);
DROP FUNCTION user_update_lastused(integer, bytea);
DROP FUNCTION user_isvalidtoken(integer, bytea);
DROP FUNCTION user_setmail(integer, integer, bytea, text);

-- Convert old password reset tokens to the new session format
INSERT INTO sessions (uid, token, expires, type)
    SELECT id, passwd, NOW() + '1 week', 'pass' FROM users WHERE length(passwd) = 20;
UPDATE users SET passwd = '' WHERE length(passwd) = 20;

\i util/sql/func.sql
