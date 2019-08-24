CREATE TABLE shop_jlist (
  id        text NOT NULL PRIMARY KEY,
  lastfetch timestamptz,
  found     boolean NOT NULL DEFAULT false,
  jbox      boolean NOT NULL DEFAULT false,
  price     text NOT NULL DEFAULT ''
);

CREATE TABLE shop_mg (
  id        integer NOT NULL PRIMARY KEY,
  lastfetch timestamptz,
  found     boolean NOT NULL DEFAULT false,
  r18       boolean NOT NULL DEFAULT true,
  price     text NOT NULL DEFAULT ''
);

CREATE TABLE shop_denpa (
  id        text NOT NULL PRIMARY KEY,
  lastfetch timestamptz,
  found     boolean NOT NULL DEFAULT false,
  sku       text NOT NULL DEFAULT '',
  price     text NOT NULL DEFAULT ''
);

GRANT SELECT, INSERT, UPDATE, DELETE ON shop_jlist               TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_mg                  TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_denpa               TO vndb_multi;
