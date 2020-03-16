CREATE TYPE image_type AS ENUM ('ch', 'cv', 'sf');
CREATE TYPE image_id AS (itype image_type, id int);

CREATE TABLE images (
  id       image_id NOT NULL PRIMARY KEY CHECK((id).id IS NOT NULL AND (id).itype IS NOT NULL),
  width    smallint, -- dimensions are only set for the 'sf' type (for now)
  height   smallint
);

BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

INSERT INTO images (id, width, height)
   SELECT ROW('sf', id)::image_id, width, height FROM screenshots
UNION ALL
   SELECT ROW('cv', image)::image_id, null, null FROM vn_hist WHERE image <> 0 GROUP BY image
UNION ALL
   SELECT ROW('ch', image)::image_id, null, null FROM chars_hist WHERE image <> 0 GROUP BY image;


ALTER TABLE vn      ALTER COLUMN image DROP NOT NULL;
ALTER TABLE vn      ALTER COLUMN image DROP DEFAULT;
ALTER TABLE vn      ALTER COLUMN image TYPE image_id USING CASE WHEN image = 0 THEN NULL ELSE ROW('cv', image)::image_id END;
ALTER TABLE vn      ADD CONSTRAINT vn_image_fkey      FOREIGN KEY (image) REFERENCES images (id);
ALTER TABLE vn      ADD CONSTRAINT vn_image_check CHECK((image).itype = 'cv');
ALTER TABLE vn_hist ALTER COLUMN image DROP NOT NULL;
ALTER TABLE vn_hist ALTER COLUMN image DROP DEFAULT;
ALTER TABLE vn_hist ALTER COLUMN image TYPE image_id USING CASE WHEN image = 0 THEN NULL ELSE ROW('cv', image)::image_id END;
ALTER TABLE vn_hist ADD CONSTRAINT vn_hist_image_fkey      FOREIGN KEY (image) REFERENCES images (id);
ALTER TABLE vn_hist ADD CONSTRAINT vn_hist_image_check CHECK((image).itype = 'cv');

ALTER TABLE vn_screenshots      DROP CONSTRAINT vn_screenshots_scr_fkey;
ALTER TABLE vn_screenshots      ALTER COLUMN scr TYPE image_id USING CASE WHEN scr = 0 THEN NULL ELSE ROW('sf', scr)::image_id END;
ALTER TABLE vn_screenshots      ADD CONSTRAINT vn_screenshots_scr_fkey      FOREIGN KEY (scr) REFERENCES images (id);
ALTER TABLE vn_screenshots      ADD CONSTRAINT vn_screenshots_scr_check CHECK((scr).itype = 'sf');
ALTER TABLE vn_screenshots_hist DROP CONSTRAINT vn_screenshots_hist_scr_fkey;
ALTER TABLE vn_screenshots_hist ALTER COLUMN scr TYPE image_id USING CASE WHEN scr = 0 THEN NULL ELSE ROW('sf', scr)::image_id END;
ALTER TABLE vn_screenshots_hist ADD CONSTRAINT vn_screenshots_hist_scr_fkey      FOREIGN KEY (scr) REFERENCES images (id);
ALTER TABLE vn_screenshots_hist ADD CONSTRAINT vn_screenshots_hist_scr_check CHECK((scr).itype = 'sf');

ALTER TABLE chars      ALTER COLUMN image DROP NOT NULL;
ALTER TABLE chars      ALTER COLUMN image DROP DEFAULT;
ALTER TABLE chars      ALTER COLUMN image TYPE image_id USING CASE WHEN image = 0 THEN NULL ELSE ROW('ch', image)::image_id END;
ALTER TABLE chars      ADD CONSTRAINT chars_image_fkey      FOREIGN KEY (image) REFERENCES images (id);
ALTER TABLE chars      ADD CONSTRAINT chars_image_check CHECK((image).itype = 'ch');
ALTER TABLE chars_hist ALTER COLUMN image DROP NOT NULL;
ALTER TABLE chars_hist ALTER COLUMN image DROP DEFAULT;
ALTER TABLE chars_hist ALTER COLUMN image TYPE image_id USING CASE WHEN image = 0 THEN NULL ELSE ROW('ch', image)::image_id END;
ALTER TABLE chars_hist ADD CONSTRAINT chars_hist_image_fkey      FOREIGN KEY (image) REFERENCES images (id);
ALTER TABLE chars_hist ADD CONSTRAINT chars_hist_image_check CHECK((image).itype = 'ch');

COMMIT;

CREATE SEQUENCE screenshots_seq;
SELECT setval('screenshots_seq', nextval('screenshots_id_seq'));
DROP TABLE screenshots;

\i util/sql/perms.sql
