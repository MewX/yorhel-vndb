ALTER TABLE releases      ADD COLUMN l_itch text NOT NULL DEFAULT '';
ALTER TABLE releases_hist ADD COLUMN l_itch text NOT NULL DEFAULT '';

\i util/sql/editfunc.sql

CREATE OR REPLACE FUNCTION migrate_website_to_itch(rid integer) RETURNS void AS $$
BEGIN
    PERFORM edit_r_init(rid, (SELECT MAX(rev) FROM changes WHERE itemid = rid AND type = 'r'));
    UPDATE edit_releases SET l_itch = regexp_replace(website, '^https?://([a-z0-9_-]+)\.itch\.io/([a-z0-9_-]+)(?:\?.+)?$', '\1.itch.io/\2'), website = '';
    UPDATE edit_revision SET requester = 1, ip = '0.0.0.0', comments = 'Automatic conversion of website to Itch.io.';
    PERFORM edit_r_commit();
END;
$$ LANGUAGE plpgsql;
SELECT migrate_website_to_itch(id) FROM releases WHERE NOT hidden AND website ~ '^https?://([a-z0-9_-]+)\.itch\.io/([a-z0-9_-]+)(?:\?.+)?$';
DROP FUNCTION migrate_website_to_itch(integer);


CREATE OR REPLACE FUNCTION migrate_notes_to_itch(rid integer) RETURNS void AS $$
BEGIN
    PERFORM edit_r_init(rid, (SELECT MAX(rev) FROM changes WHERE itemid = rid AND type = 'r'));
    UPDATE edit_releases SET
        l_itch = regexp_replace(notes, '^.*\s*(?:Also available|Available) (?:on|at|from) \[url=https?://([a-z0-9_-]+)\.itch\.io/([a-z0-9_-]+)\]\s*Itch(?:\.io)?\s*\.?\[/url\].*$', '\1.itch.io/\2', 'i'),
        notes = regexp_replace(notes, '\s*(?:Also available|Available) (?:on|at|from) \[url=https?://([a-z0-9_-]+)\.itch\.io/([a-z0-9_-]+)\]\s*Itch(?:\.io)?\s*\.?\[/url\](?:\,?$|\.\s*)', '', 'i');
    UPDATE edit_revision SET requester = 1, ip = '0.0.0.0', comments = 'Automatic extraction of Itch.io link from the notes.';
    PERFORM edit_r_commit();
END;
$$ LANGUAGE plpgsql;
SELECT migrate_notes_to_itch(id) FROM releases WHERE NOT hidden AND l_itch = ''
    AND notes ~* '\s*(?:Also available|Available) (?:on|at|from) \[url=https?://([a-z0-9_-]+)\.itch\.io/([a-z0-9_-]+)\]\s*Itch(?:\.io)?\s*\.?\[/url\](?:\,?$|\.\s*)';
    AND id NOT IN(59555, 65209, 60553);
DROP FUNCTION migrate_notes_to_itch(integer);


UPDATE releases      SET l_dmm = regexp_replace(l_dmm, 'https?://', '') where l_dmm <> '';
UPDATE releases_hist SET l_dmm = regexp_replace(l_dmm, 'https?://', '') where l_dmm <> '';
