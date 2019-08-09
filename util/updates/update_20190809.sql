-- Update instructions:
--
--  make
--  psql -U vndb -f util/updates/update_20190809.sql
--  psql -U postgres -f util/sql/perms.sql
CREATE TABLE wikidata (
  id                 integer NOT NULL PRIMARY KEY, -- [pub]
  lastfetch          timestamptz,
  enwiki             text,    -- [pub]
  jawiki             text,    -- [pub]
  website            text,    -- [pub] P856
  vndb               text,    -- [pub] P3180
  mobygames          text,    -- [pub] P1933
  mobygames_company  text,    -- [pub] P4773
  gamefaqs_game      integer, -- [pub] P4769
  gamefaqs_company   integer, -- [pub] P6182
  anidb_anime        integer, -- [pub] P5646
  anidb_person       integer, -- [pub] P5649
  ann_anime          integer, -- [pub] P1985
  ann_manga          integer, -- [pub] P1984
  musicbrainz_artist uuid,    -- [pub] P434
  twitter            text,    -- [pub] P2002
  vgmdb_product      integer, -- [pub] P5659
  vgmdb_artist       integer, -- [pub] P3435
  discogs_artist     integer, -- [pub] P1953
  acdb_char          integer, -- [pub] P7013
  acdb_source        integer, -- [pub] P7017
  indiedb_game       text,    -- [pub] P6717
  howlongtobeat      integer  -- [pub] P2816
);

ALTER TABLE producers      ADD COLUMN l_wikidata integer;
ALTER TABLE producers_hist ADD COLUMN l_wikidata integer;
ALTER TABLE staff          ADD COLUMN l_wikidata integer;
ALTER TABLE staff_hist     ADD COLUMN l_wikidata integer;
ALTER TABLE vn             ADD COLUMN l_wikidata integer;
ALTER TABLE vn_hist        ADD COLUMN l_wikidata integer;

ALTER TABLE producers                ADD CONSTRAINT producers_l_wikidata_fkey          FOREIGN KEY (l_wikidata)REFERENCES wikidata      (id);
ALTER TABLE producers_hist           ADD CONSTRAINT producers_hist_l_wikidata_fkey     FOREIGN KEY (l_wikidata)REFERENCES wikidata      (id);
ALTER TABLE staff                    ADD CONSTRAINT staff_l_wikidata_fkey              FOREIGN KEY (l_wikidata)REFERENCES wikidata      (id);
ALTER TABLE staff_hist               ADD CONSTRAINT staff_hist_l_wikidata_fkey         FOREIGN KEY (l_wikidata)REFERENCES wikidata      (id);
ALTER TABLE vn                       ADD CONSTRAINT vn_l_wikidata_fkey                 FOREIGN KEY (l_wikidata)REFERENCES wikidata      (id);
ALTER TABLE vn_hist                  ADD CONSTRAINT vn_hist_l_wikidata_fkey            FOREIGN KEY (l_wikidata)REFERENCES wikidata      (id);

\i util/sql/func.sql
\i util/sql/editfunc.sql

CREATE TRIGGER producers_wikidata_new       BEFORE INSERT ON producers      FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER producers_wikidata_edit      BEFORE UPDATE ON producers      FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER producers_hist_wikidata_new  BEFORE INSERT ON producers_hist FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER producers_hist_wikidata_edit BEFORE UPDATE ON producers_hist FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER staff_wikidata_new           BEFORE INSERT ON staff          FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER staff_wikidata_edit          BEFORE UPDATE ON staff          FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER staff_hist_wikidata_new      BEFORE INSERT ON staff_hist     FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER staff_hist_wikidata_edit     BEFORE UPDATE ON staff_hist     FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER vn_wikidata_new              BEFORE INSERT ON vn             FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER vn_wikidata_edit             BEFORE UPDATE ON vn             FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER vn_hist_wikidata_new         BEFORE INSERT ON vn_hist        FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL) EXECUTE PROCEDURE wikidata_insert();
CREATE TRIGGER vn_hist_wikidata_edit        BEFORE UPDATE ON vn_hist        FOR EACH ROW WHEN (NEW.l_wikidata IS NOT NULL AND OLD.l_wikidata IS DISTINCT FROM NEW.l_wikidata) EXECUTE PROCEDURE wikidata_insert();
