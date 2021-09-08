---
title: "在线修改PG字段类型"
date: 2020-01-30
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  如何在线修改PostgreSQL中的字段类型？一种通用方法
---



## 场景

在数据库的生命周期中，有一类需求是很常见的，修改字段类型。例如：

* 使用`INT`作为主键，结果发现业务红红火火，INT32的21亿序号不够用了，想要升级为`BIGINT`
* 使用`BIGINT`存身份证号，结果发现里面有个`X`需要改为`TEXT`类型。
* 使用`FLOAT`存放货币，发现精度丢失，想要修改为Decimal
* 使用`TEXT`存储JSON字段，想用到PostgreSQL的JSON特性，修改为JSONB类型。

那么，如何应对这种需求呢？



## 常规操作

通常来说，`ALTER TABLE`可以用来修改字段类型。

```sql
ALTER TABLE tbl_name ALTER col_name TYPE new_type USING expression;
```

修改字段类型通常会**重写**整个表。作为一个特例，如果修改后的类型与之前是[二进制兼容](https://www.postgresql.org/docs/13/sql-createcast.html)的，则可以跳过**表重写**的过程，但是如果列上有索引，**索引还是需要重建的**。二进制兼容的转换可以使用以下查询列出。

```sql
SELECT t1.typname AS from, t2.typname AS To
FROM pg_cast c
         join pg_type t1 on c.castsource = t1.oid
         join pg_type t2 on c.casttarget = t2.oid
where c.castmethod = 'b';
```

刨除PostgreSQL内部的类型，二进制兼容的类型转换如下所示

```
text     → varchar 
xml      → varchar 
xml      → text    
cidr     → inet    
varchar  → text    
bit      → varbit  
varbit   → bit     
```

常见的二进制兼容类型转换基本就是这两种：

* varchar(n1) →  varchar(n2)  （n2 ≥ n1）（比较常用，扩大长度约束不会重写，缩小会重写）

* varchar ↔  text （同义转换，基本没啥用）

也就是说，其他的类型转换，都会涉及到表的**重写**。大表的重写是很慢的，从几分钟到十几小时都有可能。一旦发生**重写**，表上就会有`AccessExclusiveLock`，阻止一切并发访问。

如果是一个玩具数据库，或者业务还没上线，或者业务根本不在乎停机多久，那么整表重写的方式当然是没有问题的。但绝大多数时候，业务根本不可能接受这样的停机时间。所以，我们需要一种在线升级的办法。在**不停机**的情况完成字段类型的改造。



## 基本思路

在线改列的基本原理如下：

* 创建一个新的临时列，使用新的类型

* 旧列的数据同步至新的临时列

  * 存量同步：分批更新
  * 增量同步：更新触发器

* 处理列依赖：索引

* 执行切换

  * 处理列以来：约束，默认值，分区，继承，触发器

  * 通过列重命名的方式完成新旧列切换



在线改造的问题在于**锁粒度拆分**，将原来一次**长期重锁**操作，等效替代为多个**瞬时轻锁**操作。

原来`ALTER TYPE`重写过程中，会加上`AccessExclusiveLock`，阻止一切并发访问，持续时间几分钟到几天。

* 添加新列：瞬间完成：`AccessExclusiveLock`
* 同步新列-增量：创建触发器，瞬间完成，锁级别低。
* 同步新列-存量：分批次UPDATE，少量多次，每次都能**快速完成**，锁级别低。
* 新旧切换：锁表，瞬间完成。



让我们用`pgbench`的默认用例来说明在线改列的基本原理。假设我们希望在`pgbench_accounts`有访问的情况下修改`abalance`字段类型，从`INT`修改为`BIGINT`，那么应该如何处理呢？

1. 首先，为`pgbench_accounts`创建一个名为`abalance_tmp`，类型为`BIGINT`的新列。
2. 编写并创建列同步触发器，触发器会在每一行被插入或更新前，使用旧列`abalance`同步到

详情如下所示：

```sql
-- 操作目标：升级 pgbench_accounts 表普通列 abalance 类型：INT -> BIGINT

-- 添加新列：abalance_tmp BIGINT
ALTER TABLE pgbench_accounts ADD COLUMN abalance_tmp BIGINT;

-- 创建触发器函数：保持新列数据与旧列同步
CREATE OR REPLACE FUNCTION public.sync_pgbench_accounts_abalance() RETURNS TRIGGER AS $$
BEGIN NEW.abalance_tmp = NEW.abalance; RETURN NEW;END;
$$ LANGUAGE 'plpgsql';

-- 完成整表更新，分批更新的方式见下
UPDATE pgbench_accounts SET abalance_tmp = abalance; -- 不要在大表上运行这个

-- 创建触发器
CREATE TRIGGER tg_sync_pgbench_accounts_abalance BEFORE INSERT OR UPDATE ON pgbench_accounts
    FOR EACH ROW EXECUTE FUNCTION sync_pgbench_accounts_abalance();

-- 完成列的新旧切换，这时候数据同步方向变化 旧列数据与新列保持同步
BEGIN;
LOCK TABLE pgbench_accounts IN EXCLUSIVE MODE;
ALTER TABLE pgbench_accounts DISABLE TRIGGER tg_sync_pgbench_accounts_abalance;
ALTER TABLE pgbench_accounts RENAME COLUMN abalance TO abalance_old;
ALTER TABLE pgbench_accounts RENAME COLUMN abalance_tmp TO abalance;
ALTER TABLE pgbench_accounts RENAME COLUMN abalance_old TO abalance_tmp;
ALTER TABLE pgbench_accounts ENABLE TRIGGER tg_sync_pgbench_accounts_abalance;
COMMIT;

-- 确认数据完整性
SELECT count(*) FROM pgbench_accounts WHERE abalance_new != abalance;

-- 清理触发器与函数
DROP FUNCTION IF EXISTS sync_pgbench_accounts_abalance();
DROP TRIGGER tg_sync_pgbench_accounts_abalance ON pgbench_accounts;
```





## 注意事项

1. ALTER TABLE的MVCC安全性
2. 列上如果有约束？（PrimaryKey、ForeignKey，Unique，NotNULL）
3. 列上如果有索引？
4. ALTER TABLE导致的主从复制延迟