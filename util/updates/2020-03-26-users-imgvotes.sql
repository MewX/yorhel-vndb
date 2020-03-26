ALTER TABLE users ADD COLUMN c_imgvotes integer NOT NULL DEFAULT 0;

UPDATE users SET c_imgvotes = (SELECT COUNT(*) FROM image_votes WHERE uid = users.id);

\i util/sql/triggers.sql
\i util/sql/perms.sql
