-- Replaces the current vnlists, votes and wlists tables
CREATE TABLE ulists (
    uid       integer NOT NULL, -- users.id
    vid       integer NOT NULL, -- vn.id
    added     timestamptz NOT NULL DEFAULT NOW(),
    lastmod   timestamptz NOT NULL DEFAULT NOW(), -- updated when anything in this row has changed?
    vote_date timestamptz, -- Used for "recent votes" - also updated when vote has changed?
    vote      smallint CHECK(vote IS NULL OR vote BETWEEN 10 AND 100),
    started   date,
    finished  date,
    notes     text NOT NULL DEFAULT '',
    PRIMARY KEY(uid, vid)
);

CREATE TABLE ulists_labels (
    uid      integer NOT NULL, -- user.id
    id       integer NOT NULL, -- 0 < builtin < 10 <= custom, ids are reused
    label    text NOT NULL,
    private  boolean NOT NULL,
    PRIMARY KEY(uid, id)
);

CREATE TABLE ulists_vn_labels (
    uid integer NOT NULL, -- user.id
    lbl integer NOT NULL,
    vid integer NOT NULL, -- vn.id
    PRIMARY KEY(uid, lbl, vid)
    -- (uid, lbl) REFERENCES ulist_labels (uid, id) ON DELETE CASCADE
    -- (uid, vid) REFERENCES ulist (uid, vid) ON DELETE CASCADE
    -- Do we want a 'when has this label been applied' timestamp?
);

-- When is a row in ulist 'public'? i.e. When it is visible in a VNs recent votes and in the user's VN list?
--
--  EXISTS(SELECT 1 FROM ulist_vn_label uvl JOIN ulist_labels ul ON ul.id = uvl.lbl AND ul.uid = uvl.uid WHERE uid = ulist.uid AND vid = ulist.vid AND NOT ul.private)
--
-- That is: It is public when it has been assigned at least one non-private label.
--
-- This means that, during the conversion of old lists to this new format, all
-- vns with an 'unknown' status (= old 'unknown' status or voted but not in
-- vnlist/wlist) from users who have not hidden their list should be assigned
-- to a new non-private label.
--
-- The "Don't allow others to see my [..] list" profile option becomes obsolete
-- with this label-based private flag.



\timing

INSERT INTO ulists_labels (uid, id, label, private)
              SELECT id,  1, 'Playing',   hide_list FROM users
    UNION ALL SELECT id,  2, 'Finished',  hide_list FROM users
    UNION ALL SELECT id,  3, 'Stalled',   hide_list FROM users
    UNION ALL SELECT id,  4, 'Dropped',   hide_list FROM users
    UNION ALL SELECT id,  5, 'Wishlist',  hide_list FROM users
    UNION ALL SELECT id,  6, 'Blacklist', hide_list FROM users
    UNION ALL SELECT id,  7, 'Voted',     hide_list FROM users
    UNION ALL SELECT id, 10, 'Wishlist-High',   hide_list FROM users WHERE id IN(SELECT DISTINCT uid FROM wlists WHERE wstat = 0)
    UNION ALL SELECT id, 11, 'Wishlist-Medium', hide_list FROM users WHERE id IN(SELECT DISTINCT uid FROM wlists WHERE wstat = 1)
    UNION ALL SELECT id, 12, 'Wishlist-Low',    hide_list FROM users WHERE id IN(SELECT DISTINCT uid FROM wlists WHERE wstat = 2);

INSERT INTO ulists (uid, vid, added, lastmod, vote_date, vote, notes)
    SELECT COALESCE(wl.uid, vl.uid, vo.uid)
         , COALESCE(wl.vid, vl.vid, vo.vid)
         , LEAST(wl.added, vl.added, vo.date)
         , GREATEST(wl.added, vl.added, vo.date)
         , vo.date, vo.vote
         , COALESCE(vl.notes, '')
      FROM wlists wl
      FULL JOIN vnlists vl ON vl.uid = wl.uid AND vl.vid = wl.vid
      FULL JOIN votes   vo ON vo.uid = COALESCE(wl.uid, vl.uid) AND vo.vid = COALESCE(wl.vid, vl.vid);

INSERT INTO ulists_vn_labels (uid, vid, lbl)
              SELECT uid, vid,  5 FROM wlists WHERE wstat <> 3 -- All wishlisted items except the blacklist
    UNION ALL SELECT uid, vid, 10 FROM wlists WHERE wstat = 0 -- Wishlist-High
    UNION ALL SELECT uid, vid, 11 FROM wlists WHERE wstat = 1 -- Wishlist-Medium
    UNION ALL SELECT uid, vid, 12 FROM wlists WHERE wstat = 2 -- Wishlist-Low
    UNION ALL SELECT uid, vid,  6 FROM wlists WHERE wstat = 3 -- Blacklist
    UNION ALL SELECT uid, vid, status FROM vnlists WHERE status <> 0 -- Playing/Finished/Stalled/Dropped
    UNION ALL SELECT uid, vid,  7 FROM votes;



ALTER TABLE ulists                   ADD CONSTRAINT ulists_uid_fkey                    FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE CASCADE;
ALTER TABLE ulists                   ADD CONSTRAINT ulists_vid_fkey                    FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE ulists_labels            ADD CONSTRAINT ulists_labels_uid_fkey             FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE CASCADE;
ALTER TABLE ulists_vn_labels         ADD CONSTRAINT ulists_vn_labels_uid_fkey          FOREIGN KEY (uid)       REFERENCES users         (id) ON DELETE CASCADE;
ALTER TABLE ulists_vn_labels         ADD CONSTRAINT ulists_vn_labels_vid_fkey          FOREIGN KEY (vid)       REFERENCES vn            (id);
ALTER TABLE ulists_vn_labels         ADD CONSTRAINT ulists_vn_labels_uid_lbl_fkey      FOREIGN KEY (uid,lbl)   REFERENCES ulists_labels (uid,id) ON DELETE CASCADE;
ALTER TABLE ulists_vn_labels         ADD CONSTRAINT ulists_vn_labels_uid_vid_fkey      FOREIGN KEY (uid,vid)   REFERENCES ulists        (uid,vid) ON DELETE CASCADE;

GRANT SELECT, INSERT, UPDATE, DELETE ON ulists                   TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON ulists_labels            TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON ulists_vn_labels         TO vndb_site;
