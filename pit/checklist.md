# 故障检查清单

当发生数据库问题时，按照以下清单检查。

* 监控系统观察通用指标
* 登录机器检查具体问题



### 操作系统指标

* CPU使用率是否超过阈值？（40警戒线，50报警线，70红线）：[`top`](../tools/unix-top.md)

  ```bash
  top -bn3 -d0.1 | grep Cpu | tail -n1
  ```

* 内存是否正常？操作系统Buffer有无突发下降与释放？：[`free`](../tools/unix-free.md)

  ```bash
  free -m
  ```

* 磁盘空间使用

* ```bash
  df -h
  ```

* PostgreSQL进程数

  ```bash
  top -bn1 | grep postgres | wc -l
  ```



### 数据库活动

检查`pg_stat_activity`

| 列                 | 类型                       | 描述                                                         |
| ------------------ | -------------------------- | ------------------------------------------------------------ |
| `datid`            | `oid`                      | 连接后端的数据库OID                                          |
| `datname`          | `name`                     | 连接后端的数据库名称                                         |
| `pid`              | `integer`                  | 后端进程ID                                                   |
| `usesysid`         | `oid`                      | 登陆后端的用户OID                                            |
| `usename`          | `name`                     | 登陆到该后端的用户名                                         |
| `application_name` | `text`                     | 连接到后端的应用名                                           |
| `client_addr`      | `inet`                     | 连接到后端的客户端的IP地址。 如果此字段是null， 它表明通过服务器机器上UNIX套接字连接客户端或者这是内部进程如autovacuum |
| `client_hostname`  | `text`                     | 连接客户端的主机名，通过`client_addr`的反向DNS查找报告。 这个字段将只是非空的IP连接，并且仅仅当启动[log_hostname](http://www.postgres.cn/docs/9.4/runtime-config-logging.html#GUC-LOG-HOSTNAME)的时候。 |
| `client_port`      | `integer`                  | 客户端用于与后端通讯的TCP端口号，或者如果使用Unix套接字，则为`-1`。 |
| `backend_start`    | `timestamp with time zone` | 该过程开始的时间，比如当客户端连接服务器时。                 |
| `xact_start`       | `timestamp with time zone` | 启动当前事务的时间，如果没有事务是活的，则为null。如果当前查询是 首个事务，则这列等同于`query_start`列。 |
| `query_start`      | `timestamp with time zone` | 开始当前活跃查询的时间， 或者如果`state`是非`活跃的`， 当开始最后查询时。 |
| `state_change`     | `timestamp with time zone` | 上次`状态`改变的时间                                         |
| `waiting`          | `boolean`                  | 如果后端当前正等待锁则为真                                   |
| `state`            | `text`                     | 该后端当前总体状态。可能值是：`活跃的`:后端正在执行一个查询。`空闲的`:后端正在等待一个新的客户端命令。`空闲事务`：后端在事务中，但是目前无法执行查询。`空闲事务(被终止)`:这个情况类似于`空闲事务`，除了事务导致错误的一个语句之一。`快速路径函数调用`:后端正在执行一个快速路径函数。`禁用`:如果后端禁用[track_activities](http://www.postgres.cn/docs/9.4/runtime-config-statistics.html#GUC-TRACK-ACTIVITIES)，则报告这个状态。 |
| `backend_xid`      | `xid`                      | 这个后端的顶级事务标识符，如果有。                           |
| `backend_xmin`     | `xid`                      | 当前后端的`xmin`范围。                                       |
| `query`            | `text`                     | 该后端的最新查询文本。如果`状态`是`活跃的`, 此字段显示当前正在执行的查询。在所有其他情况中，这表明执行过去的查询。 |

```sql
-- 活动按状态分组计数，以及活动总数
SELECT state,count(*) AS cnt FROM pg_stat_activity GROUP BY ROLLUP(state) ORDER BY 1 NULLS LAST;

-- 快速检视所有活跃查询
SELECT pid, case when state = 'active' then (now()-query_start) else state_change - query_start end as elapse, state, query 
FROM pg_stat_activity WHERE pid <> pg_backend_pid() ORDER by 2 DESC NULLS LAST;



```







### 紧急修复

```sql
-- 清理所有连接(除了自己)
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid();

-- 清理所有查询
SELECT pg_cancel_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid();
```

```bash
# 从Bash进行清理
sudo -iu postgres /usr/pgsql/bin/psql -qAtzc 'SELECT count(pg_cancel_backend(pid)) FROM pg_stat_activity WHERE application_name !~'"'psql';"
```

