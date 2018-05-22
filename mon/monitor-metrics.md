

# 需要监控的指标



## 静态

静态数据在初始化时获取，按需更新（或定时更新、例如每周）

数据库的配置项：pg_config，pg_hba，pg_settings，配置文件，主从拓扑逻辑





## 日常监控

执行时间较慢，重要不紧急的监控项，可以按照小时或天为单位进行。包括：

数据库年龄

数据库尺寸

数据表年龄

数据表大小（相关Toast大小，相关索引大小，膨胀率，估计行数）

索引大小（膨胀率，scan次数）





## 实时监控

实时拉取数据库的重要监控指标，秒/分钟级别



基本的监控指标：

* CPU：（idle, wait,sys,user,load1,load5,load15）
* 内存：（free,buffers,cached,swap,dirty）


* 连接池（前后端连接数，平均响应时间）
* 复制延迟（WAL落后字节，延迟时间（v10））
* 连接数与状态（idle, idle in xact, waiting, running）
* 查询活动
* WAL生成速率
* 事务数量（提交数，回滚数，TPS，QPS）
* IO事件（页面命中，Miss数，元组增删改查总数）
* **函数**（调用次数，执行时间）
* **表**（访问次数，增删改查统计）







一些比较重要的指标如下：

```sql
CREATE TABLE pg_facts (
  ts            TIMESTAMP,
  id            CHAR(8),
  age           INTEGER,
  db_size       BIGINT,
  slave_lag     FLOAT,
  total_conn    INTEGER,
  idle_conn     INTEGER,
  max_idle_time INTEGER,
  xact_commit   BIGINT,
  xact_rollback BIGINT,
  xact_total    BIGINT,
  blks_fetch    BIGINT,
  blks_read     BIGINT,
  blks_hit      BIGINT,
  tup_returned  BIGINT,
  tup_fetched   BIGINT,
  tup_inserted  BIGINT,
  tup_updated   BIGINT,
  tup_deleted   BIGINT
);

COMMENT ON TABLE pg_facts IS 'pg fact metrics';
COMMENT ON COLUMN pg_facts.ts IS 'timestamp, round to 5s bucket';
COMMENT ON COLUMN pg_facts.id IS 'node id';
COMMENT ON COLUMN pg_facts.age IS 'transaction id age, from age(pg_database.datfrozenxid)';
COMMENT ON COLUMN pg_facts.db_size IS 'database size in bytes';
COMMENT ON COLUMN pg_facts.slave_lag IS 'slave replication delay in ms (if it is a slave, not exact)';
COMMENT ON COLUMN pg_facts.total_conn IS 'number of backends currently connected to this database. gauge';
COMMENT ON COLUMN pg_facts.idle_conn IS 'number of conn in state "idle in transaction" from pg_stat_get_activity';
COMMENT ON COLUMN pg_facts.max_idle_time IS 'max idle in transaction duration';
COMMENT ON COLUMN pg_facts.xact_commit IS 'number of transactions in this database that have been committed, counter';
COMMENT ON COLUMN pg_facts.xact_rollback IS 'number of transactions in this database that have been rolled back, counter';
COMMENT ON COLUMN pg_facts.xact_total IS 'total transaction(commit+rollback), counter';
COMMENT ON COLUMN pg_facts.blks_fetch IS 'number of disk blocks fetched(read+hit) in this database, counter';
COMMENT ON COLUMN pg_facts.blks_read IS 'number of disk blocks read from disk in this database, counter';
COMMENT ON COLUMN pg_facts.blks_hit IS 'number of disk blocks hit shared buf in this database, counter';
COMMENT ON COLUMN pg_facts.tup_returned IS 'number of rows returned by queries in this database, counter';
COMMENT ON COLUMN pg_facts.tup_fetched IS 'number of rows fetched by queries in this database, counter';
COMMENT ON COLUMN pg_facts.tup_inserted IS 'number of rows inserted by queries in this database, counter';
COMMENT ON COLUMN pg_facts.tup_updated IS 'number of rows updated by queries in this database, counter';
COMMENT ON COLUMN pg_facts.tup_deleted IS 'number of rows deleted by queries in this database, counter';

```



