ALTER TABLE tags_vn DROP CONSTRAINT tags_vn_pkey;
ALTER TABLE tags_vn DROP CONSTRAINT tags_vn_uid_fkey;
ALTER TABLE tags_vn ALTER COLUMN uid DROP NOT NULL;
CREATE UNIQUE INDEX tags_vn_pkey ON tags_vn (tag,vid,uid);
DROP INDEX tags_vn_uid;
CREATE INDEX tags_vn_uid ON tags_vn (uid) WHERE uid IS NOT NULL;
UPDATE tags_vn SET uid = 0 WHERE uid IN(0,1);
ALTER TABLE tags_vn ADD CONSTRAINT tags_vn_uid_fkey FOREIGN KEY (uid) REFERENCES users (id) ON DELETE SET DEFAULT;
