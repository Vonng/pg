---
title: "找出没用过的索引"
date: 2018-02-04
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  索引很有用， 但不是免费的。没用到的索引是一种浪费，使用这里的方法找出未使用的索引
---


索引很有用， 但不是免费的。没用到的索引是一种浪费，使用以下SQL找出未使用的索引：


* 首先要排除用于实现约束的索引（删不得）
* 表达式索引（`pg_index.indkey`中含有0号字段）
* 然后找出走索引扫描的次数为0的索引（也可以换个更宽松的条件，比如扫描小于1000次的）



## 找出没有使用的索引

- 视图名称：`monitor.v_bloat_indexes`
- 计算时长：1秒，适合每天检查/手工检查，不适合频繁拉取。
- 验证版本：9.3 ~ 10
- 功能：显示当前数据库索引膨胀情况。

在版本9.3与10.4上工作良好。视图形式

```sql
-- CREATE SCHEMA IF NOT EXISTS monitor;
-- DROP VIEW IF EXISTS monitor.pg_stat_dummy_indexes;

CREATE OR REPLACE VIEW monitor.pg_stat_dummy_indexes AS
SELECT s.schemaname,
       s.relname AS tablename,
       s.indexrelname AS indexname,
       pg_relation_size(s.indexrelid) AS index_size
FROM pg_catalog.pg_stat_user_indexes s
   JOIN pg_catalog.pg_index i ON s.indexrelid = i.indexrelid
WHERE s.idx_scan = 0      -- has never been scanned
  AND 0 <>ALL (i.indkey)  -- no index column is an expression
  AND NOT EXISTS          -- does not enforce a constraint
         (SELECT 1 FROM pg_catalog.pg_constraint c
          WHERE c.conindid = s.indexrelid)
ORDER BY pg_relation_size(s.indexrelid) DESC;

COMMENT ON VIEW monitor.pg_stat_dummy_indexes IS 'monitor unused indexes'
```

```sql
-- 人类可读的手工查询
SELECT s.schemaname,
       s.relname AS tablename,
       s.indexrelname AS indexname,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS index_size
FROM pg_catalog.pg_stat_user_indexes s
   JOIN pg_catalog.pg_index i ON s.indexrelid = i.indexrelid
WHERE s.idx_scan = 0      -- has never been scanned
  AND 0 <>ALL (i.indkey)  -- no index column is an expression
  AND NOT EXISTS          -- does not enforce a constraint
         (SELECT 1 FROM pg_catalog.pg_constraint c
          WHERE c.conindid = s.indexrelid)
ORDER BY pg_relation_size(s.indexrelid) DESC;
```



### 批量生成删除索引的命令

```sql
SELECT 'DROP INDEX CONCURRENTLY IF EXISTS "' 
	|| s.schemaname || '"."' || s.indexrelname || '";'
FROM pg_catalog.pg_stat_user_indexes s
   JOIN pg_catalog.pg_index i ON s.indexrelid = i.indexrelid
WHERE s.idx_scan = 0      -- has never been scanned
  AND 0 <>ALL (i.indkey)  -- no index column is an expression
  AND NOT EXISTS          -- does not enforce a constraint
         (SELECT 1 FROM pg_catalog.pg_constraint c
          WHERE c.conindid = s.indexrelid)
ORDER BY pg_relation_size(s.indexrelid) DESC;
```





## 找出重复的索引

检查是否有索引工作在相同的表的相同列上，但要注意条件索引。

```sql
SELECT
  indrelid :: regclass              AS table_name,
  array_agg(indexrelid :: regclass) AS indexes
FROM pg_index
GROUP BY
  indrelid, indkey
HAVING COUNT(*) > 1;
```

