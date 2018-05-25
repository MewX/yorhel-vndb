SELECT edit_d_init(NULL, NULL);
UPDATE edit_revision SET requester = 1, comments = 'Empty page', ip = '0.0.0.0';
UPDATE edit_docs SET title = 'Privacy Policy';
SELECT edit_d_commit();
