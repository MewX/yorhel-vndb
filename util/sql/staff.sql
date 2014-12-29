-- database schema for staff/seiyuu

ALTER TYPE dbentry_type ADD VALUE 's';
CREATE TYPE credit_type AS ENUM ('script', 'chardesign', 'music', 'director', 'art', 'songs', 'staff');

CREATE TABLE staff (
    id SERIAL NOT NULL PRIMARY KEY,
    latest      integer NOT NULL DEFAULT 0,
    locked      boolean NOT NULL DEFAULT FALSE,
    hidden      boolean NOT NULL DEFAULT FALSE
);

CREATE TABLE staff_rev (
    id          integer NOT NULL PRIMARY KEY,
    sid         integer NOT NULL, -- references staff
    aid         integer NOT NULL, -- true name, references staff_alias
    image       integer NOT NULL DEFAULT 0,
    gender      gender  NOT NULL DEFAULT 'unknown',
    lang        language NOT NULL DEFAULT 'ja',
    "desc"      text    NOT NULL DEFAULT '',
    l_wp        varchar(150) NOT NULL DEFAULT ''
);

CREATE TABLE staff_alias (
    id SERIAL NOT NULL,
    rid         integer, -- references staff_rev
    name        varchar(200) NOT NULL DEFAULT '',
    original    varchar(200) NOT NULL DEFAULT '',
    PRIMARY KEY (id, rid)
);

CREATE TABLE vn_staff (
    vid         integer NOT NULL, -- vn_rev reference
    aid         integer NOT NULL, -- staff_alias reference
    role        credit_type NOT NULL DEFAULT 'staff',
    note        varchar(250) NOT NULL DEFAULT '',
    PRIMARY KEY (vid, aid, role)
);

CREATE TABLE vn_seiyuu (
    vid         integer NOT NULL, -- vn_rev reference
    aid         integer NOT NULL, -- staff_alias reference
    cid         integer NOT NULL, -- chars reference
    note        varchar(250) NOT NULL DEFAULT '',
    PRIMARY KEY (vid, aid, cid)
);

ALTER TABLE staff               ADD FOREIGN KEY (latest)    REFERENCES staff_rev     (id) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE staff_alias         ADD FOREIGN KEY (rid)       REFERENCES staff_rev     (id) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE staff_rev           ADD FOREIGN KEY (id)        REFERENCES changes       (id);
ALTER TABLE staff_rev           ADD FOREIGN KEY (sid)       REFERENCES staff         (id);
ALTER TABLE staff_rev           ADD FOREIGN KEY (aid,id)    REFERENCES staff_alias   (id,rid);
ALTER TABLE vn_staff            ADD FOREIGN KEY (vid)       REFERENCES vn_rev        (id);
ALTER TABLE vn_seiyuu           ADD FOREIGN KEY (cid)       REFERENCES chars         (id);
ALTER TABLE vn_seiyuu           ADD FOREIGN KEY (vid)       REFERENCES vn_rev        (id);

CREATE INDEX vn_staff_vid       ON vn_staff (vid);
CREATE INDEX vn_staff_aid       ON vn_staff (aid);