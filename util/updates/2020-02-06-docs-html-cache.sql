-- Run 'make' before this script
-- Run 'util/update-docs-html-cache.pl' after this script
ALTER TABLE docs      ADD COLUMN html text;
ALTER TABLE docs_hist ADD COLUMN html text;
\i util/sql/editfunc.sql
