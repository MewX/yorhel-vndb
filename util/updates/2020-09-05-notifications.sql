ALTER TABLE notifications ALTER COLUMN iid TYPE vndbid USING vndbid(ltype::text, iid);
ALTER TABLE notifications RENAME COLUMN subid TO num;
ALTER TABLE notifications DROP COLUMN ltype;
ALTER TABLE notifications ALTER COLUMN c_byuser DROP DEFAULT;
ALTER TABLE notifications ALTER COLUMN c_byuser DROP NOT NULL;
DROP TYPE notification_ltype;
UPDATE notifications SET c_byuser = NULL WHERE c_byuser = 0;

ALTER TABLE users ADD COLUMN notify_post    boolean NOT NULL DEFAULT true;
ALTER TABLE users ADD COLUMN notify_comment boolean NOT NULL DEFAULT true;
ALTER TYPE notification_ntype ADD VALUE 'post' AFTER 'announce';
ALTER TYPE notification_ntype ADD VALUE 'comment' AFTER 'post';

\i sql/func.sql
\i sql/triggers.sql
\i sql/perms.sql
