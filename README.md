# PG

> *Postgres is good* —— [Vonng](https://vonng.com/)
>
> 关于PostgreSQL[应用开发](#application-应用开发)，[监控管理](#administration-监控管理) 与 [内核架构](#architecture-内核架构) 的 [文章](#post-文章)与 [笔记](#gist-笔记).
>
> [Github Repo](https://github.com/Vonng/pg) | [Github Pages](https://vonng.github.io/pg) | [Pigsty](https://pigsty.cc) | [官方站点](https://pg.vonng.com) | [测试沙箱](test/) | [关于作者](https://vonng.com/en/) 


--------------------

## Post / 文章

### **PostgreSQL**
- [PostgreSQL好处都有啥？](post/pg-is-good.md)
- [为什么说PostgreSQL前途无量？](post/pg-is-great.md)
- [开箱即用的PostgreSQL发行版](post/pigsty-intro.md)  —— [Pigsty](https://pigsty.cc)
- [PostgreSQL开发规约](post/pg-convention.md)


### [**行业认知**](post/industry/)
- [认识互联网](post/industry/understand-the-internet.md)
- [互联网之殇](post/industry/obstacle-of-internet.md)


### **技术文章**
- [为什么要学数据库原理和设计？](post/why-learn-database.md)
- [将PostgreSQL容器化是个好主意吗？](post/postgres-in-docker.md) | [EN](post/postgres-in-docker-en.md)
- [理解字符编码](post/character-encoding.md)
- [理解时间](post/reason-about-time.md)

### **概念辨析**
- [区块链与分布式数据库](post/blockchain-and-database.md)
- [一致性：一个过载的术语](post/consistency-linearizability.md)
- [架构演化：成熟度模型](post/maturity-model.md)



--------------------

## Application / 应用开发

### **应用案例**

- [KNN问题极致优化：以找出最近餐馆为例](app/knn-optimize.md)
- [PostGIS高效解决行政区划归属查询问题](app/adcode.md)
- [5分钟用PgSQL实现推荐系统](app/recsys-itemcf.md)
- [新冠疫情数据大盘](http://demo.pigsty.cc/d/covid-overview)
- [基于Pigsty呈现NOAA ISD数据集](http://demo.pigsty.cc/d/isd-overview)

### **功能实现**

- [IP归属地查询的高效实现](app/geoip.md)
- [PostgreSQL高级模糊查询](app/fuzzymatch.md)
- [UUID：性质、原理、与应用](app/uuid.md)
- [PostgreSQL CDC: 变更数据捕获](app/cdc.md)
- [使用审计触发器自动记录数据变更](app/trigger-audit.md)
- [实现基于通知触发器的逻辑复制](app/trigger-notify.md)


### **SQL特性**

- [并发异常那些事](post/concurrent-control.md)
- [PostgreSQL中的锁](app/sql-lock.md)
- [PostgreSQL中的触发器](app/sql-trigger.md)
- [PostgreSQL中的序列号](app/sql-sequence.md)  
- [PostgreSQL中的LOCALE](app/sql-locale.md)
- [PostgreSQL复制标识详解](app/sql-replica-identity.md)
- [PostgreSQL特色：Excluded约束](app/sql-exclude.md)
- [PostgreSQL特色：Distinct On语法](app/sql-distinct-on.md)
- [PostgreSQL函数易变性分类](app/sql-func-volatility.md)
- [PostgreSQL 12新特性：JSON Path](app/sql-jsonpath.md)
- [PostGIS：DE9IM 空间相交模型](app/gis-de9im.md)


### **语言驱动**

- [Go & PG：数据库使用教程](app/pg-go-database.md)
- PostgreSQL驱动横向评测：Go语言
- PostgreSQL Golang驱动介绍：pgx
- PostgreSQL Golang驱动介绍：go-pg
- PostgreSQL Python驱动介绍：psycopg2
- psycopg2的进阶包装，让Python访问Pg更敏捷。
- PostgreSQL Node.JS驱动介绍：node-postgres


----------------


## Administration / 监控管理

### **规约习惯**

- [PostgreSQL开发规约](post/pg-convention.md)
- [PostgreSQL集群扩缩容规约](admin/rule-scaling.md)
- [数据库集群管理概念与实体命名规范](admin/entity-and-naming.md)


### **日常操作**

- [修改PostgreSQL配置](admin/alter-config.md)
- [PostgreSQL 权限管理](admin/privilege.md)


### **监控系统**
- [Pigsty监控系统架构](mon/pigsty-overview.md)
- [Pigsty监控系统使用说明](https://pigsty.cc/#/zh-cn/c-arch)
- [PostgreSQL的KPI](mon/pg-load.md)
- [监控PG中表的大小](mon/size.md)
- [监控WAL生成速率](mon/wal-rate.md)
- [关系膨胀：监控与处理](mon/bloat.md)
- [PG中表占用磁盘空间](mon/size.md)
- [使用pg_repack整理表与索引](tool/pg_repack.md)
- [监控表：空间，膨胀，年龄，IO](mon/table-bloat.md)
- [监控索引：空间，膨胀，重复，闲置](mon/index-bloat.md)
- [确保表没有访问](mon/table-have-access.md)

### **升级迁移**
- PostgreSQL逻辑复制不停机迁移方案
- PostgreSQL原地大版本升级流程
- PostgreSQL 10.0 与先前版本的不兼容性统计
- 垂直拆分，分库分表：指导原则
- 水平拆分与分片：减数分裂方法
- [业务层逻辑复制实现不停机切换（Before 10）](admin/migration-without-downtime.md)

### **备份恢复**
- [PostgreSQL备份与恢复概览](admin/backup-overview.md)
- [PostgreSQL复制延迟问题](admin/replication-delay.md)
- [Postgres逻辑复制详解](admin/logical-replication.md)
- 日志传输副本：WAL段复制
- 备份：机制、流程、问题、方法
- 复制拓扑设计：同步、异步、法定人数
- 逻辑备份：pg_dump
- PITR生产实践

### **运维调优**
- [PostgreSQL内存相关参数调谐](admin/tune-memory.md)
- [PostgreSQL检查点相关参数调谐](admin/tune-checkpoint.md)
- [PostgreSQL自动清理相关参数调谐](admin/tune-autovacuum.md)
- [操作系统内核参数调优](admin/tune-kernel.md)
- 维护表：VACUUM配置、问题、原理与实践。
- 重建索引：细节与注意事项
- ErrorTracking系统设计概览

### [**故障档案**](pit/)
- [故障档案：移走负载导致的性能恶化故障](pit/download-failure.md)
- [pg_dump导致的血案](pit/search_path.md)
- [PostgreSQL数据页损坏修复](pit/page-corruption.md)
- [故障档案：事务ID回卷故障](pit/xid-wrap-around.md)
- [故障档案：pg_repack导致的故障](pit/pg_repack.md)
- [故障档案：从删库到跑路](pit/drop-database.md)
- [Template0的清理与修复](pit/vacuum-template0.md)
- [内存错误导致操作系统丢弃页面缓存](pit/drop-cache.md)
- 磁盘写满故障
- 救火：杀查询的正确姿势
- 存疑事务：提交日志损坏问题分析与修复
- 客户端大量无超时查询堆积导致故障
- 慢查询堆积导致的雪崩，定位与排查
- 硬件故障导致的机器重启
- Docker同一数据目录启动两个实例导致数据损坏
- 级联复制的配置问题
- NOFILE配置导致文件描述符不够用
- NTP时间漂移导致的故障


--------------------

## Architecture / 内核架构

### **源码细节**
- [PostgresSQL变更数据捕获](arch/logical-decoding.md)
- [PostgreSQL前后端协议概述](arch/wire-protocol.md)
- [PostgreSQL的逻辑结构与物理结构](arch/logical-arch.md)
- [PostgreSQL的事务隔离等级](arch/isolation-level.md)
- 并发创建索引的实现方式（CREATE INDEX CONCURRENTLY）
- GIN索引的实现原理
- B树索引的原理与实现细节
- 查询处理原理
- JOIN类型及其内部实现
- VACUUM原理
- WAL：PostgreSQL WAL与检查点
- 流复制原理与实现细节
- 二阶段提交：原理与实践
- R树原理与实现细节
- PostgreSQL数据页结构
- FDW的结构与编写
- SSD Internal
- [GIN索引关键词匹配的时间复杂度为什么是O(n2)](arch/gin.md)


### **FDW**

- [FileFDW妙用无穷——从数据库读取系统信息](arch/file_fdw-intro.md)
- [RedisFDW Installation](arch/install-redis-fdw.md)
- [MongoFDW Installation](arch/install-mongo-fdw.md)



[MongoFDW安装](install-mongo-fdw.md)

[](install-pipelinedb.md)
[](install-postgis.md)
[](install-redis-fdw.md)


--------------------

## Gist / 笔记

> 用于解决某些特定问题的代码速查片段，临时笔记

### **PGSQL工具**

- [`psql`命令速查] 
- [`pg_dump`命令速查]
- [`pg_basebackup`命令速查]
- psqlrc 配置基础
- 性能压测：`pgbench`
- [性能压测：`sysbench`]()
- [组合使用psql与bash](gist/psql-and-bash.md)
- [pgbouncer安装](tool/pgbouncer-install.md)
- [pgbouncer配置文件](tool/pgbouncer-config.md)
- [pgbouncer使用方法](tool/pgbouncer-usage.md)
- [PgAdmin安装](gist/install-pgadmin.md)

### **操作系统工具**

- [查看系统任务 —— top](gist/os-top.md)
- [查看内存使用 —— free](gist/os-free.md)
- [查看虚拟内存使用 —— vmstat](gist/os-vmstat.md)
- [查看IO —— iostat](gist/os-iostat.md)
- [测试磁盘性能 —— `fio`](gist/os-fio.md)
- [批量配置SSH免密登录](gist/os-ssh-key.md)
- 查看硬盘信息 —— `smartctl`
- 查看网卡信息 —— `ethtool`
- 查看NUMA信息 —— `numactl`
- 查看时间信息 —— `timedatectl`
- 调整优化方案 —— `tuned-adm`



### **临时笔记**

- 逻辑复制常用命令速查
- 使用Githook实现远程网站部署
- 自动申请Let's Encrypt SSL证书
- [找出并清除表中重复的记录](http://blog.theodo.fr/2018/01/search-destroy-duplicate-rows-postgresql/)
- 为分区表添加索引
- 利用统计信息分批实现大表全表更新
- [如何在LB后面获取客户端真实IP](gist/toa-get-client-ip-behind-lb.md)

### **工具组件**

- [使用Wireshark抓包分析PostgreSQL协议](tool/wireshark-capture.md)

--------------------

## Reference / 参考

- [PostgreSQL Documentation](https://www.postgresql.org/docs/current/index.html): [Current](https://www.postgresql.org/docs/current/index.html) | [14](https://www.postgresql.org/docs/14/index.html) | [13](https://www.postgresql.org/docs/13/index.html) | [12](https://www.postgresql.org/docs/12/index.html) | [11](https://www.postgresql.org/docs/11/index.html) | [10](https://www.postgresql.org/docs/10/index.html) | [9.6](https://www.postgresql.org/docs/9.6/index.html) | [9.5](https://www.postgresql.org/docs/9.5/index.html) | [9.4](https://www.postgresql.org/docs/9.4/index.html)
- [PostgreSQL 中文文档](http://www.postgres.cn/docs/13/index.html): [13](http://www.postgres.cn/docs/13/index.html) | [12](http://www.postgres.cn/docs/12/index.html) | [11](http://www.postgres.cn/docs/11/index.html) | [10](http://www.postgres.cn/docs/10/index.html)
- [PostgreSQL Commit Fest](https://commitfest.postgresql.org)
- [PostGIS sDocumentation](https://postgis.net/docs/): [v3.1](https://postgis.net/docs/manual-3.1/)
- [Citus Documentation](http://docs.citusdata.com/en/latest/): [v10.1](http://docs.citusdata.com/en/v10.1/) 
- [TimescaleDB Documentation](https://docs.timescale.com/latest/main)
- [PipelineDB Documentation](http://docs.pipelinedb.com)
- [Pgbouncer Documentation](https://pgbouncer.github.io/config.html)
- [PG-INTERNAL](http://www.interdb.jp/pg/) | [CN](https://pg-internal.vonng.com/#/) | [DDIA](https://ddia.vonng.com/#/)

