-- A small note on the function naming scheme:
--   edit_*      -> revision insertion abstraction functions
--   *_notify    -> functions issuing a PgSQL NOTIFY statement
--   notify_*    -> functions creating entries in the notifications table
--   user_*      -> functions to manage users and sessions
--   update_*    -> functions to update a cache
--   *_update    ^  (I should probably rename these to
--   *_calc      ^   the update_* scheme for consistency)
-- I like to keep the nouns in functions singular, in contrast to the table
-- naming scheme where nouns are always plural. But I'm not very consistent
-- with that, either.


-- strip_bb_tags(text) - simple utility function to aid full-text searching
CREATE OR REPLACE FUNCTION strip_bb_tags(t text) RETURNS text AS $$
  SELECT regexp_replace(t, '\[(?:url=[^\]]+|/?(?:spoiler|quote|raw|code|url))\]', ' ', 'gi');
$$ LANGUAGE sql IMMUTABLE;

-- Wrapper around to_tsvector() and strip_bb_tags(), implemented in plpgsql and
-- with an associated cost function to make it opaque to the query planner and
-- ensure the query planner realizes that this function is _slow_.
CREATE OR REPLACE FUNCTION bb_tsvector(t text) RETURNS tsvector AS $$
BEGIN
  RETURN to_tsvector('english', public.strip_bb_tags(t));
END;
$$ LANGUAGE plpgsql IMMUTABLE COST 500;

-- BUG: Since this isn't a full bbcode parser, [spoiler] tags inside [raw] or [code] are still considered spoilers.
CREATE OR REPLACE FUNCTION strip_spoilers(t text) RETURNS text AS $$
  -- The website doesn't require the [spoiler] tag to be closed, the outer replace catches that case.
  SELECT regexp_replace(regexp_replace(t, '\[spoiler\].*?\[/spoiler\]', ' ', 'ig'), '\[spoiler\].*', ' ', 'i');
$$ LANGUAGE sql IMMUTABLE;


-- Assigns a score to the relevance of a substring match, intended for use in
-- an ORDER BY clause. Exact matches are ordered first, prefix matches after
-- that, and finally a normal substring match. Not particularly fast, but
-- that's to be expected of naive substring searches.
-- Pattern must be escaped for use as a LIKE pattern.
CREATE OR REPLACE FUNCTION substr_score(str text, pattern text) RETURNS integer AS $$
SELECT CASE
  WHEN str ILIKE      pattern      THEN 0
  WHEN str ILIKE      pattern||'%' THEN 1
  WHEN str ILIKE '%'||pattern||'%' THEN 2
  ELSE 3
END;
$$ LANGUAGE SQL;


-- update_vncache(id) - updates some c_* columns in the vn table
CREATE OR REPLACE FUNCTION update_vncache(integer) RETURNS void AS $$
  UPDATE vn SET
    c_released = COALESCE((
      SELECT MIN(r.released)
        FROM releases r
        JOIN releases_vn rv ON r.id = rv.id
       WHERE rv.vid = $1
         AND r.type <> 'trial'
         AND r.hidden = FALSE
         AND r.released <> 0
      GROUP BY rv.vid
    ), 0),
    c_olang = ARRAY(
      SELECT lang
        FROM releases_lang
       WHERE id = (
        SELECT r.id
          FROM releases_vn rv
          JOIN releases r ON rv.id = r.id
         WHERE r.released > 0
           AND NOT r.hidden
           AND rv.vid = $1
         ORDER BY r.released
         LIMIT 1
       )
    ),
    c_languages = ARRAY(
      SELECT rl.lang
        FROM releases_lang rl
        JOIN releases r ON r.id = rl.id
        JOIN releases_vn rv ON r.id = rv.id
       WHERE rv.vid = $1
         AND r.type <> 'trial'
         AND r.released <= TO_CHAR('today'::timestamp, 'YYYYMMDD')::integer
         AND r.hidden = FALSE
      GROUP BY rl.lang
      ORDER BY rl.lang
    ),
    c_platforms = ARRAY(
      SELECT rp.platform
        FROM releases_platforms rp
        JOIN releases r ON rp.id = r.id
        JOIN releases_vn rv ON rp.id = rv.id
       WHERE rv.vid = $1
        AND r.type <> 'trial'
        AND r.released <= TO_CHAR('today'::timestamp, 'YYYYMMDD')::integer
        AND r.hidden = FALSE
      GROUP BY rp.platform
      ORDER BY rp.platform
    )
  WHERE id = $1;
$$ LANGUAGE sql;


-- Update vn.c_popularity, c_rating and c_votecount
CREATE OR REPLACE FUNCTION update_vnvotestats() RETURNS void AS $$
  WITH votes(vid, uid, vote) AS ( -- List of all non-ignored VN votes
    SELECT vid, uid, vote FROM ulist_vns WHERE vote IS NOT NULL AND uid NOT IN(SELECT id FROM users WHERE ign_votes)
  ), avgcount(avgcount) AS ( -- Average number of votes per VN
    SELECT COUNT(vote)::real/COUNT(DISTINCT vid)::real FROM votes
  ), avgavg(avgavg) AS ( -- Average vote average
    SELECT AVG(a)::real FROM (SELECT AVG(vote) FROM votes GROUP BY vid) x(a)
  ), ratings(vid, count, rating) AS ( -- Ratings and vote counts
    SELECT vid, COALESCE(COUNT(uid), 0),
           COALESCE(
              ((SELECT avgcount FROM avgcount) * (SELECT avgavg FROM avgavg) + SUM(vote)::real) /
              ((SELECT avgcount FROM avgcount) + COUNT(uid)::real),
           0)
      FROM votes
     GROUP BY vid
  ), popularities(vid, win) AS ( -- Popularity scores (before normalization)
    SELECT vid, SUM(rank)
      FROM (
        SELECT uid, vid, ((rank() OVER (PARTITION BY uid ORDER BY vote))::real - 1) ^ 0.36788 FROM votes
      ) x(uid, vid, rank)
     GROUP BY vid
  ), stats(vid, rating, count, popularity) AS ( -- Combined stats
    SELECT v.id, COALESCE(r.rating, 0), COALESCE(r.count, 0)
         , p.win/(SELECT MAX(win) FROM popularities)
      FROM vn v
      LEFT JOIN ratings r ON r.vid = v.id
      LEFT JOIN popularities p ON p.vid = v.id AND p.win > 0
  )
  UPDATE vn SET c_rating = rating, c_votecount = count, c_popularity = popularity FROM stats WHERE id = vid;
$$ LANGUAGE SQL;



-- c_weight = if not_referenced then 0 else lower(c_votecount) -> higher(c_weight) && higher(*_stddev) -> higher(c_weight)
--
-- Current algorithm:
--
--   votes_weight = max(0, 10 - c_votecount)/10   -> linear weight between 0..1, 0 being OK and 1 being BAD
--   weight = min(1, votes_weight*100 + sexual_stddev*100 + violence_stddev*100)
--
--   Extremes: 1 .. 300, easier to tune and reason about, but still linear
--
-- This isn't very grounded in theory, I've no clue how statistics work. I
-- suspect confidence intervals/levels are more appropriate for this use case.
--
-- Non-'ch' image weights are currently reduced to 20% in order to prioritize
-- character images.
CREATE OR REPLACE FUNCTION update_images_cache(vndbid) RETURNS void AS $$
BEGIN
  UPDATE images
     SET c_votecount = votecount, c_sexual_avg = sexual_avg, c_sexual_stddev = sexual_stddev
       , c_violence_avg = violence_avg, c_violence_stddev = violence_stddev, c_weight = weight
    FROM (
      SELECT s.*,
             CASE WHEN COALESCE(v1.id,v2.id,c.id) IS NULL THEN 0
             ELSE greatest(1,
                    ((greatest(0, 10.0 - s.votecount)/10)*100 + coalesce(s.sexual_stddev, 0)*100 + coalesce(s.violence_stddev, 0)*100)
                    * (CASE WHEN vndbid_type(s.id) = 'ch' THEN 1 ELSE 0.2 END)
                  )
             END AS weight
        FROM (
            SELECT i.id, count(iv.id) AS votecount
                 , avg(sexual)   AS sexual_avg,   stddev_pop(sexual)   AS sexual_stddev
                 , avg(violence) AS violence_avg, stddev_pop(violence) AS violence_stddev
              FROM images i
              LEFT JOIN image_votes iv ON iv.id = i.id
             WHERE ($1 IS NULL OR i.id = $1)
             GROUP BY i.id
        ) s
        LEFT JOIN vn v1 ON NOT v1.hidden AND v1.image = s.id
        LEFT JOIN vn_screenshots vs ON vs.scr = s.id
        LEFT JOIN vn v2 ON NOT v2.hidden AND vs.id = v2.id
        LEFT JOIN chars c ON NOT c.hidden AND c.image = s.id
    ) weights
   WHERE weights.id = images.id;
END; $$ LANGUAGE plpgsql;



-- Update users.c_vns, c_votes and c_wish for one user (when given an id) or all users (when given NULL)
CREATE OR REPLACE FUNCTION update_users_ulist_stats(integer) RETURNS void AS $$
BEGIN
  WITH cnt(uid, votes, vns, wish) AS (
    SELECT u.id
         , COUNT(DISTINCT uvl.vid) FILTER (WHERE NOT ul.private AND uv.vote IS NOT NULL) -- Voted
         , COUNT(DISTINCT uvl.vid) FILTER (WHERE NOT ul.private AND ul.id NOT IN(5,6)) -- Labelled, but not wishlish/blacklist
         , COUNT(DISTINCT uvl.vid) FILTER (WHERE NOT ul.private AND ul.id = 5) -- Wishlist
      FROM users u
      LEFT JOIN ulist_vns_labels uvl ON uvl.uid = u.id
      LEFT JOIN ulist_labels ul ON ul.id = uvl.lbl AND ul.uid = u.id
      LEFT JOIN ulist_vns uv ON uv.uid = u.id AND uv.vid = uvl.vid
     WHERE $1 IS NULL OR u.id = $1
     GROUP BY u.id
  ) UPDATE users SET c_votes = votes, c_vns = vns, c_wish = wish FROM cnt WHERE id = uid;
END;
$$ LANGUAGE plpgsql; -- Don't use "LANGUAGE SQL" here; Make sure to generate a new query plan at invocation time.



-- Recalculate tags_vn_inherit.
-- When a vid is given, only the tags for that vid will be updated. These
-- incremental updates do not affect tags.c_items, so that may still get
-- out-of-sync.
CREATE OR REPLACE FUNCTION tag_vn_calc(uvid integer) RETURNS void AS $$
BEGIN
  IF uvid IS NULL THEN
    DROP INDEX IF EXISTS tags_vn_inherit_tag_vid;
    TRUNCATE tags_vn_inherit;
  ELSE
    DELETE FROM tags_vn_inherit WHERE vid = uvid;
  END IF;

  INSERT INTO tags_vn_inherit (tag, vid, rating, spoiler)
    -- Group votes to generate a list of directly-upvoted (vid, tag) pairs.
    -- This is essentually the same as the tag listing on VN pages.
    WITH RECURSIVE t_avg(tag, vid, vote, spoiler) AS (
        SELECT tv.tag, tv.vid, AVG(tv.vote)::real, CASE WHEN COUNT(tv.spoiler) = 0 THEN MIN(t.defaultspoil) ELSE AVG(tv.spoiler)::real END
          FROM tags_vn tv
          JOIN tags t ON t.id = tv.tag
         WHERE NOT tv.ignore AND t.state = 2
           AND vid NOT IN(SELECT id FROM vn WHERE hidden)
           AND (uvid IS NULL OR vid = uvid)
         GROUP BY tv.tag, tv.vid
        HAVING AVG(tv.vote) > 0
    -- Add parent tags
    ), t_all(lvl, tag, vid, vote, spoiler) AS (
        SELECT 15, * FROM t_avg
        UNION ALL
        SELECT ta.lvl-1, tp.parent, ta.vid, ta.vote, ta.spoiler
          FROM t_all ta
          JOIN tags_parents tp ON tp.tag = ta.tag
         WHERE ta.lvl > 0
    )
    -- Merge
    SELECT tag, vid, AVG(vote)
         , (CASE WHEN MIN(spoiler) > 1.3 THEN 2 WHEN MIN(spoiler) > 0.4 THEN 1 ELSE 0 END)::smallint
      FROM t_all
     WHERE tag IN(SELECT id FROM tags WHERE searchable)
     GROUP BY tag, vid;

  IF uvid IS NULL THEN
    CREATE INDEX tags_vn_inherit_tag_vid ON tags_vn_inherit (tag, vid);
    UPDATE tags SET c_items = (SELECT COUNT(*) FROM tags_vn_inherit WHERE tag = id);
  END IF;

  RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Recalculate traits_chars. Pretty much same thing as tag_vn_calc().
CREATE OR REPLACE FUNCTION traits_chars_calc(ucid integer) RETURNS void AS $$
BEGIN
  IF ucid IS NULL THEN
    DROP INDEX IF EXISTS traits_chars_tid;
    TRUNCATE traits_chars;
  ELSE
    DELETE FROM traits_chars WHERE cid = ucid;
  END IF;

  INSERT INTO traits_chars (tid, cid, spoil)
    -- all char<->trait links of the latest revisions, including chars inherited from child traits.
    -- (also includes non-searchable traits, because they could have a searchable trait as parent)
    WITH RECURSIVE traits_chars_all(lvl, tid, cid, spoiler) AS (
        SELECT 15, tid, ct.id, spoil
          FROM chars_traits ct
         WHERE id NOT IN(SELECT id from chars WHERE hidden)
           AND (ucid IS NULL OR ct.id = ucid)
      UNION ALL
        SELECT lvl-1, tp.parent, tc.cid, tc.spoiler
        FROM traits_chars_all tc
        JOIN traits_parents tp ON tp.trait = tc.tid
        JOIN traits t ON t.id = tp.parent
        WHERE t.state = 2
          AND tc.lvl > 0
    )
    -- now grouped by (tid, cid), with non-searchable traits filtered out
    SELECT tid, cid
         , (CASE WHEN MIN(spoiler) > 1.3 THEN 2 WHEN MIN(spoiler) > 0.7 THEN 1 ELSE 0 END)::smallint AS spoiler
      FROM traits_chars_all
     WHERE tid IN(SELECT id FROM traits WHERE searchable)
     GROUP BY tid, cid;

  IF ucid IS NULL THEN
    CREATE INDEX traits_chars_tid ON traits_chars (tid);
    UPDATE traits SET c_items = (SELECT COUNT(*) FROM traits_chars WHERE tid = id);
  END IF;
  RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Fully recalculate all rows in stats_cache
CREATE OR REPLACE FUNCTION update_stats_cache_full() RETURNS void AS $$
BEGIN
  UPDATE stats_cache SET count = (SELECT COUNT(*) FROM users)-1 WHERE section = 'users';
  UPDATE stats_cache SET count = (SELECT COUNT(*) FROM vn        WHERE hidden = FALSE) WHERE section = 'vn';
  UPDATE stats_cache SET count = (SELECT COUNT(*) FROM releases  WHERE hidden = FALSE) WHERE section = 'releases';
  UPDATE stats_cache SET count = (SELECT COUNT(*) FROM producers WHERE hidden = FALSE) WHERE section = 'producers';
  UPDATE stats_cache SET count = (SELECT COUNT(*) FROM chars     WHERE hidden = FALSE) WHERE section = 'chars';
  UPDATE stats_cache SET count = (SELECT COUNT(*) FROM staff     WHERE hidden = FALSE) WHERE section = 'staff';
  UPDATE stats_cache SET count = (SELECT COUNT(*) FROM tags      WHERE state = 2)      WHERE section = 'tags';
  UPDATE stats_cache SET count = (SELECT COUNT(*) FROM traits    WHERE state = 2)      WHERE section = 'traits';
  UPDATE stats_cache SET count = (SELECT COUNT(*) FROM threads   WHERE hidden = FALSE) WHERE section = 'threads';
  UPDATE stats_cache SET count = (SELECT COUNT(*) FROM threads_posts WHERE hidden = FALSE
    AND EXISTS(SELECT 1 FROM threads WHERE threads.id = tid AND threads.hidden = FALSE)) WHERE section = 'threads_posts';
END;
$$ LANGUAGE plpgsql;


-- Create ulist labels for new users.
CREATE OR REPLACE FUNCTION ulist_labels_create(integer) RETURNS void AS $$
  INSERT INTO ulist_labels (uid, id, label, private)
       VALUES ($1, 1, 'Playing',   false),
              ($1, 2, 'Finished',  false),
              ($1, 3, 'Stalled',   false),
              ($1, 4, 'Dropped',   false),
              ($1, 5, 'Wishlist',  false),
              ($1, 6, 'Blacklist', false),
              ($1, 7, 'Voted',     false)
  ON CONFLICT (uid, id) DO NOTHING;
$$ LANGUAGE SQL;




----------------------------------------------------------
--           revision insertion abstraction             --
----------------------------------------------------------

-- The two functions below are utility functions used by the item-specific functions in editfunc.sql

-- create temporary table for generic revision info, and returns the chid of the revision being edited (or NULL).
CREATE OR REPLACE FUNCTION edit_revtable(xtype dbentry_type, xitemid integer, xrev integer) RETURNS integer AS $$
DECLARE
  ret integer;
  x record;
BEGIN
  BEGIN
    CREATE TEMPORARY TABLE edit_revision (
      type dbentry_type NOT NULL,
      itemid integer,
      requester integer,
      ip inet,
      comments text,
      ihid boolean,
      ilock boolean
    );
  EXCEPTION WHEN duplicate_table THEN
    TRUNCATE edit_revision;
  END;
  SELECT INTO x id, ihid, ilock FROM changes c WHERE type = xtype AND itemid = xitemid AND rev = xrev;
  INSERT INTO edit_revision (type, itemid, ihid, ilock) VALUES (xtype, xitemid, COALESCE(x.ihid, FALSE), COALESCE(x.ilock, FALSE));
  RETURN x.id;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION edit_commit() RETURNS edit_rettype AS $$
DECLARE
  ret edit_rettype;
  xtype dbentry_type;
BEGIN
  SELECT type INTO xtype FROM edit_revision;
  SELECT itemid INTO ret.itemid FROM edit_revision;
  -- figure out revision number
  SELECT MAX(rev)+1 INTO ret.rev FROM changes WHERE type = xtype AND itemid = ret.itemid;
  SELECT COALESCE(ret.rev, 1) INTO ret.rev;
  -- insert DB item
  IF ret.itemid IS NULL THEN
    CASE xtype
      WHEN 'v' THEN INSERT INTO vn        DEFAULT VALUES RETURNING id INTO ret.itemid;
      WHEN 'r' THEN INSERT INTO releases  DEFAULT VALUES RETURNING id INTO ret.itemid;
      WHEN 'p' THEN INSERT INTO producers DEFAULT VALUES RETURNING id INTO ret.itemid;
      WHEN 'c' THEN INSERT INTO chars     DEFAULT VALUES RETURNING id INTO ret.itemid;
      WHEN 's' THEN INSERT INTO staff     DEFAULT VALUES RETURNING id INTO ret.itemid;
      WHEN 'd' THEN INSERT INTO docs      DEFAULT VALUES RETURNING id INTO ret.itemid;
    END CASE;
  END IF;
  -- insert change
  INSERT INTO changes (type, itemid, rev, requester, ip, comments, ihid, ilock)
    SELECT type, ret.itemid, ret.rev, requester, ip, comments, ihid, ilock FROM edit_revision RETURNING id INTO ret.chid;
  RETURN ret;
END;
$$ LANGUAGE plpgsql;



-- Check for stuff to be done when an item has been changed
CREATE OR REPLACE FUNCTION edit_committed(xtype dbentry_type, xedit edit_rettype) RETURNS void AS $$
DECLARE
  xoldchid integer;
BEGIN
  SELECT id INTO xoldchid FROM changes WHERE type = xtype AND itemid = xedit.itemid AND rev = xedit.rev-1;

  -- Set c_search to NULL and notify when
  -- 1. A new VN entry is created
  -- 2. The vn title/original/alias has changed
  IF xtype = 'v' THEN
    IF -- 1.
       xoldchid IS NULL OR
       -- 2.
       EXISTS(SELECT 1 FROM vn_hist v1, vn_hist v2 WHERE (v2.title <> v1.title OR v2.original <> v1.original OR v2.alias <> v1.alias) AND v1.chid = xoldchid AND v2.chid = xedit.chid)
    THEN
      UPDATE vn SET c_search = NULL WHERE id = xedit.itemid;
      NOTIFY vnsearch;
    END IF;
  END IF;

  -- Set related vn.c_search columns to NULL and notify when
  -- 1. A new release is created
  -- 2. A release has been hidden or unhidden
  -- 3. The release title/original has changed
  -- 4. The releases_vn table differs from a previous revision
  IF xtype = 'r' THEN
    IF -- 1.
       xoldchid IS NULL OR
       -- 2.
       EXISTS(SELECT 1 FROM changes c1, changes c2 WHERE c1.ihid IS DISTINCT FROM c2.ihid AND c1.id = xedit.chid AND c2.id = xoldchid) OR
       -- 3.
       EXISTS(SELECT 1 FROM releases_hist r1, releases_hist r2 WHERE (r2.title <> r1.title OR r2.original <> r1.original) AND r1.chid = xoldchid AND r2.chid = xedit.chid) OR
       -- 4.
       EXISTS(SELECT vid FROM releases_vn_hist WHERE chid = xoldchid   EXCEPT SELECT vid FROM releases_vn_hist WHERE chid = xedit.chid) OR
       EXISTS(SELECT vid FROM releases_vn_hist WHERE chid = xedit.chid EXCEPT SELECT vid FROM releases_vn_hist WHERE chid = xoldchid)
    THEN
      UPDATE vn SET c_search = NULL WHERE id IN(SELECT vid FROM releases_vn_hist WHERE chid IN(xedit.chid, xoldchid));
      NOTIFY vnsearch;
    END IF;
  END IF;

  -- Call update_vncache() for related VNs when a release has been created or edited
  -- (This could be made more specific, but update_vncache() is fast enough that it's not worth the complexity)
  IF xtype = 'r' THEN
    PERFORM update_vncache(vid) FROM (
      SELECT DISTINCT vid FROM releases_vn_hist WHERE chid IN(xedit.chid, xoldchid)
    ) AS v(vid);
  END IF;

  -- Call traits_chars_calc() for characters to update the traits cache
  IF xtype = 'c' THEN
    PERFORM traits_chars_calc(xedit.itemid);
  END IF;

  -- Call notify_dbdel() if an entry has been deleted
  -- Call notify_listdel() if a vn/release entry has been deleted
  IF xoldchid IS NOT NULL
     AND EXISTS(SELECT 1 FROM changes WHERE id = xoldchid AND NOT ihid)
     AND EXISTS(SELECT 1 FROM changes WHERE id = xedit.chid AND ihid)
  THEN
    PERFORM notify_dbdel(xtype, xedit);
    IF xtype = 'v' OR xtype = 'r' THEN
      PERFORM notify_listdel(xtype, xedit);
    END IF;
  END IF;

  -- Call notify_dbedit() if a non-hidden entry has been edited
  IF xoldchid IS NOT NULL AND EXISTS(SELECT 1 FROM changes WHERE id = xedit.chid AND NOT ihid)
  THEN
    PERFORM notify_dbedit(xtype, xedit);
  END IF;

  -- Make sure all visual novels linked to a release have a corresponding entry
  -- in ulist_vns for users who have the release in rlists. This is action (3) in
  -- update_vnlist_rlist().
  IF xtype = 'r' AND xoldchid IS NOT NULL
  THEN
    INSERT INTO ulist_vns (uid, vid)
      SELECT rl.uid, rv.vid FROM rlists rl JOIN releases_vn rv ON rv.id = rl.rid WHERE rl.rid = xedit.itemid
    ON CONFLICT (uid, vid) DO NOTHING;
  END IF;

  -- Call update_images_cache() where appropriate
  IF xtype = 'c'
  THEN
    PERFORM update_images_cache(image) FROM chars_hist WHERE chid IN(xoldchid,xedit.chid) AND image IS NOT NULL;
  END IF;
  IF xtype = 'v'
  THEN
    PERFORM update_images_cache(image) FROM vn_hist WHERE chid IN(xoldchid,xedit.chid) AND image IS NOT NULL;
    PERFORM update_images_cache(scr) FROM vn_screenshots_hist WHERE chid IN(xoldchid,xedit.chid);
  END IF;
END;
$$ LANGUAGE plpgsql;




----------------------------------------------------------
--                notification functions                --
----------------------------------------------------------


-- called when an entry has been deleted
CREATE OR REPLACE FUNCTION notify_dbdel(xtype dbentry_type, xedit edit_rettype) RETURNS void AS $$
  INSERT INTO notifications (ntype, ltype, uid, iid, subid, c_title, c_byuser)
    SELECT DISTINCT 'dbdel'::notification_ntype, xtype::text::notification_ltype, h.requester, xedit.itemid, xedit.rev, x.title, h2.requester
      FROM changes h
      -- join info about the deletion itself
      JOIN changes h2 ON h2.id = xedit.chid
      -- Fetch the latest name/title of the entry
      -- this method may look a bit unintuitive, but it's way faster than doing LEFT JOINs
      JOIN (  SELECT v.title FROM vn v WHERE xtype = 'v' AND v.id = xedit.itemid
        UNION SELECT r.title FROM releases r WHERE xtype = 'r' AND r.id = xedit.itemid
        UNION SELECT p.name  FROM producers p WHERE xtype = 'p' AND p.id = xedit.itemid
        UNION SELECT c.name  FROM chars c WHERE xtype = 'c' AND c.id = xedit.itemid
        UNION SELECT d.title FROM docs d WHERE xtype = 'd' AND d.id = xedit.itemid
        UNION SELECT sa.name FROM staff s JOIN staff_alias sa ON sa.aid = s.aid WHERE xtype = 's' AND s.id = xedit.itemid
      ) x(title) ON true
     WHERE h.type = xtype AND h.itemid = xedit.itemid
       AND h.requester <> 1 -- exclude Multi
       AND h.requester <> h2.requester; -- exclude the user who deleted the entry
$$ LANGUAGE sql;



-- Called when a non-deleted item has been edited.
CREATE OR REPLACE FUNCTION notify_dbedit(xtype dbentry_type, xedit edit_rettype) RETURNS void AS $$
  INSERT INTO notifications (ntype, ltype, uid, iid, subid, c_title, c_byuser)
    SELECT DISTINCT 'dbedit'::notification_ntype, xtype::text::notification_ltype, h.requester, xedit.itemid, xedit.rev, x.title, h2.requester
      FROM changes h
      -- join info about the edit itself
      JOIN changes h2 ON h2.id = xedit.chid
      -- Fetch the latest name/title of the entry
      JOIN (  SELECT v.title FROM vn v WHERE xtype = 'v' AND v.id = xedit.itemid
        UNION SELECT r.title FROM releases r WHERE xtype = 'r' AND r.id = xedit.itemid
        UNION SELECT p.name  FROM producers p WHERE xtype = 'p' AND p.id = xedit.itemid
        UNION SELECT c.name  FROM chars c WHERE xtype = 'c' AND c.id = xedit.itemid
        UNION SELECT d.title FROM docs d WHERE xtype = 'd' AND d.id = xedit.itemid
        UNION SELECT sa.name FROM staff s JOIN staff_alias sa ON sa.aid = s.aid WHERE xtype = 's' AND s.id = xedit.itemid
      ) x(title) ON true
     WHERE h.type = xtype AND h.itemid = xedit.itemid
       AND h.requester <> h2.requester -- exclude the user who edited the entry
       AND h2.requester <> 1 -- exclude edits by Multi
       -- exclude users who don't want this notify
       AND EXISTS(SELECT 1 FROM users u WHERE u.id = h.requester AND notify_dbedit);
$$ LANGUAGE sql;



-- called when a VN/release entry has been deleted
CREATE OR REPLACE FUNCTION notify_listdel(xtype dbentry_type, xedit edit_rettype) RETURNS void AS $$
  INSERT INTO notifications (ntype, ltype, uid, iid, subid, c_title, c_byuser)
    SELECT DISTINCT 'listdel'::notification_ntype, xtype::text::notification_ltype, u.uid, xedit.itemid, xedit.rev, x.title, c.requester
      -- look for users who should get this notify
      FROM (
              SELECT uid FROM ulist_vns WHERE xtype = 'v' AND vid = xedit.itemid
        UNION SELECT uid FROM rlists    WHERE xtype = 'r' AND rid = xedit.itemid
      ) u
      -- fetch info about this edit
      JOIN changes c ON c.id = xedit.chid
      JOIN (
              SELECT title FROM vn       WHERE xtype = 'v' AND id = xedit.itemid
        UNION SELECT title FROM releases WHERE xtype = 'r' AND id = xedit.itemid
      ) x ON true
     WHERE c.requester <> u.uid;
$$ LANGUAGE sql;




----------------------------------------------------------
--                    user management                   --
----------------------------------------------------------
-- XXX: These functions run with the permissions of the 'vndb' user.


-- Returns the raw scrypt parameters (N, r, p and salt) for this user, in order
-- to create an encrypted pass. Returns NULL if this user does not have a valid
-- password.
CREATE OR REPLACE FUNCTION user_getscryptargs(integer) RETURNS bytea AS $$
  SELECT
    CASE WHEN length(passwd) = 46 THEN substring(passwd from 1 for 14) ELSE NULL END
  FROM users WHERE id = $1
$$ LANGUAGE SQL SECURITY DEFINER;


-- Create a new web session for this user (uid, scryptpass, token)
CREATE OR REPLACE FUNCTION user_login(integer, bytea, bytea) RETURNS boolean AS $$
  INSERT INTO sessions (uid, token, expires, type) SELECT $1, $3, NOW() + '1 month', 'web' FROM users
   WHERE length($2) = 46 AND length($3) = 20
     AND id = $1 AND passwd = $2
  RETURNING true
$$ LANGUAGE SQL SECURITY DEFINER;


CREATE OR REPLACE FUNCTION user_logout(integer, bytea) RETURNS void AS $$
  DELETE FROM sessions WHERE uid = $1 AND token = $2 AND type = 'web'
$$ LANGUAGE SQL SECURITY DEFINER;


-- Returns true if the given session token is valid.
-- As a side effect, this also extends the expiration time of web sessions.
CREATE OR REPLACE FUNCTION user_isvalidsession(integer, bytea, session_type) RETURNS bool AS $$
  UPDATE sessions SET expires = NOW() + '1 month'
   WHERE uid = $1 AND token = $2 AND type = $3 AND $3 = 'web'
     AND expires < NOW() + '1 month'::interval - '6 hours'::interval;
  SELECT true FROM sessions WHERE uid = $1 AND token = $2 AND type = $3 AND expires > NOW();
$$ LANGUAGE SQL SECURITY DEFINER;


CREATE OR REPLACE FUNCTION user_emailexists(text, integer) RETURNS boolean AS $$
  SELECT true FROM users WHERE lower(mail) = lower($1) AND ($2 IS NULL OR id <> $2) LIMIT 1
$$ LANGUAGE SQL SECURITY DEFINER;


-- Create a password reset token. args: email, token. Returns: user id.
-- Doesn't work for usermods, otherwise an attacker could use this function to
-- gain access to all user's emails by obtaining a reset token of a usermod.
-- Ideally Postgres itself would send the user an email so that the application
-- calling this function doesn't even get the token, and thus can't get access
-- to someone's account. But alas, that'd require a separate process.
CREATE OR REPLACE FUNCTION user_resetpass(text, bytea) RETURNS integer AS $$
  INSERT INTO sessions (uid, token, expires, type)
    SELECT id, $2, NOW()+'1 week', 'pass' FROM users
     WHERE lower(mail) = lower($1) AND length($2) = 20 AND perm & 128 = 0
    RETURNING uid
$$ LANGUAGE SQL SECURITY DEFINER;


-- Changes the user's password and invalidates all existing sessions. args: uid, old_pass_or_reset_token, new_pass
CREATE OR REPLACE FUNCTION user_setpass(integer, bytea, bytea) RETURNS boolean AS $$
  WITH upd(id) AS (
    UPDATE users SET passwd = $3
     WHERE id = $1
       AND length($3) = 46
       AND (    (passwd = $2 AND length($2) = 46)
             OR EXISTS(SELECT 1 FROM sessions WHERE uid = $1 AND token = $2 AND type = 'pass' AND expires > NOW())
           )
    RETURNING id
  ), del AS( -- Not referenced, but still guaranteed to run
    DELETE FROM sessions WHERE uid IN(SELECT id FROM upd)
  )
  SELECT true FROM upd
$$ LANGUAGE SQL SECURITY DEFINER;


-- Internal function, used to verify whether user ($2 with session $3) is
-- allowed to access sensitive data from user $1.
CREATE OR REPLACE FUNCTION user_isauth(integer, integer, bytea) RETURNS boolean AS $$
  SELECT true FROM users
   WHERE id = $2
     AND EXISTS(SELECT 1 FROM sessions WHERE uid = $2 AND token = $3 AND type = 'web')
     AND ($2 = $1 OR perm & 128 = 128)
$$ LANGUAGE SQL;


-- uid of user email to get, uid currently logged in, session token of currently logged in.
-- Ensures that only the user itself or a useradmin can get someone's email address.
CREATE OR REPLACE FUNCTION user_getmail(integer, integer, bytea) RETURNS text AS $$
  SELECT mail FROM users WHERE id = $1 AND user_isauth($1, $2, $3)
$$ LANGUAGE SQL SECURITY DEFINER;


-- Set a token to change a user's email address.
-- Args: uid, web-token, new-email-token, email
CREATE OR REPLACE FUNCTION user_setmail_token(integer, bytea, bytea, text) RETURNS void AS $$
  INSERT INTO sessions (uid, token, expires, type, mail)
    SELECT id, $3, NOW()+'1 week', 'mail', $4 FROM users
     WHERE id = $1 AND user_isauth($1, $1, $2) AND length($3) = 20
$$ LANGUAGE SQL SECURITY DEFINER;


-- Actually change a user's email address, given a valid token.
CREATE OR REPLACE FUNCTION user_setmail_confirm(integer, bytea) RETURNS boolean AS $$
  WITH u(mail) AS (
    DELETE FROM sessions WHERE uid = $1 AND token = $2 AND type = 'mail' AND expires > NOW() RETURNING mail
  )
  UPDATE users SET mail = (SELECT mail FROM u) WHERE id = $1 AND EXISTS(SELECT 1 FROM u) RETURNING true;
$$ LANGUAGE SQL SECURITY DEFINER;


CREATE OR REPLACE FUNCTION user_setperm(integer, integer, bytea, integer) RETURNS void AS $$
  UPDATE users SET perm = $4 WHERE id = $1 AND user_isauth(-1, $2, $3)
$$ LANGUAGE SQL SECURITY DEFINER;


CREATE OR REPLACE FUNCTION user_admin_setpass(integer, integer, bytea, bytea) RETURNS void AS $$
  WITH upd(id) AS (
    UPDATE users SET passwd = $4 WHERE id = $1 AND user_isauth(-1, $2, $3) AND length($4) = 46 RETURNING id
  )
  DELETE FROM sessions WHERE uid IN(SELECT id FROM upd)
$$ LANGUAGE SQL SECURITY DEFINER;


CREATE OR REPLACE FUNCTION user_admin_setmail(integer, integer, bytea, text) RETURNS void AS $$
  UPDATE users SET mail = $4 WHERE id = $1 AND user_isauth(-1, $2, $3)
$$ LANGUAGE SQL SECURITY DEFINER;
