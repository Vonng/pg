---
author: "Vonng"
description: "PostgreSQL表监控"
date: "2018-04-18"
categories: ["DBA"]
tags: ["PostgreSQL","Monitor"]
type: "post"
---



# PostgreSQL表膨胀监控

## 背景

索引用久了会出现膨胀，比如索引项的对应记录已经删除，但索引使用的页还没有回收，就浪费了空间，也很影响性能，定期重建索引是维护性能的有效方法。

## 监控项目



## 手工监控

手工精确检查可以使用自带的`pgstattuple`插件，但只有SUPERUSER可以使用。

```sql
-- 创建插件
CREATE EXTENSION pgstattuple;

SELECT * FROM pgstattuple('user_school_validations');

-[ RECORD 1 ]------+----------
table_len          | 213360640
tuple_count        | 3395382
tuple_len          | 190141392
tuple_percent      | 89.12
dead_tuple_count   | 10747
dead_tuple_len     | 601832
dead_tuple_percent | 0.28
free_space         | 4202816
free_percent       | 1.97
```

此种方法精确，但相对缓慢。





 table_len | tuple_count | tuple_len | tuple_percent | dead_tuple_count | dead_tuple_len | dead_tuple_percent | free_space | free_percent
----------- | ------------- | ----------- | --------------- | ------------------ | ---------------- | -------------------- | ------------ | --------------
 213360640 |     3395307 | 190137192 |         89.12 |            10675 |         597800 |               0.28 |    4211516 |         1.97





## 监控表大小

```sql
SELECT
  *,
  total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
FROM (
       SELECT
         c.oid,
         nspname                               AS schema_name,
         relname                               AS table_name,
         c.reltuples :: BIGINT                 AS rows,
         pg_total_relation_size(c.oid)         AS total_bytes,
         pg_indexes_size(c.oid)                AS index_bytes,
         pg_total_relation_size(reltoastrelid) AS toast_bytes
       FROM pg_class c LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE relkind = 'r' AND nspname <> ALL (ARRAY ['monitor', 'pg_catalog', 'information_schema'])
     ) a;


```



## 监控表IO



## 监控视图

* 视图名称：`monitor.pg_stat_bloat_indexes`
* 计算时长：1秒，适合每天检查/手工检查，不适合频繁拉取。
* 验证版本：9.3 ~ 10
* 功能：显示当前数据库索引膨胀情况。

| Column        | Type    | Storage | Description      |
| ------------- | ------- | ------- | ---------------- |
| database_name | name    | plain   | 数据库名         |
| schema_name   | name    | plain   | 模式名           |
| table_name    | name    | plain   | 表名             |
| pct_bloat     | numeric | main    | 膨胀率           |
| mb_bloat      | numeric | main    | 膨胀大小：以MB计 |
| table_mb      | numeric | main    | 表总大小：以MB计 |

```sql
-- CREATE SCHEMA IF NOT EXISTS monitor;
-- DROP VIEW IF EXISTS monitor.pg_stat_bloat_tables

CREATE OR REPLACE VIEW monitor.pg_stat_bloat_tables AS
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
        ((constants.hdr  |  1)  |  (sum(
                                    CASE
                                    WHEN (pg_stats.null_frac <> (0) :: DOUBLE PRECISION)
                                      THEN 1
                                    ELSE 0
                                    END) / 8))                                                           AS nullhdr,
        sum((((1) :: DOUBLE PRECISION - pg_stats.null_frac) * (pg_stats.avg_width) :: DOUBLE PRECISION)) AS datawidth,
        max(pg_stats.null_frac)                                                                          AS maxfracsum,
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
        ((null_headers.datawidth  |  (((null_headers.hdr  |  null_headers.ma) -
                                     CASE
                                     WHEN ((null_headers.hdr % null_headers.ma) = 0)
                                       THEN null_headers.ma
                                     ELSE (null_headers.hdr % null_headers.ma)
                                     END)) :: DOUBLE PRECISION)) :: NUMERIC AS datahdr,
        (null_headers.maxfracsum * (((null_headers.nullhdr  |  null_headers.ma) -
                                     CASE
                                     WHEN ((null_headers.nullhdr % (null_headers.ma) :: BIGINT) = 0)
                                       THEN (null_headers.ma) :: BIGINT
                                     ELSE (null_headers.nullhdr % (null_headers.ma) :: BIGINT)
                                     END)) :: DOUBLE PRECISION)             AS nullhdr2
      FROM null_headers
  ), table_estimates AS (
      SELECT
        data_headers.schemaname,
        data_headers.tablename,
        data_headers.bs,
        (pg_class.reltuples) :: NUMERIC                    AS est_rows,
        ((pg_class.relpages) :: NUMERIC * data_headers.bs) AS table_bytes,
        (ceil(((pg_class.reltuples * (
          ((((data_headers.datahdr) :: DOUBLE PRECISION  |  data_headers.nullhdr2)  |  (4) :: DOUBLE PRECISION)  | 
           (data_headers.ma) :: DOUBLE PRECISION) - (
            CASE
            WHEN ((data_headers.datahdr % (data_headers.ma) :: NUMERIC) = (0) :: NUMERIC)
              THEN (data_headers.ma) :: NUMERIC
            ELSE (data_headers.datahdr % (data_headers.ma) :: NUMERIC)
            END) :: DOUBLE PRECISION)) / ((data_headers.bs - (20) :: NUMERIC)) :: DOUBLE PRECISION)) *
         (data_headers.bs) :: DOUBLE PRECISION)            AS expected_bytes,
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
        (table_estimates.table_bytes  |  ((COALESCE(toast.relpages, 0)) :: NUMERIC * table_estimates.bs)) AS table_bytes,
        (table_estimates.expected_bytes  |  (ceil((COALESCE(toast.reltuples, (0) :: REAL) / (4) :: DOUBLE PRECISION)) *
                                           (table_estimates.bs) :: DOUBLE PRECISION))                   AS expected_bytes
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
      WHEN (estimates_with_toast.expected_bytes > (0) :: DOUBLE PRECISION)
        THEN (estimates_with_toast.expected_bytes) :: NUMERIC
      ELSE NULL :: NUMERIC
      END                AS expected_bytes,
      CASE
      WHEN (((estimates_with_toast.expected_bytes > (0) :: DOUBLE PRECISION) AND
             (estimates_with_toast.table_bytes > (0) :: NUMERIC)) AND
            (estimates_with_toast.expected_bytes <= (estimates_with_toast.table_bytes) :: DOUBLE PRECISION))
        THEN (((estimates_with_toast.table_bytes) :: DOUBLE PRECISION - estimates_with_toast.expected_bytes)) :: NUMERIC
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
        round((table_estimates_plus.table_bytes / (((1024) :: DOUBLE PRECISION ^ (2) :: DOUBLE PRECISION)) :: NUMERIC),
              3)                                                                                          AS table_mb,
        table_estimates_plus.expected_bytes,
        round(
            (table_estimates_plus.expected_bytes / (((1024) :: DOUBLE PRECISION ^ (2) :: DOUBLE PRECISION)) :: NUMERIC),
            3)                                                                                            AS expected_mb,
        round(((table_estimates_plus.bloat_bytes * (100) :: NUMERIC) / table_estimates_plus.table_bytes)) AS pct_bloat,
        round((table_estimates_plus.bloat_bytes / ((1024) :: NUMERIC ^ (2) :: NUMERIC)), 2)               AS mb_bloat,
        table_estimates_plus.est_rows
      FROM table_estimates_plus
  )
  SELECT
    bloat_data.database_name,
    bloat_data.schema_name,
    bloat_data.table_name,
    bloat_data.pct_bloat,
    bloat_data.mb_bloat,
    bloat_data.table_mb,
    bloat_data.est_rows
  FROM bloat_data
  WHERE can_estimate
  ORDER BY bloat_data.pct_bloat DESC;

COMMENT ON VIEW monitor.pg_stat_bloat_tables IS 'monitor table bloat rate';
```

找出需要清理的表

```sql
CREATE OR REPLACE FUNCTION monitor.select_bloat_indexes() RETURNS TEXT AS
$$
WITH indexes_bloat AS (
    SELECT
      schema_name || '.' || index_name as idx_name,
      index_mb - bloat_mb as real_mb,
      bloat_pct
    FROM monitor.pg_bloat_indexes
    WHERE schema_name NOT IN ('dba', 'monitor', 'trash') AND bloat_pct > 20
    ORDER BY 2 DESC,3 DESC
)
(SELECT idx_name FROM indexes_bloat WHERE real_mb < 100 AND bloat_pct > 40 LIMIT 30) UNION -- 30 small
(SELECT idx_name FROM indexes_bloat WHERE real_mb BETWEEN 100 AND 2000 LIMIT 10) UNION -- 10 medium
(SELECT idx_name FROM indexes_bloat WHERE real_mb BETWEEN 2000 AND 10000 LIMIT 3); -- 3 big
-- index bigger than 10g require manual check
$$ LANGUAGE SQL VOLATILE;

COMMENT ON FUNCTION monitor.select_bloat_indexes() IS 'list indexes that needs rebuild';
```



## 维护表

`VACUUM <tablename>` 可以回收表空间，不锁表。autovacuum会自动执行清理。

当出现异常：文件损坏，坏块时，清理可能会出错，这时候需要人工介入，否则年龄过大会有大麻烦。