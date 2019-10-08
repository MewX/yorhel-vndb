ALTER TABLE users ADD COLUMN nodistract_can     boolean NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN nodistract_noads   boolean NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN nodistract_nofancy boolean NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN support_can     boolean NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN support_enabled boolean NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN uniname_can     boolean NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN uniname         text NOT NULL DEFAULT '';
ALTER TABLE users ADD COLUMN pubskin_can     boolean NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN pubskin_enabled boolean NOT NULL DEFAULT FALSE;
\i util/sql/perms.sql
