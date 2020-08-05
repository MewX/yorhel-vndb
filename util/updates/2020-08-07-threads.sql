-- * Convert thread identifiers to vndbids
-- * Remove threads_poll_votes.tid
-- * Add two ON DELETE CASCADE's

ALTER TABLE threads_poll_votes DROP COLUMN tid;
ALTER TABLE threads_poll_votes ADD PRIMARY KEY (optid,uid);

ALTER TABLE threads_poll_options DROP CONSTRAINT threads_poll_options_tid_fkey;
ALTER TABLE threads_poll_options ALTER COLUMN tid TYPE vndbid USING vndbid('t', tid);

ALTER TABLE threads_boards DROP CONSTRAINT threads_boards_tid_fkey;
ALTER TABLE threads_boards ALTER COLUMN tid DROP DEFAULT;
ALTER TABLE threads_boards ALTER COLUMN tid TYPE vndbid USING vndbid('t', tid);

ALTER TABLE threads DROP CONSTRAINT threads_id_fkey;
ALTER TABLE threads_posts DROP CONSTRAINT threads_posts_tid_fkey;
ALTER TABLE threads_posts ALTER COLUMN tid DROP DEFAULT;
ALTER TABLE threads_posts ALTER COLUMN tid TYPE vndbid USING vndbid('t', tid);

ALTER TABLE threads ALTER COLUMN id DROP DEFAULT;
ALTER TABLE threads ALTER COLUMN id TYPE vndbid USING vndbid('t', id);
ALTER TABLE threads ALTER COLUMN id SET DEFAULT vndbid('t', nextval('threads_id_seq')::int);
ALTER TABLE threads ADD CONSTRAINT threads_id_check CHECK(vndbid_type(id) = 't');

ALTER TABLE threads                  ADD CONSTRAINT threads_id_fkey                    FOREIGN KEY (id, count) REFERENCES threads_posts (tid, num) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE threads_poll_options     ADD CONSTRAINT threads_poll_options_tid_fkey      FOREIGN KEY (tid)       REFERENCES threads       (id) ON DELETE CASCADE;
ALTER TABLE threads_posts            ADD CONSTRAINT threads_posts_tid_fkey             FOREIGN KEY (tid)       REFERENCES threads       (id) ON DELETE CASCADE;
ALTER TABLE threads_boards           ADD CONSTRAINT threads_boards_tid_fkey            FOREIGN KEY (tid)       REFERENCES threads       (id) ON DELETE CASCADE;

\i sql/triggers.sql
