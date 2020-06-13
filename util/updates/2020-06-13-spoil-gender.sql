-- Run 'make' first to update editfunc.sql
ALTER TABLE chars      ADD COLUMN spoil_gender gender;
ALTER TABLE chars_hist ADD COLUMN spoil_gender gender;
\i sql/editfunc.sql
