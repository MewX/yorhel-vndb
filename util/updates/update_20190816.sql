-- Run 'make' before importing this script

ALTER TABLE releases      ADD COLUMN l_steam    integer NOT NULL DEFAULT 0;
ALTER TABLE releases      ADD COLUMN l_dlsite   text NOT NULL DEFAULT '';
ALTER TABLE releases      ADD COLUMN l_dlsiteen text NOT NULL DEFAULT '';
ALTER TABLE releases      ADD COLUMN l_gog      text NOT NULL DEFAULT '';
ALTER TABLE releases_hist ADD COLUMN l_steam    integer NOT NULL DEFAULT 0;
ALTER TABLE releases_hist ADD COLUMN l_dlsite   text NOT NULL DEFAULT '';
ALTER TABLE releases_hist ADD COLUMN l_dlsiteen text NOT NULL DEFAULT '';
ALTER TABLE releases_hist ADD COLUMN l_gog      text NOT NULL DEFAULT '';

\i util/sql/editfunc.sql


-- Steam URL formats:
-- https?://store.steampowered.com/app/729330/
-- These two often don't link to the game directly, but rather info about community patches.
-- Using these in the conversion will cause too many incorrect links.
-- https?://steamcommunity.com/app/755970/
-- https?://steamcommunity.com/games/323490/

CREATE OR REPLACE FUNCTION migrate_website_to_steam(rid integer) RETURNS void AS $$
BEGIN
    PERFORM edit_r_init(rid, (SELECT MAX(rev) FROM changes WHERE itemid = rid AND type = 'r'));
    UPDATE edit_releases SET l_steam = regexp_replace(website, 'https?://store\.steampowered\.com/app/([0-9]+)(?:/.*)?', '\1')::integer, website = '';
    UPDATE edit_revision SET requester = 1, ip = '0.0.0.0', comments = 'Automatic conversion of website to Steam AppID.';
    PERFORM edit_r_commit();
END;
$$ LANGUAGE plpgsql;
SELECT migrate_website_to_steam(id) FROM releases WHERE NOT hidden AND website ~ 'https?://store\.steampowered\.com/app/([0-9]+)';
DROP FUNCTION migrate_website_to_steam(integer);


CREATE OR REPLACE FUNCTION migrate_notes_to_steam(rid integer) RETURNS void AS $$
BEGIN
    PERFORM edit_r_init(rid, (SELECT MAX(rev) FROM changes WHERE itemid = rid AND type = 'r'));
    UPDATE edit_releases SET
        l_steam = regexp_replace(notes, '^.*(?:Also available|Available) on \[url=https?://store\.steampowered\.com/app/([0-9]+)[^\]]*\]\s*Steam\s*\.?\[/url\].*$', '\1')::integer,
        notes = regexp_replace(notes, '\s*(?:Also available|Available) on \[url=https?://store\.steampowered\.com/app/([0-9]+)[^\]]*\]\s*Steam\s*\.?\[/url\](?:\,?$|\.\s*)', '');
    UPDATE edit_revision SET requester = 1, ip = '0.0.0.0', comments = 'Automatic extraction of Steam AppID from the notes.';
    PERFORM edit_r_commit();
END;
$$ LANGUAGE plpgsql;
SELECT migrate_notes_to_steam(id) FROM releases WHERE NOT hidden AND l_steam = 0
    AND notes ~ '\s*(?:Also available|Available) on \[url=https?://store\.steampowered\.com/app/([0-9]+)[^\]]*\]\s*Steam\s*\.?\[/url\](?:\,?$|\.\s*)';
DROP FUNCTION migrate_notes_to_steam(integer);


-- DLsite URL formats:
-- https://www.dlsite.com/pro/work/=/product_id/VJ003580.html
--  * The '/pro/' is the store section, can also be 'home', 'eng', 'echi-eng', 'girls', 'maniax', etc (sections are listed on dlsite.com).
--    Will automatically redirect to the right URL when the section is wrong, but it can't be empty or bogus.
-- https://pro.dlsite.com/work/=/product_id/VJ003580.html
--  * Same as above, but redirects to /pro/work/..
-- https://www.dlsite.com/pro/work/=/product_id/VJ003580
--  * The .html is optional
--
-- VJ003580 is the actual ID
--  * B = Books, V = Doujin?, R = Professional?   -> Product type/format?
--  * J = Japanese, E = English, T = Taiwan
--    -> Not a property of the actual product?
--       Changing between J/E often (but not always!) redirects to same product on different store page.
--       T is only available on getchu.com.tw, no automatic redirect if you get it wrong.

CREATE OR REPLACE FUNCTION migrate_notes_to_dlsite(rid integer, rnotes text) RETURNS void AS $$
DECLARE
    l text;
BEGIN
    l := regexp_replace(rnotes, '^.*(?:Also available|Available) (?:on|at|from) \[url=https?://[^\]]+/work/=/product_id/([RV][EJ][0-9]+)[^\]]*\]\s*DLsite\s*(?:english\s*)?\.?\[/url\].*$', '\1', 'i');
    PERFORM edit_r_init(rid, (SELECT MAX(rev) FROM changes WHERE itemid = rid AND type = 'r'));
    UPDATE edit_releases SET
        l_dlsite   = CASE WHEN l ~ 'J' THEN l ELSE l_dlsite END,
        l_dlsiteen = CASE WHEN l ~ 'E' THEN l ELSE l_dlsiteen END,
        notes = regexp_replace(notes, '\s*(?:Also available|Available) (?:on|at|from) \[url=https?://[^\]]+/work/=/product_id/([RV][EJ][0-9]+)[^\]]*\]\s*DLsite\s*(?:english\s*)?\.?\[/url\](?:\,?$|\.\s*)', '', 'i');
    UPDATE edit_revision SET requester = 1, ip = '0.0.0.0', comments = 'Automatic extraction of DLsite link from the notes.';
    PERFORM edit_r_commit();
END;
$$ LANGUAGE plpgsql;
SELECT migrate_notes_to_dlsite(id, notes) FROM releases WHERE NOT hidden
    AND id <> 20242 -- odd special case
    AND notes ~* '\s*(?:Also available|Available) (?:on|at|from) \[url=https?://[^\]]+/work/=/product_id/([RV][EJ][0-9]+)[^\]]*\]\s*DLsite\s*(?:english\s*)?\.?\[/url\](?:\,?$|\.\s*)';
DROP FUNCTION migrate_notes_to_dlsite(integer, text);
