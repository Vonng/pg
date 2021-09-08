# PSQL快速上手





## PSQLRC文件配置

```sql
\set QUIET 1

-- alias
\set active_session 'SELECT pid, datname, client_addr,state, query from pg_stat_activity;'
\set stat_table 'SELECT * FROM :mytable LIMIT 10;'
\set repl 'SELECT * FROM pg_stat_replication;'
\set pg_kill 'select count(pg_terminate_backend(pid)) from pg_stat_activity where application_name !=\'psql\';'

-- Print date on startup
\echo `date  +"%Y-%m-%d %H:%M:%S"`

-- Set client encoding to UTF8 (to match what is on the server)
\encoding UTF8

-- Do NOT automatically commit after every statement!
-- \set AUTOCOMMIT off

-- Be verbose about feedback
\set VERBOSITY verbose

-- [user]@[host]:[port]/[db]['*' if we are in a transaction]['#' if we are root-like; '>' otherwise]
\set PROMPT1 '%n@%m:%>/%/%x%# '

-- Ensure second prompt is empty, to facilitate easier copying
-- of multiline SQL statements from a psql session into other
-- tools / text editors.
\set PROMPT2 ''

-- Keep a different history file for each database name you log on to.
\set HISTFILE ~/.psql_history- :DBNAME

-- Keep a history of the last 2000 commands.
\set HISTSIZE 2000

-- Instead of displaying nulls as blank space, which look the same as empty strings (but are not the same!), show nulls as [NULL].
\pset null '[NULL]'

-- Show pretty unicode lines between rows and columns in select results.
\pset linestyle unicode

-- Show pretty lines around the outside of select results.
\pset border 2

-- Turn off the pager so that results just keep scrolling by, rather than stopping.
\pset pager off

-- Within columns, wrap long lines so that select results still fit on the display.
\pset format wrapped


\set QUIET 0
```

