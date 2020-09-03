ALTER TABLE reviews ADD COLUMN c_flagged boolean NOT NULL DEFAULT false;
ALTER TABLE reviews_votes ADD COLUMN overrule boolean NOT NULL DEFAULT false;

\i sql/func.sql
select update_reviews_votes_cache(null);
