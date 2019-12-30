-- NOTE: Make sure you're cd'ed in the vndb root directory before running this script

\set ON_ERROR_STOP 1
\i util/sql/schema.sql
\i util/sql/data.sql
\i util/sql/func.sql
\i util/sql/editfunc.sql
\i util/sql/tableattrs.sql
\i util/sql/triggers.sql
\set ON_ERROR_STOP 0
\i util/sql/perms.sql
