-- This script should be run before all other scripts and as a PostgreSQL
-- superuser. It will create the VNDB database and required users.
-- All other SQL scripts should be run by the 'vndb' user.

-- In order to "activate" a user, i.e. to allow login, you need to manually run
-- the following for each user you want to activate:
--   ALTER ROLE rolename LOGIN UNENCRYPTED PASSWORD 'password';

CREATE ROLE vndb;
CREATE DATABASE vndb OWNER vndb;

-- The website
CREATE ROLE vndb_site;
-- Multi
CREATE ROLE vndb_multi;
