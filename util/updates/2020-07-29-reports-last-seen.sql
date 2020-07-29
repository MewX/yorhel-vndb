ALTER TABLE users ADD COLUMN last_reports timestamptz;
DROP          INDEX reports_status;
CREATE        INDEX reports_new            ON reports (date) WHERE status = 'new';
CREATE        INDEX reports_lastmod        ON reports (lastmod);
\i sql/perms.sql
