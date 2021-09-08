---
title: "PG复制标识详解（Replica Identity）"
linkTitle: "PG复制标识详解"
date: 2021-03-03
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  复制标识很重要，它关系到逻辑复制的成败
---





## 引子：土法逻辑复制

复制身份的概念，服务于 [**逻辑复制**](/zh/blog/2021/03/03/postgres逻辑复制详解/)。

逻辑复制的基本工作原理是，将逻辑发布相关表上**对行的增删改**事件解码，复制到逻辑订阅者上执行。

逻辑复制的工作方式有点类似于行级触发器，在事务执行后对变更的元组逐行触发。

假设您需要自己通过触发器实现逻辑复制，将一章表A上的变更复制到另一张表B中。通常情况下，这个触发器的函数逻辑通常会长这样：

```sql
-- 通知触发器
CREATE OR REPLACE FUNCTION replicate_change() RETURNS TRIGGER AS $$
BEGIN
  IF    (TG_OP = 'INSERT') THEN 
  -- INSERT INTO tbl_b VALUES (NEW.col);
  ELSIF (TG_OP = 'DELETE') THEN 
	-- DELETE tbl_b WHERE id = OLD.id;
  ELSIF (TG_OP = 'UPDATE') THEN 
	-- UPDATE tbl_b SET col = NEW.col,... WHERE id = OLD.id;
  END IF;
END; $$ LANGUAGE plpgsql;
```

触发器中会有两个变量`OLD`与`NEW`，分别包含了变更记录的旧值与新值。

* `INSERT`操作只有`NEW`变量，因为它是新插入的，我们直接将其插入到另一张表即可。
* `DELETE`操作只有`OLD`变量，因为它只是删除已有记录，我们 **根据ID** 在目标表B上。
* `UPDATE`操作同时存在`OLD`变量与`NEW`变量，我们需要通过 `OLD.id` 定位目标表B中的记录，将其更新为新值`NEW`。

这样的基于触发器的“逻辑复制”可以完美达到我们的目的，在逻辑复制中与之类似，表A上带有主键字段`id`。那么当我们删除表A上的记录时，例如：删除`id = 1`的记录时，我们只需要告诉订阅方`id = 1`，而不是把整个被删除的元组传递给订阅方。那么这里主键列`id`就是逻辑复制的**复制标识**。

但上面的例子中隐含着一个工作假设：表A和表B模式相同，上面有一个名为 `id` 的主键。

对于生产级的逻辑复制方案，即PostgreSQL 10.0后提供的逻辑复制，**这样的工作假设是不合理的**。因为系统无法要求用户建表时一定会带有主键，也无法要求主键的名字一定叫`id`。

于是，就有了 **复制标识（Replica Identity）** 的概念。复制标识是对`OLD.id`这样工作假设的进一步泛化与抽象，它用来告诉逻辑复制系统，**哪些信息可以被用于唯一定位表中的一条记录**。





## 复制标识

对于逻辑复制而言，`INSERT` 事件不需要特殊处理，但要想将`DELETE|UPDATE`复制到订阅者上时，必须提供一种标识行的方式，即**复制标识（Replica Identity）**。复制标识是一组**列的集合**，这些列可以唯一标识一条记录。其实这样的定义在概念上来说就是**构成主键的列集**，当然非空唯一索引中的列集（**候选键**）也可以起到同样的效果。

一个被纳入逻辑复制 **发布**中的表，必须配置有 **复制标识（Replica Identity）**，只有这样才可以在**订阅**者一侧定位到需要更新的行，完成`UPDATE`与`DELETE`操作的复制。默认情况下，**主键** （Primary Key）和 **非空列上的唯一索引** （UNIQUE NOT NULL）可以用作复制标识。

注意，**复制标识** 和表上的主键、非空唯一索引并不是一回事。复制标识是**表**上的一个属性，它指明了在逻辑复制时，哪些信息会被用作身份定位标识符写入到逻辑复制的记录中，供订阅端定位并执行变更。

如PostgreSQL 13[官方文档](https://www.postgresql.org/docs/13/sql-altertable.html#replica_identity)所述，表上的**复制标识** 共有4种配置模式，分别为：

* 默认模式（default）：非系统表采用的默认模式，如果有主键，则用主键列作为身份标识，否则用完整模式。
* 索引模式（index）：将某一个符合条件的索引中的列，用作身份标识
* 完整模式（full）：将整行记录中的所有列作为复制标识（类似于整个表上每一列共同组成主键）
* 无身份模式（nothing）：不记录任何复制标识，这意味着`UPDATE|DELETE`操作无法复制到订阅者上。

### 复制标识查询

表上的**复制标识**可以通过查阅`pg_class.relreplident`获取。

这是一个字符类型的“枚举”，标识用于组装 “复制标识” 的列：`d` = default ，`f` = 所有的列，`i` 使用特定的索引，`n` 没有复制标识。

表上是否具有可用作复制标识的索引约束，可以通过以下查询获取：

```sql
SELECT quote_ident(nspname) || '.' || quote_ident(relname) AS name, con.ri AS keys,
       CASE relreplident WHEN 'd' THEN 'default' WHEN 'n' THEN 'nothing' WHEN 'f' THEN 'full' WHEN 'i' THEN 'index' END AS replica_identity
FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid, LATERAL (SELECT array_agg(contype) AS ri FROM pg_constraint WHERE conrelid = c.oid) con
WHERE relkind = 'r' AND nspname NOT IN ('pg_catalog', 'information_schema', 'monitor', 'repack', 'pg_toast')
ORDER BY 2,3;
```

### 复制标识配置

表到复制标识可以通过`ALTER TABLE`进行修改。

```sql
ALTER TABLE tbl REPLICA IDENTITY { DEFAULT | USING INDEX index_name | FULL | NOTHING };
-- 具体有四种形式
ALTER TABLE t_normal REPLICA IDENTITY DEFAULT;                    -- 使用主键，如果没有主键则为FULL
ALTER TABLE t_normal REPLICA IDENTITY FULL;                       -- 使用整行作为标识
ALTER TABLE t_normal REPLICA IDENTITY USING INDEX t_normal_v_key; -- 使用唯一索引
ALTER TABLE t_normal REPLICA IDENTITY NOTHING;                    -- 不设置复制标识
```



## 复制标识实例

下面用一个具体的例子来说明复制标识的效果：

```sql
CREATE TABLE test(k text primary key, v int not null unique);
```

现在有一个表`test`，上面有两列`k`和`v`。

```sql
INSERT INTO test VALUES('Alice', '1'), ('Bob', '2');
UPDATE test SET v = '3' WHERE k = 'Alice';    -- update Alice value to 3
UPDATE test SET k = 'Oscar' WHERE k = 'Bob';  -- rename Bob to Oscaar
DELETE FROM test WHERE k = 'Alice';           -- delete Alice
```

在这个例子中，我们对表`test`执行了增删改操作，与之对应的逻辑解码结果为：

```ini
table public.test: INSERT: k[text]:'Alice' v[integer]:1
table public.test: INSERT: k[text]:'Bob' v[integer]:2
table public.test: UPDATE: k[text]:'Alice' v[integer]:3
table public.test: UPDATE: old-key: k[text]:'Bob' new-tuple: k[text]:'Oscar' v[integer]:2
table public.test: DELETE: k[text]:'Alice'
```

默认情况下，PostgreSQL会使用表的主键作为**复制标识**，因此在`UPDATE|DELETE`操作中，都通过`k`列来定位需要修改的记录。

如果我们手动修改表的复制标识，使用非空且唯一的列`v`作为复制标识，也是可以的：

```sql
ALTER TABLE test REPLICA IDENTITY USING INDEX test_v_key; -- 基于UNIQUE索引的复制身份
```

同样的变更现在产生如下的逻辑解码结果，这里`v`作为身份标识，出现在所有的`UPDATE|DELETE`事件中。

```ini
table public.test: INSERT: k[text]:'Alice' v[integer]:1
table public.test: INSERT: k[text]:'Bob' v[integer]:2
table public.test: UPDATE: old-key: v[integer]:1 new-tuple: k[text]:'Alice' v[integer]:3
table public.test: UPDATE: k[text]:'Oscar' v[integer]:2
table public.test: DELETE: v[integer]:3
```

如果使用**完整身份模式（full）**

```sql
ALTER TABLE test REPLICA IDENTITY FULL; -- 表test现在使用所有列作为表的复制身份
```

这里，`k`和`v`同时作为身份标识，记录到`UPDATE|DELETE`的日志中。对于没有主键的表，这是一种保底方案。

```ini
table public.test: INSERT: k[text]:'Alice' v[integer]:1
table public.test: INSERT: k[text]:'Bob' v[integer]:2
table public.test: UPDATE: old-key: k[text]:'Alice' v[integer]:1 new-tuple: k[text]:'Alice' v[integer]:3
table public.test: UPDATE: old-key: k[text]:'Bob' v[integer]:2 new-tuple: k[text]:'Oscar' v[integer]:2
table public.test: DELETE: k[text]:'Alice' v[integer]:3
```

如果使用**无身份模式（nothing）**

```sql
ALTER TABLE test REPLICA IDENTITY NOTHING; -- 表test现在没有复制标识
```

那么逻辑解码的记录中，`UPDATE`操作中只有新记录，没有包含旧记录中的唯一身份标识，而`DELETE`操作中则完全没有信息。

```ini
table public.test: INSERT: k[text]:'Alice' v[integer]:1
table public.test: INSERT: k[text]:'Bob' v[integer]:2
table public.test: UPDATE: k[text]:'Alice' v[integer]:3
table public.test: UPDATE: k[text]:'Oscar' v[integer]:2
table public.test: DELETE: (no-tuple-data)
```

这样的逻辑变更日志对于订阅端来说完全没用，在实际使用中，对逻辑复制中的无复制标识的表执行`DELETE|UPDATE`会直接报错。



## 复制标识详解

表上的复制标识配置，与表上有没有索引，是相对正交的两个因素。

尽管各种排列组合都是可能的，然而在实际使用中，只有三种可行的情况。

* 表上有主键，使用默认的 `default` 复制标识
* 表上没有主键，但是有非空唯一索引，显式配置 `index` 复制标识
* 表上既没有主键，也没有非空唯一索引，显式配置`full`复制标识（运行效率非常低，仅能作为兜底方案）
* 其他所有情况，都无法正常完成逻辑复制功能

| 复制身份模式\表上的约束 | 主键(p)  | 非空唯一索引(u) | 两者皆无(n) |
| :---------------------: | :------: | :-------------: | :---------: |
|       **d**efault       | **有效** |        x        |      x      |
|        **i**ndex        |    x     |    **有效**     |      x      |
|        **f**ull         | **低效** |    **低效**     |  **低效**   |
|       **n**othing       |    x     |        x        |      x      |

下面，我们来考虑几个边界条件。

### 重建主键

假设因为索引膨胀，我们希望重建表上的主键索引回收空间。

```sql
CREATE TABLE test(k text primary key, v int);
CREATE UNIQUE INDEX test_pkey2 ON test(k);
BEGIN;
ALTER TABLE test DROP CONSTRAINT test_pkey;
ALTER TABLE test ADD PRIMARY KEY USING INDEX test_pkey2;
COMMIT;
```

在`default`模式下，重建并替换主键约束与索引**并不会**影响复制标识。

### 重建唯一索引

假设因为索引膨胀，我们希望重建表上的非空唯一索引回收空间。

```sql
CREATE TABLE test(k text, v int not null unique);
ALTER TABLE test REPLICA IDENTITY USING INDEX test_v_key;
CREATE UNIQUE INDEX test_v_key2 ON test(v);
-- 使用新的test_v_key2索引替换老的Unique索引
BEGIN;
ALTER TABLE test ADD UNIQUE USING INDEX test_v_key2;
ALTER TABLE test DROP CONSTRAINT test_v_key;
COMMIT;
```

与`default`模式不同，`index`模式下，复制标识是与**具体**的索引绑定的：

```sql
                                    Table "public.test"
 Column |  Type   | Collation | Nullable | Default | Storage  | Stats target | Description
--------+---------+-----------+----------+---------+----------+--------------+-------------
 k      | text    |           |          |         | extended |              |
 v      | integer |           | not null |         | plain    |              |
Indexes:
    "test_v_key" UNIQUE CONSTRAINT, btree (v) REPLICA IDENTITY
    "test_v_key2" UNIQUE CONSTRAINT, btree (v)
```

这意味着如果采用偷天换日的方式替换UNIQUE索引会导致复制身份的丢失。

解决方案有两种：

1. 使用`REINDEX INDEX (CONCURRENTLY)`的方式重建该索引，不会丢失复制标识信息。
2. 在替换索引时，一并刷新表的默认复制身份：

```sql
BEGIN;
ALTER TABLE test ADD UNIQUE USING INDEX test_v_key2;
ALTER TABLE test REPLICA IDENTITY USING INDEX test_v_key2;
ALTER TABLE test DROP CONSTRAINT test_v_key;
COMMIT;
```

顺带一提，移除作为身份标识的索引。尽管在表的配置信息中仍然为`index`模式，但效果与`nothing`相同。所以不要随意折腾作为身份的索引。

### 使用不合格的索引作为复制标识

复制标识需要一个 唯一，不可延迟，整表范围的，建立在非空列集上的索引。

最经典的例子就是主键索引，以及通过`col type NOT NULL UNIQUE`声明的单列非空索引。

之所以要求 NOT NULL，是因为NULL值无法进行等值判断，所以表中允许UNIQE的列上存在多条取值为`NULL`的记录，允许列为空说明这个列无法起到唯一标识记录的效果。如果尝试使用一个普通的`UNIQUE`索引（列上没有非空约束）作为复制标识，则会报错。

```ini
[42809] ERROR: index "t_normal_v_key" cannot be used as replica identity because column "v" is nullable
```



### 使用FULL复制标识

如果没有任何复制标识，可以将复制标识设置为`FULL`，也就是把整个行当作复制标识。

使用`FULL`模式的复制标识效率很低，所以这种配置只能是保底方案，或者用于很小的表。因为每一行修改都需要在订阅者上执行**全表扫描**，**很容易把订阅者拖垮**。

#### FULL模式限制

使用`FULL`模式的复制标识还有一个限制，订阅端的表上的复制身份所包含的列，要么与发布者一致，要么比发布者更少，否则也无法保证的正确性，下面具体来看一个例子。

假如发布订阅两侧的表都采用`FULL`复制标识，但是订阅侧的表要比发布侧多了一列（是的，逻辑复制允许订阅端的表带有发布端表不具有的列）。这样的话，订阅端的表上的复制身份所包含的列要比发布端多了。假设在发布端上删除`(f1=a, f2=a)`的记录，却会导致在订阅端删除两条满足身份标识等值条件的记录。

```
     (Publication)       ------>           (Subscription)
|--- f1 ---|--- f2 ---|          |--- f1 ---|--- f2 ---|--- f3 ---|
|    a     |     a    |          |    a     |     a    |     b    |
                                 |    a     |     a    |     c    |
```

#### FULL模式如何应对重复行问题

PostgreSQL的逻辑复制可以“正确”处理`FULL`模式下完全相同行的场景。假设有这样一张设计糟糕的表，表中存在多条一模一样的记录。

```sql
CREATE TABLE shitty_table(
	 f1  TEXT,
	 f2  TEXT,
	 f3  TEXT
);
INSERT INTO shitty_table VALUES ('a', 'a', 'a'), ('a', 'a', 'a'), ('a', 'a', 'a');
```

在FULL模式下，整行将作为复制标识使用。假设我们在`shitty_table`上通过ctid扫描作弊，删除了3条一模一样记录中的其中一条。

```sql
# SELECT ctid,* FROM shitty_table;
 ctid  | a | b | c
-------+---+---+---
 (0,1) | a | a | a
 (0,2) | a | a | a
 (0,3) | a | a | a

# DELETE FROM shitty_table WHERE ctid = '(0,1)';
DELETE 1

# SELECT ctid,* FROM shitty_table;
 ctid  | a | b | c
-------+---+---+---
 (0,2) | a | a | a
 (0,3) | a | a | a
```

从逻辑上讲，使用整行作为身份标识，那么订阅端执行以下逻辑，会导致全部3条记录被删除。

```sql
DELETE FROM shitty_table WHERE f1 = 'a' AND f2 = 'a' AND f3 = 'a'
```

但实际情况是，因为PostgreSQL的变更记录以行为单位，这条变更仅会对**第一条匹配**的记录生效，所以在订阅侧的行为也是删除3行中的1行。在逻辑上与发布端等效。



