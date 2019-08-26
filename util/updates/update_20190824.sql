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

CREATE TABLE shop_dlsite (
  id        text NOT NULL PRIMARY KEY,
  lastfetch timestamptz,
  found     boolean NOT NULL DEFAULT false,
  shop      text NOT NULL DEFAULT '',
  price     text NOT NULL DEFAULT ''
);

CREATE TABLE shop_playasia (
  pax       text NOT NULL PRIMARY KEY,
  gtin      bigint NOT NULL,
  lastfetch timestamptz,
  url       text NOT NULL DEFAULT '',
  price     text NOT NULL DEFAULT ''
);

CREATE TABLE shop_playasia_gtin (
  gtin      bigint NOT NULL PRIMARY KEY,
  lastfetch timestamptz
);

GRANT SELECT                         ON shop_denpa               TO vndb_site;
GRANT SELECT                         ON shop_dlsite              TO vndb_site;
GRANT SELECT                         ON shop_jlist               TO vndb_site;
GRANT SELECT                         ON shop_mg                  TO vndb_site;
GRANT SELECT                         ON shop_playasia            TO vndb_site;

GRANT SELECT, INSERT, UPDATE, DELETE ON shop_jlist               TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_mg                  TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_denpa               TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_dlsite              TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_playasia            TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_playasia_gtin       TO vndb_multi;

CREATE        INDEX shop_playasia__gtin    ON shop_playasia (gtin);

INSERT INTO shop_playasia (pax, gtin, lastfetch, url, price)
  SELECT data, MAX(gtin), MAX(lastfetch), MAX(url), MAX(price)
    FROM affiliate_links
    JOIN releases ON affiliate_links.rid = releases.id
   WHERE affiliate = 0 AND NOT affiliate_links.hidden AND price <> 'US$ 0.00'
   GROUP BY data;


-- Whenever:
-- DROP TABLE affiliate_links;
-- DROP TABLE multi_affiliate_gtin;
