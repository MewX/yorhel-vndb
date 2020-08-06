-- The credit_type definition used in production was... wrong.
-- It had more values than in the schema and values were ordered incorrectly.
-- Redefine it with the proper definition.
ALTER TYPE credit_type RENAME TO old_credit_type;
CREATE TYPE credit_type       AS ENUM ('scenario', 'chardesign', 'art', 'music', 'songs', 'director', 'staff');

ALTER TABLE vn_staff ALTER COLUMN role DROP DEFAULT;
ALTER TABLE vn_staff ALTER COLUMN role TYPE credit_type USING role::text::credit_type;
ALTER TABLE vn_staff ALTER COLUMN role SET DEFAULT 'staff';
ALTER TABLE vn_staff_hist ALTER COLUMN role DROP DEFAULT;
ALTER TABLE vn_staff_hist ALTER COLUMN role TYPE credit_type USING role::text::credit_type;
ALTER TABLE vn_staff_hist ALTER COLUMN role SET DEFAULT 'staff';

DROP TYPE old_credit_type;
