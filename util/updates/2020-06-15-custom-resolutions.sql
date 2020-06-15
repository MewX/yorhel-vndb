ALTER TABLE releases      ADD COLUMN reso_x smallint NOT NULL DEFAULT 0;
ALTER TABLE releases      ADD COLUMN reso_y smallint NOT NULL DEFAULT 0;
ALTER TABLE releases_hist ADD COLUMN reso_x smallint NOT NULL DEFAULT 0;
ALTER TABLE releases_hist ADD COLUMN reso_y smallint NOT NULL DEFAULT 0;

CREATE FUNCTION tmp_convert_resolution(resolution) RETURNS TABLE (x smallint, y smallint) AS $$
  SELECT a[1], a[2] FROM (SELECT CASE
       WHEN $1 = 'nonstandard' THEN '{0,1}'::smallint[]
       WHEN $1 = '640x480'     THEN '{640,480}'
       WHEN $1 = '800x600'     THEN '{800,600}'
       WHEN $1 = '1024x768'    THEN '{1024,768}'
       WHEN $1 = '1280x960'    THEN '{1280,960}'
       WHEN $1 = '1600x1200'   THEN '{1600,1200}'
       WHEN $1 = '640x400'     THEN '{640,400}'
       WHEN $1 = '960x600'     THEN '{960,600}'
       WHEN $1 = '960x640'     THEN '{960,640}'
       WHEN $1 = '1024x576'    THEN '{1024,576}'
       WHEN $1 = '1024x600'    THEN '{1024,600}'
       WHEN $1 = '1024x640'    THEN '{1024,640}'
       WHEN $1 = '1280x720'    THEN '{1280,720}'
       WHEN $1 = '1280x800'    THEN '{1280,800}'
       WHEN $1 = '1366x768'    THEN '{1366,768}'
       WHEN $1 = '1600x900'    THEN '{1600,900}'
       WHEN $1 = '1920x1080'   THEN '{1920,1080}'
       ELSE '{0,0}' END
  ) a(a)
$$ LANGUAGE SQL;

UPDATE releases      SET (reso_x, reso_y) = (SELECT * FROM tmp_convert_resolution(resolution));
UPDATE releases_hist SET (reso_x, reso_y) = (SELECT * FROM tmp_convert_resolution(resolution));

DROP FUNCTION tmp_convert_resolution(resolution);

ALTER TABLE releases      DROP COLUMN resolution;
ALTER TABLE releases_hist DROP COLUMN resolution;

\i sql/editfunc.sql

DROP TYPE resolution;
