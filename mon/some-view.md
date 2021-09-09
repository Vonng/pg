```sql
/* pg_stats/pg_stats--1.0.sql */

\echo Use "CREATE EXTENSION pg_stats" to load this file. \quit

-- TABLES
CREATE OR REPLACE VIEW pg_stat_tables
AS
WITH s AS (
SELECT *, cast((n_tup_ins + n_tup_upd + n_tup_del) AS numeric) AS total
       FROM pg_stat_user_tables
)
SELECT s.schemaname,
       s.relname,
       s.relid,
       s.seq_scan,
       s.idx_scan,
       CASE WHEN s.seq_scan + s.idx_scan = 0 THEN 'NaN'::double precision
       	    ELSE round(100 * s.idx_scan/(s.seq_scan+s.idx_scan),2)  END AS idx_scan_ratio,

       s.seq_tup_read,
       s.idx_tup_fetch,

       sio.heap_blks_read,
       sio.heap_blks_hit,
       CASE WHEN sio.heap_blks_read = 0 THEN 0.00
       	    ELSE round(100*sio.heap_blks_hit/(sio.heap_blks_read+sio.heap_blks_hit),2)  END AS hit_ratio,

       s.n_tup_ins,
       s.n_tup_upd,
       s.n_tup_del,
       CASE WHEN s.total = 0 THEN 0.00
       	    ELSE round((100*cast(s.n_tup_ins AS numeric)/s.total) ,2) END AS ins_ratio,
       CASE WHEN s.total = 0 THEN 0.00
       	    ELSE round((100*cast(s.n_tup_upd AS numeric)/s.total) ,2) END AS upd_ratio,
       CASE WHEN s.total = 0 THEN 0.00
       	    ELSE round((100*cast(s.n_tup_del AS numeric)/s.total) ,2) END AS del_ratio,

       s.n_tup_hot_upd,
       CASE WHEN s.n_tup_upd = 0 THEN 'NaN'::double precision
       	    ELSE round(100*cast(cast(n_tup_hot_upd as numeric)/n_tup_upd as numeric), 2) END AS hot_upd_ratio,

       pg_size_pretty(pg_relation_size(sio.relid)) AS "table_size",
       pg_size_pretty(pg_total_relation_size(sio.relid)) AS "total_size",

       s.last_vacuum,
       s.last_autovacuum,
       s.vacuum_count,
       s.autovacuum_count,
       s.last_analyze,
       s.last_autoanalyze,
       s.analyze_count,
       s.autoanalyze_count
FROM s, pg_statio_user_tables AS sio WHERE s.relid = sio.relid ORDER BY relname;

-- INDEXES
CREATE OR REPLACE VIEW pg_stat_indexes
AS
SELECT s.schemaname,
       s.relname,
       s.indexrelname,
       s.relid,
       s.idx_scan,
       s.idx_tup_read,
       s.idx_tup_fetch,
       sio.idx_blks_read,
       sio.idx_blks_hit,
       CASE WHEN sio.idx_blks_read  + sio.idx_blks_hit = 0 THEN 'NaN'::double precision
       	    ELSE round(100 * sio.idx_blks_hit/(sio.idx_blks_read + sio.idx_blks_hit), 2) END AS idx_hit_ratio,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS "index_size"
FROM pg_stat_user_indexes AS s, pg_statio_user_indexes AS sio
WHERE s.relid = sio.relid ORDER BY relname;

-- USERS
CREATE OR REPLACE VIEW pg_stat_users
AS
SELECT datname,
       usename,
       pid,
       backend_start, 
       (current_timestamp - backend_start)::interval(3) AS "login_time"
FROM pg_stat_activity;

-- QUERIES
CREATE OR REPLACE VIEW pg_stat_queries 
AS
SELECT datname,
       usename,
       pid,
       (current_timestamp - xact_start)::interval(3) AS duration, 
       waiting,
       query
FROM pg_stat_activity WHERE pid != pg_backend_pid();

-- LONG TRANSACTIONS
CREATE OR REPLACE VIEW pg_stat_long_trx 
AS
SELECT pid,
       waiting,
       (current_timestamp - xact_start)::interval(3) AS duration, query
FROM pg_stat_activity
WHERE pid <> pg_backend_pid();

-- WAITING LOCKS
CREATE OR REPLACE VIEW pg_stat_waiting_locks
AS
SELECT l.locktype,
       c.relname,
       l.pid,
       l.mode,
       substring(a.query, 1, 6) AS query,
       (current_timestamp - xact_start)::interval(3) AS duration
FROM pg_locks AS l
  LEFT OUTER JOIN pg_stat_activity AS a ON l.pid = a.pid
  LEFT OUTER JOIN pg_class AS c ON l.relation = c.oid 
WHERE  NOT l.granted ORDER BY l.pid;
```

