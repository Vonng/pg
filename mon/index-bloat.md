---
author: "Vonng"
description: "PostgreSQL索引膨胀的监控与处理"
date: "2018-04-18"
categories: ["DBA"]
tags: ["PostgreSQL","Monitor"]
type: "post"
---



# PostgreSQL索引膨胀的监控与处理

## 背景

索引用久了会出现膨胀，比如索引项的对应记录已经删除，但索引使用的页还没有回收，就浪费了空间，也很影响性能，定期重建索引是维护性能的有效方法。



## 监控视图

* 视图名称：`monitor.pg_stat_bloat_indexes`
* 计算时长：1秒，适合每天检查/手工检查，不适合频繁拉取。
* 验证版本：9.3 ~ 10
* 功能：显示当前数据库索引膨胀情况。

```sql
-- CREATE SCHEMA IF NOT EXISTS monitor;
-- DROP VIEW IF EXISTS monitor.pg_stat_bloat_indexes

CREATE OR REPLACE VIEW monitor.pg_stat_bloat_indexes AS
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
        ind_atts.indrelid                                               AS table_oid,
        ind_atts.index_oid,
        (current_setting('block_size' :: TEXT)) :: NUMERIC              AS bs,
        8                                                               AS maxalign,
        24                                                              AS pagehdr,
        CASE
        WHEN (max(COALESCE(pg_stats.null_frac, (0) :: REAL)) = (0) :: DOUBLE PRECISION)
          THEN 2
        ELSE 6
        END                                                             AS index_tuple_hdr,
        sum((((1) :: DOUBLE PRECISION - COALESCE(pg_stats.null_frac, (0) :: REAL)) *
             (COALESCE(pg_stats.avg_width, 1024)) :: DOUBLE PRECISION)) AS nulldatawidth
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
                                                             END)) :: DOUBLE PRECISION + index_item_sizes.nulldatawidth)
                                                          + (index_item_sizes.maxalign) :: DOUBLE PRECISION) - (
                                                           CASE
                                                           WHEN (((index_item_sizes.nulldatawidth) :: INTEGER %
                                                                  index_item_sizes.maxalign) = 0)
                                                             THEN index_item_sizes.maxalign
                                                           ELSE ((index_item_sizes.nulldatawidth) :: INTEGER %
                                                                 index_item_sizes.maxalign)
                                                           END) :: DOUBLE PRECISION)) :: NUMERIC) :: DOUBLE PRECISION) /
                        ((index_item_sizes.bs - (index_item_sizes.pagehdr) :: NUMERIC)) :: DOUBLE PRECISION) +
                       (1) :: DOUBLE PRECISION)), (0) :: DOUBLE PRECISION) AS expected
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
        WHEN ((index_aligned_est.relpages) :: DOUBLE PRECISION <= index_aligned_est.expected)
          THEN (0) :: NUMERIC
        ELSE (index_aligned_est.bs *
              ((((index_aligned_est.relpages) :: DOUBLE PRECISION - index_aligned_est.expected)) :: BIGINT) :: NUMERIC)
        END                                                                          AS wastedbytes,
        CASE
        WHEN ((index_aligned_est.relpages) :: DOUBLE PRECISION <= index_aligned_est.expected)
          THEN (0) :: NUMERIC
        ELSE (((index_aligned_est.bs * ((((index_aligned_est.relpages) :: DOUBLE PRECISION -
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
        raw_bloat.dbname                                                        AS database_name,
        raw_bloat.nspname                                                       AS schema_name,
        raw_bloat.table_name,
        raw_bloat.index_name,
        round(
            raw_bloat.realbloat)                                                AS bloat_pct,
        round((raw_bloat.wastedbytes / (((1024) :: DOUBLE PRECISION ^
                                         (2) :: DOUBLE PRECISION)) :: NUMERIC)) AS bloat_mb,
        round((raw_bloat.totalbytes / (((1024) :: DOUBLE PRECISION ^ (2) :: DOUBLE PRECISION)) :: NUMERIC),
              3)                                                                AS index_mb,
        round(
            ((raw_bloat.table_bytes) :: NUMERIC / (((1024) :: DOUBLE PRECISION ^ (2) :: DOUBLE PRECISION)) :: NUMERIC),
            3)                                                                  AS table_mb,
        raw_bloat.index_scans
      FROM raw_bloat
  )
  SELECT
    format_bloat.database_name,
    format_bloat.schema_name,
    format_bloat.table_name,
    format_bloat.index_name,
    format_bloat.index_scans,
    format_bloat.bloat_pct,
    format_bloat.bloat_mb,
    format_bloat.index_mb,
    format_bloat.table_mb
  FROM format_bloat
  ORDER BY format_bloat.bloat_mb DESC;
  
```



## 手工维护索引

REINDEX命令可以原地重建索引，但是会锁表，阻塞线上业务。

CREATE INDEX CONCURRENTLY能够并发创建索引，创建新索引后，转移约束关系，走新索引，DROP掉旧索引，就可以在不影响线上使用的清空下完成索引的重建。

更方便的是使用`pg_repack`重建索引：

```bash
pg_repack <dbname> -T 10 -e -i <schema_name>.<index_name>
```

可以配合上面的视图每天在低峰期拉取膨胀最厉害的索引进行重建。