ALTER TABLE reviews ADD COLUMN isfull boolean NOT NULL DEFAULT false;
UPDATE reviews SET isfull = text <> '';
UPDATE reviews SET text = summary WHERE NOT isfull;
UPDATE reviews SET text = summary || text WHERE isfull;
ALTER TABLE reviews ALTER COLUMN isfull DROP DEFAULT;
ALTER TABLE reviews DROP COLUMN summary;
