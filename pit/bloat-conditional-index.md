# 条件索引膨胀问题



## 业务背景

一个比较有趣的Case，忽略掉敏感的业务信息，该问题可以抽象为：

一张交易订单表，使用`id`标识订单号，使用`ctime`标识订单创建时间，并使用`status`表示订单的状态：已提交或者已完成。

```sql
CREATE TYPE tran_status AS ENUM ('committed', 'completed');

CREATE TABLE transactions (
  id     BIGSERIAL PRIMARY KEY,
  ctime  TIMESTAMP   DEFAULT timezone('utc', now()),
  status tran_status DEFAULT 'committed' :: tran_status
);
```

相关的业务的典型查询为：

* 查找最近5分钟状态为`committed`的订单，进行处理，并将处理后的订单状态更新为`completed`。

```sql
-- 找出若干个最近某段时间内创建的某种状态的订单
SELECT * FROM transactions 
  WHERE
    status = status_
  AND
    created_time < start_
ORDER BY created_time DESC
LIMIT limit_;
```

为了加速这两种查询，需要创建索引，

```sql
CREATE INDEX ON transactions USING btree (ctime DESC) WHERE status = 'committed';
CREATE INDEX ON transactions USING btree (ctime DESC) WHERE status = 'completed';
```



## 现象

但是问题就来了，任何新创建的订单状态都是`committed`，但很快在被处理后状态就会被更新为`completed`，这意味着建立在状态`committed`上的条件索引会出现很严重的膨胀问题。因为PostgreSQL的MVCC机制，当将一比订单的状态由`committed`更新为`completed`时，其实是插入了一个新的`completed`版本，并将老的`committed`版本标记删除。对于索引而言，指向被删除旧行版本的索引项仍然存在。时间久了后，该索引就会极度膨胀，影响性能。

```
|           index_name             | bloat_pct | bloat_mb | index_mb | table_mb
+----------------------------------+-----------+----------+----------+----------
| trans_created_time_committed_idx |       100 |       19 |   19.117 | 2808.789
| trans_created_time_completed_idx |        18 |       79 |  431.938 | 2808.789
```

这里`trans_created_time_committed_idx`的膨胀率已经达到100%，因为大多数时候订单都会被快速处理掉（即该索引中被索引元组条数为0）。但因为用掉的索引页无法回收掉，导致了膨胀。

## 解决方案

而且只要在之前的索引页中存在任意有效记录，该页就无法被回收，因此就算进行了VACUUM，也无法减少索引的膨胀现象。解决该问题只能通过`pg_repack`或`vacuum full`来解决。

```bash
pg_repack vonng -T10 -t transactions
```

可以将该任务配置为定时任务，在每天低峰期执行。