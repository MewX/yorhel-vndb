CREATE UNIQUE INDEX reviews_posts_uid      ON reviews_posts (uid);

ALTER TABLE reviews ADD COLUMN c_up      int NOT NULL DEFAULT 0;
ALTER TABLE reviews ADD COLUMN c_down    int NOT NULL DEFAULT 0;
ALTER TABLE reviews ADD COLUMN c_count   smallint NOT NULL DEFAULT 0;
ALTER TABLE reviews ADD COLUMN c_lastnum smallint;

\i sql/func.sql
\i sql/triggers.sql

SELECT update_reviews_votes_cache(NULL);
UPDATE reviews
   SET c_count   = COALESCE((SELECT COUNT(*) FROM reviews_posts WHERE NOT hidden AND id = reviews.id), 0)
     , c_lastnum = (SELECT MAX(num) FROM reviews_posts WHERE NOT hidden AND id = reviews.id);
