---
description: "PostgreSQL中的锁"
categories: ["PG"]
tags: ["PostgreSQL","SQL", "Lock"]
type: "post"
---

# PostgreSQL锁

PostgreSQL的并发控制以**快照隔离（SI）**为主，以**两阶段锁定（2PL）**机制为辅。PostgreSQL对DML（`SELECT, UPDATE, INSERT, DELETE`等命令）使用SSI，对DDL（`CREATE TABLE`等命令）使用2PL。

PostgreSQL有好几类锁，其中最主要的是**表级锁**与**行级锁**，此外还有页级锁，咨询锁等，**表级锁**通常是各种命令执行时自动获取的，或者通过事务中的`LOCK`语句显式获取；而行级锁则是由`SELECT FOR UPDATE|SHARE`语句显式获取的。执行数据库命令时，都是先获取表级锁，再获取行级锁。本文主要介绍PostgreSQL中的表锁。



## 表级锁

* **表级锁**通常会在执行各种命令执行时自动获取，或者通过在事务中使用`LOCK`语句显式获取。
* 每种锁都有自己的**冲突集合**，在同一时刻的同一张表上，两个事务可以持有不冲突的锁，不能持有冲突的锁。
* 有些锁是**自斥(self-conflict)**的，即最多只能被一个事务所持有。
* 表级锁总共有八种模式，有着并不严格的强度递增关系（例外是`Share`锁不自斥）
* 表级锁存在于PG的共享内存中，可以通过`pg_locks`系统视图查阅。

### 表级锁的模式

![](../img/table-lock-mode.png)

如何记忆这么多类型的锁呢？让我们从演化的视角来看这些锁。

### 表级锁的演化

![](../img/lock-envolve.png)

最开始只有两种锁：`Share`与`Exclusive`，共享锁与排它锁，即所谓**读锁**与**写锁**。读锁的目的是阻止表数据的变更，而写锁的目的是阻止一切并发访问。这很好理解。

#### 多版本并发控制

后来随着多版本并发控制技术的出现（PostgreSQL使用快照隔离实现MVCC），读不阻塞写，写不阻塞读（针对表的增删改查而言）。因而原有的锁模型就需要升级了：这里的共享锁与排他锁都有了一个升级版本，即前面多加一个`ACCESS`。`ACCESS SHARE`是改良版共享锁，即允许`ACCESS`（多版本并发访问）的`SHARE`锁，这种锁意味着即使其他进程正在并发修改数据也不会阻塞本进程读取数据。当然有了多版本读锁也就会有对应的多版本写锁来阻止一切访问，即连`ACCESS`（多版本并发访问）都要`EXCLUSIVE`的锁，这种锁会阻止一切访问，是最强的写锁。

引入MVCC后，`INSERT|UPDATE|DELETE`仍然使用原来的`Exclusive`锁，而普通的只读`SELECT`则使用多版本的`AccessShare`锁。因为`AccessShare`锁与原来的`Exclusive`锁不冲突，所以读写之间就不会阻塞了。原来的`Share`锁现在主要的应用场景为创建索引（非并发创建模式下，创建索引会阻止任何对底层数据的变更），而升级的多版本`AccessExclusive`锁主要用于除了增删改之外的排他性变更（`DROP|TRUNCATE|REINDEX|VACUUM FULL`等），这个模型如图（a）所示。

当然，这样还是有问题的。虽然在MVCC中读写之间相互不阻塞了，但写-写之间还是会产生冲突。上面的模型中，并发写入是通过表级别的`Exclusive`锁解决的。表级锁虽然可以解决并发写入冲突问题，但这个粒度太大了，会影响并发度：因为同一时刻一张表上只能有一个进程持有`Exclusive`锁并执行写入，而典型的OLTP场景是以单行写入为主。所以常见的DBMS解决写-写冲突通常都是采用**行级锁**来实现（下面会讲到）。

行级锁和表级锁不是一回事，但这两种锁之间仍然存在着联系，协调这两种锁之间的关系，就需要引入**意向锁**。

#### 意向锁

意向锁用于协调表锁与行锁之间的关系：它用于保护较低资源级别上的锁，即说明下层节点已经被加了锁。当进程想要锁定或修改某表上的某一行时，它会在这一行上加上行级锁。但在加行级锁之前，它还需要在这张表上加上一把意向锁，表示自己将会在表中的若干行上加锁。

举个例子，假设不存在意向锁。假设进程A获取了表上某行的行锁，持有行上的排他锁意味着进程A可以对这一行执行写入；同时因为不存在意向锁，进程B很顺利地获取了该表上的表级排他锁，这意味着进程B可以对整个表，包括A锁定对那一行进行修改，这就违背了常识逻辑。因此A需要在获取行锁前先获取表上的意向锁，这样后来的B就意识到自己无法获取整个表上的排他锁了（但B依然可以加一个意向锁，获取其他行上的行锁）。

因此，这里`RowShare`就是行级共享锁对应的表级意向锁（`SELECT FOR SHARE|UPDATE`命令获取），而`RowExclusive`（`INSERT|UPDATE|DELETE`获取）则是行级排他锁对应的表级意向锁。注意因为MVCC的存在，只读查询并不会在行上加锁。引入意向锁后的模型如图（c）所示。而合并MVCC与意向锁模型之后的锁模型如图（d）所示。

#### 自斥锁

上面这个模型已经相当不错，但仍然存在一些问题，譬如自斥：这里`RowExclusive`与`Share`锁都不是自斥的。

举个例子，并发VACUUM不应阻塞数据写入，而且一个表上不应该允许多个VACUUM进程同时工作。因为不能阻塞写入，因此VACUUM所需的锁强度必须要比Share锁弱，弱于Share的最强锁为`RowExclusive`，不幸的是，该锁并不自斥。如果VACUUM使用该锁，就无法阻止单表上出现多个VACUUM进程。因此需要引入一个自斥版本的`RowExclusive`锁，即`ShareUpdateExclusive`锁。

同理，再比如执行触发器管理操作（创建，删除，启用）时，该操作不应阻塞读取和锁定，但必须禁止一切实际的数据写入，否则就难以判断某条元组的变更是否应该触发触发器。Share锁满足不阻塞读取和锁定的条件，但并不自斥，因此可能出现多个进程在同一个表上并发修改触发器。并发修改触发器会带来很多问题（譬如丢失更新，A将其配置为Replica Trigger，B将其配置为Always Trigger，都反回成功了，以谁为准？）。因此这里也需要一个自斥版本的`Share`锁，即`ShareRowExclusive`锁。

因此，引入两种自斥版本的锁后，就是PostgreSQL中的最终表级锁模型，如图（e）所示。

### 表级锁的命名与记忆

PostgreSQL的表级锁的命名有些诘屈聱牙，这是因为一些历史因素，但也可以总结出一些规律便于记忆。

- 最初只有两种锁：共享锁（`Share`）与排他锁（`Exclusive`）。
  - 特征是只有一个单词，表示这是两种最基本的锁：读锁与写锁。
- 多版本并发控制的出现，引入了多版本的共享锁与排他锁（`AccessShare`与`AccessExclusive`）。
  - 特征是`Access`前缀，表示这是用于"多版本并发控制"的改良锁。
- 为了处理并发写入之间的冲突，又引入了两种意向锁（`RowShare`与`RowExclusive`）
  - 特征是`Row`前缀，表示这是行级别共享/排他锁对应的表级意向锁。
- 最后，为了处理意向排他锁与共享锁不自斥的问题，引入了这两种锁的自斥版本（`ShareUpdateExclusive`, `ShareRowExclusive`）。这两种锁的名称比较难记：
  - 都是以`Share`打头，以`Exclusive`结尾。表示这两种锁都是某种共享锁的自斥版本。
  - 两种锁强度围绕在`Share`前后，`Update`弱于`Share`，`Row`强于`Share`。
  - `ShareRowExclusive`可以理解为`Share` + `Row Exclusive`，因为`Share`不排斥其他`Share`，但`RowExclusive`排斥`Share`，因此同时加这两种锁的结果等效于`ShareRowExclusive`，即SIX。
  - `ShareUpdateExclusive`可以理解为`ShareUpdate` + `Exclusive`：`UPDATE`操作持有`RowExclusive`锁，而`ShareUpdate`指的是本锁与普通的增删改（持`RowExclusive`锁）相容，而`Exclusive`则表示自己和自己不相容。
- `Share`, `ShareRowUpdate`, `Exclusive` 这三种锁极少出现，基本可以无视。所以实际上主要用到的锁是：
  - 多版本两种：`AccessShare`, `AccessExclusive`
  - 意向锁两种：`RowShare`,`RowExclusive`
  - 自斥意向锁一种：`ShareUpdateExclusive`



## 显式加锁

通常表级锁会在相应命令执行中自动获取，但也可以手动显式获取。使用LOCK命令加锁的方式：

```sql
LOCK [ TABLE ] [ ONLY ] name [ * ] [, ...] [ IN lockmode MODE ] [ NOWAIT ]
```

- 显式锁表必须在事务中进行，在事务外锁表会报错。
- 锁定视图时，视图定义中所有出现的表都会被锁定。
- 使用表继承时，默认父表和所有后代表都会加锁，指定`ONLY`选项则继承于该表的子表不会自动加锁。
- 锁表或者锁视图需要对应的权限，例如`AccessShare`锁需要`SELECT`权限。
- 默认获取的锁模式为`AccessExclusive`，即最强的锁。
- `LOCK TABLE`只能获取表锁，默认会等待冲突的锁被释放，指定`NOWAIT`选项时，如果命令不能立刻获得锁就会中止并报错。
- 命令一旦获取到锁， 会被在当前事务中一直持有。没有`UNLOCK TABLE`命令，锁总是在事务结束时释放。

### 例子：数据迁移

举个例子，以迁移数据为例，假设希望将某张表的数据迁移到另一个实例中。并保证在此期间旧表上的数据在迁移期间不发生变化，那么我们可以做的就是在复制数据前在表上显式加锁，并在复制结束，应用开始写入新表后释放。应用仍然可以从旧表上读取数据，但不允许写入。那么根据锁冲突矩阵，允许只读查询的锁要弱于`AccessExclusive`，阻止写入的锁不能弱于`ShareRowExclusive`，因此可以选择`ShareRowExclusive`或`Exclusive锁`。因为拒绝写入意味着锁定没有任何意义，所以这里选择更强的`Exclusive`锁。

```sql
BEGIN;
LOCK TABLE tbl IN EXCLUSIVE MODE;
-- DO Something
COMMIT
```









## 锁的查询

PostgreSQL提供了一个系统视图[`pg_locks`](http://www.postgres.cn/docs/11/view-pg-locks.html)，包含了当前活动进程持锁的信息。可以锁定的对象包括：关系，页面，元组，事务标识（虚拟的或真实的），其他数据库对象（带有OID）。

```sql
CREATE TABLE pg_locks
(
    -- 锁针对的客体对象
    locktype           text, -- 锁类型：关系，页面，元组，事务ID，对象等
    database           oid,  -- 数据库OID
    relation           oid,  -- 关系OID
    page               integer, -- 关系内页号
    tuple              smallint, -- 页内元组号
    virtualxid         text,     -- 虚拟事务ID
    transactionid      xid,      -- 事务ID
    classid            oid,      -- 锁对象所属系统目录表本身的OID
    objid              oid,      -- 系统目录内的对象的OID
    objsubid           smallint, -- 列号
  
    -- 持有|等待锁的主体
    virtualtransaction text,     -- 持锁|等待锁的虚拟事务ID
    pid                integer,  -- 持锁|等待锁的进程PID
    mode               text,     -- 锁模式
    granted            boolean,  -- t已获取，f等待中
    fastpath           boolean   -- t通过fastpath获取
);
```

| 名称                 | 类型       | 描述                                                         |
| -------------------- | ---------- | ------------------------------------------------------------ |
| `locktype`           | `text`     | 可锁对象的类型： `relation`， `extend`， `page`， `tuple`， `transactionid`， `virtualxid`， `object`， `userlock`或`advisory` |
| `database`           | `oid`      | 若锁目标为数据库（或下层对象），则为数据库OID，并引用`pg_database.oid`，共享对象为0，否则为空 |
| `relation`           | `oid`      | 若锁目标为关系（或下层对象），则为关系OID，并引用`pg_class.oid`，否则为空 |
| `page`               | `integer`  | 若锁目标为页面（或下层对象），则为页面号，否则为空           |
| `tuple`              | `smallint` | 若锁目标为元组，则为页内元组号，否则为空                     |
| `virtualxid`         | `text`     | 若锁目标为虚拟事务，则为虚拟事务ID，否则为空                 |
| `transactionid`      | `xid`      | 若锁目标为事务，则为事务ID，否则为空                         |
| `classid`            | `oid`      | 若目标为数据库对象，则为该对象相应**系统目录**的OID，并引用`pg_class.oid`，否则为空。 |
| `objid`              | `oid`      | 锁目标在其系统目录中的OID，如目标不是普通数据库对象则为空    |
| `objsubid`           | `smallint` | 锁的目标列号（`classid`和`objid`指向表本身），若目标是某种其他普通数据库对象则此列为0，如果目标不是一个普通数据库对象则此列为空。 |
| `virtualtransaction` | `text`     | 持有或等待这个锁的虚拟ID                                     |
| `pid`                | `integer`  | 持有或等待这个锁的服务器进程ID，如果此锁被一个预备事务所持有则为空 |
| `mode`               | `text`     | 持有或者等待锁的模式                                         |
| `granted`            | `boolean`  | 为真表示已经获得的锁，为假表示还在等待的锁                   |
| `fastpath`           | `boolean`  | 为真表示锁是通过fastpath获取的                               |

#### 样例数据

![](../img/pg-lock-sample.png)

这个视图需要一些额外的知识才能解读。

* 该视图是**数据库集簇**范围的视图，而非仅限于单个数据库，即可以看见其他数据库中的锁。
* 一个进程在一个时间点只能等待至多一个锁，等待锁用`granted=f`表示，等待进程会休眠至其他锁被释放，或者系统检测到死锁。
* 每个事务都有一个虚拟事务标识`virtualtransaction`（以下简称`vxid`），修改数据库状态（或者显式调用`txid_current`获取）的事务才会被分配一个真实的事务标识`transactionid`（简称`txid`），**`vxid|txid`本身也是可以锁定的对象**。
* 每个事务都会持有自己`vxid`上的`Exclusive`锁，如果有`txid`，也会**同时**持有其上的`Exclusive`锁（即同时持有`txid`和`vxid`上的排它锁）。因此当一个事务需要等待另一个事务时，它会尝试获取另一个事务`txid|vxid`上的共享锁，因而只有当目标事务结束（自动释放自己事务标识上的`Exclusive`锁）时，等待事务才会被唤醒。
* `pg_locks`视图通常并不会直接显示**行级锁**信息，因为这些信息存储在磁盘磁盘上（），如果真的有进程在等待行锁，显示的形式通常是一个事务等待另一个事务，而不是等待某个具体的行锁。
* 咨询锁本质上的锁对象客体是一个数据库范畴内的BIGINT，`classid`里包含了该整数的高32bit，`objid`里包含有低32bit，`objsubid`里则说明了咨询锁的类型，单一Bigint则取值为`1`，两个int32则取值为`2`。
* 本视图并不一定能保证提供一个一致的快照，因为所有`fastpath=true`的锁信息是从每个后端进程收集而来的，而`fastpath=false`的锁是从常规锁管理器中获取的，同时谓词锁管理器中的数据也是单独获取的，因此这几种来源的数据之间可能并不一致。
* 频繁访问本视图会对数据库系统性能产生影响，因为要对锁管理器加锁获取一致性快照。

> **虚拟事务**
>
> 一个后端进程在整个生命周期中的每一个事务都会有一个自己的**虚拟事务ID**。
>
> PG中事务号是有限的（32-bit整型），会循环使用。为了节约事务号，PG只会为**实际修改数据库状态的事务**分配真实事务ID，而只读事务就不分配了，用虚拟事务ID凑合一下。`txid`是事务标识，全局共享，而`vxid`是虚拟事务标识，在**短期**内可以保证全局唯一性。因为`vxid`由两部分组成：`BackendID`与`LocalTransactionId`，前者是后端进程的标识符（本进程在内存中进程数组中的序号），后者是一个递增的事务计数器。因此两者组合即可获得一个暂时唯一的虚拟事务标识（之所以是暂时是因为这里的后端ID是有可能重复的）
>
> ```c
> typedef struct {
> 	BackendId	backendId;		/* 后端ID，初始化时确定，其实是后端进程数组内索引号 */
> 	LocalTransactionId localTransactionId;	/* 后端内本地使用的命令标ID，类似自增计数器 */
> } VirtualTransactionId;
> ```







## 应用

### 常见操作的冲突关系

- `SELECT`与`UPDATE|DELETE|INSERT`不会相互阻塞，即使访问的是同一行。
- `I|U|D`写入操作与`I|U|D`写入操作在表层面不会互斥，会在具体的行上通过`RowExclusive`锁实现。
- `SELECT FOR UPDATE`锁定操作与`I|U|D`写入在表层级也不会互斥，仍然是通过具体元组上的行锁实现。
- 并发`VACUUM`，并发创建索引等操作不会阻塞读写，但它们是自斥的，即同一时刻只会有一个（所以同时在一个表上执行两个`CREATE INDEX CONCURRENTLY`是没有意义的，不要被名字骗了）
- 普通的索引创建`CREATE INDEX`，不带`CONCURRENTLY`会阻塞增删改，但不会阻塞查，很少用到。
- 任何对于触发器的操作，或者约束类的操作，都会阻止增删改，但不会阻塞只读查询以及锁定。
- 冷门的命令`REFRESH MATERIALIZED VIEW CONCURRENTLY`允许`SELECT`和锁定。
- 大多数很硬的变更：`VACUUM FULL`, `DROP TABLE`, `TRUNCATE`, `ALTER TABLE`的大多数形式都会阻塞一切读取。

注意，锁虽有强弱之分，但冲突关系是对等的。一个持有`AccessShare`锁的`SELECT`会阻止后续的`DROP TABLE`获得`AccessExclusive`锁。后面的命令会进入锁队列中。

### 锁队列

PG中每个锁上都会有一个锁队列。如果事务A占有一个排他锁，那么事务B在尝试获取其上的锁时就会在其锁队列中等待。如果这时候事务C同样要获取该锁，那么它不仅要和事务A进行冲突检测，也要和B进行冲突检测，以及队列中其他的事务。这意味着当用户尝试获取一个很强的锁而未得等待时，已经会阻止后续新锁的获取。一个具体的例子是加列：

```sql
ALTER TABLE tbl ADD COLUMN mtime TIMESTAMP;
```

即使这是一个不带默认值的加列操作（不会重写整个表，因而很快），但本命令需要表上的`AccessExclusive`锁，如果这张表上面已经有不少查询，那么这个命令可能会等待相当一段时间。因为它需要等待其他查询结束并释放掉锁后才能执行。相应地，因为这条命令已经在等待队列中，后续的查询都会被它所阻塞。因此，当执行此类命令时的一个最佳实践是在此类命令前修改`lock_timeout`，从而避免雪崩。

```sql
SET lock_timeout TO '1s';
ALTER TABLE tbl ADD COLUMN mtime TIMESTAMP;
```

这个设计的好处是，命令不会饿死：不会出现源源不断的短小只读查询无限阻塞住一个排他操作。

### 加锁原则

* 够用即可：使用满足条件的锁中最弱的锁模式
* 越快越好：如果可能，可以用（长时间的弱锁+短时间的强锁）替换长时间的强锁
* 递增获取：遵循2PL原则申请锁；越晚使用激进锁策略越好；在真正需要时再获取。
* 相同顺序：获取锁尽量以一致的顺序获取，从而减小死锁的几率



### 最小化锁阻塞时长

除了手工锁定之外，很多常见的操作都会"锁表"，最常见的莫过于添加新字段与添加新约束。这两种操作都会获取表上的`AccessExclusive`锁以阻止一切并发访问。当DBA需要在线维护数据库时应当最小化持锁的时间。

例如，为表添加新字段的`ALTER TABLE ADD COLUMN`子句，根据新列是否提供易变默认值，会重写整个表。

```sql
ALTER TABLE tbl ADD COLUMN mtime TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
```

如果只是个小表，业务负载也不大，那么也许可以直接这么干。但如果是很大的表，以及很高的负载，那么阻塞的时间就会很可观。在这段时间里，命令都会持有表上的`AccessExclusive`锁阻塞一切访问。

可以通过先加一个空列，再慢慢更新的方式来最小化锁等待时间：

```sql
ALTER TABLE tbl ADD COLUMN mtime TIMESTAMP;
UPDATE tbl SET mtime = CURRENT_TIMESTAMP; -- 可以分批进行
```

这样，第一条加列操作的锁阻塞时间就会非常短，而后面的更新（重写）操作就可以以不阻塞读写的形式慢慢进行，最小化锁阻塞。

同理，当想要为表添加新的约束时（例如新的主键），也可以采用这种方式：

```sql
CREATE UNIQUE INDEX CONCURRENTLY tbl_pk ON tbl(id); -- 很慢，但不阻塞读写
ALTER TABLE tbl ADD CONSTRAINT tbl_pk PRIMARY KEY USING INDEX tbl_pk;  -- 阻塞读写，但很快
```

替代单纯的

```sql
ALTER TABLE tbl ADD PRIMARY KEY (id); 
```



