CREATE TYPE cup_size AS ENUM ('', 'AAA', 'AA', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z');

ALTER TABLE chars      ADD COLUMN cup_size cup_size NOT NULL DEFAULT '';
ALTER TABLE chars_hist ADD COLUMN cup_size cup_size NOT NULL DEFAULT '';
ALTER TABLE chars      ADD COLUMN age smallint;
ALTER TABLE chars_hist ADD COLUMN age smallint;

\i util/sql/editfunc.sql



CREATE OR REPLACE FUNCTION migrate_trait_to_cup(cid integer, cup cup_size) RETURNS void AS $$
BEGIN
    PERFORM edit_c_init(cid, (SELECT MAX(rev) FROM changes WHERE itemid = cid AND type = 'c'));
    UPDATE edit_chars SET cup_size = cup;
    DELETE FROM edit_chars_traits WHERE tid IN(722, 1182, 1183, 1178, 1184, 723, 2129, 2115);
    UPDATE edit_revision SET requester = 1, ip = '0.0.0.0', comments = 'Automatic conversion of breast size trait to cup size field.';
    PERFORM edit_c_commit();
END;
$$ LANGUAGE plpgsql;

UPDATE traits SET state = 1 WHERE id IN(722, 1182, 1183, 1178, 1184);

-- This takes a while (slowness is likely due to traits_chars_calc(), can be temporarily disabled, but w/e)
\timing
SELECT count(*) FROM (SELECT migrate_trait_to_cup(c.id, 'AA') FROM chars c JOIN chars_traits ct ON ct.id = c.id WHERE NOT c.hidden AND c.cup_size = '' AND ct.tid = 722) x;
SELECT count(*) FROM (SELECT migrate_trait_to_cup(c.id, 'A' ) FROM chars c JOIN chars_traits ct ON ct.id = c.id WHERE NOT c.hidden AND c.cup_size = '' AND ct.tid = 1182) x;
SELECT count(*) FROM (SELECT migrate_trait_to_cup(c.id, 'B' ) FROM chars c JOIN chars_traits ct ON ct.id = c.id WHERE NOT c.hidden AND c.cup_size = '' AND ct.tid = 1183) x;
SELECT count(*) FROM (SELECT migrate_trait_to_cup(c.id, 'C' ) FROM chars c JOIN chars_traits ct ON ct.id = c.id WHERE NOT c.hidden AND c.cup_size = '' AND ct.tid = 1178) x;
SELECT count(*) FROM (SELECT migrate_trait_to_cup(c.id, 'D' ) FROM chars c JOIN chars_traits ct ON ct.id = c.id WHERE NOT c.hidden AND c.cup_size = '' AND ct.tid = 1184) x;
\timing

DROP FUNCTION migrate_trait_to_cup(integer, cup_size);


-- Regex magic by skorpiondeath (with minor changes) - https://query.vndb.org/queries/kKFzwjqvAshONiaf
CREATE OR REPLACE FUNCTION migrate_desc_to_cup(cid integer) RETURNS void AS $$
BEGIN
    PERFORM edit_c_init(cid, (SELECT MAX(rev) FROM changes WHERE itemid = cid AND type = 'c'));
    UPDATE edit_chars
       SET cup_size = substring( substring("desc" from '([c|C]up[\s]*(size|Size)?:[\s]*[A-Z][A]*)') from '[A]*.$')::cup_size
         , "desc" = regexp_replace("desc", '[\s]*(-)?[\s]*?cup[\s]*(size)?:[\s]?[A-Z][A]*[.|\s-]?((cup)|([\s]*-->[\s]*[A-Z]))?[\n\r]*', '', 'gi');
    DELETE FROM edit_chars_traits WHERE tid IN(722, 1182, 1183, 1178, 1184, 723, 2129, 2115);
    UPDATE edit_revision SET requester = 1, ip = '0.0.0.0', comments = 'Automatic extraction of cup size field from the description.';
    PERFORM edit_c_commit();
END;
$$ LANGUAGE plpgsql;

\timing
SELECT count(*) FROM (SELECT migrate_desc_to_cup(id) FROM chars WHERE NOT hidden AND cup_size = '' AND "desc" ~* '.*(cup[\s]*(size)?:[\s]*[A-Z]).*') x;
\timing

DROP FUNCTION migrate_desc_to_cup(integer);



CREATE OR REPLACE FUNCTION migrate_desc_to_age(cid integer) RETURNS void AS $$
BEGIN
    PERFORM edit_c_init(cid, (SELECT MAX(rev) FROM changes WHERE itemid = cid AND type = 'c'));
    UPDATE edit_chars SET
        age = regexp_replace("desc", '^.*age:\s*([0-9]+).*$', '\1', 'i')::smallint,
        "desc" = trim(both E' \t\r\n' from regexp_replace("desc", '(?<=^|\n)\s*age:\s*([0-9]+)(?:\n|\s*$|\.\s*)', '', 'ig'));
    UPDATE edit_revision SET requester = 1, ip = '0.0.0.0', comments = 'Automatic extraction of age from the description.';
    PERFORM edit_c_commit();
END;
$$ LANGUAGE plpgsql;

\timing
SELECT count(*) FROM (SELECT migrate_desc_to_age(id) FROM chars WHERE NOT hidden AND age IS NULL AND "desc" ~* '(?<=^|\n)\s*age:\s*([0-9]+)(?:\n|\s*$|\.\s*)') x;
\timing

DROP FUNCTION migrate_desc_to_age(integer);
