-- These changes have not been synced with the /util/sql/ files yet.


-- character database -> traits

CREATE TABLE traits (
  id SERIAL PRIMARY KEY,
  name varchar(250) NOT NULL,
  alias varchar(500) NOT NULL DEFAULT '',
  description text NOT NULL DEFAULT '',
  meta boolean NOT NULL DEFAULT false,
  added timestamptz NOT NULL DEFAULT NOW(),
  state smallint NOT NULL DEFAULT 0,
  addedby integer NOT NULL DEFAULT 0 REFERENCES users (id)
);

CREATE TABLE traits_parents (
  trait integer NOT NULL REFERENCES traits (id),
  parent integer NOT NULL REFERENCES traits (id),
  PRIMARY KEY(trait, parent)
);

CREATE TRIGGER insert_notify              AFTER  INSERT           ON traits        FOR EACH STATEMENT EXECUTE PROCEDURE insert_notify();



-- character database -> chars

CREATE TYPE char_role AS ENUM ('main', 'primary', 'side', 'appears');
CREATE TYPE blood_type AS ENUM ('unknown', 'a', 'b', 'ab', 'o', 'other');

CREATE TABLE chars (
  id SERIAL PRIMARY KEY,
  latest integer NOT NULL DEFAULT 0,
  locked boolean NOT NULL DEFAULT FALSE,
  hidden boolean NOT NULL DEFAULT FALSE
);

CREATE TABLE chars_rev (
  id         integer  NOT NULL PRIMARY KEY REFERENCES changes (id),
  cid        integer  NOT NULL REFERENCES chars (id),
  name       varchar(250) NOT NULL DEFAULT '',
  original   varchar(250) NOT NULL DEFAULT '',
  alias      varchar(500) NOT NULL DEFAULT '',
  image      integer  NOT NULL DEFAULT 0,
  "desc"     text     NOT NULL DEFAULT '',
  s_bust     smallint NOT NULL DEFAULT 0,
  s_waist    smallint NOT NULL DEFAULT 0,
  s_hip      smallint NOT NULL DEFAULT 0,
  b_month    smallint NOT NULL DEFAULT 0,
  b_day      smallint NOT NULL DEFAULT 0,
  height     smallint NOT NULL DEFAULT 0,
  weight     smallint NOT NULL DEFAULT 0,
  bloodt     blood_type NOT NULL DEFAULT 'unknown',
  main       integer  REFERENCES chars (id),
  main_spoil boolean  NOT NULL DEFAULT false
);
ALTER TABLE chars ADD FOREIGN KEY (latest) REFERENCES chars_rev (id) DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE chars_traits (
  cid integer NOT NULL REFERENCES chars_rev (id),
  tid integer NOT NULL REFERENCES traits (id),
  spoil smallint NOT NULL DEFAULT 0,
  PRIMARY KEY(cid, tid)
);

CREATE TABLE chars_vns (
  cid integer NOT NULL REFERENCES chars_rev (id),
  vid integer NOT NULL REFERENCES vn (id),
  rid integer REFERENCES releases (id),
  spoil boolean NOT NULL DEFAULT false,
  role char_role NOT NULL DEFAULT 'main',
  PRIMARY KEY(cid, vid, rid)
);

CREATE SEQUENCE charimg_seq;



-- allow characters to be versioned using the changes table

CREATE TYPE dbentry_type_tmp AS ENUM ('v', 'r', 'p', 'c');
ALTER TABLE changes ALTER COLUMN "type" TYPE dbentry_type_tmp USING "type"::text::dbentry_type_tmp;
DROP FUNCTION edit_revtable(dbentry_type, integer);
DROP TYPE dbentry_type;
ALTER TYPE dbentry_type_tmp RENAME TO dbentry_type;


-- load the updated functions

\i util/sql/func.sql


CREATE TRIGGER hidlock_update             BEFORE UPDATE           ON chars         FOR EACH ROW WHEN (OLD.latest IS DISTINCT FROM NEW.latest) EXECUTE PROCEDURE update_hidlock();
CREATE TRIGGER chars_rev_image_notify     AFTER  INSERT OR UPDATE ON chars_rev     FOR EACH ROW WHEN (NEW.image < 0) EXECUTE PROCEDURE chars_rev_image_notify();


/* Debugging data *-/

-- some traits, based on Echo's draft
INSERT INTO traits (name, meta, state, addedby) VALUES
  ('Hair', true, 2, 2),
  ('Hair Color', true, 2, 2),
  ('Auburn', false, 2, 2),
  ('Black', false, 2, 2),
  ('Blond', false, 2, 2),
  ('Brown', false, 2, 2),
  ('Hairstyle', true, 2, 2),
  ('Bun', false, 2, 2),
  ('Odango', false, 2, 2),
  ('Ponytail', false, 2, 2),
  ('Twin Tails', false, 2, 2),
  ('Short', false, 2, 2),
  ('Straight', false, 2, 2);
INSERT INTO traits_parents (trait, parent) VALUES
  (2, 1),
  (3, 2),
  (4, 2),
  (5, 2),
  (6, 2),
  (7, 1),
  (8, 7),
  (9, 8),
  (9, 11),
  (10, 7),
  (11, 10),
  (12, 7),
  (13, 7);


-- phorni!
SELECT edit_char_init(null);
UPDATE edit_revision SET comments = 'New test entry', requester = 2, ip = '0.0.0.0';
UPDATE edit_char SET name = 'Phorni', original = 'フォーニ', "desc" = 'Sprite of Music', height = 14;
SELECT edit_char_commit();

-- saya (incorrect test data)
SELECT edit_char_init(null);
UPDATE edit_revision SET comments = '2nd test entry', requester = 2, ip = '0.0.0.0';
UPDATE edit_char SET name = 'Saya', original = '沙耶', "desc" = 'There is more than meets the eye!', alias = 'Cute monster', height = 140, weight = 52, s_bust = 41, s_waist = 38, s_hip = 40, b_month = 3, b_day = 15, bloodt = 'a';
SELECT edit_char_commit();

-- */

