INSERT INTO users (id, username, mail, perm) VALUES (0, 'deleted', 'del@vndb.org', 0);
INSERT INTO users (id, username, mail, perm) VALUES (1, 'multi', 'multi@vndb.org', 0);
INSERT INTO users_prefs (uid, key, value)    VALUES (0, 'notify_nodbedit', '1');
INSERT INTO users_prefs (uid, key, value)    VALUES (1, 'notify_nodbedit', '1');
SELECT setval('users_id_seq', 2);

INSERT INTO stats_cache (section, count) VALUES
  ('users',         1),
  ('vn',            0),
  ('producers',     0),
  ('releases',      0),
  ('chars',         0),
  ('staff',         0),
  ('tags',          0),
  ('traits',        0),
  ('threads',       0),
  ('threads_posts', 0);
