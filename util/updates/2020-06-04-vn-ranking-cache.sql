ALTER TABLE vn ADD COLUMN c_pop_rank integer;
ALTER TABLE vn ADD COLUMN c_rat_rank integer;
\i sql/func.sql
select update_vnvotestats();
