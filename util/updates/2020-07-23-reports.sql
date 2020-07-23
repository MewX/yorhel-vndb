CREATE TYPE report_status     AS ENUM ('new', 'busy', 'done', 'dismissed');
CREATE TYPE report_type       AS ENUM ('t');

CREATE TABLE reports (
  id         SERIAL PRIMARY KEY,
  date       timestamptz NOT NULL DEFAULT NOW(),
  lastmod    timestamptz,
  uid        integer, -- user who created the report, if logged in
  ip         inet, -- IP address of the visitor, if not logged in
  reason     text NOT NULL,
  rtype      report_type NOT NULL,
  status     report_status NOT NULL DEFAULT 'new',
  object     text NOT NULL, -- The id of the thing being reported
  message    text NOT NULL,
  log        text NOT NULL DEFAULT ''
);
CREATE        INDEX reports_status         ON reports (status,id);

\i sql/perms.sql
