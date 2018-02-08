CREATE TABLE docs (
  id         SERIAL PRIMARY KEY,
  locked     boolean NOT NULL DEFAULT FALSE,
  hidden     boolean NOT NULL DEFAULT FALSE,
  title      varchar(200) NOT NULL DEFAULT '',
  content    text NOT NULL DEFAULT ''
);
CREATE TABLE docs_hist (
  chid       integer  NOT NULL PRIMARY KEY,
  title      varchar(200) NOT NULL DEFAULT '',
  content    text NOT NULL DEFAULT ''
);
ALTER TYPE dbentry_type ADD VALUE 'd';
ALTER TYPE notification_ltype ADD VALUE 'd';

\i util/sql/func.sql
\i util/sql/editfunc.sql
\i util/sql/perms.sql


-- Insert empty pages
CREATE OR REPLACE FUNCTION insert_doc(integer, text) RETURNS void AS $$
BEGIN
  PERFORM setval('docs_id_seq', $1-1);
  PERFORM edit_d_init(NULL, NULL);
  UPDATE edit_revision SET requester = 1, comments = 'Empty page', ip = '0.0.0.0';
  UPDATE edit_docs SET title = $2;
  PERFORM edit_d_commit();
END
$$ LANGUAGE plpgsql;

SELECT insert_doc( 2, 'Adding/Editing a Visual Novel');
SELECT insert_doc( 3, 'Adding/Editing a Release');
SELECT insert_doc( 4, 'Adding/Editing a Producer');
SELECT insert_doc( 5, 'Editing guidelines');
SELECT insert_doc( 6, 'Frequently Asked Questions');
SELECT insert_doc( 7, 'About us');
SELECT insert_doc( 9, 'Discussion board');
SELECT insert_doc(10, 'Tags & traits');
SELECT insert_doc(11, 'Public Database API');
SELECT insert_doc(12, 'Adding/Editing Characters');
SELECT insert_doc(13, 'How to Capture Screenshots');
SELECT insert_doc(14, 'Database Dumps');
SELECT insert_doc(15, 'Special Games');
SELECT insert_doc(16, 'Adding/Editing Staff Members');

DROP FUNCTION insert_doc(integer, text);



-- Update doc references
CREATE OR REPLACE FUNCTION safedocreplace(text) RETURNS text AS $$
  SELECT regexp_replace($1, 'd(2|3|4|5|6|7|9|10|11|12|13|14|15|16)\.([1-8](?:\.[1-8])?)', 'd\1#\2', 'g')
$$ LANGUAGE sql;
UPDATE threads_posts SET msg = safedocreplace(msg) WHERE msg ~ 'd[1-9]';
UPDATE changes SET comments = safedocreplace(comments) WHERE comments ~ 'd[1-9]';
DROP FUNCTION safedocreplace(text);
