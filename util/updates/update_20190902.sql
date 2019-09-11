ALTER TABLE releases      ALTER COLUMN l_dmm    DROP DEFAULT;
ALTER TABLE releases      ALTER COLUMN l_gyutto DROP DEFAULT;
ALTER TABLE releases_hist ALTER COLUMN l_dmm    DROP DEFAULT;
ALTER TABLE releases_hist ALTER COLUMN l_gyutto DROP DEFAULT;
ALTER TABLE releases      ALTER COLUMN l_dmm    TYPE text[]    USING CASE WHEN l_dmm = ''   THEN '{}' ELSE ARRAY[l_dmm   ] END;
ALTER TABLE releases      ALTER COLUMN l_gyutto TYPE integer[] USING CASE WHEN l_gyutto = 0 THEN '{}' ELSE ARRAY[l_gyutto] END;
ALTER TABLE releases_hist ALTER COLUMN l_dmm    TYPE text[]    USING CASE WHEN l_dmm = ''   THEN '{}' ELSE ARRAY[l_dmm   ] END;
ALTER TABLE releases_hist ALTER COLUMN l_gyutto TYPE integer[] USING CASE WHEN l_gyutto = 0 THEN '{}' ELSE ARRAY[l_gyutto] END;
ALTER TABLE releases      ALTER COLUMN l_dmm    SET DEFAULT '{}';
ALTER TABLE releases      ALTER COLUMN l_gyutto SET DEFAULT '{}';
ALTER TABLE releases_hist ALTER COLUMN l_dmm    SET DEFAULT '{}';
ALTER TABLE releases_hist ALTER COLUMN l_gyutto SET DEFAULT '{}';