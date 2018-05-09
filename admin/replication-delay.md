---
author: "Vonng"
description: "PostgreSQL主从复制延迟问题"
categories: ["DBA"]
tags: ["PostgreSQL","复制延迟"]
type: "post"
---



# PostgreSQL 复制延迟问题

复制系统的一个重要细节是：复制是**同步（synchronously）**发生还是**异步（asynchronously）**发生。 

任何使用异步复制的数据库系统不可避免地会遇到**复制延迟（replication delay）**问题。



## 复制延迟问题

基于主库的复制要求所有写入都由单个节点处理，但只读查询可以由任何副本处理。所以对于读多写少的场景（Web上的常见模式），一个有吸引力的选择是创建很多从库，并将读请求分散到所有的从库上去。这样能减小主库的负载，并允许向最近的副本发送读请求。

在这种扩展体系结构中，只需添加更多的追随者，就可以提高只读请求的服务容量。但是，这种方法实际上只适用于异步复制——如果尝试同步复制到所有追随者，则单个节点故障或网络中断将使整个系统无法写入。而且越多的节点越有可能会被关闭，所以完全同步的配置是非常不可靠的。

不幸的是，当应用程序从异步从库读取时，如果从库落后，它可能会看到过时的信息。这会导致数据库中出现明显的不一致：同时对主库和从库执行相同的查询，可能得到不同的结果，因为并非所有的写入都反映在从库中。这种不一致只是一个暂时的状态——如果停止写入数据库并等待一段时间，从库最终会赶上并与主库保持一致。出于这个原因，这种效应被称为**最终一致性（eventually consistency）**

因为滞后时间太长引入的不一致性，可不仅是一个理论问题，更是应用设计中会遇到的真实问题：

- 读写一致性：写入主库后，在复制未完成时立刻由从库读取自己的写入。
- 单调读：从复制延迟各异的从库读取，发生时光倒流的现象。
- 一致前缀读：由于不存在全局写入顺序，从分区数据库读取时可能遇到某些部分较旧，某些部分较新的情况。

## 监控复制延迟

在PostgreSQL中，与复制相关的视图包括：



`pg_stat_replication` 

| Column             | Type                       | Description                                                  |
| ------------------ | -------------------------- | ------------------------------------------------------------ |
| `pid`              | `integer`                  | Process ID of a WAL sender process                           |
| `usesysid`         | `oid`                      | OID of the user logged into this WAL sender process          |
| `usename`          | `name`                     | Name of the user logged into this WAL sender process         |
| `application_name` | `text`                     | Name of the application that is connected to this WAL sender |
| `client_addr`      | `inet`                     | IP address of the client connected to this WAL sender. If this field is null, it indicates that the client is connected via a Unix socket on the server machine. |
| `client_hostname`  | `text`                     | Host name of the connected client, as reported by a reverse DNS lookup of `client_addr`. This field will only be non-null for IP connections, and only when [log_hostname](runtime-config-logging.html#GUC-LOG-HOSTNAME) is enabled. |
| `client_port`      | `integer`                  | TCP port number that the client is using for communication with this WAL sender, or `-1` if a Unix socket is used |
| `backend_start`    | `timestamp with time zone` | Time when this process was started, i.e., when the client connected to this WAL sender |
| `backend_xmin`     | `xid`                      | This standby's `xmin` horizon reported by [hot_standby_feedback](runtime-config-replication.html#GUC-HOT-STANDBY-FEEDBACK). |
| `state`            | `text`                     | Current WAL sender state. Possible values are:`startup`: This WAL sender is starting up.`catchup`: This WAL sender's connected standby is catching up with the primary.`streaming`: This WAL sender is streaming changes after its connected standby server has caught up with the primary.`backup`: This WAL sender is sending a backup.`stopping`: This WAL sender is stopping. |
| `sent_lsn`         | `pg_lsn`                   | Last write-ahead log location sent on this connection        |
| `write_lsn`        | `pg_lsn`                   | Last write-ahead log location written to disk by this standby server |
| `flush_lsn`        | `pg_lsn`                   | Last write-ahead log location flushed to disk by this standby server |
| `replay_lsn`       | `pg_lsn`                   | Last write-ahead log location replayed into the database on this standby server |
| `write_lag`        | `interval`                 | Time elapsed between flushing recent WAL locally and receiving notification that this standby server has written it (but not yet flushed it or applied it). This can be used to gauge the delay that `synchronous_commit` level `remote_write` incurred while committing if this server was configured as a synchronous standby. |
| `flush_lag`        | `interval`                 | Time elapsed between flushing recent WAL locally and receiving notification that this standby server has written and flushed it (but not yet applied it). This can be used to gauge the delay that `synchronous_commit` level `remote_flush` incurred while committing if this server was configured as a synchronous standby. |
| `replay_lag`       | `interval`                 | Time elapsed between flushing recent WAL locally and receiving notification that this standby server has written, flushed and applied it. This can be used to gauge the delay that `synchronous_commit` level `remote_apply` incurred while committing if this server was configured as a synchronous standby. |
| `sync_priority`    | `integer`                  | Priority of this standby server for being chosen as the synchronous standby in a priority-based synchronous replication. This has no effect in a quorum-based synchronous replication. |
| `sync_state`       | `text`                     | Synchronous state of this standby server. Possible values are:`async`: This standby server is asynchronous.`potential`: This standby server is now asynchronous, but can potentially become synchronous if one of current synchronous ones fails.`sync`: This standby server is synchronous.`quorum`: This standby server is considered as a candidate for quorum standbys. |

The `pg_stat_replication` view will contain one row per WAL sender process, showing statistics about replication to that sender's connected standby server. Only directly connected standbys are listed; no information is available about downstream standby servers.

The lag times reported in the `pg_stat_replication` view are measurements of the time taken for recent WAL to be written, flushed and replayed and for the sender to know about it. These times represent the commit delay that was (or would have been) introduced by each synchronous commit level, if the remote server was configured as a synchronous standby. For an asynchronous standby, the `replay_lag` column approximates the delay before recent transactions became visible to queries. If the standby server has entirely caught up with the sending server and there is no more WAL activity, the most recently measured lag times will continue to be displayed for a short time and then show NULL.

Lag times work automatically for physical replication. Logical decoding plugins may optionally emit tracking messages; if they do not, the tracking mechanism will simply display NULL lag.

### Note

The reported lag times are not predictions of how long it will take for the standby to catch up with the sending server assuming the current rate of replay. Such a system would show similar times while new WAL is being generated, but would differ when the sender becomes idle. In particular, when the standby has caught up completely, `pg_stat_replication` shows the time taken to write, flush and replay the most recent reported WAL location rather than zero as some users might expect. This is consistent with the goal of measuring synchronous commit and transaction visibility delays for recent write transactions. To reduce confusion for users expecting a different model of lag, the lag columns revert to NULL after a short time on a fully replayed idle system. Monitoring systems should choose whether to represent this as missing data, zero or continue to display the last known value.

**Table 28.6. pg_stat_wal_receiver View**

| Column                  | Type                       | Description                                                  |
| ----------------------- | -------------------------- | ------------------------------------------------------------ |
| `pid`                   | `integer`                  | Process ID of the WAL receiver process                       |
| `status`                | `text`                     | Activity status of the WAL receiver process                  |
| `receive_start_lsn`     | `pg_lsn`                   | First write-ahead log location used when WAL receiver is started |
| `receive_start_tli`     | `integer`                  | First timeline number used when WAL receiver is started      |
| `received_lsn`          | `pg_lsn`                   | Last write-ahead log location already received and flushed to disk, the initial value of this field being the first log location used when WAL receiver is started |
| `received_tli`          | `integer`                  | Timeline number of last write-ahead log location received and flushed to disk, the initial value of this field being the timeline number of the first log location used when WAL receiver is started |
| `last_msg_send_time`    | `timestamp with time zone` | Send time of last message received from origin WAL sender    |
| `last_msg_receipt_time` | `timestamp with time zone` | Receipt time of last message received from origin WAL sender |
| `latest_end_lsn`        | `pg_lsn`                   | Last write-ahead log location reported to origin WAL sender  |
| `latest_end_time`       | `timestamp with time zone` | Time of last write-ahead log location reported to origin WAL sender |
| `slot_name`             | `text`                     | Replication slot name used by this WAL receiver              |
| `conninfo`              | `text`                     | Connection string used by this WAL receiver, with security-sensitive fields obfuscated. |

The `pg_stat_wal_receiver` view will contain only one row, showing statistics about the WAL receiver from that receiver's connected server.