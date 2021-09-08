# 复制延迟监控



注意9.6和10之间有明显的差别



```yaml
# Database replication statistics
# Add more labels & more metrics, compatible with default metrics
pg_replication:
  query: "SELECT
            client_addr,
            application_name,
            sent_lsn - '0/0'                AS sent_lsn,
            write_lsn - '0/0'               AS write_lsn,
            flush_lsn - '0/0'               AS flush_lsn,
            replay_lsn - '0/0'              AS replay_lsn,
            extract(EPOCH FROM write_lag)   AS write_lag,
            extract(EPOCH FROM flush_lag)   AS flush_lag,
            extract(EPOCH FROM replay_lag)  AS replay_lag,
            CASE WHEN pg_is_in_recovery() THEN NULL ELSE pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) :: FLOAT END AS replay_diff,
            CASE WHEN pg_is_in_recovery() THEN NULL ELSE pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn) :: FLOAT END AS  flush_diff,
            CASE WHEN pg_is_in_recovery() THEN NULL ELSE pg_wal_lsn_diff(pg_current_wal_lsn(), write_lsn) :: FLOAT END AS  write_diff,
            sync_priority
          FROM pg_stat_replication;"
  metrics:
  - client_addr:
      usage: "LABEL"
      description: "client address of wal receiver"
  - application_name:
      usage: "LABEL"
      description: "application name of slave"
  - sent_lsn:
      usage: "COUNTER"
      description: "Last transaction log position sent on this connection"
  - write_lsn:
      usage: "COUNTER"
      description: "Last transaction log position written to disk by this standby server"
  - flush_lsn:
      usage: "COUNTER"
      description: "Last transaction log position flushed to disk by this standby server"
  - replay_lsn:
      usage: "GAUGE"
      description: "Last transaction log position replayed into the database on this standby server"
  - write_lag:
      usage: "GAUGE"
      description: "Latest ACK lsn diff with write (sync-remote-write lag)"
  - flush_lag:
      usage: "GAUGE"
      description: "Latest ACK lsn diff with flush (sync-remote-flush lag)"
  - replay_lag:
      usage: "GAUGE"
      description: "Latest ACK lsn diff with replay (sync-remote-apply lag)"
  - replay_diff:
      usage: "GAUGE"
      description: "Lag in bytes between master and slave apply"
  - flush_diff:
      usage: "GAUGE"
      description: "Lag in bytes between master and slave flush"
  - write_diff:
      usage: "GAUGE"
      description: "Lag in bytes between master and slave write"
  - sync_priority:
      usage: "GAUGE"
      description: "Priority of this standby server for being chosen AS the synchronous standby"

```





### LSN如何与BIGINT相互转换

注意，`pg_lsn`是WAL日志坐标，实质上是一个int64，在9.3及以前的版本中，类型为TEXT，9.4以后为专门的类型`pg_lsn`，为了统一，建议转成一致的BIGINT。

```sql

-- PostgreSQL before 9.4 (not include)
create or replace function monitor.lsn2int(text)
returns bigint as $$
select ('x'||lpad( 'ff000000', 16, '0'))::bit(64)::bigint
* ('x'||lpad( split_part( $1 ,'/',1), 16, '0'))::bit(64)::bigint
+ ('x'||lpad( split_part( $1 ,'/',2), 16, '0'))::bit(64)::bigint ;
$$ language sql;


-- PostgreSQL after 9.4
create or replace function monitor.lsn2int(pg_lsn) 
returns bigint as $$
select ('x'||lpad( 'ff000000', 16, '0'))::bit(64)::bigint
* ('x'||lpad( split_part( $1::text ,'/',1), 16, '0'))::bit(64)::bigint
+ ('x'||lpad( split_part( $1::text ,'/',2), 16, '0'))::bit(64)::bigint ;
$$ language sql;
```

