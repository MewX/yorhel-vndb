-- Be sure to run 'make' before importing this script.

ALTER TABLE releases      ADD COLUMN engine varchar(50) NOT NULL DEFAULT '';
ALTER TABLE releases_hist ADD COLUMN engine varchar(50) NOT NULL DEFAULT '';

\i util/sql/editfunc.sql

CREATE FUNCTION set_engine(rid integer, eng text) RETURNS void AS $$
BEGIN
    PERFORM edit_r_init(rid, (SELECT MAX(rev) FROM changes WHERE itemid = rid AND type = 'r'));
    UPDATE edit_releases SET engine = eng;
    UPDATE edit_revision SET requester = 1, ip = '0.0.0.0', comments = 'Automatic conversion of the "Engine" visual novel tag.';
    PERFORM edit_r_commit();
END
$$ LANGUAGE plpgsql;

SELECT set_engine(r.id, 'Ren''Py')
  FROM releases r WHERE NOT r.hidden AND NOT r.patch
   AND (SELECT COUNT(*) FROM releases_vn rv WHERE rv.id = r.id) = 1
   AND r.id IN(
        SELECT rv.id
          FROM releases_vn rv
          JOIN vn v ON rv.vid = v.id
          JOIN tags_vn_inherit tvi ON tvi.vid = v.id
         WHERE NOT v.hidden AND tvi.tag = 1298
           AND NOT v.c_olang <@ ARRAY['ja'::language]
           AND NOT EXISTS(SELECT 1 FROM releases_platforms rp WHERE rp.id = rv.id AND platform NOT IN('win', 'lin', 'mac', 'and', 'ios'))
       ) ORDER BY id;

SELECT set_engine(r.id, 'RPG Maker')
  FROM releases r WHERE NOT r.hidden AND NOT r.patch
   AND (SELECT COUNT(*) FROM releases_vn rv WHERE rv.id = r.id) = 1
   AND r.id IN(
        SELECT rv.id
          FROM releases_vn rv
          JOIN vn v ON rv.vid = v.id
          JOIN tags_vn_inherit tvi ON tvi.vid = v.id
         WHERE NOT v.hidden AND tvi.tag = 2330
           AND NOT v.c_olang <@ ARRAY['ja'::language]
       ) ORDER BY id;

-- SELECT 'https://vndb.org/r'||r.id, r.title
SELECT set_engine(r.id, 'KiriKiri')
  FROM releases r WHERE NOT r.hidden AND NOT r.patch
   AND (SELECT COUNT(*) FROM releases_vn rv WHERE rv.id = r.id) = 1
   AND r.id IN(
        SELECT rv.id
          FROM releases_vn rv
          JOIN vn v ON rv.vid = v.id
          JOIN tags_vn_inherit tvi ON tvi.vid = v.id
         WHERE NOT v.hidden AND tvi.tag = 2776
           AND NOT EXISTS(SELECT 1 FROM releases_platforms rp WHERE rp.id = rv.id AND platform <> 'win')
       ) ORDER BY id;

DROP FUNCTION set_engine(integer, text);
