
-- plpgsql is required for our (trigger) functions
CREATE LANGUAGE plpgsql;


-- data types

CREATE TYPE anime_type        AS ENUM ('tv', 'ova', 'mov', 'oth', 'web', 'spe', 'mv');
CREATE TYPE dbentry_type      AS ENUM ('v', 'r', 'p');
CREATE TYPE medium            AS ENUM ('cd', 'dvd', 'gdr', 'blr', 'flp', 'mrt', 'mem', 'umd', 'nod', 'in', 'otc');
CREATE TYPE producer_relation AS ENUM ('old', 'new', 'sub', 'par', 'imp', 'ipa', 'spa', 'ori');
CREATE TYPE release_type      AS ENUM ('complete', 'partial', 'trial');
CREATE TYPE vn_relation       AS ENUM ('seq', 'preq', 'set', 'alt', 'char', 'side', 'par', 'ser', 'fan', 'orig');


-----------------------------------------
--  T A B L E   D E F I N I T I O N S  --
-----------------------------------------


-- anime
CREATE TABLE anime (
  id integer NOT NULL PRIMARY KEY,
  year smallint,
  ann_id integer,
  nfo_id varchar(200),
  type anime_type,
  title_romaji,
  title_kanji,
  lastfetch timestamptz
);

-- changes
CREATE TABLE changes (
  id SERIAL NOT NULL PRIMARY KEY,
  type dbentry_type NOT NULL,
  rev integer NOT NULL DEFAULT 1,
  added timestamptz NOT NULL DEFAULT NOW(),
  requester integer NOT NULL DEFAULT 0,
  ip inet NOT NULL DEFAULT '0.0.0.0',
  comments text NOT NULL DEFAULT ''
);

-- producers
CREATE TABLE producers (
  id SERIAL NOT NULL PRIMARY KEY,
  latest integer NOT NULL DEFAULT 0,
  locked boolean NOT NULL DEFAULT FALSE,
  hidden boolean NOT NULL DEFAULT FALSE,
  rgraph integer
);

-- producers_relations
CREATE TABLE producers_relations (
  pid1 integer NOT NULL,
  pid2 integer NOT NULL,
  relation producer_relation NOT NULL,
  PRIMARY KEY(pid1, pid2)
);

-- producers_rev
CREATE TABLE producers_rev (
  id integer NOT NULL PRIMARY KEY,
  pid integer NOT NULL DEFAULT 0,
  type character(2) NOT NULL DEFAULT 'co',
  name varchar(200) NOT NULL DEFAULT '',
  original varchar(200) NOT NULL DEFAULT '',
  website varchar(250) NOT NULL DEFAULT '',
  lang varchar NOT NULL DEFAULT 'ja',
  "desc" text NOT NULL DEFAULT '',
  alias varchar(500) NOT NULL DEFAULT '',
  l_wp varchar(150)
);

-- quotes
CREATE TABLE quotes (
  vid integer NOT NULL,
  quote varchar(250) NOT NULL,
  PRIMARY KEY(vid, quote)
);

-- releases
CREATE TABLE releases (
  id SERIAL NOT NULL PRIMARY KEY,
  latest integer NOT NULL DEFAULT 0,
  locked boolean NOT NULL DEFAULT FALSE,
  hidden boolean NOT NULL DEFAULT FALSE
);

-- releases_lang
CREATE TABLE releases_lang (
  rid integer NOT NULL,
  lang varchar NOT NULL,
  PRIMARY KEY(rid, lang)
);

-- releases_media
CREATE TABLE releases_media (
  rid integer NOT NULL DEFAULT 0,
  medium medium NOT NULL,
  qty smallint NOT NULL DEFAULT 1,
  PRIMARY KEY(rid, medium, qty)
);

-- releases_platforms
CREATE TABLE releases_platforms (
  rid integer NOT NULL DEFAULT 0,
  platform character(3) NOT NULL DEFAULT 0,
  PRIMARY KEY(rid, platform)
);

-- releases_producers
CREATE TABLE releases_producers (
  rid integer NOT NULL,
  pid integer NOT NULL,
  developer boolean NOT NULL DEFAULT FALSE,
  publisher boolean NOT NULL DEFAULT TRUE,
  CHECK(developer OR publisher),
  PRIMARY KEY(pid, rid)
);

-- releases_rev
CREATE TABLE releases_rev (
  id integer NOT NULL PRIMARY KEY,
  rid integer NOT NULL DEFAULT 0,
  title varchar(250) NOT NULL DEFAULT '',
  original varchar(250) NOT NULL DEFAULT '',
  type release_type NOT NULL DEFAULT 'complete',
  website varchar(250) NOT NULL DEFAULT '',
  released integer NOT NULL,
  notes text NOT NULL DEFAULT '',
  minage smallint,
  gtin bigint NOT NULL DEFAULT 0,
  patch boolean NOT NULL DEFAULT FALSE,
  catalog varchar(50) NOT NULL DEFAULT '',
  resolution smallint NOT NULL DEFAULT 0,
  voiced smallint NOT NULL DEFAULT 0,
  freeware boolean NOT NULL DEFAULT FALSE,
  doujin boolean NOT NULL DEFAULT FALSE,
  ani_story smallint NOT NULL DEFAULT 0,
  ani_ero smallint NOT NULL DEFAULT 0
);

-- releases_vn
CREATE TABLE releases_vn (
  rid integer NOT NULL DEFAULT 0,
  vid integer NOT NULL DEFAULT 0,
  PRIMARY KEY(rid, vid)
);

-- relgraphs
CREATE TABLE relgraphs (
  id SERIAL PRIMARY KEY,
  svg xml NOT NULL
);

-- rlists
CREATE TABLE rlists (
  uid integer NOT NULL DEFAULT 0,
  rid integer NOT NULL DEFAULT 0,
  vstat smallint NOT NULL DEFAULT 0,
  rstat smallint NOT NULL DEFAULT 0,
  added timestamptz NOT NULL DEFAULT NOW(),
  PRIMARY KEY(uid, rid)
);

-- screenshots
CREATE TABLE screenshots (
  id SERIAL NOT NULL PRIMARY KEY,
  processed boolean NOT NULL DEFAULT FALSE,
  width smallint NOT NULL DEFAULT 0,
  height smallint NOT NULL DEFAULT 0
);

-- sessions
CREATE TABLE sessions (
  uid integer NOT NULL,
  token bytea NOT NULL,
  expiration timestamptz NOT NULL DEFAULT (now() + '1 year'::interval),
  PRIMARY KEY (uid, token)
);

-- stats_cache
CREATE TABLE stats_cache (
  section varchar(25) NOT NULL PRIMARY KEY,
  count integer NOT NULL DEFAULT 0
);

-- tags
CREATE TABLE tags (
  id SERIAL NOT NULL PRIMARY KEY,
  name varchar(250) NOT NULL UNIQUE,
  description text NOT NULL DEFAULT '',
  meta boolean NOT NULL DEFAULT FALSE,
  added timestamptz NOT NULL DEFAULT NOW(),
  state smallint NOT NULL DEFAULT 0,
  c_vns integer NOT NULL DEFAULT 0,
  addedby integer NOT NULL DEFAULT 1
);

-- tags_aliases
CREATE TABLE tags_aliases (
  alias varchar(250) NOT NULL PRIMARY KEY,
  tag integer NOT NULL,
);

-- tags_parents
CREATE TABLE tags_parents (
  tag integer NOT NULL,
  parent integer NOT NULL,
  PRIMARY KEY(tag, parent)
);

-- tags_vn
CREATE TABLE tags_vn (
  tag integer NOT NULL,
  vid integer NOT NULL,
  uid integer NOT NULL,
  vote smallint NOT NULL DEFAULT 3 CHECK (vote >= -3 AND vote <= 3 AND vote <> 0),
  spoiler smallint CHECK(spoiler >= 0 AND spoiler <= 2),
  PRIMARY KEY(tag, vid, uid)
);

-- tags_vn_inherit
CREATE TABLE tags_vn_inherit (
  tag integer NOT NULL,
  vid integer NOT NULL,
  users integer NOT NULL,
  rating real NOT NULL,
  spoiler smallint NOT NULL
);

-- threads
CREATE TABLE threads (
  id SERIAL NOT NULL PRIMARY KEY,
  title varchar(50) NOT NULL DEFAULT '',
  locked boolean NOT NULL DEFAULT FALSE,
  hidden boolean NOT NULL DEFAULT FALSE,
  count smallint NOT NULL DEFAULT 0
);

-- threads_posts
CREATE TABLE threads_posts (
  tid integer NOT NULL DEFAULT 0,
  num smallint NOT NULL DEFAULT 0,
  uid integer NOT NULL DEFAULT 0,
  date timestamptz NOT NULL DEFAULT NOW(),
  edited timestamptz,
  msg text NOT NULL DEFAULT '',
  hidden boolean NOT NULL DEFAULT FALSE,
  PRIMARY KEY(tid, num)
);

-- threads_boards
CREATE TABLE threads_boards (
  tid integer NOT NULL DEFAULT 0,
  type character(2) NOT NULL DEFAULT 0,
  iid integer NOT NULL DEFAULT 0,
  lastread smallint NOT NULL,
  PRIMARY KEY(tid, type, iid)
);

-- users
CREATE TABLE users (
  id SERIAL NOT NULL PRIMARY KEY,
  username varchar(20) NOT NULL UNIQUE,
  mail varchar(100) NOT NULL,
  rank smallint NOT NULL DEFAULT 3,
  passwd bytea NOT NULL DEFAULT '',
  registered timestamptz NOT NULL DEFAULT NOW(),
  show_nsfw boolean NOT NULL DEFAULT FALSE,
  show_list boolean NOT NULL DEFAULT TRUE,
  c_votes integer NOT NULL DEFAULT 0,
  c_changes integer NOT NULL DEFAULT 0,
  skin varchar(128) NOT NULL DEFAULT '',
  customcss text NOT NULL DEFAULT '',
  ip inet NOT NULL DEFAULT '0.0.0.0',
  c_tags integer NOT NULL DEFAULT 0,
  salt character(9) NOT NULL DEFAULT '',
  ign_votes voolean NOT NULL DEFAULT FALSE
);

-- vn
CREATE TABLE vn (
  id SERIAL NOT NULL PRIMARY KEY,
  latest integer NOT NULL DEFAULT 0,
  locked boolean NOT NULL DEFAULT FALSE,
  hidden boolean NOT NULL DEFAULT FALSE,
  rgraph integer,
  c_released integer NOT NULL DEFAULT 0,
  c_languages varchar(32) NOT NULL DEFAULT '',
  c_platforms varchar(32) NOT NULL DEFAULT '',
  c_popularity real,
  c_rating real,
  c_votecount integer NOT NULL DEFAULT 0
);

-- vn_anime
CREATE TABLE vn_anime (
  vid integer NOT NULL,
  aid integer NOT NULL,
  PRIMARY KEY(vid, aid)
);

-- vn_relations
CREATE TABLE vn_relations (
  vid1 integer NOT NULL DEFAULT 0,
  vid2 integer NOT NULL DEFAULT 0,
  relation vn_relation NOT NULL,
  PRIMARY KEY(vid1, vid2)
);

-- vn_rev
CREATE TABLE vn_rev (
  id integer NOT NULL PRIMARY KEY,
  vid integer NOT NULL DEFAULT 0,
  title varchar(250) NOT NULL DEFAULT '',
  original varchar(250) NOT NULL DEFAULT '',
  alias varchar(500) NOT NULL DEFAULT '',
  img_nsfw boolean NOT NULL DEFAULT FALSE,
  length smallint NOT NULL DEFAULT 0,
  "desc" text NOT NULL DEFAULT '',
  l_wp varchar(150) NOT NULL DEFAULT '',
  l_vnn integer NOT NULL DEFAULT 0,
  image integer NOT NULL DEFAULT 0,
  l_encubed varchar(100) NOT NULL DEFAULT '',
  l_renai varchar(100) NOT NULL DEFAULT ''
);

-- vn_screenshots
CREATE TABLE vn_screenshots (
  vid integer NOT NULL DEFAULT 0,
  scr integer NOT NULL DEFAULT 0,
  nsfw boolean NOT NULL DEFAULT FALSE,
  rid integer DEFAULT NULL,
  PRIMARY KEY(vid, scr)
);

-- votes
CREATE TABLE votes (
  vid integer NOT NULL DEFAULT 0,
  uid integer NOT NULL DEFAULT 0,
  vote integer NOT NULL DEFAULT 0,
  date timestamptz NOT NULL DEFAULT NOW(),
  PRIMARY KEY(vid, uid)
);

-- wlists
CREATE TABLE wlists (
  uid integer NOT NULL DEFAULT 0,
  vid integer NOT NULL DEFAULT 0,
  wstat smallint NOT NULL DEFAULT 0,
  added timestamptz NOT NULL DEFAULT NOW(),
  PRIMARY KEY(uid, vid)
);





-----------------------------------------------
--  F O R E I G N   K E Y   C H E C K I N G  --
-----------------------------------------------


ALTER TABLE changes            ADD FOREIGN KEY (requester) REFERENCES users         (id);
ALTER TABLE producers          ADD FOREIGN KEY (latest)    REFERENCES producers_rev (id) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE producers          ADD FOREIGN KEY (rgraph)    REFERENCES relgraphs     (id);
ALTER TABLE producers_relations ADD FOREIGN KEY (pid1)     REFERENCES producers_rev (id);
ALTER TABLE producers_relations ADD FOREIGN KEY (pid2)     REFERENCES producers     (id);
ALTER TABLE producers_rev      ADD FOREIGN KEY (id)        REFERENCES changes       (id);
ALTER TABLE producers_rev      ADD FOREIGN KEY (pid)       REFERENCES producers     (id);
ALTER TABLE quotes             ADD FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE releases           ADD FOREIGN KEY (latest)    REFERENCES releases_rev  (id) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE releases_lang      ADD FOREIGN KEY (rid)       REFERENCES releases_rev  (id);
ALTER TABLE releases_media     ADD FOREIGN KEY (rid)       REFERENCES releases_rev  (id);
ALTER TABLE releases_platforms ADD FOREIGN KEY (rid)       REFERENCES releases_rev  (id);
ALTER TABLE releases_producers ADD FOREIGN KEY (rid)       REFERENCES releases_rev  (id);
ALTER TABLE releases_producers ADD FOREIGN KEY (pid)       REFERENCES producers     (id);
ALTER TABLE releases_rev       ADD FOREIGN KEY (id)        REFERENCES changes       (id);
ALTER TABLE releases_rev       ADD FOREIGN KEY (rid)       REFERENCES releases      (id);
ALTER TABLE releases_vn        ADD FOREIGN KEY (rid)       REFERENCES releases_rev  (id);
ALTER TABLE releases_vn        ADD FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE rlists             ADD FOREIGN KEY (uid)       REFERENCES users         (id);
ALTER TABLE rlists             ADD FOREIGN KEY (rid)       REFERENCES releases      (id);
ALTER TABLE sessions           ADD FOREIGN KEY (uid)       REFERENCES users         (id);
ALTER TABLE tags               ADD FOREIGN KEY (addedby)   REFERENCES users         (id);
ALTER TABLE tags_aliases       ADD FOREIGN KEY (tag)       REFERENCES tags          (id);
ALTER TABLE tags_parents       ADD FOREIGN KEY (tag)       REFERENCES tags          (id);
ALTER TABLE tags_parents       ADD FOREIGN KEY (parent)    REFERENCES tags          (id);
ALTER TABLE tags_vn            ADD FOREIGN KEY (tag)       REFERENCES tags          (id);
ALTER TABLE tags_vn            ADD FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE tags_vn            ADD FOREIGN KEY (uid)       REFERENCES users         (id);
ALTER TABLE threads            ADD FOREIGN KEY (id, count) REFERENCES threads_posts (tid, num) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE threads_posts      ADD FOREIGN KEY (tid)       REFERENCES threads       (id);
ALTER TABLE threads_posts      ADD FOREIGN KEY (uid)       REFERENCES users         (id);
ALTER TABLE threads_boards     ADD FOREIGN KEY (tid)       REFERENCES threads       (id);
ALTER TABLE vn                 ADD FOREIGN KEY (latest)    REFERENCES vn_rev        (id) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE vn                 ADD FOREIGN KEY (rgraph)    REFERENCES relgraphs     (id);
ALTER TABLE vn_anime           ADD FOREIGN KEY (aid)       REFERENCES anime         (id);
ALTER TABLE vn_anime           ADD FOREIGN KEY (vid)       REFERENCES vn_rev        (id);
ALTER TABLE vn_relations       ADD FOREIGN KEY (vid1)      REFERENCES vn_rev        (id);
ALTER TABLE vn_relations       ADD FOREIGN KEY (vid2)      REFERENCES vn            (id);
ALTER TABLE vn_rev             ADD FOREIGN KEY (id)        REFERENCES changes       (id);
ALTER TABLE vn_rev             ADD FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE vn_screenshots     ADD FOREIGN KEY (vid)       REFERENCES vn_rev        (id);
ALTER TABLE vn_screenshots     ADD FOREIGN KEY (scr)       REFERENCES screenshots   (id);
ALTER TABLE vn_screenshots     ADD FOREIGN KEY (rid)       REFERENCES releases      (id);
ALTER TABLE votes              ADD FOREIGN KEY (uid)       REFERENCES users         (id);
ALTER TABLE votes              ADD FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE wlists             ADD FOREIGN KEY (uid)       REFERENCES users         (id);
ALTER TABLE wlists             ADD FOREIGN KEY (vid)       REFERENCES vn            (id);






-------------------------
--  F U N C T I O N S  --
-------------------------


-- update_vncache(id) - updates the c_* columns in the vn table
CREATE OR REPLACE FUNCTION update_vncache(integer) RETURNS void AS $$
  UPDATE vn SET
    c_released = COALESCE((SELECT
      MIN(rr1.released)
      FROM releases_rev rr1
      JOIN releases r1 ON rr1.id = r1.latest
      JOIN releases_vn rv1 ON rr1.id = rv1.rid
      WHERE rv1.vid = vn.id
      AND rr1.type <> 'trial'
      AND r1.hidden = FALSE
      AND rr1.released <> 0
      GROUP BY rv1.vid
    ), 0),
    c_languages = COALESCE(ARRAY_TO_STRING(ARRAY(
      SELECT rl2.lang
      FROM releases_rev rr2
      JOIN releases_lang rl2 ON rl2.rid = rr2.id
      JOIN releases r2 ON rr2.id = r2.latest
      JOIN releases_vn rv2 ON rr2.id = rv2.rid
      WHERE rv2.vid = vn.id
      AND rr2.type <> 'trial'
      AND rr2.released <= TO_CHAR('today'::timestamp, 'YYYYMMDD')::integer
      AND r2.hidden = FALSE
      GROUP BY rl2.lang
      ORDER BY rl2.lang
    ), '/'), ''),
    c_platforms = COALESCE(ARRAY_TO_STRING(ARRAY(
      SELECT rp3.platform
      FROM releases_platforms rp3
      JOIN releases_rev rr3 ON rp3.rid = rr3.id
      JOIN releases r3 ON rp3.rid = r3.latest
      JOIN releases_vn rv3 ON rp3.rid = rv3.rid
      WHERE rv3.vid = vn.id
      AND rr3.type <> 'trial'
      AND rr3.released <= TO_CHAR('today'::timestamp, 'YYYYMMDD')::integer
      AND r3.hidden = FALSE
      GROUP BY rp3.platform
      ORDER BY rp3.platform
    ), '/'), '')
  WHERE id = $1;
$$ LANGUAGE sql;


-- recalculate vn.c_popularity
CREATE OR REPLACE FUNCTION update_vnpopularity() RETURNS void AS $$
BEGIN
  CREATE OR REPLACE TEMP VIEW tmp_pop1 (uid, vid, rank) AS
      SELECT v.uid, v.vid, sqrt(count(*))::real
        FROM votes v
        JOIN votes v2 ON v.uid = v2.uid AND v2.vote < v.vote
        JOIN users u ON u.id = v.uid AND NOT ign_votes
    GROUP BY v.vid, v.uid;
  CREATE OR REPLACE TEMP VIEW tmp_pop2 (vid, win) AS
    SELECT vid, sum(rank) FROM tmp_pop1 GROUP BY vid;
  UPDATE vn SET c_popularity = (SELECT win/(SELECT MAX(win) FROM tmp_pop2) FROM tmp_pop2 WHERE vid = id);
  RETURN;
END;
$$ LANGUAGE plpgsql;


-- recalculate tags_vn_inherit
CREATE OR REPLACE FUNCTION tag_vn_calc() RETURNS void AS $$
BEGIN
  DROP INDEX IF EXISTS tags_vn_inherit_tag_vid;
  TRUNCATE tags_vn_inherit;
  -- populate tags_vn_inherit
  INSERT INTO tags_vn_inherit
    -- all votes for all tags, including votes inherited by child tags
    -- (also includes meta tags, because they could have a normal tag as parent)
    WITH RECURSIVE tags_vn_all(lvl, tag, vid, uid, vote, spoiler, meta) AS (
        SELECT 15, tag, vid, uid, vote, spoiler, false
        FROM tags_vn
      UNION ALL
        SELECT lvl-1, tp.parent, ta.vid, ta.uid, ta.vote, ta.spoiler, t.meta
        FROM tags_vn_all ta
        JOIN tags_parents tp ON tp.tag = ta.tag
        JOIN tags t ON t.id = tp.parent
        WHERE t.state = 2
          AND ta.lvl > 0
    )
    -- grouped by (tag, vid)
    SELECT tag, vid, COUNT(uid) AS users, AVG(vote)::real AS rating,
           (CASE WHEN AVG(spoiler) < 0.7 THEN 0 WHEN AVG(spoiler) > 1.3 THEN 2 ELSE 1 END)::smallint AS spoiler
    FROM (
      -- grouped by (tag, vid, uid), so only one user votes on one parent tag per VN entry (also removing meta tags)
      SELECT tag, vid, uid, MAX(vote)::real, COALESCE(AVG(spoiler), 0)::real
      FROM tags_vn_all
      WHERE NOT meta
      GROUP BY tag, vid, uid
    ) AS t(tag, vid, uid, vote, spoiler)
    GROUP BY tag, vid
    HAVING AVG(vote) > 0;
  -- recreate index
  CREATE INDEX tags_vn_inherit_tag_vid ON tags_vn_inherit (tag, vid);
  -- and update the VN count in the tags table
  UPDATE tags SET c_vns = (SELECT COUNT(*) FROM tags_vn_inherit WHERE tag = id);
  RETURN;
END;
$$ LANGUAGE plpgsql;
SELECT tag_vn_calc();





-----------------------
--  T R I G G E R S  --
-----------------------


-- keep the c_* columns in the users table up to date
CREATE OR REPLACE FUNCTION update_users_cache() RETURNS TRIGGER AS $$
BEGIN
  IF TG_TABLE_NAME = 'votes' THEN
    IF TG_OP = 'INSERT' THEN
      UPDATE users SET c_votes = c_votes + 1 WHERE id = NEW.uid;
    ELSE
      UPDATE users SET c_votes = c_votes - 1 WHERE id = OLD.uid;
    END IF;
  ELSIF TG_TABLE_NAME = 'changes' THEN
    IF TG_OP = 'INSERT' THEN
      UPDATE users SET c_changes = c_changes + 1 WHERE id = NEW.requester;
    ELSE
      UPDATE users SET c_changes = c_changes - 1 WHERE id = OLD.requester;
    END IF;
  ELSIF TG_TABLE_NAME = 'tags_vn' THEN
    IF TG_OP = 'INSERT' THEN
      UPDATE users SET c_tags = c_tags + 1 WHERE id = NEW.uid;
    ELSE
      UPDATE users SET c_tags = c_tags - 1 WHERE id = OLD.uid;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER users_changes_update AFTER INSERT OR DELETE ON changes FOR EACH ROW EXECUTE PROCEDURE update_users_cache();
CREATE TRIGGER users_votes_update   AFTER INSERT OR DELETE ON votes   FOR EACH ROW EXECUTE PROCEDURE update_users_cache();
CREATE TRIGGER users_tags_update    AFTER INSERT OR DELETE ON tags_vn FOR EACH ROW EXECUTE PROCEDURE update_users_cache();


-- the stats_cache table
CREATE OR REPLACE FUNCTION update_stats_cache() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF TG_TABLE_NAME = 'users' THEN
      UPDATE stats_cache SET count = count+1 WHERE section = TG_TABLE_NAME;
    ELSIF NEW.hidden = FALSE THEN
      IF TG_TABLE_NAME = 'threads_posts' THEN
        IF EXISTS(SELECT 1 FROM threads WHERE id = NEW.tid AND hidden = FALSE) THEN
          UPDATE stats_cache SET count = count+1 WHERE section = TG_TABLE_NAME;
        END IF;
      ELSE
        UPDATE stats_cache SET count = count+1 WHERE section = TG_TABLE_NAME;
      END IF;
    END IF;

  ELSIF TG_OP = 'UPDATE' AND TG_TABLE_NAME <> 'users' THEN
    IF OLD.hidden = TRUE AND NEW.hidden = FALSE THEN
      IF TG_TABLE_NAME = 'threads' THEN
        UPDATE stats_cache SET count = count+NEW.count WHERE section = 'threads_posts';
      END IF;
      UPDATE stats_cache SET count = count+1 WHERE section = TG_TABLE_NAME;
    ELSIF OLD.hidden = FALSE AND NEW.hidden = TRUE THEN
      IF TG_TABLE_NAME = 'threads' THEN
        UPDATE stats_cache SET count = count-NEW.count WHERE section = 'threads_posts';
      END IF;
      UPDATE stats_cache SET count = count-1 WHERE section = TG_TABLE_NAME;
    END IF;

  ELSIF TG_OP = 'DELETE' AND TG_TABLE_NAME = 'users' THEN
    UPDATE stats_cache SET count = count-1 WHERE section = TG_TABLE_NAME;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER vn_stats_update            AFTER INSERT OR UPDATE ON vn            FOR EACH ROW EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER producers_stats_update     AFTER INSERT OR UPDATE ON producers     FOR EACH ROW EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER releases_stats_update      AFTER INSERT OR UPDATE ON releases      FOR EACH ROW EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER threads_stats_update       AFTER INSERT OR UPDATE ON threads       FOR EACH ROW EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER threads_posts_stats_update AFTER INSERT OR UPDATE ON threads_posts FOR EACH ROW EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER users_stats_update         AFTER INSERT OR DELETE ON users         FOR EACH ROW EXECUTE PROCEDURE update_stats_cache();


-- insert rows into anime for new vn_anime.aid items
CREATE OR REPLACE FUNCTION vn_anime_aid() RETURNS trigger AS $$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM anime WHERE id = NEW.aid) THEN
    INSERT INTO anime (id) VALUES (NEW.aid);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER vn_anime_aid BEFORE INSERT OR UPDATE ON vn_anime FOR EACH ROW EXECUTE PROCEDURE vn_anime_aid();


-- Send a notify whenever anime info should be fetched
CREATE OR REPLACE FUNCTION anime_fetch_notify() RETURNS trigger AS $$
BEGIN
  IF NEW.lastfetch IS NULL THEN
    NOTIFY anime;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER anime_fetch_notify AFTER INSERT OR UPDATE ON anime FOR EACH ROW EXECUTE PROCEDURE anime_fetch_notify();


-- Send a notify when a new cover image is uploaded
CREATE OR REPLACE FUNCTION vn_rev_image_notify() RETURNS trigger AS $$
BEGIN
  IF NEW.image < 0 THEN
    NOTIFY coverimage;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER vn_rev_image_notify AFTER INSERT OR UPDATE ON vn_rev FOR EACH ROW EXECUTE PROCEDURE vn_rev_image_notify();


-- Send a notify when a screenshot needs to be processed
CREATE OR REPLACE FUNCTION screenshot_process_notify() RETURNS trigger AS $$
BEGIN
  IF NEW.processed = FALSE THEN
    NOTIFY screenshot;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER screenshot_process_notify AFTER INSERT OR UPDATE ON screenshots FOR EACH ROW EXECUTE PROCEDURE screenshot_process_notify();


-- Update vn.rgraph column and send notify when a relation graph needs to be regenerated
-- 1. NOTIFY is sent on VN edit or insert or change in vn.rgraph, when rgraph = NULL and entries in vn_relations
-- vn.rgraph is set to NULL when:
-- 2. UPDATE on vn where c_released or c_languages has changed
-- 3. VN edit of which the title differs from previous revision
-- 4. VN edit with items in vn_relations that differ from previous
CREATE OR REPLACE FUNCTION vn_relgraph_notify() RETURNS trigger AS $$
BEGIN
  -- 1.
  IF NEW.rgraph IS DISTINCT FROM OLD.rgraph OR NEW.latest IS DISTINCT FROM OLD.latest THEN
    IF NEW.rgraph IS NULL AND EXISTS(SELECT 1 FROM vn_relations WHERE vid1 = NEW.latest) THEN
      NOTIFY relgraph;
    END IF;
  END IF;
  IF NEW.rgraph IS NOT NULL THEN
    IF
      -- 2.
         OLD.c_released  IS DISTINCT FROM NEW.c_released
      OR OLD.c_languages IS DISTINCT FROM NEW.c_languages
      OR OLD.latest <> 0 AND OLD.latest IS DISTINCT FROM NEW.latest AND (
        -- 3.
           EXISTS(SELECT 1 FROM vn_rev v1, vn_rev v2 WHERE v2.title <> v1.title AND v1.id = OLD.latest AND v2.id = NEW.latest)
        -- 4. (not-really-readable method of comparing two query results)
        OR EXISTS(SELECT vid2, relation FROM vn_relations WHERE vid1 = OLD.latest EXCEPT SELECT vid2, relation FROM vn_relations WHERE vid1 = NEW.latest)
        OR (SELECT COUNT(*) FROM vn_relations WHERE vid1 = OLD.latest) <> (SELECT COUNT(*) FROM vn_relations WHERE vid1 = NEW.latest)
      )
    THEN
      UPDATE vn SET rgraph = NULL WHERE id = NEW.id;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER vn_relgraph_notify AFTER UPDATE ON vn FOR EACH ROW EXECUTE PROCEDURE vn_relgraph_notify();


-- Same as above for producers, with slight differences in the steps:
-- There is no 2, and
-- 3 = Producer edit of which the name, language or type differs from the previous revision
CREATE OR REPLACE FUNCTION producer_relgraph_notify() RETURNS trigger AS $$
BEGIN
  -- 1.
  IF NEW.rgraph IS DISTINCT FROM OLD.rgraph OR NEW.latest IS DISTINCT FROM OLD.latest THEN
    IF NEW.rgraph IS NULL AND EXISTS(SELECT 1 FROM producers_relations WHERE pid1 = NEW.latest) THEN
      NOTIFY relgraph;
    END IF;
  END IF;
  IF NEW.rgraph IS NOT NULL THEN
    -- 2.
    IF OLD.latest <> 0 AND OLD.latest IS DISTINCT FROM NEW.latest AND (
        -- 3.
           EXISTS(SELECT 1 FROM producers_rev p1, producers_rev p2 WHERE (p2.name <> p1.name OR p2.type <> p1.type OR p2.lang <> p1.lang) AND p1.id = OLD.latest AND p2.id = NEW.latest)
        -- 4. (not-really-readable method of comparing two query results)
        OR EXISTS(SELECT p1.pid2, p1.relation FROM producers_relations p1 WHERE p1.pid1 = OLD.latest EXCEPT SELECT p2.pid2, p2.relation FROM producers_relations p2 WHERE p2.pid1 = NEW.latest)
        OR (SELECT COUNT(*) FROM producers_relations WHERE pid1 = OLD.latest) <> (SELECT COUNT(*) FROM producers_relations WHERE pid1 = NEW.latest)
      )
    THEN
      UPDATE producers SET rgraph = NULL WHERE id = NEW.id;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER producer_relgraph_notify AFTER UPDATE ON producers FOR EACH ROW EXECUTE PROCEDURE producer_relgraph_notify();


-- NOTIFY on insert into changes/posts/tags
CREATE OR REPLACE FUNCTION insert_notify() RETURNS trigger AS $$
BEGIN
  IF TG_TABLE_NAME = 'changes' THEN
    NOTIFY newrevision;
  ELSIF TG_TABLE_NAME = 'threads_posts' THEN
    NOTIFY newpost;
  ELSIF TG_TABLE_NAME = 'tags' THEN
    NOTIFY newtag;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER insert_notify AFTER INSERT ON changes FOR EACH STATEMENT EXECUTE PROCEDURE insert_notify();
CREATE TRIGGER insert_notify AFTER INSERT ON threads_posts FOR EACH STATEMENT EXECUTE PROCEDURE insert_notify();
CREATE TRIGGER insert_notify AFTER INSERT ON tags FOR EACH STATEMENT EXECUTE PROCEDURE insert_notify();


-- call update_vncache() when a release is added, edited, hidden or unhidden
CREATE OR REPLACE FUNCTION release_vncache_update() RETURNS trigger AS $$
BEGIN
  IF OLD.latest IS DISTINCT FROM NEW.latest OR OLD.hidden IS DISTINCT FROM NEW.hidden THEN
    PERFORM update_vncache(vid) FROM (
      SELECT DISTINCT vid FROM releases_vn WHERE rid = OLD.latest OR rid = NEW.latest
    ) AS v(vid);
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER release_vncache_update AFTER UPDATE ON releases FOR EACH ROW EXECUTE PROCEDURE release_vncache_update();





---------------------------------
--  M I S C E L L A N E O U S  --
---------------------------------


-- Sequences used for ID generation of items not in the DB
CREATE SEQUENCE covers_seq;


-- Rows that are assumed to be available
INSERT INTO users (id, username, mail, rank)
  VALUES (0, 'deleted', 'del@vndb.org', 0);
INSERT INTO users (username, mail, rank)
  VALUES ('multi', 'multi@vndb.org', 0);

INSERT INTO stats_cache (section, count) VALUES
  ('users',         1),
  ('vn',            0),
  ('producers',     0),
  ('releases',      0),
  ('threads',       0),
  ('threads_posts', 0);

