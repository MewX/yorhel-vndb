ALTER TABLE wikidata ADD COLUMN crunchyroll        text[];
ALTER TABLE wikidata ADD COLUMN igdb_game          text[];
ALTER TABLE wikidata ADD COLUMN giantbomb          text[];
ALTER TABLE wikidata ADD COLUMN pcgamingwiki       text[];
ALTER TABLE wikidata ADD COLUMN steam              integer[];
ALTER TABLE wikidata ADD COLUMN gog                text[];
ALTER TABLE wikidata ADD COLUMN pixiv_user         integer[];


ALTER TABLE staff      ADD COLUMN l_pixiv integer NOT NULL DEFAULT 0;
ALTER TABLE staff_hist ADD COLUMN l_pixiv integer NOT NULL DEFAULT 0;

\i util/sql/editfunc.sql


-- C U R S E D --

CREATE OR REPLACE FUNCTION migrate_desc_to_pixiv(sid integer) RETURNS void AS $$
BEGIN
    PERFORM edit_s_init(sid, (SELECT MAX(rev) FROM changes WHERE itemid = sid AND type = 's'));
    UPDATE edit_staff SET
        l_pixiv = regexp_replace("desc", '^.*www\.pixiv\.net/(?:member\.php\?id=|whitecube/user/)([0-9]+).*$', '\1', 'i')::integer,
        "desc" = trim(both E' \t\r\n' from regexp_replace("desc", '(?<=^|\n)\s*(?:(?:His|her )?Pixiv(?: profile| account| link)?\s*:\s+|(?:His|Her) Pixiv (?:profile|account) (?:can be (?:viewed|visited|accessed|reached)|is) )?(?:\[URL=)?(?:https?://)?www\.pixiv\.net/(?:member\.php\?id=|whitecube/user/)([0-9]+)(?:\](?:here|pixiv|link|URL|pixiv link|pixiv profile|pixiv account)\.?\[/URL\])?(?:\n|\s*$|\.\s*)', '', 'i'));
    UPDATE edit_revision SET requester = 1, ip = '0.0.0.0', comments = 'Automatic extraction of Pixiv id from the notes.';
    PERFORM edit_s_commit();
END;
$$ LANGUAGE plpgsql;
SELECT migrate_desc_to_pixiv(id) FROM staff WHERE NOT hidden
--SELECT id, "desc" FROM staff WHERE NOT hidden AND "desc" ~ 'pixiv\.net'
    AND "desc" ~* '(?<=^|\n)\s*(?:(?:His|her )?Pixiv(?: profile| account| link)?\s*:\s+|(?:His|Her) Pixiv (?:profile|account) (?:can be (?:viewed|visited|accessed|reached)|is) )?(?:\[URL=)?(?:https?://)?www\.pixiv\.net/(?:member\.php\?id=|whitecube/user/)([0-9]+)(?:\](?:here|pixiv|link|URL|pixiv link|pixiv profile|pixiv account)\.?\[/URL\])?(?:\n|\s*$|\.\s*)';
DROP FUNCTION migrate_desc_to_pixiv(integer);
