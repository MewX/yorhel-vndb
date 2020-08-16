-- WIP: The modifications in this file are not final and haven't been integrated in sql/ yet.

CREATE SEQUENCE reviews_seq;

CREATE TABLE reviews (
  id      vndbid PRIMARY KEY DEFAULT vndbid('w', nextval('reviews_seq')::int) CONSTRAINT reviews_id_check CHECK(vndbid_type(id) = 'w'),
  vid     int NOT NULL,
  uid     int,
  rid     int,
  date    timestamptz NOT NULL DEFAULT NOW(),
  lastmod timestamptz,
  summary text NOT NULL,
  text    text,
  spoiler boolean NOT NULL
);

CREATE TABLE reviews_posts (
  id      vndbid NOT NULL,
  num     smallint NOT NULL,
  uid     integer,
  date    timestamptz NOT NULL DEFAULT NOW(),
  edited  timestamptz,
  hidden  boolean NOT NULL DEFAULT FALSE,
  msg     text NOT NULL DEFAULT '',
  PRIMARY KEY(id, num)
);

CREATE TABLE reviews_votes (
  id      vndbid NOT NULL,
  uid     int,
  date    timestamptz NOT NULL,
  vote    boolean NOT NULL -- true = upvote, false = downvote
);

CREATE UNIQUE INDEX reviews_vid_uid      ON reviews (vid,uid);
CREATE        INDEX reviews_uid          ON reviews (uid);
CREATE UNIQUE INDEX reviews_votes_id_uid ON reviews_votes (id,uid);

ALTER TABLE reviews       ADD CONSTRAINT reviews_vid_fkey       FOREIGN KEY (vid) REFERENCES vn       (id) ON DELETE CASCADE;
ALTER TABLE reviews       ADD CONSTRAINT reviews_uid_fkey       FOREIGN KEY (uid) REFERENCES users    (id) ON DELETE SET DEFAULT;
ALTER TABLE reviews       ADD CONSTRAINT reviews_rid_fkey       FOREIGN KEY (rid) REFERENCES releases (id) ON DELETE SET DEFAULT;
ALTER TABLE reviews_posts ADD CONSTRAINT reviews_posts_id_fkey  FOREIGN KEY (id)  REFERENCES reviews  (id) ON DELETE CASCADE;
ALTER TABLE reviews_posts ADD CONSTRAINT reviews_posts_uid_fkey FOREIGN KEY (uid) REFERENCES users    (id) ON DELETE SET DEFAULT;
ALTER TABLE reviews_votes ADD CONSTRAINT reviews_votes_id_fkey  FOREIGN KEY (id)  REFERENCES reviews  (id) ON DELETE CASCADE;
ALTER TABLE reviews_votes ADD CONSTRAINT reviews_votes_uid_fkey FOREIGN KEY (uid) REFERENCES users    (id) ON DELETE CASCADE;

ALTER TABLE users ADD COLUMN perm_review boolean NOT NULL DEFAULT true;
UPDATE users SET perm_review = false WHERE not perm_board;

\i sql/perms.sql

--c_votes int NOT NULL DEFAULT 0,
--c_avg   float
--
--CREATE OR REPLACE FUNCTION update_reviews_vote_cache() RETURNS trigger AS $$
--BEGIN
--  WITH stats(id,cnt,avg) AS (
--    SELECT id, COUNT(*), AVG(vote::int) FROM reviews_votes WHERE id IN(OLD.id,NEW.id) GROUP BY id
--  ) UPDATE reviews SET c_votes = cnt, c_avg = avg FROM stats WHERE reviews.id = stats.id;
--  RETURN NULL;
--END
--$$ LANGUAGE plpgsql;
--
--CREATE TRIGGER reviews_votes_cache1 AFTER INSERT OR DELETE ON reviews_votes FOR EACH ROW EXECUTE PROCEDURE update_reviews_vote_cache();
--CREATE TRIGGER reviews_votes_cache2 AFTER UPDATE ON reviews_votes FOR EACH ROW WHEN ((OLD.id, OLD.vote) IS DISTINCT FROM (NEW.id, NEW.vote)) EXECUTE PROCEDURE update_reviews_vote_cache();
