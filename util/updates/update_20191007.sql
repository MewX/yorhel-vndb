ALTER TABLE tags_vn_inherit DROP COLUMN users;

ALTER TABLE traits_chars DROP CONSTRAINT traits_chars_pkey;

\i util/sql/func.sql
SELECT tag_vn_calc();
SELECT traits_chars_calc();
