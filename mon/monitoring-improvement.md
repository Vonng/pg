# Postgres Exporter Extended Metrics

### Why

Monitoring is just like the eye of operations. And the foundation of almost all other works. It is important to understand what is really going on inside database. So hereby I propose an improvement to current monitoring systems.

![](../img/google-sre-pyramid.jpg)

#### Related Issue

[Monitoring improvement for PostgreSQL #1418](https://gh.apple.com/tsa/dev/issues/1418)

#### Dashboard Links

DB Instance Dashboard for docker ( PostgreSQL 11)

http://prometheus.darknet.md:3000/d/mPua2v8mz/db-instance-for-docker?orgId=1

Some metrics is missing since we don't use pgbouncer, Disk & Network I/O Metrics is missing because of docker

DB Instance Dashboard 

For those instance haven't deploy extended metrics, we can still utilize some old data 

http://prometheus.darknet.md:3000/d/YIB4EaPmk/db-instance?orgId=1

some improvement can be done without too much effort, but can bring lot's of gains. e.g monitoring systems. The more info we get, the more control we gain. And the soon we bring this online, the soon we get the insight.

Monitor system is critical to maneuver PostgreSQL. Here is the monitor dashboard I used before



## What now

Our system is using `progres_exporter` to extract metrics from PostgreSQL. With some additional metrics listed in `/etc/postgres_exporter.yml`. Which is a great. Since it provide a mechanism to monitoring postgres and can be upgrade easily by switching the yaml configuration files.

Here is the self defined metrics currently in use, Additional metrics include:

- datbase age, size, uptime
- replication progress 
- replication slot progress

```yaml
pg_wraparound:
  query: "SELECT datname, age(datfrozenxid) AS age FROM pg_database WHERE datallowconn ORDER BY 1, 2"
  metrics:
    - datname:
        usage: "LABEL"
        description: "Name of the database"
    - age:
        usage: "GAUGE"
        description: "Age of Frozen Transaction ID"

pg_replication_slots:
  query: "SELECT slot_name, database as datname, active, pg_xlog_location_diff(pg_current_xlog_insert_location(), restart_lsn) AS retained_bytes FROM pg_replication_slots;"
  metrics:
    - slot_name:
        usage: "LABEL"
        description: "Name of the replication slot"
    - datname:
        usage: "LABEL"
        description: "Name of the database"
    - active:
        usage: "LABEL"
        description: "Currently active"
    - retained_bytes:
        usage: "GAUGE"
        description: "Number of bytes retained"

pg_replication:
  query: "SELECT pid, application_name, pg_xlog_location_diff(pg_current_xlog_insert_location(), flush_location) AS total_lag, pg_xlog_location_diff(pg_current_xlog_location(), replay_location) AS data_lag FROM pg_stat_replication;"
  metrics:
    - pid:
        usage: "LABEL"
        description: "Process id"
    - application_name:
        usage: "LABEL"
        description: "Name of the replication connection"
    - total_lag:
        usage: "GAUGE"
        description: "Total Replication lag behind master in seconds"
    - data_lag:
        usage: "GAUGE"
        description: "Replication lag behind master in seconds"

pg_postmaster:
  query: "SELECT pg_postmaster_start_time as start_time_seconds from pg_postmaster_start_time()"
  metrics:
    - start_time_seconds:
        usage: "GAUGE"
        description: "Time at which postmaster started"

pg_database:
  query: "SELECT pg_database.datname, pg_database_size(pg_database.datname) as size FROM pg_database"
  metrics:
    - datname:
        usage: "LABEL"
        description: "Name of the database"
    - size:
        usage: "GAUGE"
        description: "Disk space used by the database"
```

And strip `go_xxxx` metrics , `pg_settings` constants, The exporter will  generates result , about 200 lines of metrics.

```ini
pg_database_size{datname="postgres"} 7.518744e+06
pg_database_size{datname="template0"} 7.422468e+06
pg_database_size{datname="template1"} 7.535128e+06
pg_database_size{datname="trace"} 1.15752534684e+12
pg_exporter_last_scrape_duration_seconds 0.059105606
pg_exporter_last_scrape_error 0
pg_exporter_scrapes_total 61499
pg_exporter_user_queries_load_error{filename="/etc/postgres_exporter.yml",hashsum="9a0bfd4ef9d0482ea8597fe7ed5fc8881d706a7a2e96a498226aee66728052df"} 0

pg_locks_count{datname="postgres",mode="accessexclusivelock"} 0
pg_locks_count{datname="postgres",mode="accesssharelock"} 0
pg_locks_count{datname="postgres",mode="exclusivelock"} 0
pg_locks_count{datname="postgres",mode="rowexclusivelock"} 0
pg_locks_count{datname="postgres",mode="rowsharelock"} 0
pg_locks_count{datname="postgres",mode="sharelock"} 0
pg_locks_count{datname="postgres",mode="sharerowexclusivelock"} 0
pg_locks_count{datname="postgres",mode="shareupdateexclusivelock"} 0
pg_locks_count{datname="template0",mode="accessexclusivelock"} 0
pg_locks_count{datname="template0",mode="accesssharelock"} 0
pg_locks_count{datname="template0",mode="exclusivelock"} 0
pg_locks_count{datname="template0",mode="rowexclusivelock"} 0
pg_locks_count{datname="template0",mode="rowsharelock"} 0
pg_locks_count{datname="template0",mode="sharelock"} 0
pg_locks_count{datname="template0",mode="sharerowexclusivelock"} 0
pg_locks_count{datname="template0",mode="shareupdateexclusivelock"} 0
pg_locks_count{datname="template1",mode="accessexclusivelock"} 0
pg_locks_count{datname="template1",mode="accesssharelock"} 0
pg_locks_count{datname="template1",mode="exclusivelock"} 0
pg_locks_count{datname="template1",mode="rowexclusivelock"} 0
pg_locks_count{datname="template1",mode="rowsharelock"} 0
pg_locks_count{datname="template1",mode="sharelock"} 0
pg_locks_count{datname="template1",mode="sharerowexclusivelock"} 0
pg_locks_count{datname="template1",mode="shareupdateexclusivelock"} 0
pg_locks_count{datname="trace",mode="accessexclusivelock"} 0
pg_locks_count{datname="trace",mode="accesssharelock"} 1
pg_locks_count{datname="trace",mode="exclusivelock"} 0
pg_locks_count{datname="trace",mode="rowexclusivelock"} 4
pg_locks_count{datname="trace",mode="rowsharelock"} 0
pg_locks_count{datname="trace",mode="sharelock"} 0
pg_locks_count{datname="trace",mode="sharerowexclusivelock"} 0
pg_locks_count{datname="trace",mode="shareupdateexclusivelock"} 1

pg_postmaster_start_time_seconds 1.546573251e+09

pg_stat_activity_count{datname="postgres",state="active"} 0
pg_stat_activity_count{datname="postgres",state="disabled"} 0
pg_stat_activity_count{datname="postgres",state="fastpath function call"} 0
pg_stat_activity_count{datname="postgres",state="idle"} 0
pg_stat_activity_count{datname="postgres",state="idle in transaction"} 0
pg_stat_activity_count{datname="postgres",state="idle in transaction (aborted)"} 0
pg_stat_activity_count{datname="template0",state="active"} 0
pg_stat_activity_count{datname="template0",state="disabled"} 0
pg_stat_activity_count{datname="template0",state="fastpath function call"} 0
pg_stat_activity_count{datname="template0",state="idle"} 0
pg_stat_activity_count{datname="template0",state="idle in transaction"} 0
pg_stat_activity_count{datname="template0",state="idle in transaction (aborted)"} 0
pg_stat_activity_count{datname="template1",state="active"} 0
pg_stat_activity_count{datname="template1",state="disabled"} 0
pg_stat_activity_count{datname="template1",state="fastpath function call"} 0
pg_stat_activity_count{datname="template1",state="idle"} 0
pg_stat_activity_count{datname="template1",state="idle in transaction"} 0
pg_stat_activity_count{datname="template1",state="idle in transaction (aborted)"} 0
pg_stat_activity_count{datname="trace",state="active"} 2
pg_stat_activity_count{datname="trace",state="disabled"} 0
pg_stat_activity_count{datname="trace",state="fastpath function call"} 0
pg_stat_activity_count{datname="trace",state="idle"} 0
pg_stat_activity_count{datname="trace",state="idle in transaction"} 0
pg_stat_activity_count{datname="trace",state="idle in transaction (aborted)"} 0

pg_stat_activity_max_tx_duration{datname="postgres",state="active"} 0
pg_stat_activity_max_tx_duration{datname="postgres",state="disabled"} 0
pg_stat_activity_max_tx_duration{datname="postgres",state="fastpath function call"} 0
pg_stat_activity_max_tx_duration{datname="postgres",state="idle"} 0
pg_stat_activity_max_tx_duration{datname="postgres",state="idle in transaction"} 0
pg_stat_activity_max_tx_duration{datname="postgres",state="idle in transaction (aborted)"} 0
pg_stat_activity_max_tx_duration{datname="template0",state="active"} 0
pg_stat_activity_max_tx_duration{datname="template0",state="disabled"} 0
pg_stat_activity_max_tx_duration{datname="template0",state="fastpath function call"} 0
pg_stat_activity_max_tx_duration{datname="template0",state="idle"} 0
pg_stat_activity_max_tx_duration{datname="template0",state="idle in transaction"} 0
pg_stat_activity_max_tx_duration{datname="template0",state="idle in transaction (aborted)"} 0
pg_stat_activity_max_tx_duration{datname="template1",state="active"} 0
pg_stat_activity_max_tx_duration{datname="template1",state="disabled"} 0
pg_stat_activity_max_tx_duration{datname="template1",state="fastpath function call"} 0
pg_stat_activity_max_tx_duration{datname="template1",state="idle"} 0
pg_stat_activity_max_tx_duration{datname="template1",state="idle in transaction"} 0
pg_stat_activity_max_tx_duration{datname="template1",state="idle in transaction (aborted)"} 0
pg_stat_activity_max_tx_duration{datname="trace",state="active"} 522584.112617
pg_stat_activity_max_tx_duration{datname="trace",state="disabled"} 0
pg_stat_activity_max_tx_duration{datname="trace",state="fastpath function call"} 0
pg_stat_activity_max_tx_duration{datname="trace",state="idle"} 0
pg_stat_activity_max_tx_duration{datname="trace",state="idle in transaction"} 0
pg_stat_activity_max_tx_duration{datname="trace",state="idle in transaction (aborted)"} 0

pg_stat_bgwriter_buffers_alloc 361186
pg_stat_bgwriter_buffers_backend 2
pg_stat_bgwriter_buffers_backend_fsync 0
pg_stat_bgwriter_buffers_checkpoint 0
pg_stat_bgwriter_buffers_clean 0
pg_stat_bgwriter_checkpoint_sync_time 0
pg_stat_bgwriter_checkpoint_write_time 140985
pg_stat_bgwriter_checkpoints_req 0
pg_stat_bgwriter_checkpoints_timed 1741
pg_stat_bgwriter_maxwritten_clean 0
pg_stat_bgwriter_stats_reset 1.546570264e+09

pg_stat_database_blk_read_time{datid="1",datname="template1"} 0
pg_stat_database_blk_read_time{datid="13268",datname="template0"} 0
pg_stat_database_blk_read_time{datid="13269",datname="postgres"} 0
pg_stat_database_blk_read_time{datid="16384",datname="trace"} 0

pg_stat_database_blk_write_time{datid="1",datname="template1"} 0
pg_stat_database_blk_write_time{datid="13268",datname="template0"} 0
pg_stat_database_blk_write_time{datid="13269",datname="postgres"} 0
pg_stat_database_blk_write_time{datid="16384",datname="trace"} 0

pg_stat_database_blks_hit{datid="1",datname="template1"} 2394
pg_stat_database_blks_hit{datid="13268",datname="template0"} 0
pg_stat_database_blks_hit{datid="13269",datname="postgres"} 2721
pg_stat_database_blks_hit{datid="16384",datname="trace"} 574364

pg_stat_database_blks_read{datid="1",datname="template1"} 168
pg_stat_database_blks_read{datid="13268",datname="template0"} 0
pg_stat_database_blks_read{datid="13269",datname="postgres"} 168
pg_stat_database_blks_read{datid="16384",datname="trace"} 3.587385e+06

pg_stat_database_conflicts{datid="1",datname="template1"} 0
pg_stat_database_conflicts{datid="13268",datname="template0"} 0
pg_stat_database_conflicts{datid="13269",datname="postgres"} 0
pg_stat_database_conflicts{datid="16384",datname="trace"} 0

pg_stat_database_conflicts_confl_bufferpin{datid="1",datname="template1"} 0
pg_stat_database_conflicts_confl_bufferpin{datid="13268",datname="template0"} 0
pg_stat_database_conflicts_confl_bufferpin{datid="13269",datname="postgres"} 0
pg_stat_database_conflicts_confl_bufferpin{datid="16384",datname="trace"} 0

pg_stat_database_conflicts_confl_deadlock{datid="1",datname="template1"} 0
pg_stat_database_conflicts_confl_deadlock{datid="13268",datname="template0"} 0
pg_stat_database_conflicts_confl_deadlock{datid="13269",datname="postgres"} 0
pg_stat_database_conflicts_confl_deadlock{datid="16384",datname="trace"} 0

pg_stat_database_conflicts_confl_lock{datid="1",datname="template1"} 0
pg_stat_database_conflicts_confl_lock{datid="13268",datname="template0"} 0
pg_stat_database_conflicts_confl_lock{datid="13269",datname="postgres"} 0
pg_stat_database_conflicts_confl_lock{datid="16384",datname="trace"} 0

pg_stat_database_conflicts_confl_snapshot{datid="1",datname="template1"} 0
pg_stat_database_conflicts_confl_snapshot{datid="13268",datname="template0"} 0
pg_stat_database_conflicts_confl_snapshot{datid="13269",datname="postgres"} 0
pg_stat_database_conflicts_confl_snapshot{datid="16384",datname="trace"} 0

pg_stat_database_conflicts_confl_tablespace{datid="1",datname="template1"} 0
pg_stat_database_conflicts_confl_tablespace{datid="13268",datname="template0"} 0
pg_stat_database_conflicts_confl_tablespace{datid="13269",datname="postgres"} 0
pg_stat_database_conflicts_confl_tablespace{datid="16384",datname="trace"} 0

pg_stat_database_deadlocks{datid="1",datname="template1"} 0
pg_stat_database_deadlocks{datid="13268",datname="template0"} 0
pg_stat_database_deadlocks{datid="13269",datname="postgres"} 0
pg_stat_database_deadlocks{datid="16384",datname="trace"} 0

pg_stat_database_numbackends{datid="1",datname="template1"} 0
pg_stat_database_numbackends{datid="13268",datname="template0"} 0
pg_stat_database_numbackends{datid="13269",datname="postgres"} 0
pg_stat_database_numbackends{datid="16384",datname="trace"} 3

pg_stat_database_stats_reset{datid="1",datname="template1"} 1.546570264e+09
pg_stat_database_stats_reset{datid="13268",datname="template0"} NaN
pg_stat_database_stats_reset{datid="13269",datname="postgres"} 1.546570264e+09
pg_stat_database_stats_reset{datid="16384",datname="trace"} 1.546570264e+09

pg_stat_database_temp_bytes{datid="1",datname="template1"} 0
pg_stat_database_temp_bytes{datid="13268",datname="template0"} 0
pg_stat_database_temp_bytes{datid="13269",datname="postgres"} 0
pg_stat_database_temp_bytes{datid="16384",datname="trace"} 0

pg_stat_database_temp_files{datid="1",datname="template1"} 0
pg_stat_database_temp_files{datid="13268",datname="template0"} 0
pg_stat_database_temp_files{datid="13269",datname="postgres"} 0
pg_stat_database_temp_files{datid="16384",datname="trace"} 0

pg_stat_database_tup_deleted{datid="1",datname="template1"} 0
pg_stat_database_tup_deleted{datid="13268",datname="template0"} 0
pg_stat_database_tup_deleted{datid="13269",datname="postgres"} 0
pg_stat_database_tup_deleted{datid="16384",datname="trace"} 0

pg_stat_database_tup_fetched{datid="1",datname="template1"} 1338
pg_stat_database_tup_fetched{datid="13268",datname="template0"} 0
pg_stat_database_tup_fetched{datid="13269",datname="postgres"} 1485
pg_stat_database_tup_fetched{datid="16384",datname="trace"} 9759

pg_stat_database_tup_inserted{datid="1",datname="template1"} 0
pg_stat_database_tup_inserted{datid="13268",datname="template0"} 0
pg_stat_database_tup_inserted{datid="13269",datname="postgres"} 0
pg_stat_database_tup_inserted{datid="16384",datname="trace"} 0

pg_stat_database_tup_returned{datid="1",datname="template1"} 1557
pg_stat_database_tup_returned{datid="13268",datname="template0"} 0
pg_stat_database_tup_returned{datid="13269",datname="postgres"} 1704
pg_stat_database_tup_returned{datid="16384",datname="trace"} 17457

pg_stat_database_tup_updated{datid="1",datname="template1"} 0
pg_stat_database_tup_updated{datid="13268",datname="template0"} 0
pg_stat_database_tup_updated{datid="13269",datname="postgres"} 0
pg_stat_database_tup_updated{datid="16384",datname="trace"} 0

pg_stat_database_xact_commit{datid="1",datname="template1"} 6
pg_stat_database_xact_commit{datid="13268",datname="template0"} 0
pg_stat_database_xact_commit{datid="13269",datname="postgres"} 6
pg_stat_database_xact_commit{datid="16384",datname="trace"} 107

pg_stat_database_xact_rollback{datid="1",datname="template1"} 3
pg_stat_database_xact_rollback{datid="13268",datname="template0"} 0
pg_stat_database_xact_rollback{datid="13269",datname="postgres"} 3
pg_stat_database_xact_rollback{datid="16384",datname="trace"} 2

pg_static{short_version="9.6.10",version="PostgreSQL 9.6.10 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.4.7 20120313 (Red Hat 4.4.7-23), 64-bit"} 1

pg_up 1

pg_wraparound_age{datname="postgres"} 2.078777411e+09
pg_wraparound_age{datname="template1"} 2.131488572e+09
pg_wraparound_age{datname="trace"} 2.146483647e+09

process_cpu_seconds_total 1967.93
process_max_fds 1024
process_open_fds 8
process_resident_memory_bytes 3.93216e+06
process_start_time_seconds 1.5442177025e+09
process_virtual_memory_bytes 2.4973312e+07
```



## What we want

#### Metrics

While PostgreSQL provides lots of metrics through system catalog. Crawling these metrics would be essential to know what is really going on inside database. Here is a customer queries file I wrote before. It brings some important metrics, for example:

- TABLE LEVEL statistics: per table age, tuples, size, access info, blocks & buffers, curd stats.
- INDEX LEVE statisticts: can tell index access frequency and find out unused indexes.
- FUNC LEVEL statistics: can monitoring function execution time & QPS
- Replica lag & byte differences (write, flush, replay), replication lag to master in ms
- lsn progress of itself & it's consumer & slot.
- WAL generate speed
- VACUUM Progress to found vacuum stuck in time.
- Monitoring table & index bloat (requires two user defined view in monitor schema)
- for the bloat treatment, refer to: [PostgreSQL bloat treatment](

### Insights

Theses is one dashboard that served me for a long time.

There are seven sections: overview, OS, Activity & Session , Replication, checkpoint & WAL, conflicts,  and Table Level Stats

![](assets/mon1-overview.png)

![](assets/mon2-os.png)

![](assets/mon3-activity.png)

![](assets/mon4-replication.png)

![](assets/mon5-checkpoint.png)

![](assets/mon6-conflict.png)

![](assets/mon7-tablestat.png)

![](assets/mon8-module.png)



## How to achieve

### structures

![](assets/monitor-arch.png)



### metrics

Here is the configuration yaml file used for `postgres_exporter`, And it will generate around 1355 lines of metrics. and complete inspect in around 10ms.

```yaml
###############################################################
# PostgreSQL Extended Metrics 
# 
# Author:   Vonng (fengruohang@outlook.com)
# Desc  :   postgres_exporter extended metrics files
#           This metrics files contains default metrics
#           Disable default metrics when using this.
# Mtime :   2019-01-01
###############################################################

# Generic metrics: 
# uptime, replica status, lsn progress, lag to master
pg:
  query: "SELECT pg_is_in_recovery()::integer       as in_recovery,
            (CASE WHEN pg_is_in_recovery() THEN pg_last_xlog_replay_location() ELSE pg_current_xlog_location() END) - '0/0' as lsn,
            (CASE WHEN pg_is_in_recovery() THEN extract(EPOCH FROM now() - pg_last_xact_replay_timestamp())::FLOAT ELSE NULL END) as lag,
            extract(EPOCH FROM now() - pg_postmaster_start_time())::FLOAT as uptime;"
  metrics:
    - is_in_recovery:
        usage: "GAUGE"
        description: "True if recovery is still in progress. 0 for master, 1 for slave"
    - lsn:
        usage: "GAUGE"
        description: "Log sequence offset, bigint"
    - lag:
        usage: "GAUGE"
        description: "Replication lag behind master in seconds (view of slave)"
    - uptime:
        usage: "GAUGE"
        description: "Uptime since postmaster start"

# Database size & age
pg_database:
  query: "SELECT pg_database.datname,
                 pg_database_size(pg_database.datname) as size,
                 age(datfrozenxid) as age,
                 datfrozenxid::text::FLOAT as datfrozenxid
            FROM pg_database"
  metrics:
    - datname:
        usage: "LABEL"
        description: "Name of the database"
    - size:
        usage: "GAUGE"
        description: "Disk space used by the database"
    - age:
        usage: "GAUGE"
        description: "Age of that database: age(datfrozenxid)"
    - datfrozenxid:
        usage: "GAUGE"
        description: "All xid before this is frozen"

# Database statistics: xact, blocks, tuples, conflicts
# DEFAULT METRICS
pg_stat_database:
  query: "SELECT datname, numbackends,
                 xact_commit, xact_rollback, xact_commit + xact_rollback as xact_total,
                 blks_read, blks_hit, blks_read + blks_hit as blks_total,
                 tup_returned, tup_fetched, tup_inserted, tup_updated, tup_deleted, tup_inserted + tup_updated + tup_deleted as tup_modified,
                 conflicts, temp_files, temp_bytes, deadlocks, blk_read_time, blk_write_time, stats_reset
          FROM pg_stat_database;"
  metrics:
    - datname:
        usage: "LABEL"
        description: "Name of the database"
    - numbackends:
        usage: "GAUGE"
        description: "Number of backends currently connected to this database"
    - xact_commit:
        usage: "COUNTER"
        description: "Number of transactions in this database that have been committed"
    - xact_rollback:
        usage: "COUNTER"
        description: "Number of transactions in this database that have been rolled back"
    - xact_total:
        usage: "COUNTER"
        description: "Number of transactions in this database that occurs (xact_commit + xact_rollback)"
    - blks_read:
        usage: "COUNTER"
        description: "Number of disk blocks read from disk in this database"
    - blks_hit:
        usage: "COUNTER"
        description: "Number of times disk blocks were found already in PostgreSQL buffer cache"
    - blks_total:
        usage: "COUNTER"
        description: "Number of blocks been accessed (blks_read + blks_hit)"
    - tup_returned:
        usage: "COUNTER"
        description: "Number of rows returned by queries in this database"
    - tup_fetched:
        usage: "COUNTER"
        description: "Number of rows fetched by queries in this database"
    - tup_inserted:
        usage: "COUNTER"
        description: "Number of rows inserted by queries in this database"
    - tup_updated:
        usage: "COUNTER"
        description: "Number of rows updated by queries in this database"
    - tup_deleted:
        usage: "COUNTER"
        description: "Number of rows deleted by queries in this database"
    - tup_modified:
        usage: "COUNTER"
        description: "Number of rows modified(insert,update,delete) by queries in this database"
    - conflicts:
        usage: "COUNTER"
        description: "Number of queries canceled due to conflicts with recovery in this database. (slave only)"
    - temp_files:
        usage: "COUNTER"
        description: "Number of temporary files created by queries in this database"
    - temp_bytes:
        usage: "COUNTER"
        description: "Temporary file byte count"
    - deadlocks:
        usage: "COUNTER"
        description: "Number of deadlocks detected in this database"
    - blk_read_time:
        usage: "COUNTER"
        description: "Time spent reading data file blocks by backends in this database, in milliseconds"
    - blk_write_time:
        usage: "COUNTER"
        description: "Time spent writing data file blocks by backends in this database, in milliseconds"
    - stats_reset:
        usage: "COUNTER"
        description: "Time at which these statistics were last reset"

# Database conflict stats
# DEFAULT METRICS
pg_stat_database_conflicts:
  query: "SELECT datname, confl_tablespace, confl_lock, confl_snapshot, confl_bufferpin, confl_deadlock FROM pg_stat_database_conflicts;"
  metrics:
    - datname:
        usage: "LABEL"
        description: "Name of the database"
    - confl_tablespace:
        usage: "COUNTER"
        description: "Number of queries in this database that have been canceled due to dropped tablespaces"
    - confl_lock:
        usage: "COUNTER"
        description: "Number of queries in this database that have been canceled due to lock timeouts"
    - confl_snapshot:
        usage: "COUNTER"
        description: "Number of queries in this database that have been canceled due to old snapshots"
    - confl_bufferpin:
        usage: "COUNTER"
        description: "Number of queries in this database that have been canceled due to pinned buffers"
    - confl_deadlock:
        usage: "COUNTER"
        description: "Number of queries in this database that have been canceled due to deadlocks"

# Locks group by mode
# DEFAULT METRICS
pg_locks:
  query: "SELECT pg_database.datname,tmp.mode,COALESCE(count,0) as count
            FROM
                (
                  VALUES ('accesssharelock'),
                         ('rowsharelock'),
                         ('rowexclusivelock'),
                         ('shareupdateexclusivelock'),
                         ('sharelock'),
                         ('sharerowexclusivelock'),
                         ('exclusivelock'),
                         ('accessexclusivelock')
                ) AS tmp(mode) CROSS JOIN pg_database
            LEFT JOIN
              (SELECT database, lower(mode) AS mode,count(*) AS count
              FROM pg_locks WHERE database IS NOT NULL
              GROUP BY database, lower(mode)
            ) AS tmp2
            ON tmp.mode=tmp2.mode and pg_database.oid = tmp2.database ORDER BY 1;"
  metrics:
    - datname:
        usage: "LABEL"
        description: "Name of the database"
    - mode:
        usage: "LABEL"
        description: "Type of lock"
    - count:
        usage: "COUNTER"
        description: "Number of locks of corresponding mode"


# Database background writer
# DEFAULT METRICS
pg_stat_bgwriter:
  query: "SELECT checkpoints_timed, checkpoints_req, checkpoint_write_time, checkpoint_sync_time,
                 buffers_checkpoint, buffers_clean, buffers_backend,
                 maxwritten_clean, buffers_backend_fsync, buffers_alloc, stats_reset
            FROM pg_stat_bgwriter;"
  metrics:
    - checkpoints_timed:
        usage: "COUNTER"
        description: "Number of scheduled checkpoints that have been performed"
    - checkpoints_req:
        usage: "COUNTER"
        description: "Number of requested checkpoints that have been performed"
    - checkpoint_write_time:
        usage: "COUNTER"
        description: "Total amount of time that has been spent in the portion of checkpoint processing where files are written to disk, in milliseconds"
    - checkpoint_sync_time:
        usage: "COUNTER"
        description: "Total amount of time that has been spent in the portion of checkpoint processing where files are synchronized to disk, in milliseconds"
    - buffers_checkpoint:
        usage: "COUNTER"
        description: "Number of buffers written during checkpoints"
    - buffers_clean:
        usage: "COUNTER"
        description: "Number of buffers written by the background writer"
    - buffers_backend:
        usage: "COUNTER"
        description: "Number of buffers written directly by a backend"
    - maxwritten_clean:
        usage: "COUNTER"
        description: "Number of times the background writer stopped a cleaning scan because it had written too many buffers"
    - buffers_backend_fsync:
        usage: "COUNTER"
        description: "Number of times a backend had to execute its own fsync call (normally the background writer handles those even when the backend does its own write)"
    - buffers_alloc:
        usage: "COUNTER"
        description: "Number of buffers allocated"
    - stats_reset:
        usage: "COUNTER"
        description: "Time at which these statistics were last reset"


# Database conflict stats
# DEFAULT METRICS
pg_stat_activity:
  query: "SELECT
                pg_database.datname,
                tmp.state,
                COALESCE(count,0) as count,
                COALESCE(max_tx_duration,0) as max_tx_duration
            FROM
                (
                    VALUES ('active'),
                            ('idle'),
                            ('idle in transaction'),
                            ('idle in transaction (aborted)'),
                            ('fastpath function call'),
                            ('disabled')
                ) AS tmp(state) CROSS JOIN pg_database
            LEFT JOIN
            (
                SELECT
                    datname,
                    state,
                    count(*) AS count,
                    MAX(extract(EPOCH FROM now() - xact_start))::float AS max_tx_duration
                FROM pg_stat_activity GROUP BY datname,state) AS tmp2
                ON tmp.state = tmp2.state AND pg_database.datname = tmp2.datname"
  metrics:
    - datname:
        usage: "LABEL"
        description: "Number of scheduled checkpoints that have been performed"
    - state:
        usage: "LABEL"
        description: "Number of requested checkpoints that have been performed"
    - count:
        usage: "GAUGE"
        description: "Total amount of time that has been spent in the portion of checkpoint processing where files are written to disk, in milliseconds"
    - max_tx_duration:
        usage: "GAUGE"
        description: "Total amount of time that has been spent in the portion of checkpoint processing where files are synchronized to disk, in milliseconds"



# Database replication statistics
# Add more labels & more metrics, compatible with default metrics
pg_stat_replication:
  query: "SELECT client_addr,application_name,state,
                (CASE WHEN pg_is_in_recovery() THEN pg_last_xlog_replay_location() ELSE pg_current_xlog_location() END) - '0/0' as lsn,
                sent_location - '0/0' as sent_lsn, write_location - '0/0' as write_lsn, flush_location- '0/0' as flush_lsn, replay_location- '0/0' as replay_lsn,
                CASE WHEN pg_is_in_recovery() THEN NULL ELSE pg_xlog_location_diff(pg_current_xlog_location(), replay_location)::FLOAT END AS lsn_diff, sync_priority
            FROM pg_stat_replication;"
  metrics:
    - client_addr:
        usage: "LABEL"
        description: "Number of scheduled checkpoints that have been performed"
    - application_name:
        usage: "LABEL"
        description: "Number of requested checkpoints that have been performed"
    - state:
        usage: "LABEL"
        description: "Total amount of time that has been spent in the portion of checkpoint processing where files are written to disk, in milliseconds"
    - lsn:
        usage: "COUNTER"
        description: "pg_current_xlog_location() on master  & pg_last_xlog_replay_location() on slave"
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
        usage: "COUNTER"
        description: "Last transaction log position replayed into the database on this standby server"
    - lsn_diff:
        usage: "COUNTER"
        description: "Lag in bytes between master and slave"
    - sync_priority:
        usage: "COUNTER"
        description: "Priority of this standby server for being chosen as the synchronous standby"

# Replication Slot
pg_replication_slots:
  query: "SELECT slot_name, database as datname, restart_lsn - '0/0' AS restart_lsn, confirmed_flush_lsn - '0/0' AS flush_lsn, 
            ((CASE WHEN pg_is_in_recovery() THEN pg_last_xlog_replay_location() ELSE pg_current_xlog_location() END) - restart_lsn)::FLOAT as retained_bytes
            FROM pg_replication_slots WHERE active;"
  metrics:
    - slot_name:
        usage: "LABEL"
        description: "Name of the replication slot"
    - restart_lsn:
        usage: "GAUGE"
        description: "The address (LSN) of oldest WAL which still might be required by the consumer of this slot and thus won't be automatically removed during checkpoints."
    - flush_lsn:
        usage: "GAUGE"
        description: "slot's consumer has confirmed receiving data. Data older than this is not available anymore. NULL for physical slots."
    - retained_bytes:
        usage: "GAUGE"
        description: "Number of bytes retained"

# TABLE Level statistics: Very important table level stats
pg_stat_user_tables:
  query: "SELECT schemaname, relname, schemaname||'.'|| relname AS fullname,
            reltuples, relpages, pg_total_relation_size(relid) as relsize, relage,
            seq_scan, seq_tup_read, idx_scan, idx_tup_fetch, n_tup_ins, n_tup_upd, n_tup_del, (n_tup_ins + n_tup_upd + n_tup_del) as n_tup_mod,
            n_tup_hot_upd, n_live_tup, n_dead_tup, n_mod_since_analyze, last_vacuum, last_autovacuum, last_analyze, last_autoanalyze, vacuum_count, autovacuum_count,
            analyze_count, autoanalyze_count
        FROM pg_stat_user_tables psut, LATERAL (SELECT reltuples,relpages,age(relfrozenxid) as relage FROM pg_class pc WHERE pc.oid = psut.relid) p;"
  metrics:
    - schemaname:
        usage: "LABEL"
        description: "Name of this table schemaname.relname"
    - relname:
        usage: "LABEL"
        description: "Name of this table"
    - fullname:
        usage: "LABEL"
        description: "schemaname.relname"
    - reltuples:
        usage: "COUNTER"
        description: "Number of estimate rel tuples"
    - relpages:
        usage: "COUNTER"
        description: "Number of relation main branch pages"
    - relsize:
        usage: "COUNTER"
        description: "pg_total_relation_size(relid) in bytes"
    - relage:
        usage: "COUNTER"
        description: "age(pg_class.relfrozenxid)"
    - seq_scan:
        usage: "COUNTER"
        description: "Number of sequential scans initiated on this table"
    - seq_tup_read:
        usage: "COUNTER"
        description: "Number of live rows fetched by sequential scans"
    - idx_scan:
        usage: "COUNTER"
        description: "Number of index scans initiated on this table"
    - idx_tup_fetch:
        usage: "COUNTER"
        description: "Number of live rows fetched by index scans"
    - n_tup_ins:
        usage: "COUNTER"
        description: "Number of rows inserted"
    - n_tup_upd:
        usage: "COUNTER"
        description: "Number of rows updated"
    - n_tup_del:
        usage: "COUNTER"
        description: "Number of rows deleted"
    - n_tup_hot_upd:
        usage: "COUNTER"
        description: "Number of rows HOT updated (i.e., with no separate index update required)"
    - n_live_tup:
        usage: "GAUGE"
        description: "Estimated number of live rows"
    - n_dead_tup:
        usage: "GAUGE"
        description: "Estimated number of dead rows"
    - n_mod_since_analyze:
        usage: "GAUGE"
        description: "Estimated number of rows changed since last analyze"
    - last_vacuum:
        usage: "GAUGE"
        description: "Last time at which this table was manually vacuumed (not counting VACUUM FULL)"
    - last_autovacuum:
        usage: "GAUGE"
        description: "Last time at which this table was vacuumed by the autovacuum daemon"
    - last_analyze:
        usage: "GAUGE"
        description: "Last time at which this table was manually analyzed"
    - last_autoanalyze:
        usage: "GAUGE"
        description: "Last time at which this table was analyzed by the autovacuum daemon"
    - vacuum_count:
        usage: "COUNTER"
        description: "Number of times this table has been manually vacuumed (not counting VACUUM FULL)"
    - autovacuum_count:
        usage: "COUNTER"
        description: "Number of times this table has been vacuumed by the autovacuum daemon"
    - analyze_count:
        usage: "COUNTER"
        description: "Number of times this table has been manually analyzed"
    - autoanalyze_count:
        usage: "COUNTER"
        description: "Number of times this table has been analyzed by the autovacuum daemon"

# Indexes statistics
pg_stat_user_indexes:
    query: "SELECT schemaname, indexrelname, schemaname||'.'|| indexrelname AS fullname,
                reltuples, relpages, pg_total_relation_size(relid) as relsize,
                idx_scan, idx_tup_read, idx_tup_fetch
                FROM pg_stat_user_indexes psui, LATERAL (SELECT reltuples,relpages FROM pg_class pc WHERE pc.oid = psui.relid) p
                WHERE idx_scan > 0;"
    metrics:
        - schemaname:
            usage: "LABEL"
            description: "Name of this index schemaname.indexrelname"
        - indexrelname:
            usage: "LABEL"
            description: "Name of this index"
        - fullname:
            usage: "LABEL"
            description: "Name of this index schemaname.indexrelname"
        - reltuples:
            usage: "COUNTER"
            description: "Number of estimate rel tuples"
        - relpages:
            usage: "COUNTER"
            description: "Number of relation main branch pages"
        - relsize:
            usage: "COUNTER"
            description: "pg_total_relation_size(relid) in bytes"
        - idx_scan:
            usage: "GAUGE"
            description: "Number of index scans initiated on this index"
        - idx_tup_read:
            usage: "GAUGE"
            description: "Number of index entries returned by scans on this index"
        - idx_tup_fetch:
            usage: "GAUGE"
            description: "Number of live table rows fetched by simple index scans using this index"

# Function statistics
# set track_functions = on
pg_stat_user_functions:
    query: "SELECT schemaname, funcname, schemaname||'.'|| funcname || '.' || funcid AS fullname,
                calls, total_time, self_time
            FROM pg_stat_user_functions WHERE calls > 0;"
    metrics:
        - schemaname:
            usage: "LABEL"
            description: "Name of belonged schema"
        - funcname:
            usage: "LABEL"
            description: "Name of the function"
        - fullname:
            usage: "LABEL"
            description: "Name of this function schemaname.funcname.funcid"
        - calls:
            usage: "GAUGE"
            description: "Number of times this function has been called"
        - total_time:
            usage: "GAUGE"
            description: "Total time spent in this function and all other functions called by it, in milliseconds"
        - self_time:
            usage: "GAUGE"
            description: "Total time spent in this function itself, not including other functions called by it, in milliseconds"

# Vacuum process monitoring
pg_stat_progress_vacuum:
    query: "SELECT relid::RegClass as relname ,heap_blks_vacuumed::FLOAT / heap_blks_total as ratio from pg_stat_progress_vacuum;"
    metrics:
        - relname:
            usage: "LABEL"
            description: "Name of vacuumed table"
        - ratio:
            usage: "GAUGE"
            description: "progress ratio (0-1) of vacuum heap stage"



# WAL generate speed, no such function below 10.0 use lsn rate instead

# pg_stat_wal:
#   query: "SELECT last_5_min_size_bytes,
#             (SELECT COALESCE(sum(size),0) FROM pg_catalog.pg_ls_waldir()) AS total_size_bytes
#             FROM (SELECT COALESCE(sum(size),0) AS last_5_min_size_bytes FROM pg_catalog.pg_ls_waldir() WHERE modification > CURRENT_TIMESTAMP - '5 minutes'::interval) x;"
#   metrics:
#     - last_5min_size_bytes:
#         usage: "GAUGE"
#         description: "Current size in bytes of the last 5 minutes of WAL generation. Includes recycled WALs."
#     - total_size_bytes:
#         usage: "GAUGE"
#         description: "Current size in bytes of the WAL directory"



# Bloat of rables, requires a bloat view in monitor schema, which is optional

# pg_bloat_tables:
#     query: "select nspname || '.' || relname as fullname, bloat_pct from monitor.pg_bloat_tables;"
#     metrics:
#         - fullname:
#             usage: "LABEL"
#             description: "Name of this table: schemaname.relname"
#         - bloat_pct:
#             usage: "GAUGE"
#             description: "0-100 indicate bloat pct"


# Bloat of indexes, requires a bloat view in monitor schema, which is optional

# pg_bloat_indexes:
#     query: "select nspname || '.' || relname as fullname, bloat_pct from monitor.pg_bloat_indexes;"
#     metrics:
#         - fullname:
#             usage: "LABEL"
#             description: "Name of this table: schemaname.indexrelname"
#         - bloat_pct:
#             usage: "GAUGE"
#             description: "0-100 indicate bloat pct"
```



```yaml
pg_database_age{datname="postgres"} 2.078777411e+09
pg_database_age{datname="template0"} 2.131488572e+09
pg_database_age{datname="template1"} 2.131488572e+09
pg_database_age{datname="trace"} 2.146483647e+09
pg_database_datfrozenxid{datname="postgres"} 1.71551098e+08
pg_database_datfrozenxid{datname="template0"} 1.18839937e+08
pg_database_datfrozenxid{datname="template1"} 1.18839937e+08
pg_database_datfrozenxid{datname="trace"} 1.03844862e+08
pg_database_size{datname="postgres"} 7.518744e+06
pg_database_size{datname="template0"} 7.422468e+06
pg_database_size{datname="template1"} 7.535128e+06
pg_database_size{datname="trace"} 1.15752534684e+12
pg_exporter_last_scrape_duration_seconds 0.03875525
pg_exporter_last_scrape_error 0
pg_exporter_scrapes_total 3
pg_exporter_user_queries_load_error{filename="/etc/postgres_exporter96.yaml",hashsum="474a2f7751fc3f57e6bcbdf1d931dd230702ab1f669d0ce9ca0e1bb82dad3456"} 0
pg_in_recovery 0
pg_lag NaN
pg_locks_count{datname="postgres",mode="accessexclusivelock"} 0
pg_locks_count{datname="postgres",mode="accesssharelock"} 0
pg_locks_count{datname="postgres",mode="exclusivelock"} 0
pg_locks_count{datname="postgres",mode="rowexclusivelock"} 0
pg_locks_count{datname="postgres",mode="rowsharelock"} 0
pg_locks_count{datname="postgres",mode="sharelock"} 0
pg_locks_count{datname="postgres",mode="sharerowexclusivelock"} 0
pg_locks_count{datname="postgres",mode="shareupdateexclusivelock"} 0
pg_locks_count{datname="template0",mode="accessexclusivelock"} 0
pg_locks_count{datname="template0",mode="accesssharelock"} 0
pg_locks_count{datname="template0",mode="exclusivelock"} 0
pg_locks_count{datname="template0",mode="rowexclusivelock"} 0
pg_locks_count{datname="template0",mode="rowsharelock"} 0
pg_locks_count{datname="template0",mode="sharelock"} 0
pg_locks_count{datname="template0",mode="sharerowexclusivelock"} 0
pg_locks_count{datname="template0",mode="shareupdateexclusivelock"} 0
pg_locks_count{datname="template1",mode="accessexclusivelock"} 0
pg_locks_count{datname="template1",mode="accesssharelock"} 0
pg_locks_count{datname="template1",mode="exclusivelock"} 0
pg_locks_count{datname="template1",mode="rowexclusivelock"} 0
pg_locks_count{datname="template1",mode="rowsharelock"} 0
pg_locks_count{datname="template1",mode="sharelock"} 0
pg_locks_count{datname="template1",mode="sharerowexclusivelock"} 0
pg_locks_count{datname="template1",mode="shareupdateexclusivelock"} 0
pg_locks_count{datname="trace",mode="accessexclusivelock"} 0
pg_locks_count{datname="trace",mode="accesssharelock"} 1
pg_locks_count{datname="trace",mode="exclusivelock"} 0
pg_locks_count{datname="trace",mode="rowexclusivelock"} 4
pg_locks_count{datname="trace",mode="rowsharelock"} 0
pg_locks_count{datname="trace",mode="sharelock"} 0
pg_locks_count{datname="trace",mode="sharerowexclusivelock"} 0
pg_locks_count{datname="trace",mode="shareupdateexclusivelock"} 1
pg_lsn 7.7631556207288e+13
pg_stat_activity_count{datname="postgres",state="active"} 0
pg_stat_activity_count{datname="postgres",state="disabled"} 0
pg_stat_activity_count{datname="postgres",state="fastpath function call"} 0
pg_stat_activity_count{datname="postgres",state="idle"} 0
pg_stat_activity_count{datname="postgres",state="idle in transaction"} 0
pg_stat_activity_count{datname="postgres",state="idle in transaction (aborted)"} 0
pg_stat_activity_count{datname="template0",state="active"} 0
pg_stat_activity_count{datname="template0",state="disabled"} 0
pg_stat_activity_count{datname="template0",state="fastpath function call"} 0
pg_stat_activity_count{datname="template0",state="idle"} 0
pg_stat_activity_count{datname="template0",state="idle in transaction"} 0
pg_stat_activity_count{datname="template0",state="idle in transaction (aborted)"} 0
pg_stat_activity_count{datname="template1",state="active"} 0
pg_stat_activity_count{datname="template1",state="disabled"} 0
pg_stat_activity_count{datname="template1",state="fastpath function call"} 0
pg_stat_activity_count{datname="template1",state="idle"} 0
pg_stat_activity_count{datname="template1",state="idle in transaction"} 0
pg_stat_activity_count{datname="template1",state="idle in transaction (aborted)"} 0
pg_stat_activity_count{datname="trace",state="active"} 2
pg_stat_activity_count{datname="trace",state="disabled"} 0
pg_stat_activity_count{datname="trace",state="fastpath function call"} 0
pg_stat_activity_count{datname="trace",state="idle"} 1
pg_stat_activity_count{datname="trace",state="idle in transaction"} 0
pg_stat_activity_count{datname="trace",state="idle in transaction (aborted)"} 0
pg_stat_activity_max_tx_duration{datname="postgres",state="active"} 0
pg_stat_activity_max_tx_duration{datname="postgres",state="disabled"} 0
pg_stat_activity_max_tx_duration{datname="postgres",state="fastpath function call"} 0
pg_stat_activity_max_tx_duration{datname="postgres",state="idle"} 0
pg_stat_activity_max_tx_duration{datname="postgres",state="idle in transaction"} 0
pg_stat_activity_max_tx_duration{datname="postgres",state="idle in transaction (aborted)"} 0
pg_stat_activity_max_tx_duration{datname="template0",state="active"} 0
pg_stat_activity_max_tx_duration{datname="template0",state="disabled"} 0
pg_stat_activity_max_tx_duration{datname="template0",state="fastpath function call"} 0
pg_stat_activity_max_tx_duration{datname="template0",state="idle"} 0
pg_stat_activity_max_tx_duration{datname="template0",state="idle in transaction"} 0
pg_stat_activity_max_tx_duration{datname="template0",state="idle in transaction (aborted)"} 0
pg_stat_activity_max_tx_duration{datname="template1",state="active"} 0
pg_stat_activity_max_tx_duration{datname="template1",state="disabled"} 0
pg_stat_activity_max_tx_duration{datname="template1",state="fastpath function call"} 0
pg_stat_activity_max_tx_duration{datname="template1",state="idle"} 0
pg_stat_activity_max_tx_duration{datname="template1",state="idle in transaction"} 0
pg_stat_activity_max_tx_duration{datname="template1",state="idle in transaction (aborted)"} 0
pg_stat_activity_max_tx_duration{datname="trace",state="active"} 524873.77606
pg_stat_activity_max_tx_duration{datname="trace",state="disabled"} 0
pg_stat_activity_max_tx_duration{datname="trace",state="fastpath function call"} 0
pg_stat_activity_max_tx_duration{datname="trace",state="idle"} 0
pg_stat_activity_max_tx_duration{datname="trace",state="idle in transaction"} 0
pg_stat_activity_max_tx_duration{datname="trace",state="idle in transaction (aborted)"} 0
pg_stat_bgwriter_buffers_alloc 361429
pg_stat_bgwriter_buffers_backend 2
pg_stat_bgwriter_buffers_backend_fsync 0
pg_stat_bgwriter_buffers_checkpoint 0
pg_stat_bgwriter_buffers_clean 0
pg_stat_bgwriter_checkpoint_sync_time 0
pg_stat_bgwriter_checkpoint_write_time 141526
pg_stat_bgwriter_checkpoints_req 0
pg_stat_bgwriter_checkpoints_timed 1749
pg_stat_bgwriter_maxwritten_clean 0
pg_stat_bgwriter_stats_reset 1.546570264e+09
pg_stat_database_blk_read_time{datname="postgres"} 0
pg_stat_database_blk_read_time{datname="template0"} 0
pg_stat_database_blk_read_time{datname="template1"} 0
pg_stat_database_blk_read_time{datname="trace"} 0
pg_stat_database_blk_write_time{datname="postgres"} 0
pg_stat_database_blk_write_time{datname="template0"} 0
pg_stat_database_blk_write_time{datname="template1"} 0
pg_stat_database_blk_write_time{datname="trace"} 0
pg_stat_database_blks_hit{datname="postgres"} 6677
pg_stat_database_blks_hit{datname="template0"} 0
pg_stat_database_blks_hit{datname="template1"} 2394
pg_stat_database_blks_hit{datname="trace"} 580390
pg_stat_database_blks_read{datname="postgres"} 372
pg_stat_database_blks_read{datname="template0"} 0
pg_stat_database_blks_read{datname="template1"} 168
pg_stat_database_blks_read{datname="trace"} 3.587412e+06
pg_stat_database_blks_total{datname="postgres"} 7049
pg_stat_database_blks_total{datname="template0"} 0
pg_stat_database_blks_total{datname="template1"} 2562
pg_stat_database_blks_total{datname="trace"} 4.167802e+06
pg_stat_database_conflicts{datname="postgres"} 0
pg_stat_database_conflicts{datname="template0"} 0
pg_stat_database_conflicts{datname="template1"} 0
pg_stat_database_conflicts{datname="trace"} 0
pg_stat_database_conflicts_confl_bufferpin{datname="postgres"} 0
pg_stat_database_conflicts_confl_bufferpin{datname="template0"} 0
pg_stat_database_conflicts_confl_bufferpin{datname="template1"} 0
pg_stat_database_conflicts_confl_bufferpin{datname="trace"} 0
pg_stat_database_conflicts_confl_deadlock{datname="postgres"} 0
pg_stat_database_conflicts_confl_deadlock{datname="template0"} 0
pg_stat_database_conflicts_confl_deadlock{datname="template1"} 0
pg_stat_database_conflicts_confl_deadlock{datname="trace"} 0
pg_stat_database_conflicts_confl_lock{datname="postgres"} 0
pg_stat_database_conflicts_confl_lock{datname="template0"} 0
pg_stat_database_conflicts_confl_lock{datname="template1"} 0
pg_stat_database_conflicts_confl_lock{datname="trace"} 0
pg_stat_database_conflicts_confl_snapshot{datname="postgres"} 0
pg_stat_database_conflicts_confl_snapshot{datname="template0"} 0
pg_stat_database_conflicts_confl_snapshot{datname="template1"} 0
pg_stat_database_conflicts_confl_snapshot{datname="trace"} 0
pg_stat_database_conflicts_confl_tablespace{datname="postgres"} 0
pg_stat_database_conflicts_confl_tablespace{datname="template0"} 0
pg_stat_database_conflicts_confl_tablespace{datname="template1"} 0
pg_stat_database_conflicts_confl_tablespace{datname="trace"} 0
pg_stat_database_deadlocks{datname="postgres"} 0
pg_stat_database_deadlocks{datname="template0"} 0
pg_stat_database_deadlocks{datname="template1"} 0
pg_stat_database_deadlocks{datname="trace"} 0
pg_stat_database_numbackends{datname="postgres"} 0
pg_stat_database_numbackends{datname="template0"} 0
pg_stat_database_numbackends{datname="template1"} 0
pg_stat_database_numbackends{datname="trace"} 4
pg_stat_database_stats_reset{datname="postgres"} 1.546570264e+09
pg_stat_database_stats_reset{datname="template0"} NaN
pg_stat_database_stats_reset{datname="template1"} 1.546570264e+09
pg_stat_database_stats_reset{datname="trace"} 1.546570264e+09
pg_stat_database_temp_bytes{datname="postgres"} 0
pg_stat_database_temp_bytes{datname="template0"} 0
pg_stat_database_temp_bytes{datname="template1"} 0
pg_stat_database_temp_bytes{datname="trace"} 0
pg_stat_database_temp_files{datname="postgres"} 0
pg_stat_database_temp_files{datname="template0"} 0
pg_stat_database_temp_files{datname="template1"} 0
pg_stat_database_temp_files{datname="trace"} 0
pg_stat_database_tup_deleted{datname="postgres"} 0
pg_stat_database_tup_deleted{datname="template0"} 0
pg_stat_database_tup_deleted{datname="template1"} 0
pg_stat_database_tup_deleted{datname="trace"} 0
pg_stat_database_tup_fetched{datname="postgres"} 3785
pg_stat_database_tup_fetched{datname="template0"} 0
pg_stat_database_tup_fetched{datname="template1"} 1338
pg_stat_database_tup_fetched{datname="trace"} 12477
pg_stat_database_tup_inserted{datname="postgres"} 0
pg_stat_database_tup_inserted{datname="template0"} 0
pg_stat_database_tup_inserted{datname="template1"} 0
pg_stat_database_tup_inserted{datname="trace"} 0
pg_stat_database_tup_modified{datname="postgres"} 0
pg_stat_database_tup_modified{datname="template0"} 0
pg_stat_database_tup_modified{datname="template1"} 0
pg_stat_database_tup_modified{datname="trace"} 0
pg_stat_database_tup_returned{datname="postgres"} 14413
pg_stat_database_tup_returned{datname="template0"} 0
pg_stat_database_tup_returned{datname="template1"} 1557
pg_stat_database_tup_returned{datname="trace"} 30672
pg_stat_database_tup_updated{datname="postgres"} 0
pg_stat_database_tup_updated{datname="template0"} 0
pg_stat_database_tup_updated{datname="template1"} 0
pg_stat_database_tup_updated{datname="trace"} 0
pg_stat_database_xact_commit{datname="postgres"} 52
pg_stat_database_xact_commit{datname="template0"} 0
pg_stat_database_xact_commit{datname="template1"} 6
pg_stat_database_xact_commit{datname="trace"} 140
pg_stat_database_xact_rollback{datname="postgres"} 4
pg_stat_database_xact_rollback{datname="template0"} 0
pg_stat_database_xact_rollback{datname="template1"} 3
pg_stat_database_xact_rollback{datname="trace"} 2
pg_stat_database_xact_total{datname="postgres"} 56
pg_stat_database_xact_total{datname="template0"} 0
pg_stat_database_xact_total{datname="template1"} 9
pg_stat_database_xact_total{datname="trace"} 142
pg_stat_progress_vacuum_ratio{relname="m_parts"} 0
pg_stat_user_functions_calls{fullname="pg_catalog.col_description.1216",funcname="col_description",schemaname="pg_catalog"} 11
pg_stat_user_functions_calls{fullname="pg_catalog.obj_description.1215",funcname="obj_description",schemaname="pg_catalog"} 1
pg_stat_user_functions_self_time{fullname="pg_catalog.col_description.1216",funcname="col_description",schemaname="pg_catalog"} 2.004
pg_stat_user_functions_self_time{fullname="pg_catalog.obj_description.1215",funcname="obj_description",schemaname="pg_catalog"} 0.256
pg_stat_user_functions_total_time{fullname="pg_catalog.col_description.1216",funcname="col_description",schemaname="pg_catalog"} 2.004
pg_stat_user_functions_total_time{fullname="pg_catalog.obj_description.1215",funcname="obj_description",schemaname="pg_catalog"} 0.256
pg_stat_user_tables_analyze_count{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_analyze_count{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_analyze_count{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 0
pg_stat_user_tables_analyze_count{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 0
pg_stat_user_tables_analyze_count{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_analyze_count{fullname="pglogical.node",relname="node",schemaname="pglogical"} 0
pg_stat_user_tables_analyze_count{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 0
pg_stat_user_tables_analyze_count{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 0
pg_stat_user_tables_analyze_count{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_analyze_count{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_analyze_count{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_analyze_count{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_analyze_count{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_analyze_count{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_analyze_count{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_analyze_count{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_analyze_count{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_analyze_count{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_analyze_count{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_analyze_count{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_analyze_count{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_analyze_count{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_autoanalyze_count{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_autoanalyze_count{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 0
pg_stat_user_tables_autoanalyze_count{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 0
pg_stat_user_tables_autoanalyze_count{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_autoanalyze_count{fullname="pglogical.node",relname="node",schemaname="pglogical"} 0
pg_stat_user_tables_autoanalyze_count{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 0
pg_stat_user_tables_autoanalyze_count{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 0
pg_stat_user_tables_autoanalyze_count{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_autoanalyze_count{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_autoanalyze_count{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_autoanalyze_count{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_autoanalyze_count{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_autoanalyze_count{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_autoanalyze_count{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_autoanalyze_count{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_autoanalyze_count{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_autoanalyze_count{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_autoanalyze_count{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_autoanalyze_count{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_autoanalyze_count{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_autoanalyze_count{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_autovacuum_count{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_autovacuum_count{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 0
pg_stat_user_tables_autovacuum_count{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 0
pg_stat_user_tables_autovacuum_count{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_autovacuum_count{fullname="pglogical.node",relname="node",schemaname="pglogical"} 0
pg_stat_user_tables_autovacuum_count{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 0
pg_stat_user_tables_autovacuum_count{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 0
pg_stat_user_tables_autovacuum_count{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_autovacuum_count{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_autovacuum_count{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_autovacuum_count{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_autovacuum_count{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_autovacuum_count{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_autovacuum_count{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_autovacuum_count{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_autovacuum_count{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_autovacuum_count{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_autovacuum_count{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_autovacuum_count{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_autovacuum_count{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_autovacuum_count{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_stat_user_tables_idx_scan{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_idx_scan{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_idx_scan{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} NaN
pg_stat_user_tables_idx_scan{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 0
pg_stat_user_tables_idx_scan{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_idx_scan{fullname="pglogical.node",relname="node",schemaname="pglogical"} 0
pg_stat_user_tables_idx_scan{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 0
pg_stat_user_tables_idx_scan{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} NaN
pg_stat_user_tables_idx_scan{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_idx_scan{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_idx_scan{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_idx_scan{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_idx_scan{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_idx_scan{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_idx_scan{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_idx_scan{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_idx_scan{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_idx_scan{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_idx_scan{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_idx_scan{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_idx_scan{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_idx_scan{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} NaN
pg_stat_user_tables_idx_tup_fetch{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="pglogical.node",relname="node",schemaname="pglogical"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} NaN
pg_stat_user_tables_idx_tup_fetch{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_idx_tup_fetch{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_stat_user_tables_last_analyze{fullname="agency.agents",relname="agents",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.choices",relname="choices",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.components",relname="components",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.configs",relname="configs",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.constraints",relname="constraints",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.controls",relname="controls",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.defects",relname="defects",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.designs",relname="designs",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.events",relname="events",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.jobs",relname="jobs",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.logs",relname="logs",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.options",relname="options",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.plans",relname="plans",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.processes",relname="processes",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.projects",relname="projects",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="agency.sites",relname="sites",schemaname="agency"} NaN
pg_stat_user_tables_last_analyze{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} NaN
pg_stat_user_tables_last_analyze{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} NaN
pg_stat_user_tables_last_analyze{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} NaN
pg_stat_user_tables_last_analyze{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} NaN
pg_stat_user_tables_last_analyze{fullname="pglogical.node",relname="node",schemaname="pglogical"} NaN
pg_stat_user_tables_last_analyze{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} NaN
pg_stat_user_tables_last_analyze{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} NaN
pg_stat_user_tables_last_analyze{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} NaN
pg_stat_user_tables_last_analyze{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} NaN
pg_stat_user_tables_last_analyze{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} NaN
pg_stat_user_tables_last_analyze{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} NaN
pg_stat_user_tables_last_analyze{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} NaN
pg_stat_user_tables_last_analyze{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} NaN
pg_stat_user_tables_last_analyze{fullname="trace.import_components",relname="import_components",schemaname="trace"} NaN
pg_stat_user_tables_last_analyze{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} NaN
pg_stat_user_tables_last_analyze{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} NaN
pg_stat_user_tables_last_analyze{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} NaN
pg_stat_user_tables_last_analyze{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} NaN
pg_stat_user_tables_last_analyze{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} NaN
pg_stat_user_tables_last_analyze{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} NaN
pg_stat_user_tables_last_analyze{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.agents",relname="agents",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.choices",relname="choices",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.components",relname="components",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.configs",relname="configs",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.constraints",relname="constraints",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.controls",relname="controls",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.defects",relname="defects",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.designs",relname="designs",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.events",relname="events",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.jobs",relname="jobs",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.logs",relname="logs",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.options",relname="options",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.plans",relname="plans",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.processes",relname="processes",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.projects",relname="projects",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="agency.sites",relname="sites",schemaname="agency"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="pglogical.node",relname="node",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="trace.import_components",relname="import_components",schemaname="trace"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} NaN
pg_stat_user_tables_last_autoanalyze{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.agents",relname="agents",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.choices",relname="choices",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.components",relname="components",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.configs",relname="configs",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.constraints",relname="constraints",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.controls",relname="controls",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.defects",relname="defects",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.designs",relname="designs",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.events",relname="events",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.jobs",relname="jobs",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.logs",relname="logs",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.options",relname="options",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.plans",relname="plans",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.processes",relname="processes",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.projects",relname="projects",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="agency.sites",relname="sites",schemaname="agency"} NaN
pg_stat_user_tables_last_autovacuum{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} NaN
pg_stat_user_tables_last_autovacuum{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autovacuum{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autovacuum{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autovacuum{fullname="pglogical.node",relname="node",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autovacuum{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autovacuum{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autovacuum{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autovacuum{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autovacuum{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autovacuum{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autovacuum{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} NaN
pg_stat_user_tables_last_autovacuum{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} NaN
pg_stat_user_tables_last_autovacuum{fullname="trace.import_components",relname="import_components",schemaname="trace"} NaN
pg_stat_user_tables_last_autovacuum{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} NaN
pg_stat_user_tables_last_autovacuum{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} NaN
pg_stat_user_tables_last_autovacuum{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} NaN
pg_stat_user_tables_last_autovacuum{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} NaN
pg_stat_user_tables_last_autovacuum{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} NaN
pg_stat_user_tables_last_autovacuum{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} NaN
pg_stat_user_tables_last_autovacuum{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.agents",relname="agents",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.choices",relname="choices",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.components",relname="components",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.configs",relname="configs",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.constraints",relname="constraints",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.controls",relname="controls",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.defects",relname="defects",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.designs",relname="designs",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.events",relname="events",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.jobs",relname="jobs",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.logs",relname="logs",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.options",relname="options",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.plans",relname="plans",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.processes",relname="processes",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.projects",relname="projects",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="agency.sites",relname="sites",schemaname="agency"} NaN
pg_stat_user_tables_last_vacuum{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} NaN
pg_stat_user_tables_last_vacuum{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} NaN
pg_stat_user_tables_last_vacuum{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} NaN
pg_stat_user_tables_last_vacuum{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} NaN
pg_stat_user_tables_last_vacuum{fullname="pglogical.node",relname="node",schemaname="pglogical"} NaN
pg_stat_user_tables_last_vacuum{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} NaN
pg_stat_user_tables_last_vacuum{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} NaN
pg_stat_user_tables_last_vacuum{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} NaN
pg_stat_user_tables_last_vacuum{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} NaN
pg_stat_user_tables_last_vacuum{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} NaN
pg_stat_user_tables_last_vacuum{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} NaN
pg_stat_user_tables_last_vacuum{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} NaN
pg_stat_user_tables_last_vacuum{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} NaN
pg_stat_user_tables_last_vacuum{fullname="trace.import_components",relname="import_components",schemaname="trace"} NaN
pg_stat_user_tables_last_vacuum{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} NaN
pg_stat_user_tables_last_vacuum{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} NaN
pg_stat_user_tables_last_vacuum{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} NaN
pg_stat_user_tables_last_vacuum{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} NaN
pg_stat_user_tables_last_vacuum{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} NaN
pg_stat_user_tables_last_vacuum{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} NaN
pg_stat_user_tables_last_vacuum{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} NaN
pg_stat_user_tables_n_dead_tup{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_n_dead_tup{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_n_dead_tup{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 0
pg_stat_user_tables_n_dead_tup{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 0
pg_stat_user_tables_n_dead_tup{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_n_dead_tup{fullname="pglogical.node",relname="node",schemaname="pglogical"} 0
pg_stat_user_tables_n_dead_tup{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 0
pg_stat_user_tables_n_dead_tup{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 0
pg_stat_user_tables_n_dead_tup{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_n_dead_tup{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_n_dead_tup{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_n_dead_tup{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_n_dead_tup{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_n_dead_tup{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_n_dead_tup{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_n_dead_tup{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_n_dead_tup{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_n_dead_tup{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_n_dead_tup{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_n_dead_tup{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_n_dead_tup{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_n_dead_tup{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_n_live_tup{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_n_live_tup{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 0
pg_stat_user_tables_n_live_tup{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 0
pg_stat_user_tables_n_live_tup{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_n_live_tup{fullname="pglogical.node",relname="node",schemaname="pglogical"} 0
pg_stat_user_tables_n_live_tup{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 0
pg_stat_user_tables_n_live_tup{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 0
pg_stat_user_tables_n_live_tup{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_n_live_tup{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_n_live_tup{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_n_live_tup{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_n_live_tup{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_n_live_tup{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_n_live_tup{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_n_live_tup{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_n_live_tup{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_n_live_tup{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_n_live_tup{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_n_live_tup{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_n_live_tup{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_n_live_tup{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="pglogical.node",relname="node",schemaname="pglogical"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_n_mod_since_analyze{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_n_tup_del{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_n_tup_del{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_del{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_del{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_del{fullname="pglogical.node",relname="node",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_del{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_del{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_del{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_del{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_del{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_del{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_del{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_del{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_n_tup_del{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_n_tup_del{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_n_tup_del{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_n_tup_del{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_n_tup_del{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_n_tup_del{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_n_tup_del{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_n_tup_del{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="pglogical.node",relname="node",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_n_tup_hot_upd{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_n_tup_ins{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_n_tup_ins{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_ins{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_ins{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_ins{fullname="pglogical.node",relname="node",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_ins{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_ins{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_ins{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_ins{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_ins{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_ins{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_ins{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_ins{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_n_tup_ins{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_n_tup_ins{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_n_tup_ins{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_n_tup_ins{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_n_tup_ins{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_n_tup_ins{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_n_tup_ins{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_n_tup_ins{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_n_tup_mod{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_n_tup_mod{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_mod{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_mod{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_mod{fullname="pglogical.node",relname="node",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_mod{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_mod{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_mod{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_mod{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_mod{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_mod{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_mod{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_mod{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_n_tup_mod{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_n_tup_mod{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_n_tup_mod{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_n_tup_mod{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_n_tup_mod{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_n_tup_mod{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_n_tup_mod{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_n_tup_mod{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_n_tup_upd{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_n_tup_upd{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_upd{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_upd{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_upd{fullname="pglogical.node",relname="node",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_upd{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_upd{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_upd{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_upd{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_upd{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_upd{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_upd{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_n_tup_upd{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_n_tup_upd{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_n_tup_upd{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_n_tup_upd{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_n_tup_upd{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_n_tup_upd{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_n_tup_upd{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_n_tup_upd{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_n_tup_upd{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_stat_user_tables_relage{fullname="agency.agents",relname="agents",schemaname="agency"} 6.1715812e+07
pg_stat_user_tables_relage{fullname="agency.choices",relname="choices",schemaname="agency"} 8.1837324e+07
pg_stat_user_tables_relage{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 9.4973227e+07
pg_stat_user_tables_relage{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 1.70642855e+08
pg_stat_user_tables_relage{fullname="agency.components",relname="components",schemaname="agency"} 1.06931193e+08
pg_stat_user_tables_relage{fullname="agency.configs",relname="configs",schemaname="agency"} 1.06888514e+08
pg_stat_user_tables_relage{fullname="agency.constraints",relname="constraints",schemaname="agency"} 1.08971043e+08
pg_stat_user_tables_relage{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 1.08607386e+08
pg_stat_user_tables_relage{fullname="agency.controls",relname="controls",schemaname="agency"} 1.06888514e+08
pg_stat_user_tables_relage{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 1.12628477e+08
pg_stat_user_tables_relage{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 1.70223643e+08
pg_stat_user_tables_relage{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 1.36581337e+08
pg_stat_user_tables_relage{fullname="agency.defects",relname="defects",schemaname="agency"} 1.36581337e+08
pg_stat_user_tables_relage{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 1.36581337e+08
pg_stat_user_tables_relage{fullname="agency.designs",relname="designs",schemaname="agency"} 1.61418434e+08
pg_stat_user_tables_relage{fullname="agency.events",relname="events",schemaname="agency"} 1.06931193e+08
pg_stat_user_tables_relage{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 1.16834989e+08
pg_stat_user_tables_relage{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 1.36824879e+08
pg_stat_user_tables_relage{fullname="agency.jobs",relname="jobs",schemaname="agency"} 1.06931193e+08
pg_stat_user_tables_relage{fullname="agency.logs",relname="logs",schemaname="agency"} 1.96247246e+08
pg_stat_user_tables_relage{fullname="agency.options",relname="options",schemaname="agency"} 1.08708981e+08
pg_stat_user_tables_relage{fullname="agency.plans",relname="plans",schemaname="agency"} 1.06888514e+08
pg_stat_user_tables_relage{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 1.08971043e+08
pg_stat_user_tables_relage{fullname="agency.processes",relname="processes",schemaname="agency"} 1.61418434e+08
pg_stat_user_tables_relage{fullname="agency.projects",relname="projects",schemaname="agency"} 1.06888514e+08
pg_stat_user_tables_relage{fullname="agency.sites",relname="sites",schemaname="agency"} 1.06931193e+08
pg_stat_user_tables_relage{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 1.08854798e+08
pg_stat_user_tables_relage{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 1.28505678e+08
pg_stat_user_tables_relage{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 1.08971043e+08
pg_stat_user_tables_relage{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 1.08854798e+08
pg_stat_user_tables_relage{fullname="pglogical.node",relname="node",schemaname="pglogical"} 1.28837635e+08
pg_stat_user_tables_relage{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 1.08971043e+08
pg_stat_user_tables_relage{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 1.08854798e+08
pg_stat_user_tables_relage{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 1.28505678e+08
pg_stat_user_tables_relage{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 1.28505678e+08
pg_stat_user_tables_relage{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 1.28505678e+08
pg_stat_user_tables_relage{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 1.28505678e+08
pg_stat_user_tables_relage{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 1.08854798e+08
pg_stat_user_tables_relage{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 1.33141486e+08
pg_stat_user_tables_relage{fullname="trace.import_components",relname="import_components",schemaname="trace"} 1.36581337e+08
pg_stat_user_tables_relage{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 1.36581337e+08
pg_stat_user_tables_relage{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 1.36581337e+08
pg_stat_user_tables_relage{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 1.50885428e+08
pg_stat_user_tables_relage{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 2.146483647e+09
pg_stat_user_tables_relage{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 1.50885428e+08
pg_stat_user_tables_relage{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 1.07062665e+08
pg_stat_user_tables_relage{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 1.07062665e+08
pg_stat_user_tables_relpages{fullname="agency.agents",relname="agents",schemaname="agency"} 846226
pg_stat_user_tables_relpages{fullname="agency.choices",relname="choices",schemaname="agency"} 8
pg_stat_user_tables_relpages{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 3
pg_stat_user_tables_relpages{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 28
pg_stat_user_tables_relpages{fullname="agency.components",relname="components",schemaname="agency"} 1
pg_stat_user_tables_relpages{fullname="agency.configs",relname="configs",schemaname="agency"} 1
pg_stat_user_tables_relpages{fullname="agency.constraints",relname="constraints",schemaname="agency"} 3
pg_stat_user_tables_relpages{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 4
pg_stat_user_tables_relpages{fullname="agency.controls",relname="controls",schemaname="agency"} 4
pg_stat_user_tables_relpages{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 5
pg_stat_user_tables_relpages{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 9
pg_stat_user_tables_relpages{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 21
pg_stat_user_tables_relpages{fullname="agency.defects",relname="defects",schemaname="agency"} 71
pg_stat_user_tables_relpages{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 146
pg_stat_user_tables_relpages{fullname="agency.designs",relname="designs",schemaname="agency"} 10
pg_stat_user_tables_relpages{fullname="agency.events",relname="events",schemaname="agency"} 1
pg_stat_user_tables_relpages{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 3159
pg_stat_user_tables_relpages{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 1
pg_stat_user_tables_relpages{fullname="agency.jobs",relname="jobs",schemaname="agency"} 6466
pg_stat_user_tables_relpages{fullname="agency.logs",relname="logs",schemaname="agency"} 5.7259152e+07
pg_stat_user_tables_relpages{fullname="agency.options",relname="options",schemaname="agency"} 2
pg_stat_user_tables_relpages{fullname="agency.plans",relname="plans",schemaname="agency"} 1
pg_stat_user_tables_relpages{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 3
pg_stat_user_tables_relpages{fullname="agency.processes",relname="processes",schemaname="agency"} 8
pg_stat_user_tables_relpages{fullname="agency.projects",relname="projects",schemaname="agency"} 1
pg_stat_user_tables_relpages{fullname="agency.sites",relname="sites",schemaname="agency"} 1
pg_stat_user_tables_relpages{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 1
pg_stat_user_tables_relpages{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 1
pg_stat_user_tables_relpages{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 1
pg_stat_user_tables_relpages{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_relpages{fullname="pglogical.node",relname="node",schemaname="pglogical"} 1
pg_stat_user_tables_relpages{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 1
pg_stat_user_tables_relpages{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 1
pg_stat_user_tables_relpages{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 1
pg_stat_user_tables_relpages{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_relpages{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 1
pg_stat_user_tables_relpages{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_relpages{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_relpages{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 1
pg_stat_user_tables_relpages{fullname="trace.import_components",relname="import_components",schemaname="trace"} 13
pg_stat_user_tables_relpages{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 1
pg_stat_user_tables_relpages{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 144
pg_stat_user_tables_relpages{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_relpages{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 742070
pg_stat_user_tables_relpages{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_relpages{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 26887
pg_stat_user_tables_relpages{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 3435
pg_stat_user_tables_relsize{fullname="agency.agents",relname="agents",schemaname="agency"} 7.668768768e+09
pg_stat_user_tables_relsize{fullname="agency.choices",relname="choices",schemaname="agency"} 163840
pg_stat_user_tables_relsize{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 98304
pg_stat_user_tables_relsize{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 368640
pg_stat_user_tables_relsize{fullname="agency.components",relname="components",schemaname="agency"} 65536
pg_stat_user_tables_relsize{fullname="agency.configs",relname="configs",schemaname="agency"} 65536
pg_stat_user_tables_relsize{fullname="agency.constraints",relname="constraints",schemaname="agency"} 81920
pg_stat_user_tables_relsize{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 114688
pg_stat_user_tables_relsize{fullname="agency.controls",relname="controls",schemaname="agency"} 81920
pg_stat_user_tables_relsize{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 131072
pg_stat_user_tables_relsize{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 196608
pg_stat_user_tables_relsize{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 303104
pg_stat_user_tables_relsize{fullname="agency.defects",relname="defects",schemaname="agency"} 1.081344e+06
pg_stat_user_tables_relsize{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 2.41664e+06
pg_stat_user_tables_relsize{fullname="agency.designs",relname="designs",schemaname="agency"} 163840
pg_stat_user_tables_relsize{fullname="agency.events",relname="events",schemaname="agency"} 65536
pg_stat_user_tables_relsize{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 3.088384e+07
pg_stat_user_tables_relsize{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 81920
pg_stat_user_tables_relsize{fullname="agency.jobs",relname="jobs",schemaname="agency"} 1.33382144e+08
pg_stat_user_tables_relsize{fullname="agency.logs",relname="logs",schemaname="agency"} 1.000149999616e+12
pg_stat_user_tables_relsize{fullname="agency.options",relname="options",schemaname="agency"} 73728
pg_stat_user_tables_relsize{fullname="agency.plans",relname="plans",schemaname="agency"} 65536
pg_stat_user_tables_relsize{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 106496
pg_stat_user_tables_relsize{fullname="agency.processes",relname="processes",schemaname="agency"} 147456
pg_stat_user_tables_relsize{fullname="agency.projects",relname="projects",schemaname="agency"} 65536
pg_stat_user_tables_relsize{fullname="agency.sites",relname="sites",schemaname="agency"} 81920
pg_stat_user_tables_relsize{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 57344
pg_stat_user_tables_relsize{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 40960
pg_stat_user_tables_relsize{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 57344
pg_stat_user_tables_relsize{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 8192
pg_stat_user_tables_relsize{fullname="pglogical.node",relname="node",schemaname="pglogical"} 73728
pg_stat_user_tables_relsize{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 81920
pg_stat_user_tables_relsize{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 49152
pg_stat_user_tables_relsize{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 73728
pg_stat_user_tables_relsize{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 8192
pg_stat_user_tables_relsize{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 65536
pg_stat_user_tables_relsize{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 8192
pg_stat_user_tables_relsize{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 24576
pg_stat_user_tables_relsize{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 65536
pg_stat_user_tables_relsize{fullname="trace.import_components",relname="import_components",schemaname="trace"} 163840
pg_stat_user_tables_relsize{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 65536
pg_stat_user_tables_relsize{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 2.555904e+06
pg_stat_user_tables_relsize{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 40960
pg_stat_user_tables_relsize{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 1.49193777152e+11
pg_stat_user_tables_relsize{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 32768
pg_stat_user_tables_relsize{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 2.31481344e+08
pg_stat_user_tables_relsize{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 3.444736e+07
pg_stat_user_tables_reltuples{fullname="agency.agents",relname="agents",schemaname="agency"} 5074
pg_stat_user_tables_reltuples{fullname="agency.choices",relname="choices",schemaname="agency"} 620
pg_stat_user_tables_reltuples{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 183
pg_stat_user_tables_reltuples{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 1245
pg_stat_user_tables_reltuples{fullname="agency.components",relname="components",schemaname="agency"} 29
pg_stat_user_tables_reltuples{fullname="agency.configs",relname="configs",schemaname="agency"} 4
pg_stat_user_tables_reltuples{fullname="agency.constraints",relname="constraints",schemaname="agency"} 208
pg_stat_user_tables_reltuples{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 399
pg_stat_user_tables_reltuples{fullname="agency.controls",relname="controls",schemaname="agency"} 242
pg_stat_user_tables_reltuples{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 682
pg_stat_user_tables_reltuples{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 1030
pg_stat_user_tables_reltuples{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 1270
pg_stat_user_tables_reltuples{fullname="agency.defects",relname="defects",schemaname="agency"} 3437
pg_stat_user_tables_reltuples{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 8737
pg_stat_user_tables_reltuples{fullname="agency.designs",relname="designs",schemaname="agency"} 612
pg_stat_user_tables_reltuples{fullname="agency.events",relname="events",schemaname="agency"} 19
pg_stat_user_tables_reltuples{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 47815
pg_stat_user_tables_reltuples{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 20
pg_stat_user_tables_reltuples{fullname="agency.jobs",relname="jobs",schemaname="agency"} 476710
pg_stat_user_tables_reltuples{fullname="agency.logs",relname="logs",schemaname="agency"} 1.297057152e+09
pg_stat_user_tables_reltuples{fullname="agency.options",relname="options",schemaname="agency"} 121
pg_stat_user_tables_reltuples{fullname="agency.plans",relname="plans",schemaname="agency"} 29
pg_stat_user_tables_reltuples{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 162
pg_stat_user_tables_reltuples{fullname="agency.processes",relname="processes",schemaname="agency"} 604
pg_stat_user_tables_reltuples{fullname="agency.projects",relname="projects",schemaname="agency"} 17
pg_stat_user_tables_reltuples{fullname="agency.sites",relname="sites",schemaname="agency"} 1
pg_stat_user_tables_reltuples{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 38
pg_stat_user_tables_reltuples{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 25
pg_stat_user_tables_reltuples{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 1
pg_stat_user_tables_reltuples{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_reltuples{fullname="pglogical.node",relname="node",schemaname="pglogical"} 1
pg_stat_user_tables_reltuples{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 1
pg_stat_user_tables_reltuples{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 2
pg_stat_user_tables_reltuples{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 4
pg_stat_user_tables_reltuples{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_reltuples{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 25
pg_stat_user_tables_reltuples{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_reltuples{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_reltuples{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 2
pg_stat_user_tables_reltuples{fullname="trace.import_components",relname="import_components",schemaname="trace"} 92
pg_stat_user_tables_reltuples{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 71
pg_stat_user_tables_reltuples{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 9187
pg_stat_user_tables_reltuples{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_reltuples{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 4.034744e+07
pg_stat_user_tables_reltuples{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_reltuples{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 483894
pg_stat_user_tables_reltuples{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 32325
pg_stat_user_tables_seq_scan{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_seq_scan{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_seq_scan{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 0
pg_stat_user_tables_seq_scan{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 10
pg_stat_user_tables_seq_scan{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_seq_scan{fullname="pglogical.node",relname="node",schemaname="pglogical"} 10
pg_stat_user_tables_seq_scan{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 10
pg_stat_user_tables_seq_scan{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 0
pg_stat_user_tables_seq_scan{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_seq_scan{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_seq_scan{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_seq_scan{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 5
pg_stat_user_tables_seq_scan{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 5
pg_stat_user_tables_seq_scan{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_seq_scan{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_seq_scan{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_seq_scan{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_seq_scan{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_seq_scan{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_seq_scan{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_seq_scan{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_seq_scan{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_seq_tup_read{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_seq_tup_read{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 0
pg_stat_user_tables_seq_tup_read{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 10
pg_stat_user_tables_seq_tup_read{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_seq_tup_read{fullname="pglogical.node",relname="node",schemaname="pglogical"} 10
pg_stat_user_tables_seq_tup_read{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 10
pg_stat_user_tables_seq_tup_read{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 0
pg_stat_user_tables_seq_tup_read{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_seq_tup_read{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_seq_tup_read{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_seq_tup_read{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_seq_tup_read{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_seq_tup_read{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_seq_tup_read{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_seq_tup_read{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_seq_tup_read{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_seq_tup_read{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_seq_tup_read{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_seq_tup_read{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_seq_tup_read{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_seq_tup_read{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.agents",relname="agents",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.choices",relname="choices",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.choices_constraints",relname="choices_constraints",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.choices_designs",relname="choices_designs",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.components",relname="components",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.configs",relname="configs",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.constraints",relname="constraints",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.constraints_processes",relname="constraints_processes",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.controls",relname="controls",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.controls_events",relname="controls_events",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.controls_processes",relname="controls_processes",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.defect_groups",relname="defect_groups",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.defects",relname="defects",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.defects_processes",relname="defects_processes",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.designs",relname="designs",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.events",relname="events",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.fatp_sequences",relname="fatp_sequences",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.flyway_schema_history",relname="flyway_schema_history",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.jobs",relname="jobs",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.logs",relname="logs",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.options",relname="options",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.plans",relname="plans",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.plans_processes",relname="plans_processes",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.processes",relname="processes",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.projects",relname="projects",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="agency.sites",relname="sites",schemaname="agency"} 0
pg_stat_user_tables_vacuum_count{fullname="migrations.migrations",relname="migrations",schemaname="migrations"} 0
pg_stat_user_tables_vacuum_count{fullname="pglogical.depend",relname="depend",schemaname="pglogical"} 0
pg_stat_user_tables_vacuum_count{fullname="pglogical.local_node",relname="local_node",schemaname="pglogical"} 0
pg_stat_user_tables_vacuum_count{fullname="pglogical.local_sync_status",relname="local_sync_status",schemaname="pglogical"} 0
pg_stat_user_tables_vacuum_count{fullname="pglogical.node",relname="node",schemaname="pglogical"} 0
pg_stat_user_tables_vacuum_count{fullname="pglogical.node_interface",relname="node_interface",schemaname="pglogical"} 0
pg_stat_user_tables_vacuum_count{fullname="pglogical.queue",relname="queue",schemaname="pglogical"} 0
pg_stat_user_tables_vacuum_count{fullname="pglogical.replication_set",relname="replication_set",schemaname="pglogical"} 0
pg_stat_user_tables_vacuum_count{fullname="pglogical.replication_set_seq",relname="replication_set_seq",schemaname="pglogical"} 0
pg_stat_user_tables_vacuum_count{fullname="pglogical.replication_set_table",relname="replication_set_table",schemaname="pglogical"} 0
pg_stat_user_tables_vacuum_count{fullname="pglogical.sequence_state",relname="sequence_state",schemaname="pglogical"} 0
pg_stat_user_tables_vacuum_count{fullname="pglogical.subscription",relname="subscription",schemaname="pglogical"} 0
pg_stat_user_tables_vacuum_count{fullname="trace.import_admin_groups",relname="import_admin_groups",schemaname="trace"} 0
pg_stat_user_tables_vacuum_count{fullname="trace.import_components",relname="import_components",schemaname="trace"} 0
pg_stat_user_tables_vacuum_count{fullname="trace.import_projects",relname="import_projects",schemaname="trace"} 0
pg_stat_user_tables_vacuum_count{fullname="trace.import_user_projects",relname="import_user_projects",schemaname="trace"} 0
pg_stat_user_tables_vacuum_count{fullname="trace.m_logs",relname="m_logs",schemaname="trace"} 0
pg_stat_user_tables_vacuum_count{fullname="trace.m_parts",relname="m_parts",schemaname="trace"} 0
pg_stat_user_tables_vacuum_count{fullname="trace.m_rollups",relname="m_rollups",schemaname="trace"} 0
pg_stat_user_tables_vacuum_count{fullname="trace.reindexes",relname="reindexes",schemaname="trace"} 0
pg_stat_user_tables_vacuum_count{fullname="transferd.transfer_errors",relname="transfer_errors",schemaname="transferd"} 0
pg_static{short_version="9.6.10",version="PostgreSQL 9.6.10 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.4.7 20120313 (Red Hat 4.4.7-23), 64-bit"} 1
pg_up 1
pg_uptime 524873.834413
process_cpu_seconds_total 0.05
process_max_fds 65535
process_open_fds 8
process_resident_memory_bytes 8.11008e+06
process_start_time_seconds 1.54709807385e+09
process_virtual_memory_bytes 1.7727488e+07
```

### run

```bash
PG_EXPORTER_DISABLE_DEFAULT_METRICS=true DATA_SOURCE_NAME="postgres:///postgres?sslmode=disable&host=/tmp" PG_EXPORTER_EXTEND_QUERY_PATH=/etc/postgres_exporter96.yaml PG_EXPORTER_WEB_LISTEN_ADDRESS=:9185 PG_EXPORTER_WEB_TELEMETRY_PATH=/debug/metrics /usr/local/bin//postgres_exporter
```



## 监控系统的指标

监控面板与系统架构，不过是监控系统的面子，真正的里子在于监控指标。哪些指标需要监控，每种指标如何解读，这才是真正重要的东西。毕竟知道了这些知识，即使没有监控系统，通过命令行手工检查也可以发现问题，但不了解指标背后的涵义，即使再傻瓜再漂亮的监控面板也于事无补。

下面会简单介绍单实例监控面板中涉及到的指标。

### 概览

概览是一些重要的核心指标，一眼扫过去就应当能大致定位数据库的主要问题。这里主要包括：

* CPU使用率、平均查询时间、TPS、QPS，连接池排队数，活跃连接数：判断数据库负载水平
* 内存空闲率：判断是否出现进程异常（例如突然被杀）
* 磁盘空闲率：判断磁盘是否被写满
* 数据库年龄：数据库是否快出现事务标识回卷故障。
* 数据库大小，缓存命中率：判断异常活动

### 操作系统指标

操作系统指标主要包括：

* CPU与负载水平
* 内存使用，特别需要关注操作系统`cache`部分的变化。
* 网络与磁盘的IO吞吐量，磁盘的IOPS。

操作系统的指标能直观地反映大部分数据库活动异常，对于硬件类故障的排查尤有帮助。

### 数据库活动与会话

Activity与Session是数据库当前状态的直观反映，指标包括：

* TPS/QPS，平均响应时间都是最直接的负载指标。
* 缓存命中率对数据库性能有直接的影响，注意这里只是PostgreSQL本身BufferPool的命中率，并没有计算操作系统的文件缓存。
* 后端连接按状态的分布，`active`状态的连接是很重要的负载指标，而`idle in transaction`的连接数则需要特别关注。
* 临时文件通常是由一些复杂查询，长查询，过多的临时文件容易导致性能恶化。

### 复制指标

很多类型的故障与主从复制滞后有关，因此，ReplicationDelay是一个重要的监控指标。

在主库上可以获取从库的复制延迟，包括LSN落后的字节数，以及滞后的时长（v10以后）。在从库上也可以获得距离主库的滞后时长，但这种方法通常不如前一种准确。

### 检查点与WAL

检查点会吃IO，一方面它会引发大量页面落盘，另一方面在默认`full_page_write`打开的情况下，每一次检查点都会导致其后的WAL量升高，吃磁盘与网络的带宽。在一些情况下可能会成为故障的原因。因此有必要监控检查点与WAL，相关指标包括：

* WAL日志的生成速率
* LSN增长的速度
* 缓冲区刷回的数目，通常缓冲区刷回主要由Checkpoint负责，如果有大量缓冲区由后端进程负责刷盘，就需要检查并调整相关参数的配置了。
* 数据库与WAL日志的大小。

### 锁与数据库冲突

锁按类型分布的数据对于判断数据库活动的类型很有帮助。

### 对象级统计

对象级统计能够帮助DBA快速定位故障的根源。包括：

* 每个表的访问次数：索引扫描/顺序扫描。频繁出现的顺序扫描往往意味着索引出现了问题。
* 表中元组的拉取，修改，增删改查数目，表的大小，年龄，都有助于精确定位问题的来源。
* 死元组的比例：死元组的比例可用于估算表的膨胀程度，对于维持性能很有帮助。（还有另外一种通过统计数据估算表膨胀率的方法）
* 函数的调用次数与执行时间。





## 监控指标的来源

### 统计收集器

对于PostgreSQL而言，其监控指标主要源于自带的统计收集器。PostgreSQL提供了很多系统视图，因此能很简单地以SQL语句的形式拉取统计数据。系统视图的具体定义可以参考文档，后续文章也会依此详细介绍。其中，比较重要的视图包括：

| 视图名称                     | 描述                                                       |
| ---------------------------- | ---------------------------------------------------------- |
| `pg_stat_bgwriter`           | 只有一行，后台写入器相关统计信息                           |
| `pg_stat_activity`           | 可以看到数据库中的活动，非常重要                           |
| `pg_stat_statement`          | 可以统计数据库中每条查询的执行情况，很重要但不太适合展现。 |
| `pg_stat_database`           | 每个数据库一行，显示数据库范围的统计信息。                 |
| `pg_stat_database_conflicts` | 每个数据库一行，显示了数据库中的各类冲突数目。             |
| `pg_stat_user_tables`        | 包含了每个表的详细统计信息                                 |
| `pg_stat_user_indexes`       | 包含了每个索引上详细的统计信息                             |
| `pg_statio_user_tables`      | 包含了表上IO花费的时间，但因为计时会影响性能，打开需小心。 |
| `pg_stat_user_functions`     | 包含了函数的调用总次数，执行时长等统计信息                 |
| `pg_stat_replication`        | 每一条对应一个slave（LSN消费者），包含了复制相关的指标。   |
| `pg_stat_wal_receiver`       | 在从库上可以从这里看到主库相关的信息                       |

从统计视图中收集数据有一些注意事项：

- 统计数据并非实时更新的，每个服务进程只有在闲置前会更新统计计数。所以正在执行的查询和事务不影响计数。
- 收集器本身每隔（`PGSTAT_STAT_INTERVAL=500ms`）才发送一次新的报告。所以除了 当前进程活动`track_activity`之外的统计指标都不是最新的。
- 在事务中执行的统计查询，统计数据不会发生变化。使用`pg_stat_clear_snapshot()`来获取最新的快照。

* 要让数据库收集这些统计数据，需要在`postgresql.conf`中打开各种`track_*`选项。

### 系统视图

除了统计视图外，还有一些系统视图也能提供很多有价值的指标信息，例如`pg_database`与`pg_locks`，分别提供了数据库年龄尺寸，以及数据库内的锁等待信息。此外，还有很多系统指标是通过内建的函数提供的。



## 结语

监控是一个很大的话题，够写半本书了，因此这篇文章能做的也就是给读者留下一点直觉：监控系统应该是啥样子的。其实这玩意很简单，有了以上的信息，一个合格的架构师与PostgreSQL DBA应该能很轻松的复现该监控系统了。具体的实现细节，将在后续文章中继续介绍。







## Additional Setup

If we can go further, two things are helpful to build a better monitoring systems.

### Domain Name Systems

We should considering using a unified naming systems to identify machines, modules, services, One practical design would be like: <member>.<module>.<datacenter>.<tld>

```
# catcher suqian tracedb1 primary
1.master.tracedb1.csq.md
2.slave.tracedb1.csq.md

# api services
1.restapi.trace.flh.md
2.restapi.agency.cup.md

# gateway & LB services
1.nginx.csq.md
1.haproxy.csq.md
1.prometheus.csq.md
```

DNS LB is very import for smooth failover, we should considering establish such a domain name system ASAP. All other system will benefit from it, For example, Monitoring system could filter these domain with regex in a simple manner.

### Services Discovery

Services discovery is also important for monitoring batch of endpoints. consul could be used for this purpose. Just deploy consul across all nodes. and register services(prometheus exporter endpoint) to it by :

```
# variable
node_id="tc001m01"
role_name="master1.tracedb.csq.md"

consul_conf_dir="/etc/consul/conf.d"
mkdir -p ${consul_conf_dir}
chown -R consul:consul ${consul_conf_dir}

node_exporter_conf=$(cat <<-EOF
{"service":{"name":"prometheus-node-exporter-${role_name}", "id":"${node_id}.node_exporter","tags":[],"port":9100}}
EOF
)

postgres_exporter_conf=$(cat <<-EOF
{"service":{"name":"prometheus-postgres-exporter-${role_name}", "id":"${node_id}.postgres_exporter","tags":[],"port":9185}}
EOF
)

pgbouncer_exporter_conf=$(cat <<-EOF
{"service":{"name":"prometheus-pgbouncer-exporter-${role_name}", "id":"${node_id}.pgbouncer_exporter","tags":[],"port":9127}}
EOF
)

echo ${node_exporter_conf} > /etc/consul/conf.d/prometheus-node-exporter-${role_name}.json
echo ${postgres_exporter_conf}  > /etc/consul/conf.d/prometheus-postgres-exporter-${role_name}.json
echo ${pgbouncer_exporter_conf}  > /etc/consul/conf.d/prometheus-pgbouncer-exporter-${role_name}.json

# reload
consul reload
```

By configuring prometheus yaml files and enable sd_consul. Now you don't need to change prometheus.yaml anymore.