-- Support a '0' weight.
ALTER TABLE chars ALTER COLUMN weight DROP DEFAULT;
ALTER TABLE chars ALTER COLUMN weight DROP NOT NULL;
ALTER TABLE chars_hist ALTER COLUMN weight DROP DEFAULT;
ALTER TABLE chars_hist ALTER COLUMN weight DROP NOT NULL;

UPDATE chars SET weight = NULL WHERE weight = 0;
UPDATE chars_hist SET weight = NULL WHERE weight = 0;
