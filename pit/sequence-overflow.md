---
title: "故障档案：序列号消耗过快导致整型溢出"
linkTitle: "故障:序列号溢出"
date: 2018-07-20
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  如果您在表上用了Interger的序列号，最好还是考虑一下可能溢出的情况。
---



## 0x01 概览

* 故障表现：
  * 某张使用自增列的表序列号涨至整型上限，无法写入。
  * 发现表中的自增列存在大量空洞，很多序列号没有对应记录就被消耗掉了。
* 故障影响：非核心业务某表，10分钟左右无法写入。

* 故障原因：

  * 内因：使用了INTEGER而不是BIGINT作为主键类型。
  * 外因：业务方不了解`SEQUENCE`的特性，执行大量违背约束的无效插入，浪费了大量序列号。

* 修复方案：

  * 紧急操作：降级线上插入函数为直接返回，避免错误扩大。
  * 应急方案：创建临时表，生成5000万个浪费空洞中的临时ID，修改插入函数，变为先检查再插入，并从该临时ID表中取ID。
  * 解决方案：执行模式迁移，将所有相关表的主键与外键类型更新为Bigint。


## 原因分析

### 内因：类型使用不当

业务使用32位整型作为主键自增ID，而不是Bigint。

* 除非有特殊的理由，主键，自增列都应当使用BIGINT类型。

### 外因：不了解Sequence的特性

- 非要使用如果会频繁出现无效插入，或频繁使用UPSERT，需要关注Sequence的消耗问题。
- 可以考虑使用自定义发号函数（类Snowflake）

在PostgreSQL中，Sequence是一个比较特殊的类型。特别是，在事务中消耗的序列号不会回滚。因为序列号能被并发地获取，不存在逻辑上合理的回滚操作。

在生产中，我们就遇到了这样一种故障。有一张表直接使用了Serial作为主键：

```mysql
CREATE TABLE sample(
	id   	SERIAL PRIMARY KEY,
	name  	TEXT UNIQUE,
    value   INTEGER
);
```

而插入的时候是这样的：

```sql
INSERT INTO sample(name, value) VALUES(?,?)
```

当然，实际上由于`name`列上的约束，如果插入了重复的`name`字段，事务就会报错中止并回滚。然而序列号已经被消耗掉了，即使事务回滚了，序列号也不会回滚。

```bash
vonng=# INSERT INTO sample(name, value) VALUES('Alice',1);
INSERT 0 1
vonng=# SELECT currval('sample_id_seq'::RegClass);
 currval
---------
       1
(1 row)

vonng=# INSERT INTO sample(name, value) VALUES('Alice',1);
ERROR:  duplicate key value violates unique constraint "sample_name_key"
DETAIL:  Key (name)=(Alice) already exists.
vonng=# SELECT currval('sample_id_seq'::RegClass);
 currval
---------
       2
(1 row)

vonng=# BEGIN;
BEGIN
vonng=# INSERT INTO sample(name, value) VALUES('Alice',1);
ERROR:  duplicate key value violates unique constraint "sample_name_key"
DETAIL:  Key (name)=(Alice) already exists.
vonng=# ROLLBACK;
ROLLBACK
vonng=# SELECT currval('sample_id_seq'::RegClass);
 currval
---------
       3
```

因此，当执行的插入有大量重复，即有大量的冲突时，可能会导致序列号消耗的非常快。出现大量空洞！



另一个需要注意的点在于，UPSERT操作也会消耗序列号！从表现上来看，这就意味着即使实际操作是UPDATE而不是INSERT，也会消耗一个序列号。

```sql
vonng=# INSERT INTO sample(name, value) VALUES('Alice',3) ON CONFLICT(name) DO UPDATE SET value = EXCLUDED.value;
INSERT 0 1
vonng=# SELECT currval('sample_id_seq'::RegClass);
 currval
---------
       4
(1 row)

vonng=# INSERT INTO sample(name, value) VALUES('Alice',4) ON CONFLICT(name) DO UPDATE SET value = EXCLUDED.value;
INSERT 0 1
vonng=# SELECT currval('sample_id_seq'::RegClass);
 currval
---------
       5
(1 row)
```



## 解决方案

线上所有查询与插入都使用存储过程。非核心业务，允许接受短暂的写入失效。首先降级插入函数，避免错误影响AppServer。因为该表存在大量依赖，无法直接修改其类型，需要一个临时解决方案。

检查发现ID列中存在大量空洞，每10000个序列号中实际只有1%被使用。因此使用下列函数生成临时ID表。

```sql
CREATE TABLE sample_temp_id(id INTEGER PRIMARY KEY);

-- 插入约5000w个临时ID，够用十几天了。
INSERT INTO sample_temp_id
SELECTT generate_series(2000000000,2100000000) as id EXCEPT SELECT id FROM sample;

-- 修改插入的存储过程，从临时表中Pop出ID。
DELETE FROM sample_temp_id WHERE id = (SELECT id FROM sample_temp_id FOR UPDATE LIMIT 1) RETURNING id;
```

修改插入存储过程，每次从临时ID表中取一个ID，显式插入表中。



## 经验与教训

