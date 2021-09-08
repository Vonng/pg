# 监控WAL Rate

WAL Rate是一个很重要的监控指标，标识着数据库的负载大小。

通常来说，WAL Rate就是LSN的导数。

LSN需要转换成Bigint，便于处理，可以直接与`0/0`做减法得到BIGINT类型的偏移量。



获取WAL位置的方式包括：

```sql
-- Master, fail on slave
SELECT pg_current_wal_lsn();

-- Slave, null on master
SELECT pg_last_wal_replay_lsn();

-- Universal
SELECT CASE WHEN pg_is_in_recovery() THEN pg_last_wal_replay_lsn() ELSE pg_current_wal_lsn() END;
```





当然，这里只是理论上WAL的生成速率，实际上WAL文件占用的大小可以通过

```yaml
# WAL generate speed, Since 10.0
pg_wal:
  query: "SELECT last_5_min_size_bytes, (SELECT COALESCE(sum(size), 0) FROM pg_catalog.pg_ls_waldir()) AS total_size_bytes
          FROM (SELECT COALESCE(sum(size), 0) AS last_5_min_size_bytes FROM pg_catalog.pg_ls_waldir() WHERE modification > CURRENT_TIMESTAMP - '5 minutes' :: INTERVAL) x;"
  metrics:
  - last_5min_size_bytes:
      usage: "GAUGE"
      description: "Current size in bytes of the last 5 minutes of WAL generation. Includes recycled WALs."
  - total_size_bytes:
      usage: "GAUGE"
      description: "Current size in bytes of the WAL directory"


```

