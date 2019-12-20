ALTER TABLE threads_poll_votes ADD COLUMN date timestamptz;
ALTER TABLE threads_poll_votes ALTER COLUMN date SET DEFAULT NOW();
