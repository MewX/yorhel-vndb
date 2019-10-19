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

-- Automatically created for each user:
--
--   Wishlist (with -Low/-Medium/-High for converted wishlists, otherwise not created by default)
--   Blacklist
--   Playing
--   Finished
--   Stalled
--   Dropped
--
-- Should these be user-editable, apart from the 'private' flag?
-- I'd say no, because then it'd be impossible use the lists for stats and automated suggestions.
CREATE TABLE ulists_labels (
    uid      integer NOT NULL, -- user.id
    id       SERIAL NOT NULL,
    label    text NOT NULL,
    private  boolean NOT NULL,
    PRIMARY KEY(uid, id)
    -- Technically 'id' is already unique because of the SERIAL type, but we want labels to be local to users.
    -- Assuming we don't need 'id' to be globally unique, we can reserve fixed numbers for automatically created labels
    -- (this would allow e.g. an "exclude blacklisted VNs" filter to use the same label id for everyone).
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

-- First 1000 numbers are reserved for built-in labels, first 10 non-built-in labels are for conversion.
SELECT setval('ulists_labels_id_seq', 1010);

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
              SELECT id,    1, 'Playing',   hide_list FROM users
    UNION ALL SELECT id,    2, 'Finished',  hide_list FROM users
    UNION ALL SELECT id,    3, 'Stalled',   hide_list FROM users
    UNION ALL SELECT id,    4, 'Dropped',   hide_list FROM users
    UNION ALL SELECT id,    5, 'Wishlist',  hide_list FROM users
    UNION ALL SELECT id,    6, 'Blacklist', hide_list FROM users
    UNION ALL SELECT id,    7, 'Voted',     hide_list FROM users
    UNION ALL SELECT id, 1000,'Wishlist-High',   hide_list FROM users WHERE id IN(SELECT DISTINCT uid FROM wlists WHERE wstat = 0)
    UNION ALL SELECT id, 1001,'Wishlist-Medium', hide_list FROM users WHERE id IN(SELECT DISTINCT uid FROM wlists WHERE wstat = 1)
    UNION ALL SELECT id, 1002,'Wishlist-Low',    hide_list FROM users WHERE id IN(SELECT DISTINCT uid FROM wlists WHERE wstat = 2);

-- WAY TOO SLOW. No, really, this will likely bring down the server for a day.
--INSERT INTO ulists (uid, vid, added, lastmod, vote_date, vote, notes)
--    SELECT u.id, v.id, LEAST(wl.added, vl.added, vo.date), GREATEST(wl.added, vl.added, vo.date), vo.date, vo.vote, COALESCE(vl.notes, '')
--      FROM users u
--      JOIN vn v ON true
--      LEFT JOIN wlists  wl ON wl.uid = u.id AND wl.vid = v.id
--      LEFT JOIN vnlists vl ON vl.uid = u.id AND vl.vid = v.id
--      LEFT JOIN votes   vo ON vo.uid = u.id AND vo.vid = v.id
--     WHERE (wl.uid IS NOT NULL OR vl.uid IS NOT NULL OR vo.uid IS NOT NULL);

-- Same thing as above, but in 3 smaller steps.
--INSERT INTO ulists (uid, vid, added, lastmod, vote_date, vote) SELECT uid, vid, date, date, date, vote FROM votes;
--INSERT INTO ulists (uid, vid, added, lastmod, notes)
--    SELECT uid, vid, added, added, notes FROM vnlists ON CONFLICT (uid, vid) DO
--    UPDATE SET notes = excluded.notes, added = LEAST(ulists.added, excluded.added), lastmod = GREATEST(ulists.lastmod, excluded.added);
--INSERT INTO ulists (uid, vid, added, lastmod)
--    SELECT uid, vid, added, added FROM wlists ON CONFLICT (uid, vid) DO
--    UPDATE SET added = LEAST(ulists.added, excluded.added), lastmod = GREATEST(ulists.lastmod, excluded.added);

-- Same thing again, I realized I just needed FULL OUTER JOINs.
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
              SELECT uid, vid,   5 FROM wlists WHERE wstat <> 3 -- All wishlisted items except the blacklist
    UNION ALL SELECT uid, vid,1000 FROM wlists WHERE wstat = 0 -- Wishlist-High
    UNION ALL SELECT uid, vid,1001 FROM wlists WHERE wstat = 1 -- Wishlist-Medium
    UNION ALL SELECT uid, vid,1002 FROM wlists WHERE wstat = 2 -- Wishlist-Low
    UNION ALL SELECT uid, vid,   6 FROM wlists WHERE wstat = 3 -- Blacklist
    UNION ALL SELECT uid, vid, status FROM vnlists WHERE status <> 0 -- Playing/Finished/Stalled/Dropped
    UNION ALL SELECT uid, vid,   7 FROM votes;



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
