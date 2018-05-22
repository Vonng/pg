-- schema monitor
CREATE SCHEMA IF NOT EXISTS monitor;
-- search path for su
ALTER ROLE postgres SET search_path = public, monitor;
SET search_path = public, monitor;
-- extension
CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA monitor;
CREATE EXTENSION IF NOT EXISTS postgres_fdw WITH SCHEMA monitor;
CREATE EXTENSION IF NOT EXISTS file_fdw WITH SCHEMA monitor;
CREATE EXTENSION IF NOT EXISTS pgstattuple WITH SCHEMA monitor;
CREATE EXTENSION IF NOT EXISTS pg_buffercache WITH SCHEMA monitor;
CREATE EXTENSION IF NOT EXISTS pageinspect WITH SCHEMA monitor;
CREATE EXTENSION IF NOT EXISTS pg_repack WITH SCHEMA monitor;
-- parent table: empty
CREATE TABLE monitor.pg_log
(
  log_time               timestamp(3) with time zone,
  user_name              text,
  database_name          text,
  process_id             integer,
  connection_from        text,
  session_id             text,
  session_line_num       bigint,
  command_tag            text,
  session_start_time     timestamp with time zone,
  virtual_transaction_id text,
  transaction_id         bigint,
  error_severity         text,
  sql_state_code         text,
  message                text,
  detail                 text,
  hint                   text,
  internal_query         text,
  internal_query_pos     integer,
  context                text,
  query                  text,
  query_pos              integer,
  location               text,
  application_name       text,
  PRIMARY KEY (session_id, session_line_num)
);
COMMENT ON TABLE monitor.pg_log IS 'PostgreSQL csv log schema';
-- local file server
CREATE SERVER IF NOT EXISTS pg_log FOREIGN DATA WRAPPER file_fdw;
-- Change filename to actual path
CREATE FOREIGN TABLE IF NOT EXISTS monitor.pg_log_mon() INHERITS (monitor.pg_log) SERVER pg_log OPTIONS (filename '/pg/data/log/postgresql-Mon.csv', format 'csv');
CREATE FOREIGN TABLE IF NOT EXISTS monitor.pg_log_tue() INHERITS (monitor.pg_log) SERVER pg_log OPTIONS (filename '/pg/data/log/postgresql-Tue.csv', format 'csv');
CREATE FOREIGN TABLE IF NOT EXISTS monitor.pg_log_wed() INHERITS (monitor.pg_log) SERVER pg_log OPTIONS (filename '/pg/data/log/postgresql-Wed.csv', format 'csv');
CREATE FOREIGN TABLE IF NOT EXISTS monitor.pg_log_thu() INHERITS (monitor.pg_log) SERVER pg_log OPTIONS (filename '/pg/data/log/postgresql-Thu.csv', format 'csv');
CREATE FOREIGN TABLE IF NOT EXISTS monitor.pg_log_fri() INHERITS (monitor.pg_log) SERVER pg_log OPTIONS (filename '/pg/data/log/postgresql-Fri.csv', format 'csv');
CREATE FOREIGN TABLE IF NOT EXISTS monitor.pg_log_sat() INHERITS (monitor.pg_log) SERVER pg_log OPTIONS (filename '/pg/data/log/postgresql-Sat.csv', format 'csv');
CREATE FOREIGN TABLE IF NOT EXISTS monitor.pg_log_sun() INHERITS (monitor.pg_log) SERVER pg_log OPTIONS (filename '/pg/data/log/postgresql-Sun.csv', format 'csv');
-- Bloat Views
CREATE OR REPLACE VIEW monitor.pg_bloat_indexes AS
  WITH btree_index_atts AS (
      SELECT
        pg_namespace.nspname,
        indexclass.relname                                                          AS index_name,
        indexclass.reltuples,
        indexclass.relpages,
        pg_index.indrelid,
        pg_index.indexrelid,
        indexclass.relam,
        tableclass.relname                                                          AS tablename,
        (regexp_split_to_table((pg_index.indkey) :: TEXT, ' ' :: TEXT)) :: SMALLINT AS attnum,
        pg_index.indexrelid                                                         AS index_oid
      FROM ((((pg_index
        JOIN pg_class indexclass ON ((pg_index.indexrelid = indexclass.oid)))
        JOIN pg_class tableclass ON ((pg_index.indrelid = tableclass.oid)))
        JOIN pg_namespace ON ((pg_namespace.oid = indexclass.relnamespace)))
        JOIN pg_am ON ((indexclass.relam = pg_am.oid)))
      WHERE ((pg_am.amname = 'btree' :: NAME) AND (indexclass.relpages > 0))
  ), index_item_sizes AS (
      SELECT
        ind_atts.nspname,
        ind_atts.index_name,
        ind_atts.reltuples,
        ind_atts.relpages,
        ind_atts.relam,
        ind_atts.indrelid                                    AS table_oid,
        ind_atts.index_oid,
        (current_setting('block_size' :: TEXT)) :: NUMERIC   AS bs,
        8                                                    AS maxalign,
        24                                                   AS pagehdr,
        CASE
        WHEN (max(COALESCE(pg_stats.null_frac, (0) :: REAL)) = (0) :: FLOAT)
          THEN 2
        ELSE 6
        END                                                  AS index_tuple_hdr,
        sum((((1) :: FLOAT - COALESCE(pg_stats.null_frac, (0) :: REAL)) *
             (COALESCE(pg_stats.avg_width, 1024)) :: FLOAT)) AS nulldatawidth
      FROM ((pg_attribute
        JOIN btree_index_atts ind_atts
          ON (((pg_attribute.attrelid = ind_atts.indexrelid) AND (pg_attribute.attnum = ind_atts.attnum))))
        JOIN pg_stats ON (((pg_stats.schemaname = ind_atts.nspname) AND (((pg_stats.tablename = ind_atts.tablename) AND
                                                                          ((pg_stats.attname) :: TEXT =
                                                                           pg_get_indexdef(pg_attribute.attrelid,
                                                                                           (pg_attribute.attnum) :: INTEGER,
                                                                                           TRUE))) OR
                                                                         ((pg_stats.tablename = ind_atts.index_name) AND
                                                                          (pg_stats.attname = pg_attribute.attname))))))
      WHERE (pg_attribute.attnum > 0)
      GROUP BY ind_atts.nspname, ind_atts.index_name, ind_atts.reltuples, ind_atts.relpages, ind_atts.relam,
        ind_atts.indrelid, ind_atts.index_oid, (current_setting('block_size' :: TEXT)) :: NUMERIC, 8 :: INTEGER
  ), index_aligned_est AS (
      SELECT
        index_item_sizes.maxalign,
        index_item_sizes.bs,
        index_item_sizes.nspname,
        index_item_sizes.index_name,
        index_item_sizes.reltuples,
        index_item_sizes.relpages,
        index_item_sizes.relam,
        index_item_sizes.table_oid,
        index_item_sizes.index_oid,
        COALESCE(ceil((((index_item_sizes.reltuples * ((((((((6 + index_item_sizes.maxalign) -
                                                             CASE
                                                             WHEN ((index_item_sizes.index_tuple_hdr %
                                                                    index_item_sizes.maxalign) = 0)
                                                               THEN index_item_sizes.maxalign
                                                             ELSE (index_item_sizes.index_tuple_hdr %
                                                                   index_item_sizes.maxalign)
                                                             END)) :: FLOAT + index_item_sizes.nulldatawidth)
                                                          + (index_item_sizes.maxalign) :: FLOAT) - (
                                                           CASE
                                                           WHEN (((index_item_sizes.nulldatawidth) :: INTEGER %
                                                                  index_item_sizes.maxalign) = 0)
                                                             THEN index_item_sizes.maxalign
                                                           ELSE ((index_item_sizes.nulldatawidth) :: INTEGER %
                                                                 index_item_sizes.maxalign)
                                                           END) :: FLOAT)) :: NUMERIC) :: FLOAT) /
                        ((index_item_sizes.bs - (index_item_sizes.pagehdr) :: NUMERIC)) :: FLOAT) +
                       (1) :: FLOAT)), (0) :: FLOAT) AS expected
      FROM index_item_sizes
  ), raw_bloat AS (
      SELECT
        current_database()                                                           AS dbname,
        index_aligned_est.nspname,
        pg_class.relname                                                             AS table_name,
        index_aligned_est.index_name,
        (index_aligned_est.bs * ((index_aligned_est.relpages) :: BIGINT) :: NUMERIC) AS totalbytes,
        index_aligned_est.expected,
        CASE
        WHEN ((index_aligned_est.relpages) :: FLOAT <= index_aligned_est.expected)
          THEN (0) :: NUMERIC
        ELSE (index_aligned_est.bs *
              ((((index_aligned_est.relpages) :: FLOAT - index_aligned_est.expected)) :: BIGINT) :: NUMERIC)
        END                                                                          AS wastedbytes,
        CASE
        WHEN ((index_aligned_est.relpages) :: FLOAT <= index_aligned_est.expected)
          THEN (0) :: NUMERIC
        ELSE (((index_aligned_est.bs * ((((index_aligned_est.relpages) :: FLOAT -
                                          index_aligned_est.expected)) :: BIGINT) :: NUMERIC) * (100) :: NUMERIC) /
              (index_aligned_est.bs * ((index_aligned_est.relpages) :: BIGINT) :: NUMERIC))
        END                                                                          AS realbloat,
        pg_relation_size((index_aligned_est.table_oid) :: REGCLASS)                  AS table_bytes,
        stat.idx_scan                                                                AS index_scans
      FROM ((index_aligned_est
        JOIN pg_class ON ((pg_class.oid = index_aligned_est.table_oid)))
        JOIN pg_stat_user_indexes stat ON ((index_aligned_est.index_oid = stat.indexrelid)))
  ), format_bloat AS (
      SELECT
        raw_bloat.dbname                                             AS database_name,
        raw_bloat.nspname                                            AS schema_name,
        raw_bloat.table_name,
        raw_bloat.index_name,
        round(
            raw_bloat.realbloat)                                     AS bloat_pct,
        round((raw_bloat.wastedbytes / (((1024) :: FLOAT ^
                                         (2) :: FLOAT)) :: NUMERIC)) AS bloat_mb,
        round((raw_bloat.totalbytes / (((1024) :: FLOAT ^ (2) :: FLOAT)) :: NUMERIC),
              3)                                                     AS index_mb,
        round(
            ((raw_bloat.table_bytes) :: NUMERIC / (((1024) :: FLOAT ^ (2) :: FLOAT)) :: NUMERIC),
            3)                                                       AS table_mb,
        raw_bloat.index_scans
      FROM raw_bloat
  )
  SELECT
    format_bloat.database_name                    as datname,
    format_bloat.schema_name                      as nspname,
    format_bloat.table_name                       as relname,
    format_bloat.index_name                       as idxname,
    format_bloat.index_scans                      as idx_scans,
    format_bloat.bloat_pct                        as bloat_pct,
    format_bloat.table_mb,
    format_bloat.index_mb - format_bloat.bloat_mb as actual_mb,
    format_bloat.bloat_mb,
    format_bloat.index_mb                         as total_mb
  FROM format_bloat
  ORDER BY format_bloat.bloat_mb DESC;
COMMENT ON VIEW monitor.pg_bloat_indexes IS 'index bloat monitor';
CREATE OR REPLACE VIEW monitor.pg_bloat_tables AS
  WITH constants AS (
      SELECT
        (current_setting('block_size' :: TEXT)) :: NUMERIC AS bs,
        23                                                 AS hdr,
        8                                                  AS ma
  ), no_stats AS (
      SELECT
        columns.table_schema,
        columns.table_name,
        (psut.n_live_tup) :: NUMERIC                         AS est_rows,
        (pg_table_size((psut.relid) :: REGCLASS)) :: NUMERIC AS table_size
      FROM ((information_schema.columns
        JOIN pg_stat_user_tables psut
          ON ((((columns.table_schema) :: NAME = psut.schemaname) AND ((columns.table_name) :: NAME = psut.relname))))
        LEFT JOIN pg_stats ON (((((columns.table_schema) :: NAME = pg_stats.schemaname) AND
                                 ((columns.table_name) :: NAME = pg_stats.tablename)) AND
                                ((columns.column_name) :: NAME = pg_stats.attname))))
      WHERE ((pg_stats.attname IS NULL) AND ((columns.table_schema) :: TEXT <> ALL
                                             ((ARRAY ['pg_catalog' :: CHARACTER VARYING, 'information_schema' :: CHARACTER VARYING]) :: TEXT [])))
      GROUP BY columns.table_schema, columns.table_name, psut.relid, psut.n_live_tup
  ), null_headers AS (
      SELECT
        ((constants.hdr + 1) + (sum(
                                    CASE
                                    WHEN (pg_stats.null_frac <> (0) :: FLOAT)
                                      THEN 1
                                    ELSE 0
                                    END) / 8))                                     AS nullhdr,
        sum((((1) :: FLOAT - pg_stats.null_frac) * (pg_stats.avg_width) :: FLOAT)) AS datawidth,
        max(pg_stats.null_frac)                                                    AS maxfracsum,
        pg_stats.schemaname,
        pg_stats.tablename,
        constants.hdr,
        constants.ma,
        constants.bs
      FROM ((pg_stats
        CROSS JOIN constants)
        LEFT JOIN no_stats ON (((pg_stats.schemaname = (no_stats.table_schema) :: NAME) AND
                                (pg_stats.tablename = (no_stats.table_name) :: NAME))))
      WHERE (((pg_stats.schemaname <> ALL (ARRAY ['pg_catalog' :: NAME, 'information_schema' :: NAME])) AND
              (no_stats.table_name IS NULL)) AND (EXISTS(SELECT 1
                                                         FROM information_schema.columns
                                                         WHERE
                                                           ((pg_stats.schemaname = (columns.table_schema) :: NAME) AND
                                                            (pg_stats.tablename = (columns.table_name) :: NAME)))))
      GROUP BY pg_stats.schemaname, pg_stats.tablename, constants.hdr, constants.ma, constants.bs
  ), data_headers AS (
      SELECT
        null_headers.ma,
        null_headers.bs,
        null_headers.hdr,
        null_headers.schemaname,
        null_headers.tablename,
        ((null_headers.datawidth + (((null_headers.hdr + null_headers.ma) -
                                     CASE
                                     WHEN ((null_headers.hdr % null_headers.ma) = 0)
                                       THEN null_headers.ma
                                     ELSE (null_headers.hdr % null_headers.ma)
                                     END)) :: FLOAT)) :: NUMERIC AS datahdr,
        (null_headers.maxfracsum * (((null_headers.nullhdr + null_headers.ma) -
                                     CASE
                                     WHEN ((null_headers.nullhdr % (null_headers.ma) :: BIGINT) = 0)
                                       THEN (null_headers.ma) :: BIGINT
                                     ELSE (null_headers.nullhdr % (null_headers.ma) :: BIGINT)
                                     END)) :: FLOAT)             AS nullhdr2
      FROM null_headers
  ), table_estimates AS (
      SELECT
        data_headers.schemaname,
        data_headers.tablename,
        data_headers.bs,
        (pg_class.reltuples) :: NUMERIC                    AS est_rows,
        ((pg_class.relpages) :: NUMERIC * data_headers.bs) AS table_bytes,
        (ceil(((pg_class.reltuples * (
          ((((data_headers.datahdr) :: FLOAT + data_headers.nullhdr2) + (4) :: FLOAT) +
           (data_headers.ma) :: FLOAT) - (
            CASE
            WHEN ((data_headers.datahdr % (data_headers.ma) :: NUMERIC) = (0) :: NUMERIC)
              THEN (data_headers.ma) :: NUMERIC
            ELSE (data_headers.datahdr % (data_headers.ma) :: NUMERIC)
            END) :: FLOAT)) / ((data_headers.bs - (20) :: NUMERIC)) :: FLOAT)) *
         (data_headers.bs) :: FLOAT)                       AS expected_bytes,
        pg_class.reltoastrelid
      FROM ((data_headers
        JOIN pg_class ON ((data_headers.tablename = pg_class.relname)))
        JOIN pg_namespace
          ON (((pg_class.relnamespace = pg_namespace.oid) AND (data_headers.schemaname = pg_namespace.nspname))))
      WHERE (pg_class.relkind = 'r')
  ), estimates_with_toast AS (
      SELECT
        table_estimates.schemaname,
        table_estimates.tablename,
        TRUE                                                                                            AS can_estimate,
        table_estimates.est_rows,
        (table_estimates.table_bytes + ((COALESCE(toast.relpages, 0)) :: NUMERIC * table_estimates.bs)) AS table_bytes,
        (table_estimates.expected_bytes + (ceil((COALESCE(toast.reltuples, (0) :: REAL) / (4) :: FLOAT)) *
                                           (table_estimates.bs) :: FLOAT))                              AS expected_bytes
      FROM (table_estimates
        LEFT JOIN pg_class toast ON (((table_estimates.reltoastrelid = toast.oid) AND (toast.relkind = 't'))))
  ), table_estimates_plus AS (
    SELECT
      current_database() AS databasename,
      estimates_with_toast.schemaname,
      estimates_with_toast.tablename,
      estimates_with_toast.can_estimate,
      estimates_with_toast.est_rows,
      CASE
      WHEN (estimates_with_toast.table_bytes > (0) :: NUMERIC)
        THEN estimates_with_toast.table_bytes
      ELSE NULL :: NUMERIC
      END                AS table_bytes,
      CASE
      WHEN (estimates_with_toast.expected_bytes > (0) :: FLOAT)
        THEN (estimates_with_toast.expected_bytes) :: NUMERIC
      ELSE NULL :: NUMERIC
      END                AS expected_bytes,
      CASE
      WHEN (((estimates_with_toast.expected_bytes > (0) :: FLOAT) AND
             (estimates_with_toast.table_bytes > (0) :: NUMERIC)) AND
            (estimates_with_toast.expected_bytes <= (estimates_with_toast.table_bytes) :: FLOAT))
        THEN (((estimates_with_toast.table_bytes) :: FLOAT - estimates_with_toast.expected_bytes)) :: NUMERIC
      ELSE (0) :: NUMERIC
      END                AS bloat_bytes
    FROM estimates_with_toast
    UNION ALL
    SELECT
      current_database() AS databasename,
      no_stats.table_schema,
      no_stats.table_name,
      FALSE              AS bool,
      no_stats.est_rows,
      no_stats.table_size,
      NULL :: NUMERIC    AS "numeric",
      NULL :: NUMERIC    AS "numeric"
    FROM no_stats
  ), bloat_data AS (
      SELECT
        current_database()                                                                                AS database_name,
        table_estimates_plus.schemaname                                                                   AS schema_name,
        table_estimates_plus.tablename                                                                    AS table_name,
        table_estimates_plus.can_estimate,
        table_estimates_plus.table_bytes,
        round((table_estimates_plus.table_bytes / (((1024) :: FLOAT ^ (2) :: FLOAT)) :: NUMERIC),
              3)                                                                                          AS table_mb,
        table_estimates_plus.expected_bytes,
        round(
            (table_estimates_plus.expected_bytes / (((1024) :: FLOAT ^ (2) :: FLOAT)) :: NUMERIC),
            3)                                                                                            AS expected_mb,
        round(((table_estimates_plus.bloat_bytes * (100) :: NUMERIC) / table_estimates_plus.table_bytes)) AS pct_bloat,
        round((table_estimates_plus.bloat_bytes / ((1024) :: NUMERIC ^ (2) :: NUMERIC)), 2)               AS mb_bloat,
        table_estimates_plus.est_rows
      FROM table_estimates_plus
  )
  SELECT
    bloat_data.database_name as datname,
    bloat_data.schema_name as nspname,
    bloat_data.table_name as relname,
    bloat_data.est_rows,
    bloat_data.pct_bloat as bloat_pct,
    bloat_data.table_mb - bloat_data.mb_bloat as actual_mb,
    bloat_data.mb_bloat as bloat_mb,
    bloat_data.table_mb as total_mb
  FROM bloat_data
    WHERE can_estimate
  ORDER BY bloat_data.pct_bloat DESC;
COMMENT ON VIEW monitor.pg_bloat_tables IS 'monitor table bloat';
