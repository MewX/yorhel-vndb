INSERT INTO users (id, username, mail, notify_dbedit) VALUES (0, 'deleted', 'del@vndb.org', FALSE);
INSERT INTO users (id, username, mail, notify_dbedit) VALUES (1, 'multi', 'multi@vndb.org', FALSE);
SELECT setval('users_id_seq', 2);

INSERT INTO stats_cache (section, count) VALUES
  ('vn',            0),
  ('producers',     0),
  ('releases',      0),
  ('chars',         0),
  ('staff',         0),
  ('tags',          0),
  ('traits',        0);
