---
title: "PgSQL Exclude约束"
date: 2018-04-06
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  Exclude约束是一个PostgreSQL扩展，它可以实现一些更高级，更巧妙的的数据库约束。
---

# PostgreSQL Excluded 约束详解

Exclude约束是一个PostgreSQL扩展，它可以实现一些更高级，更巧妙的的数据库约束。

## 前言

数据完整性是极其重要的，但由应用保证的数据完整性并不总是那么靠谱：人会犯傻，程序会出错。如果能通过数据库约束来强制数据完整性那是再好不过了：后端程序员不用再担心竞态条件导致的微妙错误，数据分析师也可以对数据质量充满信心，不需要验证与清洗。

关系型数据库通常会提供`PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `CHECK`约束，然而并不是所有的业务约束都可以用这几种约束表达。一些约束会稍微复杂一些，例如确保IP网段表中的IP范围不发生重叠，确保同一个会议室不会出现预定时间重叠，确保地理区划表中各个城市的边界不会重叠。传统上要实现这种保证是相当困难的：譬如`UNIQUE`约束就无法表达这种语义，`CHECK`与存储过程或者触发器虽然可以实现这种检查，但也相当tricky。PostgreSQL提供的`EXCLUDE`约束可以优雅地解决这一类问题。



## Eclude约束的语法

```sql
 EXCLUDE [ USING index_method ] ( exclude_element WITH operator [, ... ] ) index_parameters [ WHERE ( predicate ) ] |
 
exclude_element in an EXCLUDE constraint is:
{ column_name | ( expression ) } [ opclass ] [ ASC | DESC ] [ NULLS { FIRST | LAST } ]
```

`EXCLUDE`子句定一个排除约束，它保证如果任意两行在指定列或表达式上使用指定操作符进行比较，不是所有的比较都将会返回`TRUE`。如果所有指定的操作符都测试相等，这就等价于一个`UNIQUE`约束，尽管一个普通的唯一约束将更快。不过，排除约束能够指定比简单相等更通用的约束。例如，你可以使用`&&`操作符指定一个约束，要求表中没有两行包含相互覆盖的圆（见 [Section 8.8](http://www.postgres.cn/docs/11/datatype-geometric.html)）。

排除约束使用一个索引实现，这样每一个指定的操作符必须与用于索引访问方法*index_method*的一个适当的操作符类（见[Section 11.9](http://www.postgres.cn/docs/11/indexes-opclass.html)）相关联。操作符被要求是交换的。每一个*exclude_element*可以选择性地指定一个操作符类或者顺序选项，这些在[???](http://www.postgres.cn/docs/11/SQL-CREATETABLE.html)中有完整描述。

访问方法必须支持`amgettuple`（见[Chapter 61](http://www.postgres.cn/docs/11/indexam.html)），目前这意味着GIN无法使用。尽管允许，但是在一个排除约束中使用 B-树或哈希索引没有意义，因为它无法做得比一个普通唯一索引更出色。因此在实践中访问方法将总是GiST或SP-GiST。

*predicate*允许你在该表的一个子集上指定一个排除约束。在内部这会创建一个部分索引。注意在为此周围的圆括号是必须的。



## 应用案例：会议室预定

假设我们想要设计一个会议室预定系统，并希望在数据库层面确保不会有冲突的会议室预定出现：即，对于同一个会议室，不允许同时存在两条预定时间范围上存在重叠的记录。那么数据库表可以这样设计：

```sql
-- PostgreSQL自带扩展，为普通类型添加GIST索引运算符支持
CREATE EXTENSION btree_gist;

-- 会议室预定表
CREATE TABLE meeting_room
(
    id      SERIAL PRIMARY KEY,
    user_id INTEGER,
    room_id INTEGER,
    range   tsrange,
    EXCLUDE USING GIST(room_id WITH = , range WITH &&)
);
```

这里`EXCLUDE USING GIST(room_id WITH = , range WITH &&)`指明了一个排它约束：不允许存在`room_id`相等，且`range`相互重叠的多条记录。

```sql
-- 用户1预定了101号房间，从早上10点到下午6点
INSERT INTO meeting_room(user_id, room_id, range) 
VALUES (1,101, tsrange('2019-01-01 10:00', '2019-01-01 18:00'));

-- 用户2也尝试预定101号房间，下午4点到下午6点
INSERT INTO meeting_room(user_id, room_id, range) 
VALUES (2,101, tsrange('2019-01-01 16:00', '2019-01-01 18:00'));

-- 用户2的预定报错，违背了排它约束
ERROR:  conflicting key value violates exclusion constraint "meeting_room_room_id_range_excl"
DETAIL:  Key (room_id, range)=(101, ["2019-01-01 16:00:00","2019-01-01 18:00:00")) conflicts with existing key (room_id, range)=(101, ["2019-01-01 10:00:00","2019-01-01 18:00:00")).
```

这里的`EXCLUDE`约束会自动创建一个相应的GIST索引：

```sql
"meeting_room_room_id_range_excl" EXCLUDE USING gist (room_id WITH =, range WITH &&)
```



## 应用案例：确保IP网段不重复

有一些约束是相当复杂的，例如确保表中的IP范围不发生重叠，类似的，确保地理区划表中各个城市的边界不会重叠。传统上要实现这种保证是相当困难的：譬如`UNIQUE`约束就无法表达这种语义，`CHECK`与存储过程或者触发器虽然可以实现这种检查，但也相当tricky。PostgreSQL提供的`EXCLUDE`约束可以优雅地解决这个问题。修改我们的`geoips`表：

```sql
create table geoips
(
  ips          inetrange,
  geo          geometry(Point),
  country_code text,
  region_code  text,
  city_name    text,
  ad_code      text,
  postal_code  text,
  EXCLUDE USING gist (ips WITH &&) DEFERRABLE INITIALLY DEFERRED 
);
```

​	这里`EXCLUDE USING gist (ips WITH &&)  ` 的意思就是`ips`字段上不允许出现范围重叠，即新插入的字段不能与任何现存范围重叠（`&&`为真）。而`DEFERRABLE INITIALLY IMMEDIATE `表示在语句结束时再检查所有行上的约束。创建该约束会自动在`ips`字段上创建GIST索引，因此无需手工创建了。



