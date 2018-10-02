CREATE TYPE resolution AS ENUM ('unknown', 'nonstandard', '640x480', '800x600', '1024x768', '1280x960', '1600x1200', '640x400', '960x600', '1024x576', '1024x600', '1024x640', '1280x720', '1280x800', '1366x768', '1600x900', '1920x1080');

CREATE OR REPLACE FUNCTION conv_resolution(integer) RETURNS resolution AS $$
SELECT CASE
  WHEN $1 =  0 THEN 'unknown'::resolution
  WHEN $1 =  1 THEN 'nonstandard'
  WHEN $1 =  2 THEN '640x480'
  WHEN $1 =  3 THEN '800x600'
  WHEN $1 =  4 THEN '1024x768'
  WHEN $1 =  5 THEN '1280x960'
  WHEN $1 =  6 THEN '1600x1200'
  WHEN $1 =  7 THEN '640x400'
  WHEN $1 =  8 THEN '960x600'
  WHEN $1 =  9 THEN '1024x576'
  WHEN $1 = 10 THEN '1024x600'
  WHEN $1 = 11 THEN '1024x640'
  WHEN $1 = 12 THEN '1280x720'
  WHEN $1 = 13 THEN '1280x800'
  WHEN $1 = 14 THEN '1366x768'
  WHEN $1 = 15 THEN '1600x900'
  WHEN $1 = 16 THEN '1920x1080'
END $$ LANGUAGE SQL;

ALTER TABLE releases ALTER COLUMN resolution DROP DEFAULT;
ALTER TABLE releases ALTER COLUMN resolution TYPE resolution USING conv_resolution(resolution);
ALTER TABLE releases ALTER COLUMN resolution SET DEFAULT 'unknown';

ALTER TABLE releases_hist ALTER COLUMN resolution DROP DEFAULT;
ALTER TABLE releases_hist ALTER COLUMN resolution TYPE resolution USING conv_resolution(resolution);
ALTER TABLE releases_hist ALTER COLUMN resolution SET DEFAULT 'unknown';

DROP FUNCTION conv_resolution(int);
