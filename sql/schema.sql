-- Convention for database items with version control:
--
--   CREATE TABLE items ( -- dbentry_type=x
--     id        SERIAL PRIMARY KEY,
--     locked    boolean NOT NULL DEFAULT FALSE,
--     hidden    boolean NOT NULL DEFAULT FALSE,
--     -- item-specific columns here
--   );
--   CREATE TABLE items_hist ( -- History of the 'items' table
--     chid integer NOT NULL,  -- references changes.id
--     -- item-specific columns here
--   );
--
-- The '-- dbentry_type=x' comment is required, and is used by
-- util/sqleditfunc.pl to generate the correct editing functions.  The history
-- of the 'locked' and 'hidden' flags is recorded in the changes table.  It's
-- possible for 'items' to have more item-specific columns than 'items_hist'.
-- Some columns are caches or otherwise autogenerated, and do not need to be
-- versioned.
--
-- item-related tables work roughly the same:
--
--   CREATE TABLE items_field (
--     id integer,  -- references items.id
--     -- field-specific columns here
--   );
--   CREATE TABLE items_field_hist ( -- History of the 'items_field' table
--     chid integer, -- references changes.id
--     -- field-specific columns here
--   );
--
-- The changes and *_hist tables contain all the data. In a sense, the other
-- tables related to the item are just a cache/view into the latest versions.
-- All modifications to the item tables has to go through the edit_* functions
-- in editfunc.sql, these are also responsible for keeping things synchronized.
--
-- Columns marked with a '[pub]' comment on the same line are included in the
-- public database dump. Be aware that not all properties of the to-be-dumped
-- data is annotated in this file. Which tables and which rows are exported is
-- defined in util/dbdump.pl.
--
-- Note: Every CREATE TABLE clause and each column should be on a separate
-- line. This file is parsed by lib/VNDB/Schema.pm and it doesn't implement a
-- full SQL query parser.


-- data types

CREATE TYPE anime_type        AS ENUM ('tv', 'ova', 'mov', 'oth', 'web', 'spe', 'mv');
CREATE TYPE blood_type        AS ENUM ('unknown', 'a', 'b', 'ab', 'o');
CREATE TYPE board_type        AS ENUM ('an', 'db', 'ge', 'v', 'p', 'u');
CREATE TYPE char_role         AS ENUM ('main', 'primary', 'side', 'appears');
CREATE TYPE credit_type       AS ENUM ('scenario', 'chardesign', 'art', 'music', 'songs', 'director', 'staff');
CREATE TYPE cup_size          AS ENUM ('', 'AAA', 'AA', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z');
CREATE TYPE dbentry_type      AS ENUM ('v', 'r', 'p', 'c', 's', 'd');
CREATE TYPE edit_rettype      AS (itemid integer, chid integer, rev integer);
CREATE TYPE gender            AS ENUM ('unknown', 'm', 'f', 'b');
CREATE TYPE language          AS ENUM ('ar', 'bg', 'ca', 'cs', 'da', 'de', 'el', 'en', 'eo', 'es', 'fi', 'fr', 'gd', 'he', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'mk', 'ms', 'lt', 'lv', 'nl', 'no', 'pl', 'pt-pt', 'pt-br', 'ro', 'ru', 'sk', 'sl', 'sv', 'ta', 'th', 'tr', 'uk', 'vi', 'zh');
CREATE TYPE medium            AS ENUM ('cd', 'dvd', 'gdr', 'blr', 'flp', 'mrt', 'mem', 'umd', 'nod', 'in', 'otc');
CREATE TYPE notification_ntype AS ENUM ('pm', 'dbdel', 'listdel', 'dbedit', 'announce', 'post', 'comment');
CREATE TYPE platform          AS ENUM ('win', 'dos', 'lin', 'mac', 'ios', 'and', 'dvd', 'bdp', 'fmt', 'gba', 'gbc', 'msx', 'nds', 'nes', 'p88', 'p98', 'pce', 'pcf', 'psp', 'ps1', 'ps2', 'ps3', 'ps4', 'psv', 'drc', 'sat', 'sfc', 'swi', 'wii', 'wiu', 'n3d', 'x68', 'xb1', 'xb3', 'xbo', 'web', 'oth');
CREATE TYPE producer_type     AS ENUM ('co', 'in', 'ng');
CREATE TYPE producer_relation AS ENUM ('old', 'new', 'sub', 'par', 'imp', 'ipa', 'spa', 'ori');
CREATE TYPE release_type      AS ENUM ('complete', 'partial', 'trial');
CREATE TYPE report_status     AS ENUM ('new', 'busy', 'done', 'dismissed');
CREATE TYPE tag_category      AS ENUM('cont', 'ero', 'tech');
CREATE TYPE vn_relation       AS ENUM ('seq', 'preq', 'set', 'alt', 'char', 'side', 'par', 'ser', 'fan', 'orig');
CREATE TYPE session_type      AS ENUM ('web', 'pass', 'mail');

-- Sequences used for ID generation
CREATE SEQUENCE charimg_seq;
CREATE SEQUENCE covers_seq;
CREATE SEQUENCE reviews_seq;
CREATE SEQUENCE screenshots_seq;
CREATE SEQUENCE threads_id_seq;



-- anime
CREATE TABLE anime (
  id integer NOT NULL PRIMARY KEY, -- [pub]
  year smallint, -- [pub]
  ann_id integer, -- [pub]
  nfo_id varchar(200), -- [pub]
  type anime_type, -- [pub]
  title_romaji varchar(250), -- [pub]
  title_kanji varchar(250), -- [pub]
  lastfetch timestamptz
);

-- audit_log
CREATE TABLE audit_log (
  date          timestamptz NOT NULL DEFAULT NOW(),
  by_uid        integer,
  by_name       text,
  by_ip         inet NOT NULL,
  affected_uid  integer,
  affected_name text,
  action        text NOT NULL,
  detail        text
);

-- changes
CREATE TABLE changes (
  id         SERIAL PRIMARY KEY,
  type       dbentry_type NOT NULL,
  itemid     integer NOT NULL,
  rev        integer NOT NULL DEFAULT 1,
  added      timestamptz NOT NULL DEFAULT NOW(),
  requester  integer NOT NULL DEFAULT 0,
  ip         inet NOT NULL DEFAULT '0.0.0.0',
  comments   text NOT NULL DEFAULT '',
  ihid       boolean NOT NULL DEFAULT FALSE,
  ilock      boolean NOT NULL DEFAULT FALSE
);

-- chars
CREATE TABLE chars ( -- dbentry_type=c
  id         SERIAL PRIMARY KEY, -- [pub]
  locked     boolean NOT NULL DEFAULT FALSE,
  hidden     boolean NOT NULL DEFAULT FALSE,
  name       varchar(250) NOT NULL DEFAULT '', -- [pub]
  original   varchar(250) NOT NULL DEFAULT '', -- [pub]
  alias      varchar(500) NOT NULL DEFAULT '', -- [pub]
  image      vndbid CONSTRAINT chars_image_check CHECK(vndbid_type(image) = 'ch'), -- [pub]
  "desc"     text     NOT NULL DEFAULT '', -- [pub]
  gender     gender NOT NULL DEFAULT 'unknown', -- [pub]
  s_bust     smallint NOT NULL DEFAULT 0, -- [pub]
  s_waist    smallint NOT NULL DEFAULT 0, -- [pub]
  s_hip      smallint NOT NULL DEFAULT 0, -- [pub]
  b_month    smallint NOT NULL DEFAULT 0, -- [pub]
  b_day      smallint NOT NULL DEFAULT 0, -- [pub]
  height     smallint NOT NULL DEFAULT 0, -- [pub]
  weight     smallint, -- [pub]
  bloodt     blood_type NOT NULL DEFAULT 'unknown', -- [pub]
  main       integer, -- [pub] chars.id
  main_spoil smallint NOT NULL DEFAULT 0, -- [pub]
  cup_size   cup_size NOT NULL DEFAULT '', -- [pub]
  age        smallint, -- [pub]
  spoil_gender gender -- [pub]
);

-- chars_hist
CREATE TABLE chars_hist (
  chid       integer  NOT NULL PRIMARY KEY,
  name       varchar(250) NOT NULL DEFAULT '',
  original   varchar(250) NOT NULL DEFAULT '',
  alias      varchar(500) NOT NULL DEFAULT '',
  image      vndbid CONSTRAINT chars_hist_image_check CHECK(vndbid_type(image) = 'ch'),
  "desc"     text     NOT NULL DEFAULT '',
  gender     gender NOT NULL DEFAULT 'unknown',
  s_bust     smallint NOT NULL DEFAULT 0,
  s_waist    smallint NOT NULL DEFAULT 0,
  s_hip      smallint NOT NULL DEFAULT 0,
  b_month    smallint NOT NULL DEFAULT 0,
  b_day      smallint NOT NULL DEFAULT 0,
  height     smallint NOT NULL DEFAULT 0,
  weight     smallint,
  bloodt     blood_type NOT NULL DEFAULT 'unknown',
  main       integer, -- chars.id
  main_spoil smallint NOT NULL DEFAULT 0,
  cup_size   cup_size NOT NULL DEFAULT '',
  age        smallint,
  spoil_gender gender
);

-- chars_traits
CREATE TABLE chars_traits (
  id         integer NOT NULL, -- [pub]
  tid        integer NOT NULL, -- [pub] traits.id
  spoil      smallint NOT NULL DEFAULT 0, -- [pub]
  PRIMARY KEY(id, tid)
);

-- chars_traits_hist
CREATE TABLE chars_traits_hist (
  chid       integer NOT NULL,
  tid        integer NOT NULL, -- traits.id
  spoil      smallint NOT NULL DEFAULT 0,
  PRIMARY KEY(chid, tid)
);

-- chars_vns
CREATE TABLE chars_vns (
  id         integer NOT NULL, -- [pub]
  vid        integer NOT NULL, -- [pub] vn.id
  rid        integer NULL, -- [pub] releases.id
  spoil      smallint NOT NULL DEFAULT 0, -- [pub]
  role       char_role NOT NULL DEFAULT 'main' -- [pub]
);

-- chars_vns_hist
CREATE TABLE chars_vns_hist (
  chid       integer NOT NULL,
  vid        integer NOT NULL, -- vn.id
  rid        integer NULL, -- releases.id
  spoil      smallint NOT NULL DEFAULT 0,
  role       char_role NOT NULL DEFAULT 'main'
);

-- docs
CREATE TABLE docs ( -- dbentry_type=d
  id         SERIAL PRIMARY KEY, -- [pub]
  locked     boolean NOT NULL DEFAULT FALSE,
  hidden     boolean NOT NULL DEFAULT FALSE,
  title      varchar(200) NOT NULL DEFAULT '', -- [pub]
  content    text NOT NULL DEFAULT '', -- [pub]
  html       text -- cache, can be manually updated with util/update-docs-html-cache.pl
);

-- docs_hist
CREATE TABLE docs_hist (
  chid       integer  NOT NULL PRIMARY KEY,
  title      varchar(200) NOT NULL DEFAULT '',
  content    text NOT NULL DEFAULT '',
  html       text -- cache
);

-- images
CREATE TABLE images (
  id                vndbid NOT NULL PRIMARY KEY CONSTRAINT images_id_check CHECK(vndbid_type(id) IN('ch', 'cv', 'sf')), -- [pub]
  width             smallint NOT NULL, -- [pub]
  height            smallint NOT NULL, -- [pub]
  c_votecount       integer  NOT NULL DEFAULT 0, -- [pub] (cached columns are marked [pub] for easy querying...)
  c_sexual_avg      float, -- [pub]
  c_sexual_stddev   float, -- [pub]
  c_violence_avg    float, -- [pub]
  c_violence_stddev float, -- [pub]
  c_weight          float NOT NULL DEFAULT 0 -- [pub]
);

-- image_votes
CREATE TABLE image_votes (
  id       vndbid NOT NULL, -- [pub]
  uid      integer, -- [pub]
  sexual   smallint NOT NULL CHECK(sexual >= 0 AND sexual <= 2), -- [pub]
  violence smallint NOT NULL CHECK(violence >= 0 AND violence <= 2), -- [pub]
  date     timestamptz NOT NULL DEFAULT NOW(),-- [pub]
  ignore   boolean NOT NULL DEFAULT false -- [pub]
);

-- login_throttle
CREATE TABLE login_throttle (
  ip inet NOT NULL PRIMARY KEY,
  timeout timestamptz NOT NULL
);

-- notifications
CREATE TABLE notifications (
  id       serial PRIMARY KEY,
  uid      integer NOT NULL,
  date     timestamptz NOT NULL DEFAULT NOW(),
  read     timestamptz,
  ntype    notification_ntype NOT NULL,
  iid      vndbid NOT NULL,
  num      integer,
  c_title  text NOT NULL,
  c_byuser integer
);

-- producers
CREATE TABLE producers ( -- dbentry_type=p
  id         SERIAL PRIMARY KEY, -- [pub]
  locked     boolean NOT NULL DEFAULT FALSE,
  hidden     boolean NOT NULL DEFAULT FALSE,
  type       producer_type NOT NULL DEFAULT 'co', -- [pub]
  name       varchar(200) NOT NULL DEFAULT '', -- [pub]
  original   varchar(200) NOT NULL DEFAULT '', -- [pub]
  website    varchar(250) NOT NULL DEFAULT '', -- [pub]
  lang       language NOT NULL DEFAULT 'ja', -- [pub]
  "desc"     text NOT NULL DEFAULT '', -- [pub]
  alias      varchar(500) NOT NULL DEFAULT '', -- [pub]
  l_wp       varchar(150), -- [pub] (deprecated)
  l_wikidata integer -- [pub]
);

-- producers_hist
CREATE TABLE producers_hist (
  chid       integer NOT NULL PRIMARY KEY,
  type       producer_type NOT NULL DEFAULT 'co',
  name       varchar(200) NOT NULL DEFAULT '',
  original   varchar(200) NOT NULL DEFAULT '',
  website    varchar(250) NOT NULL DEFAULT '',
  lang       language NOT NULL DEFAULT 'ja',
  "desc"     text NOT NULL DEFAULT '',
  alias      varchar(500) NOT NULL DEFAULT '',
  l_wp       varchar(150),
  l_wikidata integer
);

-- producers_relations
CREATE TABLE producers_relations (
  id         integer NOT NULL, -- [pub]
  pid        integer NOT NULL, -- [pub] producers.id
  relation   producer_relation NOT NULL, -- [pub]
  PRIMARY KEY(id, pid)
);

-- producers_relations_hist
CREATE TABLE producers_relations_hist (
  chid       integer NOT NULL,
  pid        integer NOT NULL, -- producers.id
  relation   producer_relation NOT NULL,
  PRIMARY KEY(chid, pid)
);

-- quotes
CREATE TABLE quotes (
  vid integer NOT NULL,
  quote varchar(250) NOT NULL,
  PRIMARY KEY(vid, quote)
);

-- releases
CREATE TABLE releases ( -- dbentry_type=r
  id         SERIAL PRIMARY KEY, -- [pub]
  locked     boolean NOT NULL DEFAULT FALSE,
  hidden     boolean NOT NULL DEFAULT FALSE,
  title      varchar(300) NOT NULL DEFAULT '', -- [pub]
  original   varchar(250) NOT NULL DEFAULT '', -- [pub]
  type       release_type NOT NULL DEFAULT 'complete', -- [pub]
  website    varchar(250) NOT NULL DEFAULT '', -- [pub]
  catalog    varchar(50) NOT NULL DEFAULT '', -- [pub]
  gtin       bigint NOT NULL DEFAULT 0, -- [pub]
  released   integer NOT NULL DEFAULT 0, -- [pub]
  notes      text NOT NULL DEFAULT '', -- [pub]
  minage     smallint, -- [pub]
  patch      boolean NOT NULL DEFAULT FALSE, -- [pub]
  freeware   boolean NOT NULL DEFAULT FALSE, -- [pub]
  doujin     boolean NOT NULL DEFAULT FALSE, -- [pub]
  voiced     smallint NOT NULL DEFAULT 0, -- [pub]
  ani_story  smallint NOT NULL DEFAULT 0, -- [pub]
  ani_ero    smallint NOT NULL DEFAULT 0, -- [pub]
  uncensored boolean NOT NULL DEFAULT FALSE, -- [pub]
  engine     varchar(50) NOT NULL DEFAULT '', -- [pub]
  l_steam    integer NOT NULL DEFAULT 0, -- [pub]
  l_dlsite   text NOT NULL DEFAULT '', -- [pub]
  l_dlsiteen text NOT NULL DEFAULT '', -- [pub]
  l_gog      text NOT NULL DEFAULT '', -- [pub]
  l_denpa    text NOT NULL DEFAULT '', -- [pub]
  l_jlist    text NOT NULL DEFAULT '', -- [pub]
  l_gyutto   integer[] NOT NULL DEFAULT '{}', -- [pub]
  l_digiket  integer NOT NULL DEFAULT 0, -- [pub]
  l_melon    integer NOT NULL DEFAULT 0, -- [pub]
  l_mg       integer NOT NULL DEFAULT 0, -- [pub]
  l_getchu   integer NOT NULL DEFAULT 0, -- [pub]
  l_getchudl integer NOT NULL DEFAULT 0, -- [pub]
  l_dmm      text[] NOT NULL DEFAULT '{}', -- [pub]
  l_itch     text NOT NULL DEFAULT '', -- [pub]
  l_jastusa  text NOT NULL DEFAULT '', -- [pub]
  l_egs      integer NOT NULL DEFAULT 0, -- [pub]
  l_erotrail integer NOT NULL DEFAULT 0, -- [pub]
  l_toranoana bigint NOT NULL DEFAULT 0, -- [pub]
  l_melonjp  integer NOT NULL DEFAULT 0, -- [pub]
  l_gamejolt integer NOT NULL DEFAULT 0, -- [pub]
  l_nutaku   text NOT NULL DEFAULT '', -- [pub]
  reso_x     smallint NOT NULL DEFAULT 0, -- [pub] When reso_x is 0, reso_y is either 0 for 'unknown' or 1 for 'non-standard'.
  reso_y     smallint NOT NULL DEFAULT 0 -- [pub]
);

-- releases_hist
CREATE TABLE releases_hist (
  chid       integer NOT NULL PRIMARY KEY,
  title      varchar(300) NOT NULL DEFAULT '',
  original   varchar(250) NOT NULL DEFAULT '',
  type       release_type NOT NULL DEFAULT 'complete',
  website    varchar(250) NOT NULL DEFAULT '',
  catalog    varchar(50) NOT NULL DEFAULT '',
  gtin       bigint NOT NULL DEFAULT 0,
  released   integer NOT NULL DEFAULT 0,
  notes      text NOT NULL DEFAULT '',
  minage     smallint,
  patch      boolean NOT NULL DEFAULT FALSE,
  freeware   boolean NOT NULL DEFAULT FALSE,
  doujin     boolean NOT NULL DEFAULT FALSE,
  voiced     smallint NOT NULL DEFAULT 0,
  ani_story  smallint NOT NULL DEFAULT 0,
  ani_ero    smallint NOT NULL DEFAULT 0,
  uncensored boolean NOT NULL DEFAULT FALSE,
  engine     varchar(50) NOT NULL DEFAULT '',
  l_steam    integer NOT NULL DEFAULT 0,
  l_dlsite   text NOT NULL DEFAULT '',
  l_dlsiteen text NOT NULL DEFAULT '',
  l_gog      text NOT NULL DEFAULT '',
  l_denpa    text NOT NULL DEFAULT '',
  l_jlist    text NOT NULL DEFAULT '',
  l_gyutto   integer[] NOT NULL DEFAULT '{}',
  l_digiket  integer NOT NULL DEFAULT 0,
  l_melon    integer NOT NULL DEFAULT 0,
  l_mg       integer NOT NULL DEFAULT 0,
  l_getchu   integer NOT NULL DEFAULT 0,
  l_getchudl integer NOT NULL DEFAULT 0,
  l_dmm      text[] NOT NULL DEFAULT '{}',
  l_itch     text NOT NULL DEFAULT '',
  l_jastusa  text NOT NULL DEFAULT '',
  l_egs      integer NOT NULL DEFAULT 0,
  l_erotrail integer NOT NULL DEFAULT 0,
  l_toranoana bigint NOT NULL DEFAULT 0,
  l_melonjp  integer NOT NULL DEFAULT 0,
  l_gamejolt integer NOT NULL DEFAULT 0,
  l_nutaku   text NOT NULL DEFAULT '',
  reso_x     smallint NOT NULL DEFAULT 0,
  reso_y     smallint NOT NULL DEFAULT 0
);

-- releases_lang
CREATE TABLE releases_lang (
  id         integer NOT NULL, -- [pub]
  lang       language NOT NULL, -- [pub]
  PRIMARY KEY(id, lang)
);

-- releases_lang_hist
CREATE TABLE releases_lang_hist (
  chid       integer NOT NULL,
  lang       language NOT NULL,
  PRIMARY KEY(chid, lang)
);

-- releases_media
CREATE TABLE releases_media (
  id         integer NOT NULL, -- [pub]
  medium     medium NOT NULL, -- [pub]
  qty        smallint NOT NULL DEFAULT 1, -- [pub]
  PRIMARY KEY(id, medium, qty)
);

-- releases_media_hist
CREATE TABLE releases_media_hist (
  chid       integer NOT NULL,
  medium     medium NOT NULL,
  qty        smallint NOT NULL DEFAULT 1,
  PRIMARY KEY(chid, medium, qty)
);

-- releases_platforms
CREATE TABLE releases_platforms (
  id         integer NOT NULL, -- [pub]
  platform   platform NOT NULL, -- [pub]
  PRIMARY KEY(id, platform)
);

-- releases_platforms_hist
CREATE TABLE releases_platforms_hist (
  chid       integer NOT NULL,
  platform   platform NOT NULL,
  PRIMARY KEY(chid, platform)
);

-- releases_producers
CREATE TABLE releases_producers (
  id         integer NOT NULL, -- [pub]
  pid        integer NOT NULL, -- [pub] producers.id
  developer  boolean NOT NULL DEFAULT FALSE, -- [pub]
  publisher  boolean NOT NULL DEFAULT TRUE, -- [pub]
  CONSTRAINT releases_producers_check1 CHECK(developer OR publisher),
  PRIMARY KEY(id, pid)
);

-- releases_producers_hist
CREATE TABLE releases_producers_hist (
  chid       integer NOT NULL,
  pid        integer NOT NULL, -- producers.id
  developer  boolean NOT NULL DEFAULT FALSE,
  publisher  boolean NOT NULL DEFAULT TRUE,
  CHECK(developer OR publisher),
  PRIMARY KEY(chid, pid)
);

-- releases_vn
CREATE TABLE releases_vn (
  id         integer NOT NULL, -- [pub]
  vid        integer NOT NULL, -- [pub] vn.id
  PRIMARY KEY(id, vid)
);

-- releases_vn_hist
CREATE TABLE releases_vn_hist (
  chid       integer NOT NULL,
  vid        integer NOT NULL, -- vn.id
  PRIMARY KEY(chid, vid)
);

-- reports
CREATE TABLE reports (
  id         SERIAL PRIMARY KEY,
  date       timestamptz NOT NULL DEFAULT NOW(),
  lastmod    timestamptz,
  uid        integer, -- user who created the report, if logged in
  ip         inet, -- IP address of the visitor, if not logged in
  reason     text NOT NULL,
  status     report_status NOT NULL DEFAULT 'new',
  object     vndbid NOT NULL, -- The id of the thing being reported
  message    text NOT NULL,
  log        text NOT NULL DEFAULT '',
  objectnum  integer -- The sub-id of the thing to be reported
);

-- reviews
CREATE TABLE reviews (
  id      vndbid PRIMARY KEY DEFAULT vndbid('w', nextval('reviews_seq')::int) CONSTRAINT reviews_id_check CHECK(vndbid_type(id) = 'w'),
  vid     int NOT NULL,
  uid     int,
  rid     int,
  date    timestamptz NOT NULL DEFAULT NOW(),
  lastmod timestamptz,
  text    text,
  spoiler boolean NOT NULL,
  c_up    int NOT NULL DEFAULT 0,
  c_down  int NOT NULL DEFAULT 0,
  c_count smallint NOT NULL DEFAULT 0,
  c_lastnum smallint,
  isfull  boolean NOT NULL,
  c_flagged boolean NOT NULL DEFAULT false
);

-- reviews_posts
CREATE TABLE reviews_posts (
  id      vndbid NOT NULL,
  num     smallint NOT NULL,
  uid     integer,
  date    timestamptz NOT NULL DEFAULT NOW(),
  edited  timestamptz,
  hidden  boolean NOT NULL DEFAULT FALSE,
  msg     text NOT NULL DEFAULT '',
  PRIMARY KEY(id, num)
);

-- reviews_votes
CREATE TABLE reviews_votes (
  id      vndbid NOT NULL,
  uid     int,
  date    timestamptz NOT NULL,
  vote    boolean NOT NULL, -- true = upvote, false = downvote
  overrule boolean NOT NULL DEFAULT false
);

-- rlists
CREATE TABLE rlists (
  uid integer NOT NULL DEFAULT 0, -- [pub]
  rid integer NOT NULL DEFAULT 0, -- [pub]
  status smallint NOT NULL DEFAULT 0, -- [pub]
  added timestamptz NOT NULL DEFAULT NOW(), -- [pub]
  PRIMARY KEY(uid, rid)
);

-- sessions
CREATE TABLE sessions (
  uid     integer NOT NULL,
  token   bytea NOT NULL,
  added   timestamptz NOT NULL DEFAULT NOW(),
  expires timestamptz NOT NULL,
  type    session_type NOT NULL,
  mail    text,
  PRIMARY KEY (uid, token)
);

-- shop_denpa
CREATE TABLE shop_denpa (
  id        text NOT NULL PRIMARY KEY,
  lastfetch timestamptz,
  deadsince timestamptz,
  sku       text NOT NULL DEFAULT '',
  price     text NOT NULL DEFAULT ''
);

-- shop_dlsite
CREATE TABLE shop_dlsite (
  id        text NOT NULL PRIMARY KEY,
  lastfetch timestamptz,
  deadsince timestamptz,
  shop      text NOT NULL DEFAULT '',
  price     text NOT NULL DEFAULT ''
);

-- shop_jlist
CREATE TABLE shop_jlist (
  id        text NOT NULL PRIMARY KEY,
  lastfetch timestamptz,
  deadsince timestamptz,
  jbox      boolean NOT NULL DEFAULT false,
  price     text NOT NULL DEFAULT '' -- empty when unknown or not in stock
);

-- shop_mg
CREATE TABLE shop_mg (
  id        integer NOT NULL PRIMARY KEY,
  lastfetch timestamptz,
  deadsince timestamptz,
  r18       boolean NOT NULL DEFAULT true,
  price     text NOT NULL DEFAULT ''
);

-- shop_playasia
CREATE TABLE shop_playasia (
  pax       text NOT NULL PRIMARY KEY,
  gtin      bigint NOT NULL,
  lastfetch timestamptz,
  url       text NOT NULL DEFAULT '',
  price     text NOT NULL DEFAULT ''
);

-- shop_playasia_gtin
CREATE TABLE shop_playasia_gtin (
  gtin      bigint NOT NULL PRIMARY KEY,
  lastfetch timestamptz
);

-- staff
CREATE TABLE staff ( -- dbentry_type=s
  id         SERIAL PRIMARY KEY, -- [pub]
  locked     boolean NOT NULL DEFAULT FALSE,
  hidden     boolean NOT NULL DEFAULT FALSE,
  aid        integer NOT NULL DEFAULT 0, -- [pub] staff_alias.aid
  gender     gender NOT NULL DEFAULT 'unknown', -- [pub]
  lang       language NOT NULL DEFAULT 'ja', -- [pub]
  "desc"     text NOT NULL DEFAULT '', -- [pub]
  l_wp       varchar(150) NOT NULL DEFAULT '', -- [pub] (deprecated)
  l_site     varchar(250) NOT NULL DEFAULT '', -- [pub]
  l_twitter  varchar(16) NOT NULL DEFAULT '', -- [pub]
  l_anidb    integer, -- [pub]
  l_wikidata integer, -- [pub]
  l_pixiv    integer NOT NULL DEFAULT 0 -- [pub]
);

-- staff_hist
CREATE TABLE staff_hist (
  chid       integer NOT NULL PRIMARY KEY,
  aid        integer NOT NULL DEFAULT 0, -- Can't refer to staff_alias.id, because the alias might have been deleted
  gender     gender NOT NULL DEFAULT 'unknown',
  lang       language NOT NULL DEFAULT 'ja',
  "desc"     text NOT NULL DEFAULT '',
  l_wp       varchar(150) NOT NULL DEFAULT '',
  l_site     varchar(250) NOT NULL DEFAULT '',
  l_twitter  varchar(16) NOT NULL DEFAULT '',
  l_anidb    integer,
  l_wikidata integer,
  l_pixiv    integer NOT NULL DEFAULT 0
);

-- staff_alias
CREATE TABLE staff_alias (
  id         integer NOT NULL, -- [pub]
  aid        SERIAL PRIMARY KEY, -- [pub] Globally unique ID of this alias
  name       varchar(200) NOT NULL DEFAULT '', -- [pub]
  original   varchar(200) NOT NULL DEFAULT '' -- [pub]
);

-- staff_alias_hist
CREATE TABLE staff_alias_hist (
  chid       integer NOT NULL,
  aid        integer NOT NULL, -- staff_alias.aid, but can't reference it because the alias may have been deleted
  name       varchar(200) NOT NULL DEFAULT '',
  original   varchar(200) NOT NULL DEFAULT '',
  PRIMARY KEY(chid, aid)
);

-- stats_cache
CREATE TABLE stats_cache (
  section varchar(25) NOT NULL PRIMARY KEY,
  count integer NOT NULL DEFAULT 0
);

-- tags
CREATE TABLE tags (
  id SERIAL NOT NULL PRIMARY KEY, -- [pub]
  name varchar(250) NOT NULL UNIQUE, -- [pub]
  description text NOT NULL DEFAULT '', -- [pub]
  added timestamptz NOT NULL DEFAULT NOW(),
  state smallint NOT NULL DEFAULT 0, -- [pub]
  c_items integer NOT NULL DEFAULT 0,
  addedby integer NOT NULL DEFAULT 0,
  cat tag_category NOT NULL DEFAULT 'cont', -- [pub]
  defaultspoil smallint NOT NULL DEFAULT 0, -- [pub]
  searchable boolean NOT NULL DEFAULT TRUE, -- [pub]
  applicable boolean NOT NULL DEFAULT TRUE -- [pub]
);

-- tags_aliases
CREATE TABLE tags_aliases (
  alias varchar(250) NOT NULL PRIMARY KEY, -- [pub]
  tag integer NOT NULL -- [pub]
);

-- tags_parents
CREATE TABLE tags_parents (
  tag integer NOT NULL, -- [pub]
  parent integer NOT NULL, -- [pub]
  PRIMARY KEY(tag, parent)
);

-- tags_vn
CREATE TABLE tags_vn (
  tag integer NOT NULL, -- [pub]
  vid integer NOT NULL, -- [pub]
  uid integer, -- [pub]
  vote smallint NOT NULL DEFAULT 3 CHECK (vote >= -3 AND vote <= 3 AND vote <> 0), -- [pub]
  spoiler smallint CHECK(spoiler >= 0 AND spoiler <= 2), -- [pub]
  date timestamptz NOT NULL DEFAULT NOW(), -- [pub]
  ignore boolean NOT NULL DEFAULT false, -- [pub]
  notes text NOT NULL DEFAULT '' -- [pub]
);

-- tags_vn_inherit
CREATE TABLE tags_vn_inherit (
  tag integer NOT NULL,
  vid integer NOT NULL,
  rating real NOT NULL,
  spoiler smallint NOT NULL
);

-- threads
CREATE TABLE threads (
  id vndbid PRIMARY KEY DEFAULT vndbid('t', nextval('threads_id_seq')::int) CONSTRAINT threads_id_check CHECK(vndbid_type(id) = 't'),
  title varchar(50) NOT NULL DEFAULT '',
  locked boolean NOT NULL DEFAULT FALSE,
  hidden boolean NOT NULL DEFAULT FALSE,
  poll_question varchar(100),
  poll_max_options smallint NOT NULL DEFAULT 1,
  poll_preview boolean NOT NULL DEFAULT FALSE, -- deprecated
  poll_recast boolean NOT NULL DEFAULT FALSE, -- deprecated
  private boolean NOT NULL DEFAULT FALSE,
  c_count smallint NOT NULL DEFAULT 0, -- Number of non-hidden posts
  c_lastnum smallint NOT NULL DEFAULT 1 -- 'num' of the most recent non-hidden post
);

-- threads_poll_options
CREATE TABLE threads_poll_options (
  id     SERIAL PRIMARY KEY,
  tid    vndbid NOT NULL,
  option varchar(100) NOT NULL
);

-- threads_poll_votes
CREATE TABLE threads_poll_votes (
  uid   integer NOT NULL,
  optid integer NOT NULL,
  date  timestamptz DEFAULT NOW(),
  PRIMARY KEY (optid, uid)
);

-- threads_posts
CREATE TABLE threads_posts (
  tid vndbid NOT NULL,
  num smallint NOT NULL,
  uid integer,
  date timestamptz NOT NULL DEFAULT NOW(),
  edited timestamptz,
  hidden boolean NOT NULL DEFAULT FALSE,
  msg text NOT NULL DEFAULT '',
  PRIMARY KEY(tid, num),
  CONSTRAINT threads_posts_first_nonhidden CHECK(num > 1 OR NOT hidden)
);

-- threads_boards
CREATE TABLE threads_boards (
  tid vndbid NOT NULL,
  type board_type NOT NULL,
  iid integer NOT NULL DEFAULT 0,
  PRIMARY KEY(tid, type, iid)
);

-- trace_log
CREATE TABLE trace_log (
  date      timestamptz NOT NULL DEFAULT NOW(),
  method    text NOT NULL,
  path      text NOT NULL,
  query     text NOT NULL DEFAULT '',
  module    text,
  line      integer,
  sql_num   integer,
  sql_time  float,
  perl_time float,
  has_txn   boolean,
  loggedin  boolean,
  elm_mods  text[]
);

-- traits
CREATE TABLE traits (
  id SERIAL PRIMARY KEY, -- [pub]
  name varchar(250) NOT NULL, -- [pub]
  alias varchar(500) NOT NULL DEFAULT '', -- [pub]
  description text NOT NULL DEFAULT '', -- [pub]
  added timestamptz NOT NULL DEFAULT NOW(),
  state smallint NOT NULL DEFAULT 0, -- [pub]
  addedby integer NOT NULL DEFAULT 0,
  "group" integer, -- [pub]
  "order" smallint NOT NULL DEFAULT 0, -- [pub]
  sexual boolean NOT NULL DEFAULT false, -- [pub]
  c_items integer NOT NULL DEFAULT 0,
  defaultspoil smallint NOT NULL DEFAULT 0, -- [pub]
  searchable boolean NOT NULL DEFAULT true, -- [pub]
  applicable boolean NOT NULL DEFAULT true -- [pub]
);

-- traits_chars
-- This table is a cache for the data in chars_traits and includes child traits
-- into parent traits. In order to improve performance, there are no foreign
-- key constraints on this table.
CREATE TABLE traits_chars (
  cid integer NOT NULL,  -- chars (id)
  tid integer NOT NULL,  -- traits (id)
  spoil smallint NOT NULL DEFAULT 0
);

-- traits_parents
CREATE TABLE traits_parents (
  trait integer NOT NULL, -- [pub]
  parent integer NOT NULL, -- [pub]
  PRIMARY KEY(trait, parent)
);

-- ulist_labels
CREATE TABLE ulist_labels (
  uid      integer NOT NULL, -- [pub] user.id
  id       integer NOT NULL, -- [pub] 0 < builtin < 10 <= custom, ids are reused
  label    text NOT NULL, -- [pub]
  private  boolean NOT NULL,
  PRIMARY KEY(uid, id)
);

-- ulist_vns
CREATE TABLE ulist_vns (
  uid       integer NOT NULL, -- [pub] users.id
  vid       integer NOT NULL, -- [pub] vn.id
  added     timestamptz NOT NULL DEFAULT NOW(), -- [pub]
  lastmod   timestamptz NOT NULL DEFAULT NOW(), -- [pub] updated when anything in this row has changed?
  vote_date timestamptz, -- [pub] Used for "recent votes" - also updated when vote has changed?
  vote      smallint CHECK(vote IS NULL OR vote BETWEEN 10 AND 100), -- [pub]
  started   date, -- [pub]
  finished  date, -- [pub]
  notes     text NOT NULL DEFAULT '', -- [pub]
  PRIMARY KEY(uid, vid)
);

-- ulist_vns_labels
CREATE TABLE ulist_vns_labels (
  uid integer NOT NULL, -- [pub] user.id
  lbl integer NOT NULL, -- [pub]
  vid integer NOT NULL, -- [pub] vn.id
  PRIMARY KEY(uid, lbl, vid)
);

-- users
CREATE TABLE users (
  id         SERIAL NOT NULL PRIMARY KEY, -- [pub]
  username   varchar(20) NOT NULL UNIQUE, -- [pub]
  mail       varchar(100) NOT NULL,
  -- A valid passwd column is 46 bytes:
  --   4 bytes: N (big endian)
  --   1 byte: r
  --   1 byte: p
  --   8 bytes: salt
  --   32 bytes: scrypt(passwd, global_salt + salt, N, r, p, 32)
  -- Anything else is invalid, account disabled.
  passwd          bytea NOT NULL DEFAULT '',
  registered      timestamptz NOT NULL DEFAULT NOW(),
  c_votes         integer NOT NULL DEFAULT 0,
  c_changes       integer NOT NULL DEFAULT 0,
  ip              inet NOT NULL DEFAULT '0.0.0.0',
  c_tags          integer NOT NULL DEFAULT 0,
  ign_votes       boolean NOT NULL DEFAULT FALSE, -- [pub]
  email_confirmed boolean NOT NULL DEFAULT FALSE,
  skin            text NOT NULL DEFAULT '',
  customcss       text NOT NULL DEFAULT '',
  filter_vn       text NOT NULL DEFAULT '',
  filter_release  text NOT NULL DEFAULT '',
  show_nsfw       boolean NOT NULL DEFAULT FALSE, -- Not used anymore, replaced by max_sexual and max_violence
  notify_dbedit   boolean NOT NULL DEFAULT TRUE,
  notify_announce boolean NOT NULL DEFAULT FALSE,
  vn_list_own     boolean NOT NULL DEFAULT FALSE,
  vn_list_wish    boolean NOT NULL DEFAULT FALSE, -- Not used anymore, wishlist column in the VN list view has been removed
  tags_all        boolean NOT NULL DEFAULT FALSE,
  tags_cont       boolean NOT NULL DEFAULT TRUE,
  tags_ero        boolean NOT NULL DEFAULT FALSE,
  tags_tech       boolean NOT NULL DEFAULT TRUE,
  spoilers        smallint NOT NULL DEFAULT 0,
  traits_sexual   boolean NOT NULL DEFAULT FALSE,
  nodistract_can     boolean NOT NULL DEFAULT FALSE,
  nodistract_noads   boolean NOT NULL DEFAULT FALSE,
  nodistract_nofancy boolean NOT NULL DEFAULT FALSE,
  support_can     boolean NOT NULL DEFAULT FALSE,
  support_enabled boolean NOT NULL DEFAULT FALSE,
  uniname_can     boolean NOT NULL DEFAULT FALSE,
  uniname         text NOT NULL DEFAULT '',
  pubskin_can     boolean NOT NULL DEFAULT FALSE,
  pubskin_enabled boolean NOT NULL DEFAULT FALSE,
  c_vns           integer NOT NULL DEFAULT 0,
  c_wish          integer NOT NULL DEFAULT 0,
  ulist_votes     jsonb,
  ulist_vnlist    jsonb,
  ulist_wish      jsonb,
  c_imgvotes      integer NOT NULL DEFAULT 0,
  perm_board      boolean NOT NULL DEFAULT true,
  perm_boardmod   boolean NOT NULL DEFAULT false,
  perm_dbmod      boolean NOT NULL DEFAULT false,
  perm_edit       boolean NOT NULL DEFAULT true,
  perm_imgvote    boolean NOT NULL DEFAULT true, -- [pub] (public because this is used in calculating image flagging scores)
  perm_tag        boolean NOT NULL DEFAULT true, -- [pub] (public because this is used in calculating VN tag scores)
  perm_tagmod     boolean NOT NULL DEFAULT false,
  perm_usermod    boolean NOT NULL DEFAULT false,
  perm_imgmod     boolean NOT NULL DEFAULT false,
  max_sexual      smallint NOT NULL DEFAULT 0,
  max_violence    smallint NOT NULL DEFAULT 0,
  last_reports    timestamptz, -- For mods: Most recent activity seen on the reports listing
  perm_review     boolean NOT NULL DEFAULT false, -- TODO: DEFAULT true when out of beta.
  notify_post     boolean NOT NULL DEFAULT true,
  notify_comment  boolean NOT NULL DEFAULT true
);

-- vn
CREATE TABLE vn ( -- dbentry_type=v
  id         SERIAL PRIMARY KEY, -- [pub]
  locked     boolean NOT NULL DEFAULT FALSE,
  hidden     boolean NOT NULL DEFAULT FALSE,
  title      varchar(250) NOT NULL DEFAULT '', -- [pub]
  original   varchar(250) NOT NULL DEFAULT '', -- [pub]
  alias      varchar(500) NOT NULL DEFAULT '', -- [pub]
  length     smallint NOT NULL DEFAULT 0, -- [pub]
  img_nsfw   boolean NOT NULL DEFAULT FALSE, -- (deprecated)
  image      vndbid CONSTRAINT vn_image_check CHECK(vndbid_type(image) = 'cv'), -- [pub]
  "desc"     text NOT NULL DEFAULT '', -- [pub]
  l_wp       varchar(150) NOT NULL DEFAULT '', -- [pub] (deprecated)
  l_encubed  varchar(100) NOT NULL DEFAULT '', -- [pub] (deprecated)
  l_renai    varchar(100) NOT NULL DEFAULT '', -- [pub]
  c_released integer NOT NULL DEFAULT 0,
  c_languages language[] NOT NULL DEFAULT '{}',
  c_olang    language[] NOT NULL DEFAULT '{}',
  c_platforms platform[] NOT NULL DEFAULT '{}',
  c_popularity real, -- [pub]
  c_rating   real, -- [pub]
  c_votecount integer NOT NULL DEFAULT 0, -- [pub]
  c_search   text,
  l_wikidata integer, -- [pub]
  c_pop_rank integer,
  c_rat_rank integer
);

-- vn_hist
CREATE TABLE vn_hist (
  chid       integer NOT NULL PRIMARY KEY,
  title      varchar(250) NOT NULL DEFAULT '',
  original   varchar(250) NOT NULL DEFAULT '',
  alias      varchar(500) NOT NULL DEFAULT '',
  length     smallint NOT NULL DEFAULT 0,
  img_nsfw   boolean NOT NULL DEFAULT FALSE,
  image      vndbid CONSTRAINT vn_hist_image_check CHECK(vndbid_type(image) = 'cv'),
  "desc"     text NOT NULL DEFAULT '',
  l_wp       varchar(150) NOT NULL DEFAULT '',
  l_encubed  varchar(100) NOT NULL DEFAULT '',
  l_renai    varchar(100) NOT NULL DEFAULT '',
  l_wikidata integer
);

-- vn_anime
CREATE TABLE vn_anime (
  id         integer NOT NULL, -- [pub]
  aid        integer NOT NULL, -- [pub] anime.id
  PRIMARY KEY(id, aid)
);

-- vn_anime_hist
CREATE TABLE vn_anime_hist (
  chid       integer NOT NULL,
  aid        integer NOT NULL, -- anime.id
  PRIMARY KEY(chid, aid)
);

-- vn_relations
CREATE TABLE vn_relations (
  id         integer NOT NULL, -- [pub]
  vid        integer NOT NULL, -- [pub] vn.id
  relation   vn_relation NOT NULL, -- [pub]
  official   boolean NOT NULL DEFAULT TRUE, -- [pub]
  PRIMARY KEY(id, vid)
);

-- vn_relations_hist
CREATE TABLE vn_relations_hist (
  chid       integer NOT NULL,
  vid        integer NOT NULL, -- vn.id
  relation   vn_relation NOT NULL,
  official   boolean NOT NULL DEFAULT TRUE,
  PRIMARY KEY(chid, vid)
);

-- vn_screenshots
CREATE TABLE vn_screenshots (
  id         integer NOT NULL, -- [pub]
  scr        vndbid NOT NULL CONSTRAINT vn_screenshots_scr_check CHECK(vndbid_type(scr) = 'sf'), -- [pub] images.id
  rid        integer,          -- [pub] releases.id (only NULL for old revisions, nowadays not allowed anymore)
  nsfw       boolean NOT NULL DEFAULT FALSE, -- (deprecated)
  PRIMARY KEY(id, scr)
);

-- vn_screenshots_hist
CREATE TABLE vn_screenshots_hist (
  chid       integer NOT NULL,
  scr        vndbid NOT NULL CONSTRAINT vn_screenshots_hist_scr_check CHECK(vndbid_type(scr) = 'sf'),
  rid        integer,
  nsfw       boolean NOT NULL DEFAULT FALSE,
  PRIMARY KEY(chid, scr)
);

-- vn_seiyuu
CREATE TABLE vn_seiyuu (
  id         integer NOT NULL, -- [pub]
  aid        integer NOT NULL, -- [pub] staff_alias.aid
  cid        integer NOT NULL, -- [pub] chars.id
  note       varchar(250) NOT NULL DEFAULT '', -- [pub]
  PRIMARY KEY (id, aid, cid)
);

-- vn_seiyuu_hist
CREATE TABLE vn_seiyuu_hist (
  chid       integer NOT NULL,
  aid        integer NOT NULL, -- staff_alias.aid, but can't reference it because the alias may have been deleted
  cid        integer NOT NULL, -- chars.id
  note       varchar(250) NOT NULL DEFAULT '',
  PRIMARY KEY (chid, aid, cid)
);

-- vn_staff
CREATE TABLE vn_staff (
  id         integer NOT NULL, -- [pub]
  aid        integer NOT NULL, -- [pub] staff_alias.aid
  role       credit_type NOT NULL DEFAULT 'staff', -- [pub]
  note       varchar(250) NOT NULL DEFAULT '', -- [pub]
  PRIMARY KEY (id, aid, role)
);

-- vn_staff_hist
CREATE TABLE vn_staff_hist (
  chid       integer NOT NULL,
  aid        integer NOT NULL, -- See note at vn_seiyuu_hist.aid
  role       credit_type NOT NULL DEFAULT 'staff',
  note       varchar(250) NOT NULL DEFAULT '',
  PRIMARY KEY (chid, aid, role)
);

-- wikidata
CREATE TABLE wikidata (
  id                 integer NOT NULL PRIMARY KEY, -- [pub]
  lastfetch          timestamptz,
  enwiki             text,      -- [pub]
  jawiki             text,      -- [pub]
  website            text[],    -- [pub] P856
  vndb               text[],    -- [pub] P3180
  mobygames          text[],    -- [pub] P1933
  mobygames_company  text[],    -- [pub] P4773
  gamefaqs_game      integer[], -- [pub] P4769
  gamefaqs_company   integer[], -- [pub] P6182
  anidb_anime        integer[], -- [pub] P5646
  anidb_person       integer[], -- [pub] P5649
  ann_anime          integer[], -- [pub] P1985
  ann_manga          integer[], -- [pub] P1984
  musicbrainz_artist uuid[],    -- [pub] P434
  twitter            text[],    -- [pub] P2002
  vgmdb_product      integer[], -- [pub] P5659
  vgmdb_artist       integer[], -- [pub] P3435
  discogs_artist     integer[], -- [pub] P1953
  acdb_char          integer[], -- [pub] P7013
  acdb_source        integer[], -- [pub] P7017
  indiedb_game       text[],    -- [pub] P6717
  howlongtobeat      integer[], -- [pub] P2816
  crunchyroll        text[],    -- [pub] P4110
  igdb_game          text[],    -- [pub] P5794
  giantbomb          text[],    -- [pub] P5247
  pcgamingwiki       text[],    -- [pub] P6337
  steam              integer[], -- [pub] P1733
  gog                text[],    -- [pub] P2725
  pixiv_user         integer[], -- [pub] P5435
  doujinshi_author   integer[]  -- [pub] P7511
);
