ALTER TABLE notifications ALTER COLUMN iid TYPE vndbid USING vndbid(ltype::text, iid);
ALTER TABLE notifications RENAME COLUMN subid TO num;
ALTER TABLE notifications DROP COLUMN ltype;
ALTER TABLE notifications ALTER COLUMN c_byuser DROP DEFAULT;
ALTER TABLE notifications ALTER COLUMN c_byuser DROP NOT NULL;
DROP TYPE notification_ltype;
UPDATE notifications SET c_byuser = NULL WHERE c_byuser = 0;

\i sql/func.sql
\i sql/triggers.sql
