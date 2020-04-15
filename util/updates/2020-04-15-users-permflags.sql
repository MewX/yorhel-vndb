ALTER TABLE users ADD COLUMN perm_board    boolean NOT NULL DEFAULT true;
ALTER TABLE users ADD COLUMN perm_boardmod boolean NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN perm_dbmod    boolean NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN perm_edit     boolean NOT NULL DEFAULT true;
ALTER TABLE users ADD COLUMN perm_imgvote  boolean NOT NULL DEFAULT true;
ALTER TABLE users ADD COLUMN perm_tag      boolean NOT NULL DEFAULT true;
ALTER TABLE users ADD COLUMN perm_tagmod   boolean NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN perm_usermod  boolean NOT NULL DEFAULT false;

UPDATE users SET
    perm_board    = (perm &   1) > 0,
    perm_boardmod = (perm &   2) > 0,
    perm_dbmod    = (perm &  32) > 0,
    perm_edit     = (perm &   4) > 0,
    perm_imgvote  = (perm &   8) > 0,
    perm_tag      = (perm &  16) > 0,
    perm_tagmod   = (perm &  64) > 0,
    perm_usermod  = (perm & 128) > 0;

ALTER TABLE users DROP COLUMN perm;
ALTER TABLE users DROP COLUMN hide_list;

DROP FUNCTION user_setperm(integer, integer, bytea, integer);

\i sql/func.sql
\i sql/perms.sql
