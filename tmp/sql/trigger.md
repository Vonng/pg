# PostgreSQL的触发器

* 触发器行为概述
* 触发器的分类
* 触发器的功能
* 触发器的种类
* 触发器的触发
* 触发器的创建
* 触发器的修改
* 触发器的查询
* 触发器的性能



## 触发器概述

触发器行为概述：[英文](https://www.postgresql.org/docs/11/trigger-definition.html)，[中文](http://www.postgres.cn/docs/11/trigger-definition.html)



## 触发器分类

触发时机：`BEFORE`, `AFTER`, `INSTEAD`

触发事件：`INSERT`, `UPDATE`, `DELETE`,`TRUNCATE`

触发范围：语句级，行级

内部创建：用于约束的触发器，用户定义的触发器

触发模式：`origin|local(O)`, `replica(R)`,`disable(D)`



## 触发器操作

触发器的操作通过SQL DDL语句进行，包括`CREATE|ALTER|DROP TRIGGER`，以及`ALTER TABLE ENABLE|DISABLE TRIGGER`进行。注意PostgreSQL内部的约束是通过触发器实现的。

#### 创建

[`CREATE TRIGGER`](https://www.postgresql.org/docs/current/sql-createtrigger.html) 可以用于创建触发器。

```sql
CREATE [ CONSTRAINT ] TRIGGER name { BEFORE | AFTER | INSTEAD OF } { event [ OR ... ] }
    ON table_name
    [ FROM referenced_table_name ]
    [ NOT DEFERRABLE | [ DEFERRABLE ] [ INITIALLY IMMEDIATE | INITIALLY DEFERRED ] ]
    [ REFERENCING { { OLD | NEW } TABLE [ AS ] transition_relation_name } [ ... ] ]
    [ FOR [ EACH ] { ROW | STATEMENT } ]
    [ WHEN ( condition ) ]
    EXECUTE { FUNCTION | PROCEDURE } function_name ( arguments )

event包括：
    INSERT
    UPDATE [ OF column_name [, ... ] ]
    DELETE
    TRUNCATE
```

#### 删除

[`DROP TRIGGER`](https://www.postgresql.org/docs/current/sql-droptrigger.html) 用于移除触发器。

```sql
DROP TRIGGER [ IF EXISTS ] name ON table_name [ CASCADE | RESTRICT ]
```

#### 修改

[`ALTER TRIGGER`](https://www.postgresql.org/docs/current/sql-altertrigger.html) 用于修改触发器定义，注意这里只能修改触发器名，以及其依赖的扩展。

```sql
ALTER TRIGGER name ON table_name RENAME TO new_name
ALTER TRIGGER name ON table_name DEPENDS ON EXTENSION extension_name
```

启用禁用触发器，修改触发模式是通过[`ALTER TABLE`](https://www.postgresql.org/docs/11/sql-altertable.html)的子句实现的。

[`ALTER TABLE`](https://www.postgresql.org/docs/11/sql-altertable.html)  包含了一系列触发器修改的子句：

```sql
ALTER TABLE tbl ENABLE TRIGGER tgname; -- 设置触发模式为O (本地连接写入触发，默认)
ALTER TABLE tbl ENABLE REPLICA TRIGGER tgname; -- 设置触发模式为R (复制连接写入触发)
ALTER TABLE tbl ENABLE ALWAYS TRIGGER tgname; -- 设置触发模式为A (总是触发)
ALTER TABLE tbl DISABLE TRIGGER tgname; -- 设置触发模式为D (禁用)
```

注意这里在`ENABLE`与`DISABLE`触发器时，可以指定用`USER`替换具体的触发器名称，这样可以只禁用用户显式创建的触发器，不会把系统用于维持约束的触发器也禁用了。

```sql
ALTER TABLE tbl_name DISABLE TRIGGER USER; -- 禁用所有用户定义的触发器，系统触发器不变  
ALTER TABLE tbl_name DISABLE TRIGGER ALL;  -- 禁用所有触发器
ALTER TABLE tbl_name ENABLE TRIGGER USER;  -- 启用所有用户定义的触发器
ALTER TABLE tbl_name ENABLE TRIGGER ALL;   -- 启用所有触发器
```

#### 查询

**获取表上的触发器**

最简单的方式当然是psql的`\d+ tablename`。但这种方式只会列出用户创建的触发器，不会列出与表上约束相关联的触发器。直接查询系统目录`pg_trigger`，并通过`tgrelid`用表名过滤

```sql
SELECT * FROM pg_trigger WHERE tgrelid = 'tbl_name'::RegClass;
```

**获取触发器定义**

`pg_get_triggerdef(trigger_oid oid)`函数可以给出触发器的定义。

该函数输入参数为触发器OID，返回创建触发器的SQL DDL语句。

```sql
SELECT pg_get_triggerdef(oid) FROM pg_trigger; -- WHERE xxx
```

#### 





## 触发器视图

[`pg_trigger`](https://www.postgresql.org/docs/current/catalog-pg-trigger.html) ([中文](http://www.postgres.cn/docs/11/catalog-pg-trigger.html)) 提供了系统中触发器的目录

| 名称             | 类型           | 引用                  | 描述                                               |
| ---------------- | -------------- | --------------------- | -------------------------------------------------- |
| `oid`            | `oid`          |                       | 触发器对象标识，系统隐藏列                         |
| `tgrelid`        | `oid`          | `pg_class.oid`        | 触发器所在的表 oid                                 |
| `tgname`         | `name`         |                       | 触发器名，表级命名空间内不重名                     |
| `tgfoid`         | `oid`          | `pg_proc.oid`         | 触发器所调用的函数                                 |
| `tgtype`         | `int2`         |                       | 触发器类型，触发条件，详见注释                     |
| `tgenabled`      | `char`         |                       | 触发模式，详见下。`O|R|A|D`                        |
| `tgisinternal`   | `bool`         |                       | 如果是内部用于约束的触发器则为真                   |
| `tgconstrrelid`  | `oid`          | `pg_class.oid`        | 参照完整性约束中被引用的表，无则为0                |
| `tgconstrindid`  | `oid`          | `pg_class.oid`        | 支持约束的相关索引，没有则为0                      |
| `tgconstraint`   | `oid`          | `pg_constraint.oid`   | 与触发器相关的**约束**对象                         |
| `tgdeferrable`   | `bool`         |                       | `DEFERRED`则为真                                   |
| `tginitdeferred` | `bool`         |                       | `INITIALLY DEFERRED`则为真                         |
| `tgnargs`        | `int2`         |                       | 传入触发器函数的字符串参数个数                     |
| `tgattr`         | `int2vector`   | `pg_attribute.attnum` | 如果是列级更新触发器，这里存储列号，否则为空数组。 |
| `tgargs`         | `bytea`        |                       | 传递给触发器的参数字符串，C风格零结尾字符串        |
| `tgqual`         | `pg_node_tree` |                       | 触发器`WHEN`条件的内部表示                         |
| `tgoldtable`     | `name`         |                       | `OLD TABLE`的`REFERENCING`列名称，无则为空         |
| `tgnewtable`     | `name`         |                       | `NEW TABLE`的`REFERENCING`列名称，无则为空         |

> #### 触发器类型
>
> 触发器类型`tgtype`包含了触发器触发条件相关信息：`BEFORE|AFTER|INSTEAD OF`, `INSERT|UPDATE|DELETE|TRUNCATE`
>
> ```c
> TRIGGER_TYPE_ROW         (1 << 0)  // [0] 0:语句级 	1:行级
> TRIGGER_TYPE_BEFORE      (1 << 1)  // [1] 0:AFTER 	1:BEFORE
> TRIGGER_TYPE_INSERT      (1 << 2)  // [2] 1: INSERT
> TRIGGER_TYPE_DELETE      (1 << 3)  // [3] 1: DELETE
> TRIGGER_TYPE_UPDATE      (1 << 4)  // [4] 1: UPDATE
> TRIGGER_TYPE_TRUNCATE    (1 << 5)  // [5] 1: TRUNCATE
> TRIGGER_TYPE_INSTEAD     (1 << 6)  // [6] 1: INSTEAD OF 
> ```
>
> #### 触发器模式
>
> 触发器`tgenabled`字段控制触发器的工作模式，参数[`session_replication_role`](http://www.postgres.cn/docs/11/runtime-config-client.html#GUC-SESSION-REPLICATION-ROLE) 可以用于配置触发器的触发模式。该参数可以在会话层级更改，可能的取值包括：`origin(default)`,`replica`,`local`。
>
>  `(D)isable`触发器永远不会被触发，`(A)lways`触发器在任何情况下触发， `(O)rigin`触发器会在`origin|local`模式触发（默认），而 `(R)eplica`触发器`replica`模式触发。R触发器主要用于逻辑复制，例如`pglogical`的复制连接就会将会话参数`session_replication_role`设置为`replica`，而R触发器只会在该连接进行的变更上触发。
>
> ```sql
> ALTER TABLE tbl ENABLE TRIGGER tgname; -- 设置触发模式为O (本地连接写入触发，默认)
> ALTER TABLE tbl ENABLE REPLICA TRIGGER tgname; -- 设置触发模式为R (复制连接写入触发)
> ALTER TABLE tbl ENABLE ALWAYS TRIGGER tgname; -- 设置触发模式为A (始终触发)
> ALTER TABLE tbl DISABLE TRIGGER tgname; -- 设置触发模式为D (禁用)
> ```

在`information_schema`中还有两个触发器相关的视图：`information_schema.triggers`, `information_schema.triggered_update_columns`，表过不提。



## 触发器FAQ

### 触发器可以建在哪些类型的表上？

普通表（分区表主表，分区表分区表，继承表父表，继承表子表），视图，外部表。

### 触发器的类型限制

* 视图上不允许建立`BEFORE`与`AFTER`触发器（不论是行级还是语句级）
* 视图上只能建立`INSTEAD OF`触发器，`INSERTEAD OF`触发器也只能建立在视图上，且只有行级，不存在语句级`INSTEAD OF`触发器。
* INSTEAD OF` 触发器只能定义在视图上，并且只能使用行级触发器，不能使用语句级触发器。

### 触发器与锁

在表上创建触发器会先尝试获取表级的`Share Row Exclusive Lock`。这种锁会阻止底层表的数据变更，且自斥。因此创建触发器会阻塞对表的写入。

### 触发器与COPY的关系

COPY只是消除了数据解析打包的开销，实际写入表中时仍然会触发触发器，就像INSERT一样。

