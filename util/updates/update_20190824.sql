CREATE TABLE shop_jlist (
  id        text NOT NULL PRIMARY KEY,
  lastfetch timestamptz,
  found     boolean NOT NULL DEFAULT false,
  jbox      boolean NOT NULL DEFAULT false,
  price     text NOT NULL DEFAULT ''
);

GRANT SELECT, INSERT, UPDATE, DELETE ON shop_jlist               TO vndb_multi;
