-- vndb_site

DROP OWNED BY vndb_site;
GRANT CONNECT, TEMP ON DATABASE :DBNAME TO vndb_site;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO vndb_site;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO vndb_site;

GRANT SELECT, INSERT                 ON anime                    TO vndb_site;
GRANT SELECT, INSERT                 ON changes                  TO vndb_site;
GRANT SELECT, INSERT, UPDATE         ON chars                    TO vndb_site;
GRANT SELECT, INSERT                 ON chars_hist               TO vndb_site;
GRANT SELECT, INSERT,         DELETE ON chars_traits             TO vndb_site;
GRANT SELECT, INSERT                 ON chars_traits_hist        TO vndb_site;
GRANT SELECT, INSERT,         DELETE ON chars_vns                TO vndb_site;
GRANT SELECT, INSERT                 ON chars_vns_hist           TO vndb_site;
GRANT SELECT, INSERT, UPDATE         ON docs                     TO vndb_site;
GRANT SELECT, INSERT                 ON docs_hist                TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON login_throttle           TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON notifications            TO vndb_site;
GRANT SELECT, INSERT, UPDATE         ON producers                TO vndb_site;
GRANT SELECT, INSERT                 ON producers_hist           TO vndb_site;
GRANT SELECT, INSERT,         DELETE ON producers_relations      TO vndb_site;
GRANT SELECT, INSERT                 ON producers_relations_hist TO vndb_site;
GRANT SELECT                         ON quotes                   TO vndb_site;
GRANT SELECT, INSERT, UPDATE         ON releases                 TO vndb_site;
GRANT SELECT, INSERT                 ON releases_hist            TO vndb_site;
GRANT SELECT, INSERT,         DELETE ON releases_lang            TO vndb_site;
GRANT SELECT, INSERT                 ON releases_lang_hist       TO vndb_site;
GRANT SELECT, INSERT,         DELETE ON releases_media           TO vndb_site;
GRANT SELECT, INSERT                 ON releases_media_hist      TO vndb_site;
GRANT SELECT, INSERT,         DELETE ON releases_platforms       TO vndb_site;
GRANT SELECT, INSERT                 ON releases_platforms_hist  TO vndb_site;
GRANT SELECT, INSERT,         DELETE ON releases_producers       TO vndb_site;
GRANT SELECT, INSERT                 ON releases_producers_hist  TO vndb_site;
GRANT SELECT, INSERT,         DELETE ON releases_vn              TO vndb_site;
GRANT SELECT, INSERT                 ON releases_vn_hist         TO vndb_site;
GRANT SELECT                         ON relgraphs                TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON rlists                   TO vndb_site;
GRANT SELECT, INSERT, UPDATE         ON screenshots              TO vndb_site;
-- No access to the 'sessions' table, managed by the user_* functions.
GRANT SELECT                         ON shop_denpa               TO vndb_site;
GRANT SELECT                         ON shop_dlsite              TO vndb_site;
GRANT SELECT                         ON shop_jlist               TO vndb_site;
GRANT SELECT                         ON shop_mg                  TO vndb_site;
GRANT SELECT                         ON shop_playasia            TO vndb_site;
GRANT SELECT, INSERT, UPDATE         ON staff                    TO vndb_site;
GRANT SELECT, INSERT,         DELETE ON staff_alias              TO vndb_site;
GRANT SELECT, INSERT                 ON staff_alias_hist         TO vndb_site;
GRANT SELECT, INSERT                 ON staff_hist               TO vndb_site;
GRANT SELECT, UPDATE                 ON stats_cache              TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON tags                     TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON tags_aliases             TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON tags_parents             TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON tags_vn                  TO vndb_site;
GRANT SELECT                         ON tags_vn_inherit          TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON threads                  TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON threads_boards           TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON threads_poll_options     TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON threads_poll_votes       TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON threads_posts            TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON traits                   TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON traits_chars             TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON traits_parents           TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON ulists                   TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON ulists_labels            TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON ulists_vn_labels         TO vndb_site;

-- users table is special; The 'perm', 'passwd' and 'mail' columns are
-- protected and can only be accessed through the user_* functions.
GRANT SELECT (id, username,       registered, perm, c_votes, c_changes, ip, c_tags, ign_votes, email_confirmed, skin, customcss, filter_vn, filter_release, show_nsfw, hide_list, notify_dbedit, notify_announce, vn_list_own, vn_list_wish, tags_all, tags_cont, tags_ero, tags_tech, spoilers, traits_sexual, nodistract_can, nodistract_noads, nodistract_nofancy, support_can, support_enabled, uniname_can, uniname, pubskin_can, pubskin_enabled),
      INSERT (id, username, mail, registered,       c_votes, c_changes, ip, c_tags, ign_votes, email_confirmed, skin, customcss, filter_vn, filter_release, show_nsfw, hide_list, notify_dbedit, notify_announce, vn_list_own, vn_list_wish, tags_all, tags_cont, tags_ero, tags_tech, spoilers, traits_sexual, nodistract_can, nodistract_noads, nodistract_nofancy, support_can, support_enabled, uniname_can, uniname, pubskin_can, pubskin_enabled),
      UPDATE (    username,       registered,       c_votes, c_changes, ip, c_tags, ign_votes, email_confirmed, skin, customcss, filter_vn, filter_release, show_nsfw, hide_list, notify_dbedit, notify_announce, vn_list_own, vn_list_wish, tags_all, tags_cont, tags_ero, tags_tech, spoilers, traits_sexual, nodistract_can, nodistract_noads, nodistract_nofancy, support_can, support_enabled, uniname_can, uniname, pubskin_can, pubskin_enabled) ON users TO vndb_site;

GRANT SELECT, INSERT, UPDATE         ON vn                       TO vndb_site;
GRANT SELECT, INSERT,         DELETE ON vn_anime                 TO vndb_site;
GRANT SELECT, INSERT                 ON vn_anime_hist            TO vndb_site;
GRANT SELECT, INSERT                 ON vn_hist                  TO vndb_site;
GRANT SELECT, INSERT,         DELETE ON vn_relations             TO vndb_site;
GRANT SELECT, INSERT                 ON vn_relations_hist        TO vndb_site;
GRANT SELECT, INSERT,         DELETE ON vn_screenshots           TO vndb_site;
GRANT SELECT, INSERT                 ON vn_screenshots_hist      TO vndb_site;
GRANT SELECT, INSERT,         DELETE ON vn_seiyuu                TO vndb_site;
GRANT SELECT, INSERT                 ON vn_seiyuu_hist           TO vndb_site;
GRANT SELECT, INSERT,         DELETE ON vn_staff                 TO vndb_site;
GRANT SELECT, INSERT                 ON vn_staff_hist            TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON vnlists                  TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON votes                    TO vndb_site;
GRANT SELECT, INSERT, UPDATE, DELETE ON wlists                   TO vndb_site;
GRANT SELECT, INSERT                 ON wikidata                 TO vndb_site;




-- vndb_multi
-- (Assuming all modules are loaded)

DROP OWNED BY vndb_multi;
GRANT CONNECT, TEMP ON DATABASE :DBNAME TO vndb_multi;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO vndb_multi;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO vndb_multi;

GRANT SELECT,         UPDATE         ON anime                    TO vndb_multi;
GRANT SELECT                         ON changes                  TO vndb_multi;
GRANT SELECT                         ON chars                    TO vndb_multi;
GRANT SELECT                         ON chars_hist               TO vndb_multi;
GRANT SELECT                         ON chars_traits             TO vndb_multi;
GRANT SELECT                         ON chars_vns                TO vndb_multi;
GRANT SELECT                         ON docs                     TO vndb_multi;
GRANT SELECT                         ON docs_hist                TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON login_throttle           TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON notifications            TO vndb_multi;
GRANT SELECT,         UPDATE         ON producers                TO vndb_multi;
GRANT SELECT                         ON producers_hist           TO vndb_multi;
GRANT SELECT                         ON producers_relations      TO vndb_multi;
GRANT SELECT                         ON quotes                   TO vndb_multi;
GRANT SELECT                         ON releases                 TO vndb_multi;
GRANT SELECT                         ON releases_hist            TO vndb_multi;
GRANT SELECT                         ON releases_lang            TO vndb_multi;
GRANT SELECT                         ON releases_media           TO vndb_multi;
GRANT SELECT                         ON releases_platforms       TO vndb_multi;
GRANT SELECT                         ON releases_producers       TO vndb_multi;
GRANT SELECT                         ON releases_vn              TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON relgraphs                TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON rlists                   TO vndb_multi;
GRANT SELECT                         ON screenshots              TO vndb_multi;
GRANT SELECT (expires)               ON sessions                 TO vndb_multi;
GRANT                         DELETE ON sessions                 TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_denpa               TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_dlsite              TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_jlist               TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_mg                  TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_playasia            TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_playasia_gtin       TO vndb_multi;
GRANT SELECT                         ON staff                    TO vndb_multi;
GRANT SELECT                         ON staff_alias              TO vndb_multi;
GRANT SELECT                         ON staff_alias_hist         TO vndb_multi;
GRANT SELECT                         ON staff_hist               TO vndb_multi;
GRANT SELECT,         UPDATE         ON stats_cache              TO vndb_multi;
GRANT SELECT                         ON tags                     TO vndb_multi;
GRANT SELECT                         ON tags_aliases             TO vndb_multi;
GRANT SELECT                         ON tags_parents             TO vndb_multi;
GRANT SELECT                         ON tags_vn                  TO vndb_multi;
GRANT SELECT                         ON tags_vn_inherit          TO vndb_multi; -- tag_vn_calc() is SECURITY DEFINER due to index drop/create, so no extra perms needed here
GRANT SELECT                         ON threads                  TO vndb_multi;
GRANT SELECT                         ON threads_boards           TO vndb_multi;
GRANT SELECT                         ON threads_posts            TO vndb_multi;
GRANT SELECT,         UPDATE         ON traits                   TO vndb_multi;
GRANT SELECT                         ON traits_chars             TO vndb_multi; -- traits_chars_calc() is SECURITY DEFINER
GRANT SELECT                         ON traits_parents           TO vndb_multi;
GRANT SELECT (id, username, registered, c_votes, c_changes, c_tags, ign_votes, email_confirmed, hide_list, notify_dbedit, notify_announce),
      UPDATE (                          c_votes, c_changes, c_tags) ON users TO vndb_multi;
GRANT                         DELETE ON users                    TO vndb_multi;
GRANT SELECT,         UPDATE         ON vn                       TO vndb_multi;
GRANT SELECT                         ON vn_anime                 TO vndb_multi;
GRANT SELECT                         ON vn_hist                  TO vndb_multi;
GRANT SELECT                         ON vn_relations             TO vndb_multi;
GRANT SELECT                         ON vn_screenshots           TO vndb_multi;
GRANT SELECT                         ON vn_screenshots_hist      TO vndb_multi;
GRANT SELECT                         ON vn_seiyuu                TO vndb_multi;
GRANT SELECT                         ON vn_staff                 TO vndb_multi;
GRANT SELECT                         ON vn_staff_hist            TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON vnlists                  TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON votes                    TO vndb_multi;
GRANT SELECT, INSERT, UPDATE, DELETE ON wlists                   TO vndb_multi;
GRANT SELECT, INSERT, UPDATE         ON wikidata                 TO vndb_multi;
