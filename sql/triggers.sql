-- keep the c_tags, c_changes and c_imgvotes columns in the users table up to date
-- Assumption: The column referencing the user is never modified.

CREATE OR REPLACE FUNCTION update_users_cache() RETURNS trigger AS $$
BEGIN
  IF TG_TABLE_NAME = 'changes' THEN
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
  ELSIF TG_TABLE_NAME = 'image_votes' THEN
    IF TG_OP = 'INSERT' THEN
      UPDATE users SET c_imgvotes = c_imgvotes + 1 WHERE id = NEW.uid;
    ELSE
      UPDATE users SET c_imgvotes = c_imgvotes - 1 WHERE id = OLD.uid;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER users_changes_update  AFTER INSERT OR DELETE ON changes     FOR EACH ROW EXECUTE PROCEDURE update_users_cache();
CREATE TRIGGER users_tags_update     AFTER INSERT OR DELETE ON tags_vn     FOR EACH ROW EXECUTE PROCEDURE update_users_cache();
CREATE TRIGGER users_imgvotes_update AFTER INSERT OR DELETE ON image_votes FOR EACH ROW EXECUTE PROCEDURE update_users_cache();




-- the stats_cache table

CREATE OR REPLACE FUNCTION update_stats_cache() RETURNS TRIGGER AS $$
DECLARE
  unhidden boolean;
  hidden boolean;
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE stats_cache SET count = count+1 WHERE section = TG_TABLE_NAME;

  ELSIF TG_OP = 'UPDATE' THEN
    IF TG_TABLE_NAME IN('tags', 'traits') THEN
      unhidden := OLD.state <> 2 AND NEW.state = 2;
      hidden := OLD.state = 2 AND NEW.state <> 2;
    ELSE
      unhidden := OLD.hidden AND NOT NEW.hidden;
      hidden := NEW.hidden AND NOT OLD.hidden;
    END IF;
    IF unhidden THEN
      UPDATE stats_cache SET count = count+1 WHERE section = TG_TABLE_NAME;
    ELSIF hidden THEN
      UPDATE stats_cache SET count = count-1 WHERE section = TG_TABLE_NAME;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER stats_cache_new  AFTER  INSERT           ON vn            FOR EACH ROW WHEN (NEW.hidden = FALSE)                     EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit AFTER  UPDATE           ON vn            FOR EACH ROW WHEN (OLD.hidden IS DISTINCT FROM NEW.hidden) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_new  AFTER  INSERT           ON producers     FOR EACH ROW WHEN (NEW.hidden = FALSE)                     EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit AFTER  UPDATE           ON producers     FOR EACH ROW WHEN (OLD.hidden IS DISTINCT FROM NEW.hidden) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_new  AFTER  INSERT           ON releases      FOR EACH ROW WHEN (NEW.hidden = FALSE)                     EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit AFTER  UPDATE           ON releases      FOR EACH ROW WHEN (OLD.hidden IS DISTINCT FROM NEW.hidden) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_new  AFTER  INSERT           ON chars         FOR EACH ROW WHEN (NEW.hidden = FALSE)                     EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit AFTER  UPDATE           ON chars         FOR EACH ROW WHEN (OLD.hidden IS DISTINCT FROM NEW.hidden) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_new  AFTER  INSERT           ON staff         FOR EACH ROW WHEN (NEW.hidden = FALSE)                     EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit AFTER  UPDATE           ON staff         FOR EACH ROW WHEN (OLD.hidden IS DISTINCT FROM NEW.hidden) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_new  AFTER  INSERT           ON tags          FOR EACH ROW WHEN (NEW.state = 2)                          EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit AFTER  UPDATE           ON tags          FOR EACH ROW WHEN (OLD.state IS DISTINCT FROM NEW.state)   EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_new  AFTER  INSERT           ON traits        FOR EACH ROW WHEN (NEW.state = 2)                          EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit AFTER  UPDATE           ON traits        FOR EACH ROW WHEN (OLD.state IS DISTINCT FROM NEW.state)   EXECUTE PROCEDURE update_stats_cache();




-- insert rows into anime for new vn_anime.aid items

CREATE OR REPLACE FUNCTION vn_anime_aid() RETURNS trigger AS $$
BEGIN
  INSERT INTO anime (id) VALUES (NEW.aid) ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER vn_anime_aid_new  BEFORE INSERT ON vn_anime FOR EACH ROW EXECUTE PROCEDURE vn_anime_aid();
CREATE TRIGGER vn_anime_aid_edit BEFORE UPDATE ON vn_anime FOR EACH ROW WHEN (OLD.aid IS DISTINCT FROM NEW.aid) EXECUTE PROCEDURE vn_anime_aid();




-- Send a notify whenever anime info should be fetched

CREATE OR REPLACE FUNCTION anime_fetch_notify() RETURNS trigger AS $$
  BEGIN NOTIFY anime; RETURN NULL; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER anime_fetch_notify AFTER INSERT OR UPDATE ON anime FOR EACH ROW WHEN (NEW.lastfetch IS NULL) EXECUTE PROCEDURE anime_fetch_notify();




-- insert rows into wikidata for new l_wikidata items

CREATE OR REPLACE FUNCTION wikidata_insert() RETURNS trigger AS $$
BEGIN
  INSERT INTO wikidata (id) VALUES (NEW.l_wikidata) ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER producers_wikidata_new       BEFORE INSERT ON producers      FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL)                                                    EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER producers_wikidata_edit      BEFORE UPDATE ON producers      FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER producers_hist_wikidata_new  BEFORE INSERT ON producers_hist FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL)                                                    EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER producers_hist_wikidata_edit BEFORE UPDATE ON producers_hist FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER staff_wikidata_new           BEFORE INSERT ON staff          FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL)                                                    EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER staff_wikidata_edit          BEFORE UPDATE ON staff          FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER staff_hist_wikidata_new      BEFORE INSERT ON staff_hist     FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL)                                                    EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER staff_hist_wikidata_edit     BEFORE UPDATE ON staff_hist     FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER vn_wikidata_new              BEFORE INSERT ON vn             FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL)                                                    EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER vn_wikidata_edit             BEFORE UPDATE ON vn             FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER vn_hist_wikidata_new         BEFORE INSERT ON vn_hist        FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL)                                                    EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER vn_hist_wikidata_edit        BEFORE UPDATE ON vn_hist        FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();




-- For each row in rlists, there should be at least one corresponding row in
-- ulist_vns for each VN linked to that release.
-- 1. When a row is deleted from ulist_vns, also remove all rows from rlists
--    with that VN linked.
-- 2. When a row is inserted to rlists and there is not yet a corresponding row
--    in ulist_vns, add a row to ulist_vns for each vn linked to the release.
-- 3. When a release is edited to add another VN, add those VNs to ulist_vns
--    for everyone who has the release in rlists.
--    This is done in edit_committed().
-- #. When a release is edited to remove a VN, that VN kinda should also be
--    removed from ulist_vns, but only if that ulist_vns entry was
--    automatically added as part of the rlists entry and the user has not
--    changed anything in the ulist_vns row. This isn't currently done.
CREATE OR REPLACE FUNCTION update_vnlist_rlist() RETURNS trigger AS $$
BEGIN
  -- 1.
  IF TG_TABLE_NAME = 'ulist_vns' THEN
    DELETE FROM rlists WHERE uid = OLD.uid AND rid IN(SELECT id FROM releases_vn WHERE vid = OLD.vid);
  -- 2.
  ELSE
   INSERT INTO ulist_vns (uid, vid)
     SELECT NEW.uid, rv.vid FROM releases_vn rv WHERE rv.id = NEW.rid
     ON CONFLICT (uid, vid) DO NOTHING;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER update_ulist_vns_rlist AFTER DELETE ON ulist_vns DEFERRABLE FOR EACH ROW EXECUTE PROCEDURE update_vnlist_rlist();
CREATE CONSTRAINT TRIGGER update_rlist_ulist_vns AFTER INSERT ON rlists    DEFERRABLE FOR EACH ROW EXECUTE PROCEDURE update_vnlist_rlist();




-- Create ulist_label rows when a new user is added

CREATE OR REPLACE FUNCTION ulist_labels_create() RETURNS trigger AS 'BEGIN PERFORM ulist_labels_create(NEW.id); RETURN NULL; END' LANGUAGE plpgsql;

CREATE TRIGGER ulist_labels_create AFTER INSERT ON users FOR EACH ROW EXECUTE PROCEDURE ulist_labels_create();




-- Set/unset the 'Voted' label when voting.

CREATE OR REPLACE FUNCTION ulist_voted_label() RETURNS trigger AS $$
BEGIN
    IF NEW.vote IS NULL THEN
        DELETE FROM ulist_vns_labels WHERE uid = NEW.uid AND vid = NEW.vid AND lbl = 7;
    ELSE
        INSERT INTO ulist_vns_labels (uid, vid, lbl) VALUES (NEW.uid, NEW.vid, 7) ON CONFLICT (uid, vid, lbl) DO NOTHING;
    END IF;
    RETURN NULL;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER ulist_voted_label AFTER INSERT OR UPDATE ON ulist_vns FOR EACH ROW EXECUTE PROCEDURE ulist_voted_label();




-- NOTIFY on insert into changes/posts/tags/trait/reviews

CREATE OR REPLACE FUNCTION insert_notify() RETURNS trigger AS $$
BEGIN
  IF TG_TABLE_NAME = 'changes' THEN
    NOTIFY newrevision;
  ELSIF TG_TABLE_NAME = 'threads_posts' THEN
    NOTIFY newpost;
  ELSIF TG_TABLE_NAME = 'tags' THEN
    NOTIFY newtag;
  ELSIF TG_TABLE_NAME = 'traits' THEN
    NOTIFY newtrait;
  ELSIF TG_TABLE_NAME = 'reviews' THEN
    NOTIFY newreview;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER insert_notify AFTER INSERT ON changes       FOR EACH STATEMENT EXECUTE PROCEDURE insert_notify();
CREATE TRIGGER insert_notify AFTER INSERT ON threads_posts FOR EACH STATEMENT EXECUTE PROCEDURE insert_notify();
CREATE TRIGGER insert_notify AFTER INSERT ON tags          FOR EACH STATEMENT EXECUTE PROCEDURE insert_notify();
CREATE TRIGGER insert_notify AFTER INSERT ON traits        FOR EACH STATEMENT EXECUTE PROCEDURE insert_notify();
CREATE TRIGGER insert_notify AFTER INSERT ON reviews       FOR EACH STATEMENT EXECUTE PROCEDURE insert_notify();




-- Send a vnsearch notification when the c_search column is set to NULL.

CREATE OR REPLACE FUNCTION vn_vnsearch_notify() RETURNS trigger AS 'BEGIN NOTIFY vnsearch; RETURN NULL; END;' LANGUAGE plpgsql;

CREATE TRIGGER vn_vnsearch_notify AFTER UPDATE ON vn FOR EACH ROW WHEN (OLD.c_search IS NOT NULL AND NEW.c_search IS NULL) EXECUTE PROCEDURE vn_vnsearch_notify();




-- Add a notification when someone posts in someone's board.

CREATE OR REPLACE FUNCTION notify_pm() RETURNS trigger AS $$
BEGIN
  INSERT INTO notifications (ntype, uid, iid, num, c_title, c_byuser)
    SELECT 'pm', tb.iid, t.id, NEW.num, t.title, NEW.uid
      FROM threads t
      JOIN threads_boards tb ON tb.tid = t.id
     WHERE t.id = NEW.tid
       AND tb.type = 'u'
       AND tb.iid <> NEW.uid -- don't notify when posting in your own board
       AND NOT EXISTS( -- don't notify when you haven't read an earlier post in the thread yet
         SELECT 1
           FROM notifications n
          WHERE n.uid = tb.iid
            AND n.iid = t.id
            AND n.read IS NULL
       );
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notify_pm AFTER INSERT ON threads_posts FOR EACH ROW EXECUTE PROCEDURE notify_pm();




-- Add a notification when a thread is created in /t/an

CREATE OR REPLACE FUNCTION notify_announce() RETURNS trigger AS $$
BEGIN
  INSERT INTO notifications (ntype, uid, iid, num, c_title, c_byuser)
    SELECT 'announce', u.id, t.id, 1, t.title, NEW.uid
      FROM threads t
      JOIN threads_boards tb ON tb.tid = t.id
      -- get the users who want this announcement
      JOIN users u ON u.notify_announce
     WHERE t.id = NEW.tid
       AND tb.type = 'an' -- announcement board
       AND NOT t.hidden;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notify_announce AFTER INSERT ON threads_posts FOR EACH ROW WHEN (NEW.num = 1) EXECUTE PROCEDURE notify_announce();




-- Add a notification on new posts

CREATE OR REPLACE FUNCTION notify_post() RETURNS trigger AS $$
BEGIN
  INSERT INTO notifications (ntype, uid, iid, num, c_title, c_byuser)
    SELECT DISTINCT 'post'::notification_ntype, u.id, t.id, NEW.num, t.title, NEW.uid
      FROM threads t
      JOIN threads_posts tp ON tp.tid = t.id
      JOIN users u ON tp.uid = u.id
     WHERE t.id = NEW.tid
       AND u.notify_post
       AND u.id <> NEW.uid
       AND NOT t.hidden
       AND NOT t.private -- don't leak posts in private threads, these are handled by notify_pm anyway
       AND NOT EXISTS( -- don't notify when you haven't read an earlier post in the thread yet (also avoids double notification with notify_pm)
         SELECT 1
           FROM notifications n
          WHERE n.uid = u.id
            AND n.iid = t.id
            AND n.read IS NULL
       );
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notify_post AFTER INSERT ON threads_posts FOR EACH ROW EXECUTE PROCEDURE notify_post();




-- Add a notification on new comment to review

CREATE OR REPLACE FUNCTION notify_comment() RETURNS trigger AS $$
BEGIN
  INSERT INTO notifications (ntype, uid, iid, num, c_title, c_byuser)
    SELECT 'comment', u.id, w.id, NEW.num, v.title, NEW.uid
      FROM reviews w
      JOIN vn v ON v.id = w.vid
      JOIN users u ON w.uid = u.id
     WHERE w.id = NEW.id
       AND u.notify_comment
       AND u.id <> NEW.uid
       AND NOT EXISTS( -- don't notify when you haven't read earlier comments yet
         SELECT 1
           FROM notifications n
          WHERE n.uid = u.id
            AND n.iid = w.id
            AND n.read IS NULL
       );
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notify_comment AFTER INSERT ON reviews_posts FOR EACH ROW EXECUTE PROCEDURE notify_comment();




-- Update threads.c_count and c_lastnum

CREATE OR REPLACE FUNCTION update_threads_cache() RETURNS trigger AS $$
BEGIN
  UPDATE threads
     SET c_count   = (SELECT COUNT(*) FROM threads_posts WHERE NOT hidden AND tid = threads.id)
       , c_lastnum = (SELECT MAX(num) FROM threads_posts WHERE NOT hidden AND tid = threads.id)
   WHERE id IN(OLD.tid,NEW.tid);
  RETURN NULL;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_threads_cache AFTER INSERT OR UPDATE OR DELETE ON threads_posts FOR EACH ROW EXECUTE PROCEDURE update_threads_cache();




-- Update reviews.c_count and c_lastnum

CREATE OR REPLACE FUNCTION update_reviews_cache() RETURNS trigger AS $$
BEGIN
  UPDATE reviews
     SET c_count   = COALESCE((SELECT COUNT(*) FROM reviews_posts WHERE NOT hidden AND id = reviews.id), 0)
       , c_lastnum = (SELECT MAX(num) FROM reviews_posts WHERE NOT hidden AND id = reviews.id)
   WHERE id IN(OLD.id,NEW.id);
  RETURN NULL;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_reviews_cache AFTER INSERT OR UPDATE OR DELETE ON reviews_posts FOR EACH ROW EXECUTE PROCEDURE update_reviews_cache();





-- Call update_images_cache() for every change on image_votes

CREATE OR REPLACE FUNCTION update_images_cache() RETURNS trigger AS $$
BEGIN
  PERFORM update_images_cache(id) FROM (SELECT OLD.id UNION SELECT NEW.id) AS x(id) WHERE id IS NOT NULL;
  RETURN NULL;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER image_votes_cache1 AFTER INSERT OR DELETE ON image_votes FOR EACH ROW EXECUTE PROCEDURE update_images_cache();
CREATE TRIGGER image_votes_cache2 AFTER UPDATE ON image_votes FOR EACH ROW WHEN ((OLD.id, OLD.sexual, OLD.violence, OLD.ignore) IS DISTINCT FROM (NEW.id, NEW.sexual, NEW.violence, NEW.ignore)) EXECUTE PROCEDURE update_images_cache();




-- Call update_reviews_votes_cache() for every change on reviews_votes

CREATE OR REPLACE FUNCTION update_reviews_votes_cache() RETURNS trigger AS $$
BEGIN
  PERFORM update_reviews_votes_cache(id) FROM (SELECT OLD.id UNION SELECT NEW.id) AS x(id) WHERE id IS NOT NULL;
  RETURN NULL;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER reviews_votes_cache AFTER INSERT OR UPDATE OR DELETE ON reviews_votes FOR EACH ROW EXECUTE PROCEDURE update_reviews_votes_cache();
