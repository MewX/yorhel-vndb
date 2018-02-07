-- Producer aliases are now separated by newline
UPDATE producers SET alias = regexp_replace(alias, '\s*,\s*', E'\n', 'g');
UPDATE producers_hist SET alias = regexp_replace(alias, '\s*,\s*', E'\n', 'g');
