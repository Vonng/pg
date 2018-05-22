-- CMDB Table
CREATE TABLE nodes (
  id       TEXT PRIMARY KEY,
  name     TEXT,
  port     INTEGER DEFAULT 5432,
  dbname   TEXT,
  username TEXT default 'postgres',
  password TEXT DEFAULT 'postgres',
  ctime    TEXT default current_timestamp
);
COMMENT ON TABLE nodes IS 'PostgreSQL Node List';


