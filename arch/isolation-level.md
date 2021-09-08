---
title: "PgSQL事务隔离等级"
date: 2019-11-12
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  PostgreSQL实际上只有两种事务隔离等级：**读已提交（Read Commited）**与**可序列化（Serializable）**
---




# PostgreSQL 事务隔离等级



## 基础

SQL标准定义了四种隔离级别，但PostgreSQL实际上只有两种事务隔离等级：**读已提交（Read Commited）**与**可序列化（Serializable）**

SQL标准定义了四种隔离级别，但实际上这也是很粗鄙的一种划分。详情请参考[并发异常那些事](/zh/blog/2018/06/09/并发异常那些事/)。



## 查看/设置事务隔离等级

通过执行：`SELECT current_setting('transaction_isolation');` 可以查看当前事务隔离等级。

通过在事务块顶部执行 `SET TRANSACTION ISOLATION LEVEL { SERIALIZABLE | REPEATABLE READ | READ COMMITTED | READ UNCOMMITTED } `来设定事务的隔离等级。

或者为当前会话生命周期设置事务隔离等级：

`SET SESSION CHARACTERISTICS AS TRANSACTION transaction_mode`



| Actual isolation level       | P4   | G-single | G2-item | G2   |
| ---------------------------- | ---- | -------- | ------- | ---- |
| RC（monotonic atomic views） | -    | -        | -       | -    |
| RR（snapshot isolation）     | ✓    | ✓        | -       | -    |
| Serializable                 | ✓    | ✓        | ✓       | ✓    |

## 隔离等级与并发问题

创建测试表 `t` ，并插入两行测试数据。

```sql
CREATE TABLE t (k INTEGER PRIMARY KEY, v int);
TRUNCATE t; INSERT INTO t VALUES (1,10), (2,20);
```



## 更新丢失（P4）

PostgreSQL的 **读已提交RC** 隔离等级无法阻止丢失更新的问题，但可重复读隔离等级则可以。

丢失更新，顾名思义，就是一个事务的写入覆盖了另一个事务的写入结果。

在读已提交隔离等级下，无法阻止丢失更新的问题，考虑一个计数器并发更新的例子，两个事务同时从计数器中读取出值，加1后写回原表。

|                 T1                  |                 T2                  |   Comment    |
| :---------------------------------: | :---------------------------------: | :----------: |
|             ` begin; `              |                                     |              |
|                                     |              ` begin;`              |              |
|    `SELECT v FROM t WHERE k = 1`    |                                     |     T1读     |
|                                     |    `SELECT v FROM t WHERE k = 1`    |     T2读     |
| `update t set v = 11 where k = 1; ` |                                     |     T1写     |
|                                     | ` update t set v = 11 where k = 1;` |  T2因T1阻塞  |
|              `COMMIT`               |                                     | T2恢复，写入 |
|                                     |              `COMMIT`               | T2写入覆盖T1 |

解决这个问题有两种方式，使用原子操作，或者在可重复读的隔离等级执行事务。

使用原子操作的方式为：

|                  T1                  |                   T2                   |   Comment    |
| :----------------------------------: | :------------------------------------: | :----------: |
|              ` begin; `              |                                        |              |
|                                      |               ` begin;`                |              |
| `update t set v = v+1 where k = 1; ` |                                        |     T1写     |
|                                      | ` update t set v = v + 1 where k = 1;` |  T2因T1阻塞  |
|               `COMMIT`               |                                        | T2恢复，写入 |
|                                      |                `COMMIT`                | T2写入覆盖T1 |

解决这个问题有两种方式，使用原子操作，或者在可重复读的隔离等级执行事务。

在可重复读的隔离等级





## 读已提交（RC）

```sql
begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2

update t set v = 11 where k = 1; -- T1
update t set v = 12 where k = 1; -- T2, BLOCKS
update t set v = 21 where k = 2; -- T1

commit; -- T1. This unblocks T2
select * from t; -- T1. Shows 1 => 11, 2 => 21
update t set v = 22 where k = 2; -- T2


commit; -- T2
select * from test; -- either. Shows 1 => 12, 2 => 22
```



|                            T1                             |                            T2                             |          Comment           |
| :-------------------------------------------------------: | :-------------------------------------------------------: | :------------------------: |
| ` begin; set transaction isolation level read committed;` |                                                           |                            |
|                                                           | ` begin; set transaction isolation level read committed;` |                            |
|            `update t set v = 11 where k = 1; `            |                                                           |                            |
|                                                           |            ` update t set v = 12 where k = 1;`            |     T2会等待T1持有的锁     |
|                     `SELECT * FROM t`                     |                                                           |         2:20, 1:11         |
|          ` update pair set v = 21 where k = 2;`           |                                                           |                            |
|                        ` commit;`                         |                                                           |           T2解锁           |
|                                                           |                  ` select * from pair;`                   | T2看见T1的结果和自己的修改 |
|                                                           |            ` update t set v = 22 where k = 2`             |                            |
|                                                           |                         `commit`                          |                            |

提交后的结果



1

```bash
 relname | locktype | virtualtransaction |  pid  |       mode       | granted | fastpath
---------+----------+--------------------+-------+------------------+---------+----------
 t_pkey  | relation | 4/578              | 37670 | RowExclusiveLock | t       | t
 t       | relation | 4/578              | 37670 | RowExclusiveLock | t       | t
```

```bash
 relname | locktype | virtualtransaction |  pid  |       mode       | granted | fastpath
---------+----------+--------------------+-------+------------------+---------+----------
 t_pkey  | relation | 4/578              | 37670 | RowExclusiveLock | t       | t
 t       | relation | 4/578              | 37670 | RowExclusiveLock | t       | t
 t_pkey  | relation | 6/494              | 37672 | RowExclusiveLock | t       | t
 t       | relation | 6/494              | 37672 | RowExclusiveLock | t       | t
 t       | tuple    | 6/494              | 37672 | ExclusiveLock    | t       | f
```

```bash
 relname | locktype | virtualtransaction |  pid  |       mode       | granted | fastpath
---------+----------+--------------------+-------+------------------+---------+----------
 t_pkey  | relation | 4/578              | 37670 | RowExclusiveLock | t       | t
 t       | relation | 4/578              | 37670 | RowExclusiveLock | t       | t
 t_pkey  | relation | 6/494              | 37672 | RowExclusiveLock | t       | t
 t       | relation | 6/494              | 37672 | RowExclusiveLock | t       | t
 t       | tuple    | 6/494              | 37672 | ExclusiveLock    | t       | f
```





# Testing PostgreSQL transaction isolation levels

These tests were run with Postgres 9.3.5.

Setup (before every test case):

```
create table test (id int primary key, value int);
insert into test (id, value) values (1, 10), (2, 20);
```

To see the current isolation level:

```
select current_setting('transaction_isolation');
```

## Read Committed basic requirements (G0, G1a, G1b, G1c)

Postgres "read committed" prevents Write Cycles (G0) by locking updated rows:

```
begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2
update test set value = 11 where id = 1; -- T1
update test set value = 12 where id = 1; -- T2, BLOCKS
update test set value = 21 where id = 2; -- T1
commit; -- T1. This unblocks T2
select * from test; -- T1. Shows 1 => 11, 2 => 21
update test set value = 22 where id = 2; -- T2
commit; -- T2
select * from test; -- either. Shows 1 => 12, 2 => 22
```

Postgres "read committed" prevents Aborted Reads (G1a):

```
begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2
update test set value = 101 where id = 1; -- T1
select * from test; -- T2. Still shows 1 => 10
abort;  -- T1
select * from test; -- T2. Still shows 1 => 10
commit; -- T2
```

Postgres "read committed" prevents Intermediate Reads (G1b):

```
begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2
update test set value = 101 where id = 1; -- T1
select * from test; -- T2. Still shows 1 => 10
update test set value = 11 where id = 1; -- T1
commit; -- T1
select * from test; -- T2. Now shows 1 => 11
commit; -- T2
```

Postgres "read committed" prevents Circular Information Flow (G1c):

```
begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2
update test set value = 11 where id = 1; -- T1
update test set value = 22 where id = 2; -- T2
select * from test where id = 2; -- T1. Still shows 2 => 20
select * from test where id = 1; -- T2. Still shows 1 => 10
commit; -- T1
commit; -- T2
```

## Observed Transaction Vanishes (OTV)

Postgres "read committed" prevents Observed Transaction Vanishes (OTV):

```
begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2
begin; set transaction isolation level read committed; -- T3
update test set value = 11 where id = 1; -- T1
update test set value = 19 where id = 2; -- T1
update test set value = 12 where id = 1; -- T2. BLOCKS
commit; -- T1. This unblocks T2
select * from test where id = 1; -- T3. Shows 1 => 11
update test set value = 18 where id = 2; -- T2
select * from test where id = 2; -- T3. Shows 2 => 19
commit; -- T2
select * from test where id = 2; -- T3. Shows 2 => 18
select * from test where id = 1; -- T3. Shows 1 => 12
commit; -- T3
```

## Predicate-Many-Preceders (PMP)

Postgres "read committed" does not prevent Predicate-Many-Preceders (PMP):

```
begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2
select * from test where value = 30; -- T1. Returns nothing
insert into test (id, value) values(3, 30); -- T2
commit; -- T2
select * from test where value % 3 = 0; -- T1. Returns the newly inserted row
commit; -- T1
```

Postgres "repeatable read" prevents Predicate-Many-Preceders (PMP):

```
begin; set transaction isolation level repeatable read; -- T1
begin; set transaction isolation level repeatable read; -- T2
select * from test where value = 30; -- T1. Returns nothing
insert into test (id, value) values(3, 30); -- T2
commit; -- T2
select * from test where value % 3 = 0; -- T1. Still returns nothing
commit; -- T1
```

Postgres "read committed" does not prevent Predicate-Many-Preceders (PMP) for write predicates -- example from Postgres documentation:

```
begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2
update test set value = value + 10; -- T1
delete from test where value = 20;  -- T2, BLOCKS
commit; -- T1. This unblocks T2
select * from test where value = 20; -- T2, returns 1 => 20 (despite ostensibly having been deleted)
commit; -- T2
```

Postgres "repeatable read" prevents Predicate-Many-Preceders (PMP) for write predicates -- example from Postgres documentation:

```
begin; set transaction isolation level repeatable read; -- T1
begin; set transaction isolation level repeatable read; -- T2
update test set value = value + 10; -- T1
delete from test where value = 20;  -- T2, BLOCKS
commit; -- T1. T2 now prints out "ERROR: could not serialize access due to concurrent update"
abort;  -- T2. There's nothing else we can do, this transaction has failed
```

## Lost Update (P4)

Postgres "read committed" does not prevent Lost Update (P4):

```
begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2
select * from test where id = 1; -- T1
select * from test where id = 1; -- T2
update test set value = 11 where id = 1; -- T1
update test set value = 11 where id = 1; -- T2, BLOCKS
commit; -- T1. This unblocks T2, so T1's update is overwritten
commit; -- T2
```

Postgres "repeatable read" prevents Lost Update (P4):

```
begin; set transaction isolation level repeatable read; -- T1
begin; set transaction isolation level repeatable read; -- T2
select * from test where id = 1; -- T1
select * from test where id = 1; -- T2
update test set value = 11 where id = 1; -- T1
update test set value = 11 where id = 1; -- T2, BLOCKS
commit; -- T1. T2 now prints out "ERROR: could not serialize access due to concurrent update"
abort;  -- T2. There's nothing else we can do, this transaction has failed
```

## Read Skew (G-single)

Postgres "read committed" does not prevent Read Skew (G-single):

```
begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2
select * from test where id = 1; -- T1. Shows 1 => 10
select * from test where id = 1; -- T2
select * from test where id = 2; -- T2
update test set value = 12 where id = 1; -- T2
update test set value = 18 where id = 2; -- T2
commit; -- T2
select * from test where id = 2; -- T1. Shows 2 => 18
commit; -- T1
```

Postgres "repeatable read" prevents Read Skew (G-single):

```
begin; set transaction isolation level repeatable read; -- T1
begin; set transaction isolation level repeatable read; -- T2
select * from test where id = 1; -- T1. Shows 1 => 10
select * from test where id = 1; -- T2
select * from test where id = 2; -- T2
update test set value = 12 where id = 1; -- T2
update test set value = 18 where id = 2; -- T2
commit; -- T2
select * from test where id = 2; -- T1. Shows 2 => 20
commit; -- T1
```

Postgres "repeatable read" prevents Read Skew (G-single) -- test using predicate dependencies:

```
begin; set transaction isolation level repeatable read; -- T1
begin; set transaction isolation level repeatable read; -- T2
select * from test where value % 5 = 0; -- T1
update test set value = 12 where value = 10; -- T2
commit; -- T2
select * from test where value % 3 = 0; -- T1. Returns nothing
commit; -- T1
```

Postgres "repeatable read" prevents Read Skew (G-single) -- test using write predicate:

```
begin; set transaction isolation level repeatable read; -- T1
begin; set transaction isolation level repeatable read; -- T2
select * from test where id = 1; -- T1. Shows 1 => 10
select * from test; -- T2
update test set value = 12 where id = 1; -- T2
update test set value = 18 where id = 2; -- T2
commit; -- T2
delete from test where value = 20; -- T1. Prints "ERROR: could not serialize access due to concurrent update"
abort; -- T1. There's nothing else we can do, this transaction has failed
```

## Write Skew (G2-item)

Postgres "repeatable read" does not prevent Write Skew (G2-item):

```
begin; set transaction isolation level repeatable read; -- T1
begin; set transaction isolation level repeatable read; -- T2
select * from test where id in (1,2); -- T1
select * from test where id in (1,2); -- T2
update test set value = 11 where id = 1; -- T1
update test set value = 21 where id = 2; -- T2
commit; -- T1
commit; -- T2
```

Postgres "serializable" prevents Write Skew (G2-item):

```
begin; set transaction isolation level serializable; -- T1
begin; set transaction isolation level serializable; -- T2
select * from test where id in (1,2); -- T1
select * from test where id in (1,2); -- T2
update test set value = 11 where id = 1; -- T1
update test set value = 21 where id = 2; -- T2
commit; -- T1
commit; -- T2. Prints out "ERROR: could not serialize access due to read/write dependencies among transactions"
```

## Anti-Dependency Cycles (G2)

Postgres "repeatable read" does not prevent Anti-Dependency Cycles (G2):

```
begin; set transaction isolation level repeatable read; -- T1
begin; set transaction isolation level repeatable read; -- T2
select * from test where value % 3 = 0; -- T1
select * from test where value % 3 = 0; -- T2
insert into test (id, value) values(3, 30); -- T1
insert into test (id, value) values(4, 42); -- T2
commit; -- T1
commit; -- T2
select * from test where value % 3 = 0; -- Either. Returns 3 => 30, 4 => 42
```

Postgres "serializable" prevents Anti-Dependency Cycles (G2):

```
begin; set transaction isolation level serializable; -- T1
begin; set transaction isolation level serializable; -- T2
select * from test where value % 3 = 0; -- T1
select * from test where value % 3 = 0; -- T2
insert into test (id, value) values(3, 30); -- T1
insert into test (id, value) values(4, 42); -- T2
commit; -- T1
commit; -- T2. Prints out "ERROR: could not serialize access due to read/write dependencies among transactions"
```

Postgres "serializable" prevents Anti-Dependency Cycles (G2) -- Fekete et al's example with two anti-dependency edges:

```
begin; set transaction isolation level serializable; -- T1
select * from test; -- T1. Shows 1 => 10, 2 => 20
begin; set transaction isolation level serializable; -- T2
update test set value = value + 5 where id = 2; -- T2
commit; -- T2
begin; set transaction isolation level serializable; -- T3
select * from test; -- T3. Shows 1 => 10, 2 => 25
commit; -- T3
update test set value = 0 where id = 1; -- T1. Prints out "ERROR: could not serialize access due to read/write dependencies among transactions"
abort; -- T1. There's nothing else we can do, this transaction has failed
```