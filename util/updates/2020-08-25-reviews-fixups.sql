DROP INDEX reviews_posts_uid;
CREATE        INDEX reviews_posts_uid      ON reviews_posts (uid);

\i sql/func.sql
\i sql/triggers.sql
