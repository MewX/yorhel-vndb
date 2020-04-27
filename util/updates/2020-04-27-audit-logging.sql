CREATE TABLE audit_log (
  date          timestamptz NOT NULL DEFAULT NOW(),
  by_uid        integer,
  by_name       text,
  by_ip         inet NOT NULL,
  affected_uid  integer,
  affected_name text,
  action        text NOT NULL,
  detail        text
);
\i sql/perms.sql
