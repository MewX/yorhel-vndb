ALTER TABLE image_votes ADD COLUMN ignore boolean NOT NULL DEFAULT false;
DROP TRIGGER image_votes_cache2 ON image_votes;
CREATE TRIGGER image_votes_cache2 AFTER UPDATE ON image_votes FOR EACH ROW WHEN ((OLD.id, OLD.sexual, OLD.violence, OLD.ignore) IS DISTINCT FROM (NEW.id, NEW.sexual, NEW.violence, NEW.ignore)) EXECUTE PROCEDURE update_images_cache();
\i sql/func.sql
