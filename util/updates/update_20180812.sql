-- New resolution before 1920x1080
UPDATE releases      SET resolution = 16 WHERE resolution = 15;
UPDATE releases_hist SET resolution = 16 WHERE resolution = 15;
