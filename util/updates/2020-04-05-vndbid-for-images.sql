-- Make sure to import sql/vndbid.sql before running this script.

ALTER TABLE chars                    DROP CONSTRAINT chars_image_fkey;
ALTER TABLE chars_hist               DROP CONSTRAINT chars_hist_image_fkey;
ALTER TABLE image_votes              DROP CONSTRAINT image_votes_id_fkey;
ALTER TABLE vn                       DROP CONSTRAINT vn_image_fkey;
ALTER TABLE vn_hist                  DROP CONSTRAINT vn_hist_image_fkey;
ALTER TABLE vn_screenshots           DROP CONSTRAINT vn_screenshots_scr_fkey;
ALTER TABLE vn_screenshots_hist      DROP CONSTRAINT vn_screenshots_hist_scr_fkey;

ALTER TABLE chars                    DROP CONSTRAINT chars_image_check;
ALTER TABLE chars_hist               DROP CONSTRAINT chars_hist_image_check;
ALTER TABLE images                   DROP CONSTRAINT images_id_check;
ALTER TABLE vn                       DROP CONSTRAINT vn_image_check;
ALTER TABLE vn_hist                  DROP CONSTRAINT vn_hist_image_check;
ALTER TABLE vn_screenshots           DROP CONSTRAINT vn_screenshots_scr_check;
ALTER TABLE vn_screenshots_hist      DROP CONSTRAINT vn_screenshots_hist_scr_check;

ALTER TABLE chars                    ALTER COLUMN image TYPE vndbid USING vndbid((image).itype::text, (image).id);
ALTER TABLE chars_hist               ALTER COLUMN image TYPE vndbid USING vndbid((image).itype::text, (image).id);
ALTER TABLE images                   ALTER COLUMN id    TYPE vndbid USING vndbid((id).itype::text, (id).id);
ALTER TABLE image_votes              ALTER COLUMN id    TYPE vndbid USING vndbid((id).itype::text, (id).id);
ALTER TABLE vn                       ALTER COLUMN image TYPE vndbid USING vndbid((image).itype::text, (image).id);
ALTER TABLE vn_hist                  ALTER COLUMN image TYPE vndbid USING vndbid((image).itype::text, (image).id);
ALTER TABLE vn_screenshots           ALTER COLUMN scr   TYPE vndbid USING vndbid((scr).itype::text, (scr).id);
ALTER TABLE vn_screenshots_hist      ALTER COLUMN scr   TYPE vndbid USING vndbid((scr).itype::text, (scr).id);

ALTER TABLE chars                    ADD CONSTRAINT chars_image_check             CHECK(vndbid_type(image) = 'ch');
ALTER TABLE chars_hist               ADD CONSTRAINT chars_hist_image_check        CHECK(vndbid_type(image) = 'ch');
ALTER TABLE images                   ADD CONSTRAINT images_id_check               CHECK(vndbid_type(id) IN('ch', 'cv', 'sf'));
ALTER TABLE vn                       ADD CONSTRAINT vn_image_check                CHECK(vndbid_type(image) = 'cv');
ALTER TABLE vn_hist                  ADD CONSTRAINT vn_hist_image_check           CHECK(vndbid_type(image) = 'cv');
ALTER TABLE vn_screenshots           ADD CONSTRAINT vn_screenshots_scr_check      CHECK(vndbid_type(scr) = 'sf');
ALTER TABLE vn_screenshots_hist      ADD CONSTRAINT vn_screenshots_hist_scr_check CHECK(vndbid_type(scr) = 'sf');

ALTER TABLE chars                    ADD CONSTRAINT chars_image_fkey                   FOREIGN KEY (image)     REFERENCES images        (id);
ALTER TABLE chars_hist               ADD CONSTRAINT chars_hist_image_fkey              FOREIGN KEY (image)     REFERENCES images        (id);
ALTER TABLE image_votes              ADD CONSTRAINT image_votes_id_fkey                FOREIGN KEY (id)        REFERENCES images        (id) ON DELETE CASCADE;
ALTER TABLE vn                       ADD CONSTRAINT vn_image_fkey                      FOREIGN KEY (image)     REFERENCES images        (id);
ALTER TABLE vn_hist                  ADD CONSTRAINT vn_hist_image_fkey                 FOREIGN KEY (image)     REFERENCES images        (id);
ALTER TABLE vn_screenshots           ADD CONSTRAINT vn_screenshots_scr_fkey            FOREIGN KEY (scr)       REFERENCES images        (id);
ALTER TABLE vn_screenshots_hist      ADD CONSTRAINT vn_screenshots_hist_scr_fkey       FOREIGN KEY (scr)       REFERENCES images        (id);

DROP FUNCTION update_images_cache(image_id);

\i sql/func.sql

DROP TYPE image_id;
DROP TYPE image_type;

ANALYZE images, image_votes;
