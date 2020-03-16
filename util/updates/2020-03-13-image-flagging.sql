ALTER TABLE images ADD COLUMN c_votecount integer NOT NULL DEFAULT 0;
ALTER TABLE images ADD COLUMN c_sexual_avg float;
ALTER TABLE images ADD COLUMN c_sexual_stddev float;
ALTER TABLE images ADD COLUMN c_violence_avg float;
ALTER TABLE images ADD COLUMN c_violence_stddev float;
ALTER TABLE images ADD COLUMN c_weight float NOT NULL DEFAULT 0;

CREATE TABLE image_votes (
  id       image_id NOT NULL,
  uid      integer,
  sexual   smallint NOT NULL CHECK(sexual >= 0 AND sexual <= 2),
  violence smallint NOT NULL CHECK(violence >= 0 AND violence <= 2),
  date     timestamptz NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX image_votes_pkey ON image_votes (uid, id);
CREATE INDEX image_votes_id ON image_votes (id);
ALTER TABLE image_votes ADD CONSTRAINT image_votes_id_fkey      FOREIGN KEY (id) REFERENCES images (id);

-- These significantly speed up the update_image_cache() and reverse image search on the flagging UI
CREATE INDEX vn_image ON vn (image);
CREATE INDEX vn_screenshots_scr ON vn_screenshots (scr);
CREATE INDEX chars_image ON chars (image);

\i util/sql/func.sql
\i util/sql/triggers.sql
\i util/sql/perms.sql

\timing
select update_images_cache(NULL);
