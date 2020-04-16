ALTER TABLE image_votes              ADD CONSTRAINT image_votes_uid_fkey               FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE SET DEFAULT;

DROP TRIGGER image_votes_cache ON image_votes;
\i sql/triggers.sql
