-- Run 'make' before importing this script

ALTER TABLE releases      ADD COLUMN l_steam    integer NOT NULL DEFAULT 0;
ALTER TABLE releases_hist ADD COLUMN l_steam    integer NOT NULL DEFAULT 0;

\i util/sql/editfunc.sql

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


-- https?://store.steampowered.com/app/729330/
-- These two often don't link to the game directly, but rather info about community patches.
-- Using these in the conversion will cause too many incorrect links.
-- https?://steamcommunity.com/app/755970/
-- https?://steamcommunity.com/games/323490/
