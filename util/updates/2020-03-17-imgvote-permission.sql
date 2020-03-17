ALTER TABLE users ALTER COLUMN perm SET DEFAULT 1 + 4 + 8 + 16;
-- Give the 'imgvote' permission to everyone who has the 'edit' permission.
UPDATE users SET perm = perm | (CASE WHEN perm & 4 = 4 THEN 8 ELSE 0 END);
