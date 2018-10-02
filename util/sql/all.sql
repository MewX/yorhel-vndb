-- NOTE: Make sure you're cd'ed in the vndb root directory before running this script


-- data types

CREATE TYPE anime_type        AS ENUM ('tv', 'ova', 'mov', 'oth', 'web', 'spe', 'mv');
CREATE TYPE blood_type        AS ENUM ('unknown', 'a', 'b', 'ab', 'o');
CREATE TYPE board_type        AS ENUM ('an', 'db', 'ge', 'v', 'p', 'u');
CREATE TYPE char_role         AS ENUM ('main', 'primary', 'side', 'appears');
CREATE TYPE credit_type       AS ENUM ('scenario', 'chardesign', 'art', 'music', 'songs', 'director', 'staff');
CREATE TYPE dbentry_type      AS ENUM ('v', 'r', 'p', 'c', 's', 'd');
CREATE TYPE edit_rettype      AS (itemid integer, chid integer, rev integer);
CREATE TYPE gender            AS ENUM ('unknown', 'm', 'f', 'b');
CREATE TYPE language          AS ENUM ('ar', 'bg', 'ca', 'cs', 'da', 'de', 'en', 'es', 'fi', 'fr', 'he', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'nl', 'no', 'pl', 'pt-pt', 'pt-br', 'ro', 'ru', 'sk', 'sv', 'ta', 'th', 'tr', 'uk', 'vi', 'zh');
CREATE TYPE medium            AS ENUM ('cd', 'dvd', 'gdr', 'blr', 'flp', 'mrt', 'mem', 'umd', 'nod', 'in', 'otc');
CREATE TYPE notification_ntype AS ENUM ('pm', 'dbdel', 'listdel', 'dbedit', 'announce');
CREATE TYPE notification_ltype AS ENUM ('v', 'r', 'p', 'c', 't', 's', 'd');
CREATE TYPE platform          AS ENUM ('win', 'dos', 'lin', 'mac', 'ios', 'and', 'dvd', 'bdp', 'fmt', 'gba', 'gbc', 'msx', 'nds', 'nes', 'p88', 'p98', 'pce', 'pcf', 'psp', 'ps1', 'ps2', 'ps3', 'ps4', 'psv', 'drc', 'sat', 'sfc', 'swi', 'wii', 'wiu', 'n3d', 'x68', 'xb1', 'xb3', 'xbo', 'web', 'oth');
CREATE TYPE prefs_key         AS ENUM ('l10n', 'skin', 'customcss', 'filter_vn', 'filter_release', 'show_nsfw', 'hide_list', 'notify_nodbedit', 'notify_announce', 'vn_list_own', 'vn_list_wish', 'tags_all', 'tags_cat', 'spoilers', 'traits_sexual');
CREATE TYPE producer_type     AS ENUM ('co', 'in', 'ng');
CREATE TYPE producer_relation AS ENUM ('old', 'new', 'sub', 'par', 'imp', 'ipa', 'spa', 'ori');
CREATE TYPE release_type      AS ENUM ('complete', 'partial', 'trial');
CREATE TYPE tag_category      AS ENUM('cont', 'ero', 'tech');
CREATE TYPE vn_relation       AS ENUM ('seq', 'preq', 'set', 'alt', 'char', 'side', 'par', 'ser', 'fan', 'orig');
CREATE TYPE resolution        AS ENUM ('unknown', 'nonstandard', '640x480', '800x600', '1024x768', '1280x960', '1600x1200', '640x400', '960x600', '1024x576', '1024x600', '1024x640', '1280x720', '1280x800', '1366x768', '1600x900', '1920x1080');


-- schema

\i util/sql/schema.sql


-- functions

\i util/sql/func.sql

-- auto-generated editing functions

\i util/sql/editfunc.sql

-- constraints & indices

\i util/sql/tableattrs.sql

-- triggers

\i util/sql/triggers.sql

-- Sequences used for ID generation of items not in the DB
CREATE SEQUENCE covers_seq;
CREATE SEQUENCE charimg_seq;

-- permissions

\i util/sql/perms.sql


-- Rows that are assumed to be available

\i util/sql/data.sql
