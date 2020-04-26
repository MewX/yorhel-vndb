ALTER TABLE users ADD COLUMN perm_imgmod boolean NOT NULL DEFAULT false;
UPDATE users SET perm_imgmod = perm_dbmod;
\i sql/perms.sql
