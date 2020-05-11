ALTER TABLE users ADD COLUMN max_sexual   smallint NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN max_violence smallint NOT NULL DEFAULT 0;
UPDATE users SET max_sexual = 2, max_violence = 2 WHERE show_nsfw;
\i sql/perms.sql
