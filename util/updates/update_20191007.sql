ALTER TABLE tags_vn_inherit DROP COLUMN users;

ALTER TABLE traits_chars DROP CONSTRAINT traits_chars_pkey;

DROP FUNCTION tag_vn_calc();
DROP FUNCTION traits_chars_calc();

\i util/sql/func.sql
SELECT tag_vn_calc(NULL);
SELECT traits_chars_calc(NULL);
