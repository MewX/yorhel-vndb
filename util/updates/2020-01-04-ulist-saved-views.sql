ALTER TABLE users ADD COLUMN ulist_votes  jsonb;
ALTER TABLE users ADD COLUMN ulist_vnlist jsonb;
ALTER TABLE users ADD COLUMN ulist_wish   jsonb;
\i util/sql/perms.sql
