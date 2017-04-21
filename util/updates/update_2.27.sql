-- Added 1366x768 resolution
UPDATE releases SET resolution = 15 WHERE resolution = 14 AND NOT EXISTS(SELECT 1 FROM releases WHERE resolution = 15);
UPDATE releases_hist SET resolution = 15 WHERE resolution = 14 AND NOT EXISTS(SELECT 1 FROM releases_hist WHERE resolution = 15);
