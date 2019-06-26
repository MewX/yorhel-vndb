ALTER TABLE tags ADD COLUMN searchable boolean NOT NULL DEFAULT TRUE;
ALTER TABLE tags ADD COLUMN applicable boolean NOT NULL DEFAULT TRUE;
UPDATE tags SET searchable = NOT meta, applicable = NOT meta;
ALTER TABLE tags DROP COLUMN meta;

ALTER TABLE traits ADD COLUMN searchable boolean NOT NULL DEFAULT TRUE;
ALTER TABLE traits ADD COLUMN applicable boolean NOT NULL DEFAULT TRUE;
UPDATE traits SET searchable = NOT meta, applicable = NOT meta;
ALTER TABLE traits DROP COLUMN meta;

-- NOTE: Be sure to run util/sql/func.sql
