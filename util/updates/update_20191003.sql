ALTER TABLE users ADD COLUMN skin            text NOT NULL DEFAULT '';
ALTER TABLE users ADD COLUMN customcss       text NOT NULL DEFAULT '';
ALTER TABLE users ADD COLUMN filter_vn       text NOT NULL DEFAULT '';
ALTER TABLE users ADD COLUMN filter_release  text NOT NULL DEFAULT '';
ALTER TABLE users ADD COLUMN show_nsfw       boolean NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN hide_list       boolean NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN notify_dbedit   boolean NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN notify_announce boolean NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN vn_list_own     boolean NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN vn_list_wish    boolean NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN tags_all        boolean NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN tags_cont       boolean NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN tags_ero        boolean NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN tags_tech       boolean NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN spoilers        boolean NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN traits_sexual   boolean NOT NULL DEFAULT FALSE;

UPDATE users SET
    skin            = COALESCE((SELECT value FROM users_prefs WHERE uid = id AND key = 'skin'           ), ''),
    customcss       = COALESCE((SELECT value FROM users_prefs WHERE uid = id AND key = 'customcss'      ), ''),
    filter_vn       = COALESCE((SELECT value FROM users_prefs WHERE uid = id AND key = 'filter_vn'      ), ''),
    filter_release  = COALESCE((SELECT value FROM users_prefs WHERE uid = id AND key = 'filter_release' ), ''),
    show_nsfw       = COALESCE((SELECT TRUE  FROM users_prefs WHERE uid = id AND key = 'show_nsfw'      ), FALSE),
    hide_list       = COALESCE((SELECT TRUE  FROM users_prefs WHERE uid = id AND key = 'hide_list'      ), FALSE),
    notify_dbedit   = COALESCE((SELECT FALSE FROM users_prefs WHERE uid = id AND key = 'notify_nodbedit'), TRUE), -- NOTE: Inverted
    notify_announce = COALESCE((SELECT TRUE  FROM users_prefs WHERE uid = id AND key = 'notify_announce'), FALSE),
    vn_list_own     = COALESCE((SELECT TRUE  FROM users_prefs WHERE uid = id AND key = 'vn_list_own'    ), FALSE),
    vn_list_wish    = COALESCE((SELECT TRUE  FROM users_prefs WHERE uid = id AND key = 'vn_list_wish'   ), FALSE),
    tags_all        = COALESCE((SELECT TRUE  FROM users_prefs WHERE uid = id AND key = 'tags_all'       ), FALSE),
    spoilers        = COALESCE((SELECT TRUE  FROM users_prefs WHERE uid = id AND key = 'spoilers'       ), FALSE),
    traits_sexual   = COALESCE((SELECT TRUE  FROM users_prefs WHERE uid = id AND key = 'traits_sexual'  ), FALSE),
    tags_cont       = COALESCE((SELECT value LIKE '%cont%' FROM users_prefs WHERE uid = id AND key = 'tags_cat'), TRUE),
    tags_ero        = COALESCE((SELECT value LIKE '%ero%'  FROM users_prefs WHERE uid = id AND key = 'tags_cat'), FALSE),
    tags_tech       = COALESCE((SELECT value LIKE '%tech%' FROM users_prefs WHERE uid = id AND key = 'tags_cat'), TRUE);

\i util/sql/func.sql
\i util/sql/perms.sql

DROP TABLE users_prefs;
DROP TYPE prefs_key;
