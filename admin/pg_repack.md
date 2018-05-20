# pg_repack用法

`pg_repack`是个很实用的工具，能够进行无锁的VACUUM FULL，CLUSTER等操作。



## 原理

### 对表Repack

1. 创建一张原始表的相应日志表。
2. 为原始表添加行触发器，在相应日志表中记录所有`INSERT`,`DELETE`,`UPDATE`操作。
3. 创建一张包含老表所有行的表。
4. 在新表上创建同样的索引
5. 将日志表中的增量变更应用到新表上
6. 使用系统目录切换表，相关索引，相关Toast表。

### 对索引单独Repack

1. 使用`CREATE INDEX CONCURRENTLY`在原表上创建新索引，保持与旧索引相同的定义。
2. 在数据目录中将新旧索引交换。
3. 删除旧索引。

注意，并发建立索引时，如果出现死锁或违背唯一约束，可能会失败，留下一个`INVALID`状态的索引。



## 安装

PostgreSQL官方yum源提供了pg_repack，直接通过yum安装即可：

```bash
yum install pg_repack10
```



## 使用

通常良好实践是：在业务低峰期估算表膨胀率，对膨胀比较厉害的表进行Repack。参阅膨胀监控一节。





## 注意事项

#### Repack之前

* Repack开始之前，最好取消掉所有正在进行了Vacuum任务。
* 对索引做Repack之前，r

#### 事故现场清理

临时表与临时索引建立在与原表/索引同一个schema内，

* 临时表的名称为：`${schema_name}.table_${table_oid}`
* 临时索引的名称为：`${schema_name}.index_${table_oid}}`

如果出现异常的情况，有可能留下未清理的垃圾，也许需要手工清理。





## 官方信息

- Homepage: <http://reorg.github.com/pg_repack>
- Download: <http://pgxn.org/dist/pg_repack/>
- Development: <https://github.com/reorg/pg_repack>
- Bug Report: <https://github.com/reorg/pg_repack/issues>
- Mailing List: <http://pgfoundry.org/mailman/listinfo/reorg-general>

[pg_repack](http://reorg.github.com/pg_repack) is a PostgreSQL extension which lets you remove bloat from tables and indexes, and optionally restore the physical order of clustered indexes. Unlike [CLUSTER](http://www.postgresql.org/docs/current/static/sql-cluster.html) and [VACUUM FULL](http://www.postgresql.org/docs/current/static/sql-vacuum.html) it works online, without holding an exclusive lock on the processed tables during processing. pg_repack is efficient to boot, with performance comparable to using CLUSTER directly.

Please check the documentation (in the `doc` directory or [online](http://reorg.github.com/pg_repack)) for installation and usage instructions.

## 