ALTER TABLE tags ADD COLUMN searchable boolean NOT NULL DEFAULT TRUE;
ALTER TABLE tags ADD COLUMN applicable boolean NOT NULL DEFAULT TRUE;
UPDATE tags SET searchable = NOT meta, applicable = NOT meta;
ALTER TABLE tags DROP COLUMN meta;
