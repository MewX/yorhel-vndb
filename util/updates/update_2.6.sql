

-- The anime table:
--  - use timestamp data type for anime.lastfetch
--  - allow NULL for all columns except id
ALTER TABLE anime ALTER COLUMN lastfetch DROP NOT NULL;
ALTER TABLE anime ALTER COLUMN lastfetch DROP DEFAULT;
UPDATE anime SET lastfetch = NULL WHERE lastfetch <= 0;
ALTER TABLE anime ALTER COLUMN lastfetch TYPE timestamp USING timestamp 'epoch' + lastfetch * interval '1 second';

ALTER TABLE anime ALTER COLUMN ann_id DROP NOT NULL;
ALTER TABLE anime ALTER COLUMN ann_id DROP DEFAULT;
UPDATE anime SET ann_id = NULL WHERE ann_id = 0;

ALTER TABLE anime ALTER COLUMN nfo_id DROP NOT NULL;
ALTER TABLE anime ALTER COLUMN nfo_id DROP DEFAULT;
UPDATE anime SET nfo_id = NULL WHERE nfo_id = '';

ALTER TABLE anime ALTER COLUMN title_kanji DROP NOT NULL;
ALTER TABLE anime ALTER COLUMN title_kanji DROP DEFAULT;
UPDATE anime SET title_kanji = NULL WHERE title_kanji = '';

ALTER TABLE anime ALTER COLUMN title_romaji DROP NOT NULL;
ALTER TABLE anime ALTER COLUMN title_romaji DROP DEFAULT;
UPDATE anime SET title_romaji = NULL WHERE title_romaji = '';

ALTER TABLE anime ALTER COLUMN type DROP NOT NULL;
ALTER TABLE anime ALTER COLUMN type DROP DEFAULT;
UPDATE anime SET type = NULL WHERE type = 0;
UPDATE anime SET type = type-1;

ALTER TABLE anime ALTER COLUMN year DROP NOT NULL;
ALTER TABLE anime ALTER COLUMN year DROP DEFAULT;
UPDATE anime SET year = NULL WHERE year = 0;

