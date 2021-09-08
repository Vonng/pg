---
title: "Postgres逻辑复制详解"
date: 2021-03-03
weight: 5
description: >
  本文介绍PostgreSQL 13中逻辑复制的相关原理，以及最佳实践。
---



## 逻辑复制

**逻辑复制（Logical Replication）**，是一种根据数据对象的 [**复制标识**](/zh/blog/2021/03/03/pg复制标识详解replica-identity/)（Replica Identity）（通常是主键）复制数据对象及其变化的方法。

**逻辑复制** 这个术语与 **物理复制**相对应，物理复制使用精确的块地址与逐字节复制，而逻辑复制则允许对复制过程进行精细的控制。

逻辑复制基于 **发布（Publication）** 与 **订阅**（**Subscription**）模型：

* 一个 **发布者（Publisher）** 上可以有多个**发布**，一个 **订阅者（Subscriber）** 上可以有多个 **订阅** 。
* 一个发布可被多个订阅者订阅，一个订阅只能订阅一个**发布者**，但可订阅同发布者上的多个不同发布。

针对一张表的逻辑复制通常是这样的：订阅者获取发布者数据库上的一个快照，并拷贝表中的存量数据。一旦完成数据拷贝，发布者上的**变更**（增删改清）就会实时发送到订阅者上。订阅者会按照相同的顺序应用这些变更，因此可以保证逻辑复制的事务一致性。这种方式有时候又称为 **事务性复制（transactional  replication）**。

逻辑复制的典型用途是：

* 迁移，跨PostgreSQL大版本，跨操作系统平台进行复制。
* CDC，收集数据库（或数据库的一个子集）中的增量变更，在订阅者上为增量变更触发触发器执行定制逻辑。
* 分拆，将多个数据库集成为一个，或者将一个数据库拆分为多个，进行精细的分拆集成与访问控制。

逻辑订阅者的行为就是一个普通的PostgreSQL实例（主库），逻辑订阅者也可以创建自己的发布，拥有自己的订阅者。

如果逻辑订阅者只读，那么不会有**冲突**。如果会写入逻辑订阅者的订阅集，那么就可能会出现冲突。



## 发布（Publication）

一个 **发布（Publication）** 可以在物理复制**主库** 上定义。创建发布的节点被称为 **发布者（Publisher）** 。

一个 **发布** 是 **由一组表构成的变更集合**。也可以被视作一个 **变更集（change set）** 或 **复制集（Replication Set）** 。每个发布都只能在一个 **数据库（Database）** 中存在。

发布不同于**模式（Schema）**，不会影响表的访问方式。（表纳不纳入发布，自身访问不受影响）

发布目前只能包含**表**（即：索引，序列号，物化视图这些不会被发布），每个表可以添加到多个发布中。

除非针对`ALL TABLES`创建发布，否则发布中的对象（表）只能（通过`ALTER PUBLICATION ADD TABLE`）被**显式添加**。

发布可以筛选所需的变更类型：包括`INSERT`、`UPDATE`、`DELETE` 和`TRUNCATE`的任意组合，类似触发器事件，默认所有变更都会被发布。

### [复制标识](/zh/blog/2021/03/03/pg复制标识详解replica-identity/)

一个被纳入发布中的表，必须带有 **复制标识（Replica Identity）**，只有这样才可以在订阅者一侧定位到需要更新的行，完成`UPDATE`与`DELETE`操作的复制。

默认情况下，**主键** （Primary Key）是表的复制标识，**非空列上的唯一索引** （UNIQUE NOT NULL）也可以用作复制标识。

如果没有任何复制标识，可以将复制标识设置为`FULL`，也就是把整个行当作复制标识。（一种有趣的情况，表中存在多条完全相同的记录，也可以被正确处理，见后续案例）使用`FULL`模式的复制标识效率很低（因为每一行修改都需要在订阅者上执行全表扫描，很容易把订阅者拖垮），所以这种配置只能是保底方案。使用`FULL`模式的复制标识还有一个限制，订阅端的表上的复制身份所包含的列，要么与发布者一致，要么比发布者更少。

`INSERT`操作总是可以无视 复制标识 直接进行（因为插入一条新记录，在订阅者上并不需要定位任何现有记录；而删除和更新则需要通过**复制标识** 定位到需要操作的记录）。如果一个没有 复制标识 的表被加入到带有`UPDATE`和`DELETE`的发布中，后续的`UPDATE`和`DELETE`会导致发布者上报错。

表的复制标识模式可以查阅`pg_class.relreplident`获取，可以通过`ALTER TABLE`进行修改。

```sql
ALTER TABLE tbl REPLICA IDENTITY 
{ DEFAULT | USING INDEX index_name | FULL | NOTHING };
```

尽管各种排列组合都是可能的，然而在实际使用中，只有三种可行的情况。

* 表上有主键，使用默认的 `default` 复制标识
* 表上没有主键，但是有非空唯一索引，显式配置 `index` 复制标识
* 表上既没有主键，也没有非空唯一索引，显式配置`full`复制标识（运行效率非常低，仅能作为兜底方案）
* 其他所有情况，都无法正常完成逻辑复制功能。输出的信息不足，可能会报错，也可能不会。
* 特别需要注意：如果`nothing`复制标识的表纳入到逻辑复制中，对其进行删改会导致发布端报错！

| 复制身份模式\表上的约束 | 主键(p)  | 非空唯一索引(u) | 两者皆无(n) |
| :---------------------: | :------: | :-------------: | :---------: |
|       **d**efault       | **有效** |        x        |      x      |
|        **i**ndex        |    x     |    **有效**     |      x      |
|        **f**ull         | **低效** |    **低效**     |  **低效**   |
|       **n**othing       |   xxxx   |      xxxx       |    xxxx     |

### 管理发布

`CREATE PUBLICATION`用于创建发布，`DROP PUBLICATION`用于移除发布，`ALTER PUBLICATION`用于修改发布。

发布创建之后，可以通过`ALTER PUBLICATION`动态地向发布中添加或移除表，这些操作都是事务性的。

```sql
CREATE PUBLICATION name
    [ FOR TABLE [ ONLY ] table_name [ * ] [, ...]
      | FOR ALL TABLES ]
    [ WITH ( publication_parameter [= value] [, ... ] ) ]

ALTER PUBLICATION name ADD TABLE [ ONLY ] table_name [ * ] [, ...]
ALTER PUBLICATION name SET TABLE [ ONLY ] table_name [ * ] [, ...]
ALTER PUBLICATION name DROP TABLE [ ONLY ] table_name [ * ] [, ...]
ALTER PUBLICATION name SET ( publication_parameter [= value] [, ... ] )
ALTER PUBLICATION name OWNER TO { new_owner | CURRENT_USER | SESSION_USER }
ALTER PUBLICATION name RENAME TO new_name

DROP PUBLICATION [ IF EXISTS ] name [, ...];
```

`publication_parameter` 主要包括两个选项：

* `publish`：定义要发布的变更操作类型，逗号分隔的字符串，默认为`insert, update, delete, truncate`。
* `publish_via_partition_root`：13后的新选项，如果为真，分区表将使用根分区的复制标识进行逻辑复制。

### 查询发布

发布可以使用psql元命令`\dRp`查询。

```bash
# \dRp
  Owner   | All tables | Inserts | Updates | Deletes | Truncates | Via root
----------+------------+---------+---------+---------+-----------+----------
 postgres | t          | t       | t       | t       | t         | f
```

###  `pg_publication` 发布定义表

``pg_publication` 包含了发布的原始定义，每一条记录对应一个发布。

```mssql
# table pg_publication;
oid          | 20453
pubname      | pg_meta_pub
pubowner     | 10
puballtables | t
pubinsert    | t
pubupdate    | t
pubdelete    | t
pubtruncate  | t
pubviaroot   | f
```

* `puballtables`：是否包含所有的表
* `pubinsert|update|delete|truncate` 是否发布这些操作
* `pubviaroot`：如果设置了该选项，任何分区表（叶表）都会使用最顶层的（被）分区表的**复制身份**。所以可以把整个分区表当成一个表，而不是一系列表进行发布。

###  `pg_publication_tables` 发布内容表

`pg_publication_tables`是由`pg_publication`，`pg_class`和`pg_namespace`拼合而成的视图，记录了发布中包含的表信息。

```bash
postgres@meta:5432/meta=# table pg_publication_tables;
   pubname   | schemaname |    tablename
-------------+------------+-----------------
 pg_meta_pub | public     | spatial_ref_sys
 pg_meta_pub | public     | t_normal
 pg_meta_pub | public     | t_unique
 pg_meta_pub | public     | t_tricky
```

使用`pg_get_publication_tables`可以根据订阅的名字获取订阅表的OID

```sql
SELECT * FROM pg_get_publication_tables('pg_meta_pub');
SELECT p.pubname,
       n.nspname AS schemaname,
       c.relname AS tablename
FROM pg_publication p,
     LATERAL pg_get_publication_tables(p.pubname::text) gpt(relid),
     pg_class c
         JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.oid = gpt.relid;
```

同时，`pg_publication_rel` 也提供类似的信息，但采用的是多对多的OID对应视角，包含的是原始数据。

```
  oid  | prpubid | prrelid
-------+---------+---------
 20414 |   20413 |   20397
 20415 |   20413 |   20400
 20416 |   20413 |   20391
 20417 |   20413 |   20394
```

这两者的区别特别需要注意：当针对`ALL TABLES`发布时，`pg_publication_rel`中不会有具体表的OID，但是在`pg_publication_tables`中可以查询到实际纳入逻辑复制的表列表。所以通常应当以`pg_publication_tables`为准。

创建订阅时，数据库会先修改`pg_publication`目录，然后将发布表的信息填入`pg_publication_rel`。



## 订阅

**订阅（Subscription）** 是逻辑复制的下游。定义订阅的节点被称为 **订阅者（Subscriber）** 。

订阅定义了：如何**连接**到另一个数据库，以及需要订阅目标发布者上的哪些**发布**。

逻辑订阅者的行为与一个普通的PostgreSQL实例（主库）无异，逻辑订阅者也可以创建自己的发布，拥有自己的订阅者。

每个订阅者，都会通过一个 **复制槽（Replication）** 来接收变更，在初始数据复制阶段，可能会需要更多的临时复制槽。

逻辑复制订阅可以作为同步复制的备库，备库的名字默认就是订阅的名字，也可以通过在连接信息中设置`application_name`来使用别的名字。

只有超级用户才可以用`pg_dump`转储订阅的定义，因为只有超级用户才可以访问`pg_subscription`视图，普通用户尝试转储时会跳过并打印警告信息。

逻辑复制不会复制DDL变更，因此发布集中的表必须**已经存在**于订阅端上。只有**普通表**上的变更会被复制，视图、物化视图、序列号，索引这些都不会被复制。

发布与订阅端的表是通过完整限定名（如`public.table`）进行匹配的，不支持把变更复制到一个名称不同的表上。

发布与订阅端的表的列也是通过**名称**匹配的。列的顺序无关紧要，数据类型也不一定非得一致，只要两个列的**文本表示**兼容即可，即数据的文本表示可以转换为目标列的类型。订阅端的表可以包含有发布端没有的列，这些新列都会使用默认值填充。

### 管理订阅

`CREATE SUBSCRIPTION`用于创建订阅，`DROP SUBSCRIPTION`用于移除订阅，`ALTER SUBSCRIPTION`用于修改订阅。

订阅创建之后，可以通过`ALTER SUBSCRIPTION` 随时**暂停**与**恢复**订阅。

移除并重建订阅会导致**同步信息丢失**，这意味着相关数据需要重新进行同步。

```sql
CREATE SUBSCRIPTION subscription_name
    CONNECTION 'conninfo'
    PUBLICATION publication_name [, ...]
    [ WITH ( subscription_parameter [= value] [, ... ] ) ]

ALTER SUBSCRIPTION name CONNECTION 'conninfo'
ALTER SUBSCRIPTION name SET PUBLICATION publication_name [, ...] [ WITH ( set_publication_option [= value] [, ... ] ) ]
ALTER SUBSCRIPTION name REFRESH PUBLICATION [ WITH ( refresh_option [= value] [, ... ] ) ]
ALTER SUBSCRIPTION name ENABLE
ALTER SUBSCRIPTION name DISABLE
ALTER SUBSCRIPTION name SET ( subscription_parameter [= value] [, ... ] )
ALTER SUBSCRIPTION name OWNER TO { new_owner | CURRENT_USER | SESSION_USER }
ALTER SUBSCRIPTION name RENAME TO new_name

DROP SUBSCRIPTION [ IF EXISTS ] name;
```

`subscription_parameter`定义了订阅的一些选项，包括：

* `copy_data(bool)`：复制开始后，是否拷贝数据，默认为真
* `create_slot(bool)`：是否在发布者上创建复制槽，默认为真
* `enabled(bool)`：是否启用该订阅，默认为真
* `connect(bool)`：是否尝试连接到发布者，默认为真，置为假会把上面几个选项强制设置为假。
* `synchronous_commit(bool)`：是否启用同步提交，向主库上报自己的进度信息。
* `slot_name`：订阅所关联的复制槽名称，设置为空会取消订阅与复制槽的关联。


### 管理复制槽

每个活跃的订阅都会通过**复制槽** 从远程发布者接受变更。 

通常这个远端的**复制槽**是自动管理的，在`CREATE SUBSCRIPTION`时自动创建，在`DROP SUBSCRIPTION`时自动删除。

在特定场景下，可能需要分别操作订阅与底层的复制槽：

* 创建订阅时，所需的复制槽已经存在。则可以通过`create_slot = false`关联已有复制槽。

* 创建订阅时，远端不可达或状态不明朗，则可以通过`connect = false`不访问远程主机，`pg_dump`就是这么做的。这种情况下，您必须在远端手工创建复制槽后，才能在本地启用该订阅。

* 移除订阅时，需要保留复制槽。这种情况通常是订阅者要搬到另一台机器上去，希望在那里重新开始订阅。这种情况下需要先通过`ALTER SUBSCRIPTION`解除订阅与复制槽点关联

* 移除订阅时，远端不可达。这种情况下，需要在删除订阅之前使用`ALTER SUBSCRIPTION`解除复制槽与订阅的关联。

  如果远端实例不再使用那么没事，然而如果远端实例只是暂时不可达，那就应该手动删除其上的复制槽；否则它将继续保留WAL，并可能导致磁盘撑爆。

### 订阅查询

订阅可以使用psql元命令`\dRs`查询。

```bash
# \dRs
     Name     |  Owner   | Enabled |  Publication
--------------+----------+---------+----------------
 pg_bench_sub | postgres | t       | {pg_bench_pub}
```

###  `pg_subscription` 订阅定义表

每一个逻辑订阅都会有一条记录，注意这个视图是跨数据库集簇范畴的，每个数据库中都可以看到整个集簇中的订阅信息。

只有超级用户才可以访问此视图，因为里面包含有明文密码（连接信息）。

```sql
oid             | 20421
subdbid         | 19356
subname         | pg_test_sub
subowner        | 10
subenabled      | t
subconninfo     | host=10.10.10.10 user=replicator password=DBUser.Replicator dbname=meta
subslotname     | pg_test_sub
subsynccommit   | off
subpublications | {pg_meta_pub}
```

* `subenabled`：订阅是否启用
* `subconninfo` ：因为包含敏感信息，会针对普通用户进行隐藏。
* `subslotname`：订阅使用的复制槽名称，也会被用作逻辑复制的**源名称（Origin Name）**，用于除重。
* `subpublications`：订阅的发布名称列表。
* 其他状态信息：是否启用同步提交等等。

### `pg_subscription_rel` 订阅内容表

`pg_subscription_rel` 记录了每张处于订阅中的表的相关信息，包括状态与进度。

* `srrelid` 订阅中关系的OID
* `srsubstate`，订阅中关系的状态：`i` 初始化中，`d` 拷贝数据中，`s` 同步已完成，`r` 正常复制中。
* `srsublsn`，当处于`i|d`状态时为空，当处于`s|r`状态时，远端的LSN位置。

### 创建订阅时

当一个新的订阅创建时，会依次执行以下操作：

* 将发布的信息存入 `pg_subscription` 目录中，包括连接信息，复制槽，发布名称，一些配置选项等。
* 连接至发布者，检查复制权限，（注意这里**不会检查对应发布是否存在**），
* 创建逻辑复制槽：`pg_create_logical_replication_slot(name, 'pgoutput')`
* 将复制集中的表注册到订阅端的 `pg_subscription_rel` 目录中。
* 执行初始快照同步，注意订阅测表中的原有数据不会被删除。



## 复制冲突

逻辑复制的行为类似于正常的DML操作，即使数据在用户节点上的本地发生了变化，数据也会被更新。如果复制来的数据违反了任何约束，复制就会停止，这种现象被称为 **冲突（Conflict）** 。

当复制`UPDATE`或`DELETE`操作时，缺失数据（即要更新/删除的数据已经不存在）不会产生冲突，此类操作直接跳过。

冲突会导致错误，并中止逻辑复制，逻辑复制管理进程会以5秒为间隔不断重试。冲突不会阻塞订阅端对复制集中表上的SQL。关于冲突的细节可以在用户的服务器日志中找到，**冲突必须由用户手动解决**。

### 日志中可能出现的冲突

|          冲突模式          | 复制进程 | 输出日志 |
| :------------------------: | :------: | :------: |
|   缺少UPDATE/DELETE对象    |   继续   |  不输出  |
|        表/行锁等待         |   等待   |  不输出  |
|  违背主键/唯一/Check约束   | **中止** |   输出   |
| 目标表不存在/目标列不存在  | **中止** |   输出   |
| 无法将数据转换为目标列类型 | **中止** |   输出   |



解决冲突的方法，可以是改变订阅侧的数据，使其不与进入的变更相冲突，或者跳过与现有数据冲突的事务。

使用订阅对应的`node_name`与LSN位置调用函数`pg_replication_origin_advance()`可以跳过事务，`pg_replication_origin_status`系统视图中可以看到当前ORIGIN的位置。



## 局限性

逻辑复制目前有以下限制，或者说功能缺失。这些问题可能会在未来的版本中解决。

**数据库模式和DDL命令不会被复制**。存量模式可以通过`pg_dump --schema-only`手动复制，增量模式变更需要手动保持同步（发布订阅两边的模式不需要绝对相同不需要两边的模式绝对相同)。逻辑复制对于对在线DDL变更仍然可靠：在发布数据库中执行DDL变更后，复制的数据到达订阅者但因为表模式不匹配而导致复制出错停止，订阅者的模式更新后复制会继续。在许多情况下，先在订阅者上执行变更可以避免中间的错误。

**序列号数据不会被复制**。**序列号**所服务的标识列与`SERIAL`类型里面的数据作为表的一部分当然会被复制，但序列号本身仍会在订阅者上保持为初始值。如果订阅者被当成只读库使用，那么通常没事。然而如果打算进行某种形式的切换或Failover到订阅者数据库，那么需要将序列号更新为最新的值，要么通过从发布者复制当前数据（也许可以使用`pg_dump -t *seq*`），要么从表本身的数据内容确定一个足够高的值（例如`max(id)+1000000`）。否则如果在新库执行获取序列号作为身份的操作时，很可能会产生冲突。

**逻辑复制支持复制`TRUNCATE`命令**，但是在`TRUNCATE`由外键关联的一组表时需要特别小心。当执行`TRUNCATE`操作时，发布者上与之关联的一组表（通过显式列举或级连关联）都会被`TRUNCATE`，但是在订阅者上，不在订阅集中的表不会被`TRUNCATE`。这样的操作在逻辑上是合理的，因为逻辑复制不应该影响到复制集之外的表。但如果有一些不在订阅集中的表通过外键引用订阅集中被`TRUNCATE`的表，那么`TRUNCATE`操作就会失败。

**大对象不会被复制**

**只有表能被复制（包括分区表）**，尝试复制其他类型的表会导致错误（视图，物化视图，外部表，Unlogged表）。具体来说，只有在`pg_class.relkind = 'r'`的表才可以参与逻辑复制。

**复制分区表时默认按子表进行复制**。默认情况下，变更是按照分区表的叶子分区触发的，这意味着发布上的每一个分区子表都需要在订阅上存在（当然，订阅者上的这个分区子表不一定是一个分区子表，也可能本身就是一个分区母表，或者一个普通表）。发布可以声明要不要使用分区根表上的复制标识取代分区叶表上的复制标识，这是PG13提供的新功能，可以在创建发布时通过`publish_via_partition_root` 选项指定。

**触发器的行为表现有所不同**。**行级触发器**会触发，但`UPDATE OF cols`类型的触发器不触发。而语句级触发器只会在初始数据拷贝时触发。

**日志行为不同**。即使设置`log_statement = 'all'`，日志中也不会记录由复制产生的SQL语句。

**双向复制需要极其小心**：互为发布与订阅是可行的，只要两遍的表集合不相交即可。但一旦出现表的交集，就会出现WAL无限循环。

**同一实例内的复制**：同一个实例内的逻辑复制需要特别小心，必须**手工创建逻辑复制槽**，并在创建订阅时使用已有的逻辑复制槽，否则会卡死。

**只能在主库上进行**：目前不支持从物理复制的从库上进行逻辑解码，也无法在从库上创建复制槽，所以从库无法作为发布者。但这个问题可能会在未来解决。



## 架构

逻辑复制始于获取发布者数据库上的快照，基于此快照拷贝表上的存量数据。一旦拷贝完成，发布者上的**变更**（增删改等）就会实时发送到订阅者上。

逻辑复制采用与物理复制类似的架构，是通过一个`walsender`和`apply`进程实现的。发布端端`walsender`进程会加载逻辑解码插件（`pgoutput`），并开始逻辑解码WAL日志。**逻辑解码插件（Logical Decoding Plugin）** 会读取WAL中的变更，按照**发布**的定义筛选变更，将变更转变为特定的形式，以逻辑复制协议传输出去。数据会按照流复制协议传输至订阅者一侧的`apply`进程，该进程会在接收到变更时，将变更映射至本地表上，然后按照事务顺序重新应用这些变更。

### 初始快照

订阅侧的表在初始化与拷贝数据期间，会由一种特殊的`apply`进程负责。这个进程会创建它自己的**临时复制槽**，并拷贝表中的存量数据。

一旦数据拷贝完成，这张表会进入到同步模式（`pg_subscription_rel.srsubstate = 's'`），同步模式确保了 **主apply进程** 可以使用标准的逻辑复制方式应用拷贝数据期间发生的变更。一旦完成同步，表复制的控制权会转交回 **主apply进程**，恢复正常的复制模式。

### 进程结构

逻辑复制的发布端会针对来自订阅端端每一条连接，创建一个对应的 `walsender` 进程，发送解码的WAL日志。在订阅测，则会

### 复制槽

当创建订阅时，

一条逻辑复制



### 逻辑解码

### 同步提交

逻辑复制的同步提交是通过Backend与Walsender之间的SIGUSR1通信完成的。

### 临时数据

逻辑解码的临时数据会落盘为本地日志快照。当walsender接收到walwriter发送的`SIGUSR1`信号时，就会读取WAL日志并生成相应的逻辑解码快照。当传输结束时会删除这些快照。

文件地址为：`$PGDATA/pg_logical/snapshots/{LSN Upper}-{LSN Lower}.snap`



## 监控

逻辑复制采用与物理流复制类似的架构，所以监控一个逻辑复制的**发布者节点**与监控一个物理复制主库差别不大。

订阅者的监控信息可以通过`pg_stat_subscription`视图获取。

###  `pg_stat_subscription` 订阅统计表

每个**活跃订阅**都会在这个视图中有**至少一条** 记录，即Main Worker（负责应用逻辑日志）。

Main Worker的`relid = NULL`，如果有负责初始数据拷贝的进程，也会在这里有一行记录，`relid`为负责拷贝数据的表。

```bash
subid                 | 20421
subname               | pg_test_sub
pid                   | 5261
relid                 | NULL
received_lsn          | 0/2A4F6B8
last_msg_send_time    | 2021-02-22 17:05:06.578574+08
last_msg_receipt_time | 2021-02-22 17:05:06.583326+08
latest_end_lsn        | 0/2A4F6B8
latest_end_time       | 2021-02-22 17:05:06.578574+08
```

* `received_lsn` ：最近**收到**的日志位置。
* `lastest_end_lsn`：最后向walsender回报的LSN位置，即主库上的`confirmed_flush_lsn`。不过这个值更新不太勤快，

通常情况下一个活跃的订阅会有一个apply进程在运行，被禁用的订阅或崩溃的订阅则在此视图中没有记录。在初始同步期间，被同步的表会有额外的工作进程记录。

###  `pg_replication_slot` 复制槽

```bash
postgres@meta:5432/meta=# table pg_replication_slots ;
-[ RECORD 1 ]-------+------------
slot_name           | pg_test_sub
plugin              | pgoutput
slot_type           | logical
datoid              | 19355
database            | meta
temporary           | f
active              | t
active_pid          | 89367
xmin                | NULL
catalog_xmin        | 1524
restart_lsn         | 0/2A08D40
confirmed_flush_lsn | 0/2A097F8
wal_status          | reserved
safe_wal_size       | NULL
```

复制槽视图中同时包含了逻辑复制槽与物理复制槽。逻辑复制槽点主要特点是：

* `plugin`字段不为空，标识了使用的逻辑解码插件，逻辑复制默认使用`pgoutput`插件。
* `slot_type = logical`，物理复制的槽类型为`physical`。
* `datoid`与`database`字段不为空，因为物理复制与集簇关联，而逻辑复制与数据库关联。

逻辑订阅者也会作为一个标准的 **复制从库** ，出现于 `pg_stat_replication` 视图中。

### `pg_replication_origin` 复制源

复制源

```sql
table pg_replication_origin_status;
-[ RECORD 1 ]-----------
local_id    | 1
external_id | pg_19378
remote_lsn  | 0/0
local_lsn   | 0/6BB53640
```

* `local_id`：复制源在本地的ID，2字节高效表示。
* `external_id`：复制源的ID，可以跨节点引用。
* `remote_lsn`：源端最近的**提交位点**。
* `local_lsn`：本地已经持久化提交记录的LSN

### 检测复制冲突

最稳妥的检测方法总是从发布与订阅两侧的日志中检测。当出现复制冲突时，发布测上可以看见复制连接中断

```yaml
LOG:  terminating walsender process due to replication timeout
LOG:  starting logical decoding for slot "pg_test_sub"
DETAIL:  streaming transactions committing after 0/xxxxx, reading WAL from 0/xxxx
```

而订阅端则可以看到复制冲突的具体原因，例如：

```csv
logical replication worker PID 4585 exited with exit code 1
ERROR: duplicate key value violates unique constraint "pgbench_tellers_pkey","Key (tid)=(9) already exists.",,,,"COPY pgbench_tellers, line 31",,,,"","logical replication worker"
```

此外，一些监控指标也可以反映逻辑复制的状态：

例如：`pg_replication_slots.confirmed_flush_lsn` 长期落后于`pg_cureent_wal_lsn`。或者`pg_stat_replication.flush_ag/write_lag` 有显著增长。



## 安全

参与订阅的表，其Ownership与Trigger权限必须控制在超级用户所信任的角色手中（否则修改这些表可能导致逻辑复制中断）。

在发布节点上，如果不受信任的用户具有建表权限，那么创建发布时应当显式指定表名而非通配`ALL TABLES`。也就是说，只有当超级用户信任所有 可以在发布或订阅侧具有建表（非临时表）权限的用户时，才可以使用`FOR ALL TABLES`。

用于复制连接的用户必须具有`REPLICATION`权限（或者为SUPERUSER）。如果该角色缺少`SUPERUSER`与`BYPASSRLS`，发布者上的行安全策略可能会被执行。如果表的属主在复制启动之后设置了行级安全策略，这个配置可能会导致复制直接中断，而不是策略生效。该用户必须拥有LOGIN权限，而且HBA规则允许其访问。

为了能够复制初始表数据，用于复制连接的角色必须在已发布的表上拥有`SELECT`权限（或者属于超级用户）。

创建发布，需要在数据库中的`CREATE`权限，创建一个`FOR ALL TABLES`的发布，需要超级用户权限。

将表加入到发布中，用户需要具有表的**属主**权限。

创建订阅需要超级用户权限，因为订阅的apply进程在本地数据库中以超级用户的权限运行。

**权限只会在建立复制连接时检查**，不会在发布端读取每条变更记录时重复检查，也不会在订阅端应用每条记录时检查。





## 配置选项

逻辑复制需要一些配置选项才能正常工作。

在发布者一侧，`wal_level` 必须设置为`logical`，`max_replication_slots`最少需要设为 订阅的数量+用于表数据同步的数量。`max_wal_senders`最少需要设置为`max_replication_slots` + 为物理复制保留的数量，

在订阅者一侧，也需要设置`max_replication_slots`，`max_replication_slots`，最少需要设为订阅数。

`max_logical_replication_workers`最少需要配置为订阅的数量，再加上一些用于数据同步的工作进程数。

此外，`max_worker_processes`需要相应调整，至少应当为`max_logical_replication_worker` + 1。注意一些扩展插件和并行查询也会从工作进程的池子中获取连接使用。

### 配置参数样例

64核机器，1～2个发布与订阅，最多6个同步工作进程，最多8个物理从库的场景，一种样例配置如下所示：

首先决定Slot数量，2个订阅，6个同步工作进程，8个物理从库，所以配置为16。Sender = Slot + Physical Replica = 24。

同步工作进程限制为6，2个订阅，所以逻辑复制的总工作进程设置为8。

```ini
wal_level: logical                      # logical	
max_worker_processes: 64                # default 8 -> 64, set to CPU CORE 64
max_parallel_workers: 32                # default 8 -> 32, limit by max_worker_processes
max_parallel_maintenance_workers: 16    # default 2 -> 16, limit by parallel worker
max_parallel_workers_per_gather: 0      # default 2 -> 0,  disable parallel query on OLTP instance
# max_parallel_workers_per_gather: 16   # default 2 -> 16, enable parallel query on OLAP instance

max_wal_senders: 24                     # 10 -> 24
max_replication_slots: 16               # 10 -> 16 
max_logical_replication_workers: 8      # 4 -> 8, 6 sync worker + 1~2 apply worker
max_sync_workers_per_subscription: 6    # 2 -> 6, 6 sync worker
```



## 快速配置

首先设置发布侧的配置选项 `wal_level = logical`，该参数需要重启方可生效，其他参数的默认值都不影响使用。

然后创建复制用户，添加`pg_hba.conf`配置项，允许外部访问，一种典型配置是：

```sql
CREATE USER replicator REPLICATION BYPASSRLS PASSWORD 'DBUser.Replicator';
```

注意，逻辑复制的用户需要具有`SELECT`权限，在Pigsty中`replicator`已经被授予了`dbrole_readonly`角色。

```ini
host     all          replicator     0.0.0.0/0     md5
host     replicator   replicator     0.0.0.0/0     md5
```

然后在发布侧的数据库中执行：

```sql
CREATE PUBLICATION mypub FOR TABLE <tablename>;
```

然后在订阅测数据库中执行：

```sql
CREATE SUBSCRIPTION mysub CONNECTION 'dbname=<pub_db> host=<pub_host> user=replicator' PUBLICATION mypub;
```

以上配置即会开始复制，首先复制表的初始数据，然后开始同步增量变更。

### 沙箱样例

以Pigsty标准4节点两集群沙箱为例，有两套数据库集群`pg-meta`与`pg-test`。现在将`pg-meta-1`作为发布者，`pg-test-1`作为订阅者。

```bash
PGSRC='postgres://dbuser_admin@meta-1/meta'           # 发布者
PGDST='postgres://dbuser_admin@node-1/test'           # 订阅者
pgbench -is100 ${PGSRC}                               # 在发布端初始化Pgbench
pg_dump -Oscx -t pgbench* -s ${PGSRC} | psql ${PGDST} # 在订阅端同步表结构

# 在发布者上创建**发布**，将默认的`pgbench`相关表加入到发布集中。
psql ${PGSRC} -AXwt <<-'EOF'
CREATE PUBLICATION "pg_meta_pub" FOR TABLE
  pgbench_accounts,pgbench_branches,pgbench_history,pgbench_tellers;
EOF

# 在订阅者上创建**订阅**，订阅发布者上的发布。
psql ${PGDST} <<-'EOF'
CREATE SUBSCRIPTION pg_test_sub
  CONNECTION 'host=10.10.10.10 dbname=meta user=replicator' 
  PUBLICATION pg_meta_pub;
EOF
```







## 复制流程

逻辑复制的订阅创建后，如果一切正常，逻辑复制会自动开始，针对**每张订阅中的表**执行复制状态机逻辑。

如下图所示。

<div class="mermaid">
stateDiagram-v2
    [*] --> init : 表被加入到订阅集中
    init --> data : 开始同步表的初始快照
    data --> sync : 存量数据同步完成
    sync --> ready : 同步期间的增量变更应用完毕，进入就绪状态
</div>

当所有的表都完成复制，进入`r`（ready）状态时，逻辑复制的存量同步阶段便完成了，发布端与订阅端整体进入同步状态。

因此从逻辑上讲，存在两种状态机：**表级复制小状态机**与**全局复制大状态机**。每一个Sync Worker负责一张表上的小状态机，而一个Apply Worker负责一条逻辑复制的大状态机。



## 逻辑复制状态机



逻辑复制有两种Worker：Sync与Apply。Sync

因此，逻辑复制在逻辑上分为两个部分：**每张表独自进行复制**，当复制进度追赶至最新位置时，由



当创建或刷新订阅时，表会被加入到 订阅集 中，每一张订阅集中的表都会在`pg_subscription_rel`视图中有一条对应纪录，展示这张表当前的复制状态。刚加入订阅集的表初始状态为`i`，即`initialize`，**初始状态**。

如果订阅的`copy_data`选项为真（默认情况），且工作进程池中有空闲的Worker，PostgreSQL会为这张表分配一个同步工作进程，同步这张表上的存量数据，此时表的状态进入`d`，即**拷贝数据中**。对表做数据同步类似于对数据库集群进行`basebackup`，Sync Worker会在发布端创建临时的复制槽，获取表上的快照并通过COPY完成基础数据同步。

当表上的基础数据拷贝完成后，表会进入`sync`模式，即**数据同步**，同步进程会追赶同步过程中发生的增量变更。当追赶完成时，同步进程会将这张表标记为`r`（ready）状态，转交逻辑复制主Apply进程管理变更，表示这张表已经处于正常复制中。





### 2.4 等待逻辑复制同步

创建订阅后，首先必须监控 发布端与订阅端两侧的数据库日志，**确保没有错误产生**。

#### 2.4.1 逻辑复制状态机



#### 2.4.2 同步进度跟踪

数据同步（`d`）阶段可能需要花费一些时间，取决于网卡，网络，磁盘，表的大小与分布，逻辑复制的同步worker数量等因素。

作为参考，1TB的数据库，20张表，包含有250GB的大表，双万兆网卡，在6个数据同步worker的负责下大约需要6~8小时完成复制。

在数据同步过程中，每个表同步任务都会源端库上创建临时的复制槽。请确保逻辑复制初始同步期间不要给源端主库施加过大的不必要写入压力，以免WAL撑爆磁盘。

发布侧的 `pg_stat_replication`，`pg_replication_slots`，订阅端的`pg_stat_subscription`，`pg_subscription_rel`提供了逻辑复制状态的相关信息，需要关注。

```sql
psql ${PGDST} -Xxw <<-'EOF'
    SELECT subname, json_object_agg(srsubstate, cnt) FROM
    pg_subscription s JOIN
      (SELECT srsubid, srsubstate, count(*) AS cnt FROM pg_subscription_rel 
       GROUP BY srsubid, srsubstate) sr
    ON s.oid = sr.srsubid GROUP BY subname;
EOF
```

可以使用以下SQL确认订阅中表的状态，如果所有表的状态都显示为`r`，则表示逻辑复制已经成功建立，订阅端可以用于切换。

```bash
   subname   | json_object_agg
-------------+-----------------
 pg_test_sub | { "r" : 5 }
```

当然，最好的方式始终是通过监控系统来跟踪复制状态。





































## 沙箱样例

以Pigsty标准4节点两集群沙箱为例，有两套数据库集群`pg-meta`与`pg-test`。现在将`pg-meta-1`作为发布者，`pg-test-1`作为订阅者。

通常逻辑复制的前提是，发布者上设置有`wal_level = logical`，并且有一个可以正常访问，具有正确权限的复制用户。

Pigsty的默认配置已经符合要求，且带有满足条件的复制用户`replicator`，以下命令均从元节点以`postgres`用户发起，数据库用户`dbuser_admin`，带有`SUPERUSER`权限。

```bash
PGSRC='postgres://dbuser_admin@meta-1/meta'        # 发布者
PGDST='postgres://dbuser_admin@node-1/test'        # 订阅者
```

### 准备逻辑复制

使用`pgbench`工具，在`pg-meta`集群的`meta`数据库中初始化表结构。

```bash
pgbench -is100 ${PGSRC}
```

使用`pg_dump`与`psql`  **同步** `pgbench*` 相关表的定义。

```bash
pg_dump -Oscx -t pgbench* -s ${PGSRC} | psql ${PGDST}
```

### 创建发布订阅

在发布者上创建**发布**，将默认的`pgbench`相关表加入到发布集中。

```bash
psql ${PGSRC} -AXwt <<-'EOF'
CREATE PUBLICATION "pg_meta_pub" FOR TABLE
  pgbench_accounts,pgbench_branches,pgbench_history,pgbench_tellers;
EOF
```

在订阅者上创建**订阅**，订阅发布者上的发布。

```bash
psql ${PGDST} <<-'EOF'
CREATE SUBSCRIPTION pg_test_sub
  CONNECTION 'host=10.10.10.10 dbname=meta user=replicator' 
  PUBLICATION pg_meta_pub;
EOF
```

### 观察复制状态

当`pg_subscription_rel.srsubstate`全部变为`r` （准备就绪）状态后，逻辑复制就建立起来了。

```bash
$ psql ${PGDST} -c 'TABLE pg_subscription_rel;'
 srsubid | srrelid | srsubstate |  srsublsn
---------+---------+------------+------------
   20451 |   20433 | d          | NULL
   20451 |   20442 | r          | 0/4ECCDB78
   20451 |   20436 | r          | 0/4ECCDB78
   20451 |   20439 | r          | 0/4ECCDBB0
```

### 校验复制数据

可以简单地比较发布与订阅端两侧的表记录条数，与复制标识列的最大最小值来校验数据是否完整地复制。

```bash
function compare_relation(){
	local relname=$1
	local identity=${2-'id'}
	psql ${3-${PGPUB}} -AXtwc "SELECT count(*) AS cnt, max($identity) AS max, min($identity) AS min FROM ${relname};"
	psql ${4-${PGSUB}} -AXtwc "SELECT count(*) AS cnt, max($identity) AS max, min($identity) AS min FROM ${relname};"
}
compare_relation pgbench_accounts aid
compare_relation pgbench_branches bid
compare_relation pgbench_history  tid
compare_relation pgbench_tellers  tid
```

更近一步的验证可以通过在发布者上手工创建一条记录，再从订阅者上读取出来。

```bash
$ psql ${PGPUB} -AXtwc 'INSERT INTO pgbench_accounts(aid,bid,abalance) VALUES (99999999,1,0);'
INSERT 0 1
$ psql ${PGSUB} -AXtwc 'SELECT * FROM pgbench_accounts WHERE aid = 99999999;'
99999999|1|0|
```

现在已经拥有一个正常工作的逻辑复制了。下面让我们来通过一系列实验来掌握逻辑复制的使用与管理，探索可能遇到的各种离奇问题。









## 逻辑复制实验

### 将表加入已有发布

```sql
CREATE TABLE t_normal(id BIGSERIAL PRIMARY KEY,v  TIMESTAMP); -- 常规表，带有主键
ALTER PUBLICATION pg_meta_pub ADD TABLE t_normal; -- 将新创建的表加入到发布中
```

如果这张表在订阅端已经存在，那么即可进入正常的逻辑复制流程：`i -> d -> s -> r`。

如果向发布加入一张订阅端不存在的表？那么新订阅将会**无法创建**。**已有订阅无法刷新**，但可以保持原有复制继续进行。

如果订阅**还不存在**，那么创建的时候会报错无法进行：在订阅端找不到这张表。如果订阅**已经存在**，无法执行刷新命令：

```sql
ALTER SUBSCRIPTION pg_test_sub REFRESH PUBLICATION;
```

如果新加入的表没有任何写入，已有的复制关系不会发生变化，一旦新加入的表发生变更，会立即产生**复制冲突**。



### 将表从发布中移除

```sql
ALTER PUBLICATION pg_meta_pub ADD TABLE t_normal;
```

从发布移除后，订阅端不会有影响。效果上就是这张表的变更似乎消失了。执行订阅刷新后，这张表会从订阅集中被移除。

另一种情况是**重命名**发布/订阅中的表，在发布端执行表重命名时，发布端的发布集会立刻随之更新。尽管订阅集中的表名不会立刻更新，但只要重命名后的表发生任何变更，而订阅端没有对应的表，那么会立刻出现**复制冲突**。

同理，在订阅端重命名表时，订阅的关系集也会刷新，但因为发布端的表没有对应物了。如果这张表没有变更，那么一切照旧，一旦发生变更，立刻出现**复制冲突**。

直接在发布端`DROP`此表，会顺带**将该表从发布中移除**，不会有报错或影响。但直接在订阅端`DROP`表则可能出现**问题**，`DROP TABLE`时该表也会从订阅集中被移除。如果发布端此时这张表上仍有变更产生，则会导致**复制冲突**。

**所以，删表应当先在发布端进行，再在订阅端进行。**



### 两端列定义不一致

发布与订阅端的表的列通过**名称**匹配，列的顺序无关紧要。

**订阅端表的列更多，通常不会有什么影响**。多出来的列会被填充为默认值（通常是`NULL`）。

特别需要注意的是，如果要为多出来的列添加`NOT NULL`约束，那么一定要配置一个默认值，否则变更发生时违反约束会导致复制冲突。

**订阅端如果列要比发布端更少，会产生复制冲突**。在发布端添加一个新列并不会**立刻**导致复制冲突，随后的第一条变更将导致复制冲突。

所以在执行加列DDL变更时，可以先在订阅者上先执行，然后在发布端进行。

列的**数据类型不需要完全一致**，只要两个列的**文本表示**兼容即可，即数据的文本表示可以转换为目标列的类型。

这意味着任何类型都能转换成TEXT类型，`BIGINT` 只要不出错，也可以转换成`INT`，不过一旦溢出，还是会出现**复制冲突**。



### 复制身份与索引的正确配置

表上的复制标识配置，与表上有没有索引是两件独立的事。尽管各种排列组合都是可能的，然而在实际使用中只有三种可行的情况，其他情况都无法正常完成逻辑复制的功能（如果不报错，通常也是侥幸）

* 表上有主键，使用默认的 `default` 复制标识，不需要额外配置。
* 表上没有主键，但是有非空唯一索引，显式配置 `index` 复制标识。
* 表上既没有主键也没有非空唯一索引，显式配置`full`复制标识（运行效率低，仅作为兜底方案）

| 复制身份模式\表上的约束 | 主键(p)  | 非空唯一索引(u) | 两者皆无(n) |
| :---------------------: | :------: | :-------------: | :---------: |
|       **d**efault       | **有效** |        x        |      x      |
|        **i**ndex        |    x     |    **有效**     |      x      |
|        **f**ull         | **低效** |    **低效**     |  **低效**   |
|       **n**othing       |    x     |        x        |      x      |

> 在所有情况下，`INSERT`都可以被正常复制。`x`代表`DELETE|UPDATE`所需关键信息缺失无法正常完成。

最好的方式当然是事前修复，为所有的表指定主键，以下查询可以用于找出缺失主键或非空唯一索引的表：

```sql
SELECT quote_ident(nspname) || '.' || quote_ident(relname) AS name, con.ri AS keys,
       CASE relreplident WHEN 'd' THEN 'default' WHEN 'n' THEN 'nothing' WHEN 'f' THEN 'full' WHEN 'i' THEN 'index' END AS replica_identity
FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid, LATERAL (SELECT array_agg(contype) AS ri FROM pg_constraint WHERE conrelid = c.oid) con
WHERE relkind = 'r' AND nspname NOT IN ('pg_catalog', 'information_schema', 'monitor', 'repack', 'pg_toast')
ORDER BY 2,3;
```

注意，复制身份为`nothing`的表可以加入到发布中，但在发布者上对其执行`UPDATE|DELETE`会直接导致报错。



## 其他问题

### Q：逻辑复制准备工作

### Q：什么样的表可以逻辑复制？

### Q：监控逻辑复制状态

### Q：将新表加入发布

### Q：没有主键的表加入发布？

### Q：没有复制身份的表如何处理？

### Q：ALTER PUB的生效方式

### Q：在同一对 发布者-订阅者 上如果存在多对订阅，且发布包含的表重叠？

### Q：订阅者和发布者的表定义有什么限制？

### Q：pg_dump是如何处理订阅的

### Q：什么情况下需要手工管理订阅复制槽？