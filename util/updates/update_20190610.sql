ALTER TABLE chars_hist               DROP CONSTRAINT chars_hist_chid_fkey             ;
ALTER TABLE chars_traits_hist        DROP CONSTRAINT chars_traits_hist_chid_fkey      ;
ALTER TABLE chars_vns_hist           DROP CONSTRAINT chars_vns_hist_chid_fkey         ;
ALTER TABLE producers_hist           DROP CONSTRAINT producers_chid_id_fkey           ;
ALTER TABLE producers_relations_hist DROP CONSTRAINT producers_relations_hist_id_fkey ;
ALTER TABLE releases_hist            DROP CONSTRAINT releases_hist_chid_fkey          ;
ALTER TABLE releases_lang_hist       DROP CONSTRAINT releases_lang_hist_chid_fkey     ;
ALTER TABLE releases_media_hist      DROP CONSTRAINT releases_media_hist_chid_fkey    ;
ALTER TABLE releases_platforms_hist  DROP CONSTRAINT releases_platforms_hist_chid_fkey;
ALTER TABLE releases_producers_hist  DROP CONSTRAINT releases_producers_hist_chid_fkey;
ALTER TABLE releases_vn_hist         DROP CONSTRAINT releases_vn_hist_chid_fkey       ;
ALTER TABLE staff_hist               DROP CONSTRAINT staff_hist_chid_fkey             ;
ALTER TABLE staff_alias_hist         DROP CONSTRAINT staff_alias_chid_fkey            ;
ALTER TABLE vn_hist                  DROP CONSTRAINT vn_hist_chid_fkey                ;
ALTER TABLE vn_anime_hist            DROP CONSTRAINT vn_anime_hist_chid_fkey          ;
ALTER TABLE vn_relations_hist        DROP CONSTRAINT vn_relations_chid_fkey           ;
ALTER TABLE vn_screenshots_hist      DROP CONSTRAINT vn_screenshots_hist_chid_fkey    ;
ALTER TABLE vn_seiyuu_hist           DROP CONSTRAINT vn_seiyuu_hist_chid_fkey         ;
ALTER TABLE vn_staff_hist            DROP CONSTRAINT vn_staff_hist_chid_fkey          ;

ALTER TABLE chars_hist               ADD CONSTRAINT chars_hist_chid_fkey               FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE chars_traits_hist        ADD CONSTRAINT chars_traits_hist_chid_fkey        FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE chars_vns_hist           ADD CONSTRAINT chars_vns_hist_chid_fkey           FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE producers_hist           ADD CONSTRAINT producers_chid_id_fkey             FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE producers_relations_hist ADD CONSTRAINT producers_relations_hist_id_fkey   FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE releases_hist            ADD CONSTRAINT releases_hist_chid_fkey            FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE releases_lang_hist       ADD CONSTRAINT releases_lang_hist_chid_fkey       FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE releases_media_hist      ADD CONSTRAINT releases_media_hist_chid_fkey      FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE releases_platforms_hist  ADD CONSTRAINT releases_platforms_hist_chid_fkey  FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE releases_producers_hist  ADD CONSTRAINT releases_producers_hist_chid_fkey  FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE releases_vn_hist         ADD CONSTRAINT releases_vn_hist_chid_fkey         FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE staff_hist               ADD CONSTRAINT staff_hist_chid_fkey               FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE staff_alias_hist         ADD CONSTRAINT staff_alias_chid_fkey              FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE vn_hist                  ADD CONSTRAINT vn_hist_chid_fkey                  FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE vn_anime_hist            ADD CONSTRAINT vn_anime_hist_chid_fkey            FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE vn_relations_hist        ADD CONSTRAINT vn_relations_chid_fkey             FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE vn_screenshots_hist      ADD CONSTRAINT vn_screenshots_hist_chid_fkey      FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE vn_seiyuu_hist           ADD CONSTRAINT vn_seiyuu_hist_chid_fkey           FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;
ALTER TABLE vn_staff_hist            ADD CONSTRAINT vn_staff_hist_chid_fkey            FOREIGN KEY (chid)      REFERENCES changes       (id) ON DELETE CASCADE;