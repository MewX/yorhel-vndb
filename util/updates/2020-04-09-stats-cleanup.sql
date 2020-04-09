DROP TRIGGER stats_cache_new   ON threads;
DROP TRIGGER stats_cache_edit  ON threads;
DROP TRIGGER stats_cache_new   ON threads_posts;
DROP TRIGGER stats_cache_edit  ON threads_posts;
DROP TRIGGER stats_cache       ON users;

DELETE FROM stats_cache WHERE section IN('users', 'threads', 'threads_posts');

\i sql/triggers.sql
\i sql/func.sql
