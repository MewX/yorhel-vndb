ALTER TABLE traits DROP CONSTRAINT traits_addedby_fkey;
ALTER TABLE traits ADD CONSTRAINT traits_addedby_fkey FOREIGN KEY (addedby) REFERENCES users (id) ON DELETE SET DEFAULT;
