-- Constraints

ALTER TABLE changes                  ADD CONSTRAINT changes_requester_fkey             FOREIGN KEY (requester) REFERENCES users         (id) ON DELETE SET DEFAULT;
ALTER TABLE chars                    ADD CONSTRAINT chars_main_fkey                    FOREIGN KEY (main)      REFERENCES chars         (id);
ALTER TABLE chars_hist               ADD CONSTRAINT chars_hist_chid_fkey               FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE chars_hist               ADD CONSTRAINT chars_hist_main_fkey               FOREIGN KEY (main)      REFERENCES chars         (id);
ALTER TABLE chars_traits             ADD CONSTRAINT chars_traits_id_fkey               FOREIGN KEY (id)        REFERENCES chars         (id);
ALTER TABLE chars_traits             ADD CONSTRAINT chars_traits_tid_fkey              FOREIGN KEY (tid)       REFERENCES traits        (id);
ALTER TABLE chars_traits_hist        ADD CONSTRAINT chars_traits_hist_chid_fkey        FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE chars_traits_hist        ADD CONSTRAINT chars_traits_hist_tid_fkey         FOREIGN KEY (tid)       REFERENCES traits        (id);
ALTER TABLE chars_vns                ADD CONSTRAINT chars_vns_id_fkey                  FOREIGN KEY (id)        REFERENCES chars         (id);
ALTER TABLE chars_vns                ADD CONSTRAINT chars_vns_vid_fkey                 FOREIGN KEY (vid)       REFERENCES vn            (id) DEFERRABLE;
ALTER TABLE chars_vns                ADD CONSTRAINT chars_vns_rid_fkey                 FOREIGN KEY (rid)       REFERENCES releases      (id) DEFERRABLE;
ALTER TABLE chars_vns_hist           ADD CONSTRAINT chars_vns_hist_chid_fkey           FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE chars_vns_hist           ADD CONSTRAINT chars_vns_hist_vid_fkey            FOREIGN KEY (vid)       REFERENCES vn            (id) DEFERRABLE;
ALTER TABLE chars_vns_hist           ADD CONSTRAINT chars_vns_hist_rid_fkey            FOREIGN KEY (rid)       REFERENCES releases      (id) DEFERRABLE;
ALTER TABLE notifications            ADD CONSTRAINT notifications_uid_fkey             FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE CASCADE;
ALTER TABLE notifications            ADD CONSTRAINT notifications_c_byuser_fkey        FOREIGN KEY (c_byuser)  REFERENCES users         (id) ON DELETE SET DEFAULT;
ALTER TABLE producers                ADD CONSTRAINT producers_rgraph_fkey              FOREIGN KEY (rgraph)    REFERENCES relgraphs     (id);
ALTER TABLE producers                ADD CONSTRAINT producers_l_wikidata_fkey          FOREIGN KEY (l_wikidata)REFERENCES wikidata      (id);
ALTER TABLE producers_hist           ADD CONSTRAINT producers_chid_id_fkey             FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE producers_hist           ADD CONSTRAINT producers_hist_l_wikidata_fkey     FOREIGN KEY (l_wikidata)REFERENCES wikidata      (id);
ALTER TABLE producers_relations      ADD CONSTRAINT producers_relations_pid_fkey       FOREIGN KEY (pid)       REFERENCES producers     (id);
ALTER TABLE producers_relations_hist ADD CONSTRAINT producers_relations_hist_id_fkey   FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE producers_relations_hist ADD CONSTRAINT producers_relations_hist_pid_fkey  FOREIGN KEY (pid)       REFERENCES producers     (id);
ALTER TABLE quotes                   ADD CONSTRAINT quotes_vid_fkey                    FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE releases_hist            ADD CONSTRAINT releases_hist_chid_fkey            FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE releases_lang            ADD CONSTRAINT releases_lang_id_fkey              FOREIGN KEY (id)        REFERENCES releases      (id);
ALTER TABLE releases_lang_hist       ADD CONSTRAINT releases_lang_hist_chid_fkey       FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE releases_media           ADD CONSTRAINT releases_media_id_fkey             FOREIGN KEY (id)        REFERENCES releases      (id);
ALTER TABLE releases_media_hist      ADD CONSTRAINT releases_media_hist_chid_fkey      FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE releases_platforms       ADD CONSTRAINT releases_platforms_id_fkey         FOREIGN KEY (id)        REFERENCES releases      (id);
ALTER TABLE releases_platforms_hist  ADD CONSTRAINT releases_platforms_hist_chid_fkey  FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE releases_producers       ADD CONSTRAINT releases_producers_id_fkey         FOREIGN KEY (id)        REFERENCES releases      (id);
ALTER TABLE releases_producers       ADD CONSTRAINT releases_producers_pid_fkey        FOREIGN KEY (pid)       REFERENCES producers     (id);
ALTER TABLE releases_producers_hist  ADD CONSTRAINT releases_producers_hist_chid_fkey  FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE releases_producers_hist  ADD CONSTRAINT releases_producers_hist_pid_fkey   FOREIGN KEY (pid)       REFERENCES producers     (id);
ALTER TABLE releases_vn              ADD CONSTRAINT releases_vn_id_fkey                FOREIGN KEY (id)        REFERENCES releases      (id);
ALTER TABLE releases_vn              ADD CONSTRAINT releases_vn_vid_fkey               FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE releases_vn_hist         ADD CONSTRAINT releases_vn_hist_chid_fkey         FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE releases_vn_hist         ADD CONSTRAINT releases_vn_hist_vid_fkey          FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE rlists                   ADD CONSTRAINT rlists_uid_fkey                    FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE CASCADE;
ALTER TABLE rlists                   ADD CONSTRAINT rlists_rid_fkey                    FOREIGN KEY (rid)       REFERENCES releases      (id);
ALTER TABLE sessions                 ADD CONSTRAINT sessions_uid_fkey                  FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE CASCADE;
ALTER TABLE staff                    ADD CONSTRAINT staff_aid_fkey                     FOREIGN KEY (aid)       REFERENCES staff_alias   (aid) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE staff                    ADD CONSTRAINT staff_l_wikidata_fkey              FOREIGN KEY (l_wikidata)REFERENCES wikidata      (id);
ALTER TABLE staff_hist               ADD CONSTRAINT staff_hist_chid_fkey               FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE staff_hist               ADD CONSTRAINT staff_hist_l_wikidata_fkey         FOREIGN KEY (l_wikidata)REFERENCES wikidata      (id);
ALTER TABLE staff_alias              ADD CONSTRAINT staff_alias_id_fkey                FOREIGN KEY (id)        REFERENCES staff         (id);
ALTER TABLE staff_alias_hist         ADD CONSTRAINT staff_alias_chid_fkey              FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE tags                     ADD CONSTRAINT tags_addedby_fkey                  FOREIGN KEY (addedby)   REFERENCES users         (id) ON DELETE SET DEFAULT;
ALTER TABLE tags_aliases             ADD CONSTRAINT tags_aliases_tag_fkey              FOREIGN KEY (tag)       REFERENCES tags          (id);
ALTER TABLE tags_parents             ADD CONSTRAINT tags_parents_tag_fkey              FOREIGN KEY (tag)       REFERENCES tags          (id);
ALTER TABLE tags_parents             ADD CONSTRAINT tags_parents_parent_fkey           FOREIGN KEY (parent)    REFERENCES tags          (id);
ALTER TABLE tags_vn                  ADD CONSTRAINT tags_vn_tag_fkey                   FOREIGN KEY (tag)       REFERENCES tags          (id);
ALTER TABLE tags_vn                  ADD CONSTRAINT tags_vn_vid_fkey                   FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE tags_vn                  ADD CONSTRAINT tags_vn_uid_fkey                   FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE CASCADE;
ALTER TABLE threads                  ADD CONSTRAINT threads_id_fkey                    FOREIGN KEY (id, count) REFERENCES threads_posts (tid, num) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE threads_poll_options     ADD CONSTRAINT threads_poll_options_tid_fkey      FOREIGN KEY (tid)       REFERENCES threads       (id) ON DELETE CASCADE;
ALTER TABLE threads_poll_votes       ADD CONSTRAINT threads_poll_votes_tid_fkey        FOREIGN KEY (tid)       REFERENCES threads       (id) ON DELETE CASCADE;
ALTER TABLE threads_poll_votes       ADD CONSTRAINT threads_poll_votes_uid_fkey        FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE CASCADE;
ALTER TABLE threads_poll_votes       ADD CONSTRAINT threads_poll_votes_optid_fkey      FOREIGN KEY (optid)     REFERENCES threads_poll_options (id) ON DELETE CASCADE;
ALTER TABLE threads_posts            ADD CONSTRAINT threads_posts_tid_fkey             FOREIGN KEY (tid)       REFERENCES threads       (id);
ALTER TABLE threads_posts            ADD CONSTRAINT threads_posts_uid_fkey             FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE SET DEFAULT;
ALTER TABLE threads_boards           ADD CONSTRAINT threads_boards_tid_fkey            FOREIGN KEY (tid)       REFERENCES threads       (id);
ALTER TABLE traits                   ADD CONSTRAINT traits_addedby_fkey                FOREIGN KEY (addedby)   REFERENCES users         (id) ON DELETE SET DEFAULT;
ALTER TABLE traits                   ADD CONSTRAINT traits_group_fkey                  FOREIGN KEY ("group")   REFERENCES traits        (id);
ALTER TABLE traits_parents           ADD CONSTRAINT traits_parents_trait_fkey          FOREIGN KEY (trait)     REFERENCES traits        (id);
ALTER TABLE traits_parents           ADD CONSTRAINT traits_parents_parent_fkey         FOREIGN KEY (parent)    REFERENCES traits        (id);
ALTER TABLE ulist_labels             ADD CONSTRAINT ulist_labels_uid_fkey              FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE CASCADE;
ALTER TABLE ulist_vns                ADD CONSTRAINT ulist_vns_uid_fkey                 FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE CASCADE;
ALTER TABLE ulist_vns                ADD CONSTRAINT ulist_vns_vid_fkey                 FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE ulist_vns_labels         ADD CONSTRAINT ulist_vns_labels_uid_fkey          FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE CASCADE;
ALTER TABLE ulist_vns_labels         ADD CONSTRAINT ulist_vns_labels_vid_fkey          FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE ulist_vns_labels         ADD CONSTRAINT ulist_vns_labels_uid_lbl_fkey      FOREIGN KEY (uid,lbl)   REFERENCES ulist_labels  (uid,id) ON DELETE CASCADE;
ALTER TABLE ulist_vns_labels         ADD CONSTRAINT ulist_vns_labels_uid_vid_fkey      FOREIGN KEY (uid,vid)   REFERENCES ulist_vns     (uid,vid) ON DELETE CASCADE;
ALTER TABLE vn                       ADD CONSTRAINT vn_rgraph_fkey                     FOREIGN KEY (rgraph)    REFERENCES relgraphs     (id);
ALTER TABLE vn                       ADD CONSTRAINT vn_l_wikidata_fkey                 FOREIGN KEY (l_wikidata)REFERENCES wikidata      (id);
ALTER TABLE vn_hist                  ADD CONSTRAINT vn_hist_chid_fkey                  FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE vn_hist                  ADD CONSTRAINT vn_hist_l_wikidata_fkey            FOREIGN KEY (l_wikidata)REFERENCES wikidata      (id);
ALTER TABLE vn_anime                 ADD CONSTRAINT vn_anime_id_fkey                   FOREIGN KEY (id)        REFERENCES vn            (id);
ALTER TABLE vn_anime                 ADD CONSTRAINT vn_anime_aid_fkey                  FOREIGN KEY (aid)       REFERENCES anime         (id);
ALTER TABLE vn_anime_hist            ADD CONSTRAINT vn_anime_hist_chid_fkey            FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE vn_anime_hist            ADD CONSTRAINT vn_anime_hist_aid_fkey             FOREIGN KEY (aid)       REFERENCES anime         (id);
ALTER TABLE vn_relations             ADD CONSTRAINT vn_relations_id_fkey               FOREIGN KEY (id)        REFERENCES vn            (id);
ALTER TABLE vn_relations             ADD CONSTRAINT vn_relations_vid_fkey              FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE vn_relations_hist        ADD CONSTRAINT vn_relations_chid_fkey             FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE vn_relations_hist        ADD CONSTRAINT vn_relations_vid_fkey              FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE vn_screenshots           ADD CONSTRAINT vn_screenshots_id_fkey             FOREIGN KEY (id)        REFERENCES vn            (id);
ALTER TABLE vn_screenshots           ADD CONSTRAINT vn_screenshots_scr_fkey            FOREIGN KEY (scr)       REFERENCES screenshots   (id);
ALTER TABLE vn_screenshots           ADD CONSTRAINT vn_screenshots_rid_fkey            FOREIGN KEY (rid)       REFERENCES releases      (id) DEFERRABLE;
ALTER TABLE vn_screenshots_hist      ADD CONSTRAINT vn_screenshots_hist_chid_fkey      FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE vn_screenshots_hist      ADD CONSTRAINT vn_screenshots_hist_scr_fkey       FOREIGN KEY (scr)       REFERENCES screenshots   (id);
ALTER TABLE vn_screenshots_hist      ADD CONSTRAINT vn_screenshots_hist_rid_fkey       FOREIGN KEY (rid)       REFERENCES releases      (id) DEFERRABLE;
ALTER TABLE vn_seiyuu                ADD CONSTRAINT vn_seiyuu_id_fkey                  FOREIGN KEY (id)        REFERENCES vn            (id);
ALTER TABLE vn_seiyuu                ADD CONSTRAINT vn_seiyuu_aid_fkey                 FOREIGN KEY (aid)       REFERENCES staff_alias   (aid) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE vn_seiyuu                ADD CONSTRAINT vn_seiyuu_cid_fkey                 FOREIGN KEY (cid)       REFERENCES chars         (id);
ALTER TABLE vn_seiyuu_hist           ADD CONSTRAINT vn_seiyuu_hist_chid_fkey           FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE vn_seiyuu_hist           ADD CONSTRAINT vn_seiyuu_hist_cid_fkey            FOREIGN KEY (cid)       REFERENCES chars         (id);
ALTER TABLE vn_staff                 ADD CONSTRAINT vn_staff_id_fkey                   FOREIGN KEY (id)        REFERENCES vn            (id);
ALTER TABLE vn_staff                 ADD CONSTRAINT vn_staff_aid_fkey                  FOREIGN KEY (aid)       REFERENCES staff_alias   (aid) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE vn_staff_hist            ADD CONSTRAINT vn_staff_hist_chid_fkey            FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE vnlists                  ADD CONSTRAINT vnlists_uid_fkey                   FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE CASCADE;
ALTER TABLE vnlists                  ADD CONSTRAINT vnlists_vid_fkey                   FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE votes                    ADD CONSTRAINT votes_uid_fkey                     FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE CASCADE;
ALTER TABLE votes                    ADD CONSTRAINT votes_vid_fkey                     FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE wlists                   ADD CONSTRAINT wlists_uid_fkey                    FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE CASCADE;
ALTER TABLE wlists                   ADD CONSTRAINT wlists_vid_fkey                    FOREIGN KEY (vid)       REFERENCES vn            (id);



-- Indices

CREATE        INDEX chars_main             ON chars (main) WHERE main IS NOT NULL AND NOT hidden; -- Only used on /c+
CREATE        INDEX chars_vns_vid          ON chars_vns (vid);
CREATE        INDEX notifications_uid      ON notifications (uid);
CREATE        INDEX releases_producers_pid ON releases_producers (pid);
CREATE        INDEX releases_vn_vid        ON releases_vn (vid);
CREATE        INDEX staff_alias_id         ON staff_alias (id);
CREATE        INDEX tags_vn_date           ON tags_vn (date);
CREATE        INDEX tags_vn_inherit_tag_vid ON tags_vn_inherit (tag, vid);
CREATE        INDEX tags_vn_uid            ON tags_vn (uid);
CREATE        INDEX shop_playasia__gtin    ON shop_playasia (gtin);
CREATE        INDEX tags_vn_vid            ON tags_vn (vid);
CREATE        INDEX threads_posts_date     ON threads_posts (date);
CREATE        INDEX threads_posts_ts       ON threads_posts USING gin(bb_tsvector(msg));
CREATE        INDEX threads_posts_uid      ON threads_posts (uid); -- Only really used on /u+ pages to get stats
CREATE        INDEX traits_chars_tid       ON traits_chars (tid);
CREATE        INDEX vn_seiyuu_aid          ON vn_seiyuu (aid); -- Only used on /s+?
CREATE        INDEX vn_seiyuu_cid          ON vn_seiyuu (cid); -- Only used on /c+?
CREATE        INDEX vn_staff_aid           ON vn_staff (aid);
CREATE        INDEX votes_date             ON votes (date desc); -- Mainly used on /v+ pages, other pages don't really need it
CREATE        INDEX votes_uid              ON votes (uid);
CREATE UNIQUE INDEX changes_itemrev        ON changes (type, itemid, rev);
CREATE UNIQUE INDEX chars_vns_pkey         ON chars_vns (id, vid, COALESCE(rid, 0));
CREATE UNIQUE INDEX chars_vns_hist_pkey    ON chars_vns_hist (chid, vid, COALESCE(rid, 0));
CREATE        INDEX ulist_vns_voted        ON ulist_vns (vid, vote_date) WHERE vote IS NOT NULL; -- For VN recent votes & vote graph. INCLUDE(vote) speeds up vote graph even more
CREATE        INDEX users_ign_votes        ON users (id) WHERE ign_votes;



-- Triggers

CREATE TRIGGER users_changes_update       AFTER  INSERT OR DELETE ON changes       FOR EACH ROW EXECUTE PROCEDURE update_users_cache();
CREATE TRIGGER users_tags_update          AFTER  INSERT OR DELETE ON tags_vn       FOR EACH ROW EXECUTE PROCEDURE update_users_cache();

CREATE TRIGGER stats_cache_new            AFTER  INSERT           ON vn            FOR EACH ROW WHEN (NEW.hidden = FALSE) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit           AFTER  UPDATE           ON vn            FOR EACH ROW WHEN (OLD.hidden IS DISTINCT FROM NEW.hidden) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_new            AFTER  INSERT           ON producers     FOR EACH ROW WHEN (NEW.hidden = FALSE) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit           AFTER  UPDATE           ON producers     FOR EACH ROW WHEN (OLD.hidden IS DISTINCT FROM NEW.hidden) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_new            AFTER  INSERT           ON releases      FOR EACH ROW WHEN (NEW.hidden = FALSE) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit           AFTER  UPDATE           ON releases      FOR EACH ROW WHEN (OLD.hidden IS DISTINCT FROM NEW.hidden) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_new            AFTER  INSERT           ON chars         FOR EACH ROW WHEN (NEW.hidden = FALSE) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit           AFTER  UPDATE           ON chars         FOR EACH ROW WHEN (OLD.hidden IS DISTINCT FROM NEW.hidden) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_new            AFTER  INSERT           ON staff         FOR EACH ROW WHEN (NEW.hidden = FALSE) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit           AFTER  UPDATE           ON staff         FOR EACH ROW WHEN (OLD.hidden IS DISTINCT FROM NEW.hidden) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_new            AFTER  INSERT           ON tags          FOR EACH ROW WHEN (NEW.state = 2) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit           AFTER  UPDATE           ON tags          FOR EACH ROW WHEN (OLD.state IS DISTINCT FROM NEW.state) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_new            AFTER  INSERT           ON traits        FOR EACH ROW WHEN (NEW.state = 2) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit           AFTER  UPDATE           ON traits        FOR EACH ROW WHEN (OLD.state IS DISTINCT FROM NEW.state) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_new            AFTER  INSERT           ON threads       FOR EACH ROW WHEN (NEW.hidden = FALSE) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit           AFTER  UPDATE           ON threads       FOR EACH ROW WHEN (OLD.hidden IS DISTINCT FROM NEW.hidden) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_new            AFTER  INSERT           ON threads_posts FOR EACH ROW WHEN (NEW.hidden = FALSE) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache_edit           AFTER  UPDATE           ON threads_posts FOR EACH ROW WHEN (OLD.hidden IS DISTINCT FROM NEW.hidden) EXECUTE PROCEDURE update_stats_cache();
CREATE TRIGGER stats_cache                AFTER  INSERT OR DELETE ON users         FOR EACH ROW EXECUTE PROCEDURE update_stats_cache();

CREATE TRIGGER vn_anime_aid_new           BEFORE INSERT           ON vn_anime      FOR EACH ROW EXECUTE PROCEDURE vn_anime_aid();
CREATE TRIGGER vn_anime_aid_edit          BEFORE UPDATE           ON vn_anime      FOR EACH ROW WHEN (OLD.aid IS DISTINCT FROM NEW.aid) EXECUTE PROCEDURE vn_anime_aid();

CREATE TRIGGER anime_fetch_notify         AFTER  INSERT OR UPDATE ON anime         FOR EACH ROW WHEN (NEW.lastfetch IS NULL) EXECUTE PROCEDURE anime_fetch_notify();

CREATE TRIGGER producers_wikidata_new       BEFORE INSERT ON producers      FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER producers_wikidata_edit      BEFORE UPDATE ON producers      FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER producers_hist_wikidata_new  BEFORE INSERT ON producers_hist FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER producers_hist_wikidata_edit BEFORE UPDATE ON producers_hist FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER staff_wikidata_new           BEFORE INSERT ON staff          FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER staff_wikidata_edit          BEFORE UPDATE ON staff          FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER staff_hist_wikidata_new      BEFORE INSERT ON staff_hist     FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER staff_hist_wikidata_edit     BEFORE UPDATE ON staff_hist     FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER vn_wikidata_new              BEFORE INSERT ON vn             FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER vn_wikidata_edit             BEFORE UPDATE ON vn             FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER vn_hist_wikidata_new         BEFORE INSERT ON vn_hist        FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER vn_hist_wikidata_edit        BEFORE UPDATE ON vn_hist        FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();

CREATE TRIGGER vn_relgraph_notify AFTER UPDATE ON vn FOR EACH ROW
  WHEN ((OLD.rgraph IS NOT NULL AND NEW.rgraph IS NULL)
     OR (NEW.rgraph IS NOT NULL AND (OLD.c_released IS DISTINCT FROM NEW.c_released OR OLD.c_languages IS DISTINCT FROM NEW.c_languages))
  ) EXECUTE PROCEDURE vn_relgraph_notify();

CREATE TRIGGER producer_relgraph_notify AFTER UPDATE ON producers FOR EACH ROW WHEN (OLD.rgraph IS NOT NULL AND NEW.rgraph IS NULL) EXECUTE PROCEDURE producer_relgraph_notify();

CREATE TRIGGER insert_notify              AFTER  INSERT           ON changes       FOR EACH STATEMENT EXECUTE PROCEDURE insert_notify();
CREATE TRIGGER insert_notify              AFTER  INSERT           ON threads_posts FOR EACH STATEMENT EXECUTE PROCEDURE insert_notify();
CREATE TRIGGER insert_notify              AFTER  INSERT           ON tags          FOR EACH STATEMENT EXECUTE PROCEDURE insert_notify();
CREATE TRIGGER insert_notify              AFTER  INSERT           ON traits        FOR EACH STATEMENT EXECUTE PROCEDURE insert_notify();

CREATE TRIGGER notify_pm                  AFTER  INSERT           ON threads_posts FOR EACH ROW EXECUTE PROCEDURE notify_pm();
CREATE TRIGGER notify_announce            AFTER  INSERT           ON threads_posts FOR EACH ROW WHEN (NEW.num = 1) EXECUTE PROCEDURE notify_announce();

CREATE TRIGGER ulist_labels_create        AFTER  INSERT           ON users         FOR EACH ROW EXECUTE PROCEDURE ulist_labels_create();
CREATE TRIGGER ulist_voted_label          AFTER  INSERT OR UPDATE ON ulist_vns     FOR EACH ROW EXECUTE PROCEDURE ulist_voted_label();

CREATE TRIGGER vn_vnsearch_notify AFTER UPDATE ON vn FOR EACH ROW WHEN (OLD.c_search IS NOT NULL AND NEW.c_search IS NULL) EXECUTE PROCEDURE vn_vnsearch_notify();

CREATE CONSTRAINT TRIGGER update_vnlist_rlist AFTER DELETE ON ulist_vns DEFERRABLE FOR EACH ROW EXECUTE PROCEDURE update_vnlist_rlist();
CREATE CONSTRAINT TRIGGER update_vnlist_rlist AFTER INSERT ON rlists    DEFERRABLE FOR EACH ROW EXECUTE PROCEDURE update_vnlist_rlist();
