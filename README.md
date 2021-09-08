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
- [互联网之冬](post/industry/winter-of-the-internet.md)


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
- [PostGIS高效解决行政区划归属查询问题](app/adcode-geodecode.md)
- [5分钟用PgSQL实现推荐系统](app/pg-recsys.md)
- [新冠疫情数据大盘](http://demo.pigsty.cc/d/covid-overview)
- [基于Pigsty呈现NOAA ISD数据集](http://demo.pigsty.cc/d/isd-overview)
- 个人博客网站数据库设计
- 使用PG监控PG：元数据库设计
- 标签管理系统元数据库设计
- 实时用户画s像系统数据库设计
- PostGraphQL：使用自动生成的API解放生产力

### **功能实现**

- [IP归属地查询的高效实现](app/geoip.md)
- [PostgreSQL高级模糊查询](app/fuzzymatch.md)
- [UUID：性质、原理、与应用](app/uuid.md)
- [PostgreSQL CDC: 变更数据捕获](post/pg-cdc.md)
- [使用审计触发器自动记录数据变更](app/audit-change.md)
- [实现基于通知触发器的逻辑复制](app/notify-trigger-based-repl.md)
- 使用三维/四维点存储时空轨迹
- 连接池：连接数背后的问题
- QPS/TPS：一个容易误解的指标
- 自动化后端：PostGraphQL, PgRest, PostgRest横向对比
- postgres_fdw应用：管理远程数据库


### **SQL特性**

- [并发异常那些事](post/concurrent-control.md)
- [PostgreSQL中的锁](app/pg-lock.md)
- [PostgreSQL中的触发器](app/pg-trigger.md)
- [PostgreSQL中的LOCALE](app/pg-locale.md)
- [PostgreSQL特色：Excluded约束](app/sql-exclude.md)
- [PostgreSQL特色：Distinct On语法](app/sql-distinct-on.md)
- [PostgreSQL函数易变性分类](app/sql-func-volatility.md)
- [PostgreSQL 12新特性：JSON Path](app/jsonpath.md)
- [PostGIS：DE9IM 空间相交模型](app/gis-de9im.md)
- PostgreSQL中的时间与时区
- Sequence的方方面面
- 常见索引类型及其应用场景
- PostgreSQL中的JOIN
- 子查询还是CTE？
- LATERAL JOIN
- DISTINCT ON子句与除重
- 递归查询
- Advanced SQL
- Pl/PgSQL快速上手
- 函数的权限管理


### **语言驱动**

- [Go & PG：数据库使用教程](app/pg-go-database.md)
- PostgreSQL驱动横向评测：Go语言
- PostgreSQL Golang驱动介绍：pgx
- PostgreSQL Golang驱动介绍：go-pg
- PostgreSQL Python驱动介绍：psycopg2
- psycopg2的进阶包装，让Python访问Pg更敏捷。
- PostgreSQL Node.JS驱动介绍：node-postgres


### **工具组件**

- [使用Wireshark抓包分析PostgreSQL协议](tool/wireshark-capture.md)
- [psqlrc使用基础](admin/psql.md)
- [批量配置SSH免密登录](admin/ssh-add-key.md)
- [组合使用psql与bash](admin/psql-and-bash.md)
- [sysbench](tool/sysbench.md)
- [pgbouncer安装](tool/pgbouncer-install.md)
- [pgbouncer配置文件](tool/pgbouncer-config.md)
- [pgbouncer使用方法](tool/pgbouncer-usage.md)
- pgpool的应用方式
- 查看硬盘信息——smartctl
- 查看网卡信息——ethtool

----------------


## Administration / 监控管理

### **规约习惯**

- [PostgreSQL开发规约](post/pg-convention.md)
- PostgreSQL集群扩缩容规约
- PostgreSQL数据库模式变更规约
- [数据库集群管理概念与实体命名规范](admin/entity-and-naming.md)

### **监控系统**
- [Pigsty监控系统架构](mon/pigsty-overview.md)
- [Pigsty监控系统使用说明](mon/pigsty-introduction.md)
- [PostgreSQL的KPI](mon/pg-load.md)
- [监控PG中表的大小](mon/size.md)
- [监控WAL生成速率](mon/wal-rate.md)
- [关系膨胀：监控与处理](mon/bloat.md)
- [PG中表占用磁盘空间](mon/size.md)
- [使用pg_repack整理表与索引](tool/pg_repack.md)
- [监控表：空间，膨胀，年龄，IO](mon/table-bloat.md)
- [监控索引：空间，膨胀，重复，闲置](mon/index-bloat.md)
- [确保表没有访问](mon/table-have-access.md)


### **架构设计**

- [PostgreSQL安装部署](admin/install.md)
- [PostgreSQL日志配置](admin/logging.md)
- [PostgreSQL复制方案](admin/replication-plan.md)
- [PostgreSQL备份方案](admin/backup-plan.md)
- [PostgreSQL报警系统](admin/alert-overview.md)
- [PostgreSQL变更管理方案](admin/mange-change.md)
- [PostgreSQL目录设计](admin/directory-design.md)
- [PostgreSQL配置修改方式](admin/config.md)
- [PostgreSQL客户端认证](admin/hba-auth.md)
- [PostgreSQL角色权限](admin/privilege.md)
- [PostgreSQL监控系统]((mon/overview.md))

### **安装部署**

- [安装TimescaleDB](admin/install-timescale.md)
- [安装PipelineDB](admin/install-pipelinedb.md)
- [安装Citus]()
- [PgAdmin Server 安装](tool/pgadmin-install.md)
- [PgBackRest 中文文档](admin/pgbackrest.md)
- [PgBackRest2中文文档](tool/pgbackrest.md)
- QGIS安装与简单使用

### **升级迁移**
- PostgreSQL逻辑复制不停机迁移方案
- PostgreSQL原地大版本升级流程
- [飞行中换引擎：PostgreSQL不停机数据迁移](admin/migration-without-downtime.md)
- PostgreSQL 10.0 与先前版本的不兼容性统计
- 垂直拆分，分库分表：指导原则
- 水平拆分与分片：减数分裂方法

### **备份恢复**
- [PostgreSQL备份与恢复概览](admin/backup-overview.md)
- [PostgreSQL复制延迟问题](admin/replication-delay.md)
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

### [**故障档案**](admin/pit/)
- [故障档案：移走负载导致的性能恶化故障](admin/pit/download-failure.md)
- [pg_dump导致的血案](admin/pit/search_path.md)
- [PostgreSQL数据页损坏修复](admin/pit/page-corruption.md)
- [故障档案：事务ID回卷故障](admin/pit/xid-wrap-around.md)
- [故障档案：pg_repack导致的故障](admin/pit/pg_repack.md)
- [故障档案：从删库到跑路](admin/pit/drop-database.md)
- [Template0的清理与修复](admin/pit/vacuum-template0.md)
- [内存错误导致操作系统丢弃页面缓存](admin/pit/drop-cache.md)
- 磁盘写满故障
- 救火：杀查询的正确姿势
- 存疑事务：提交日志损坏问题分析与修复
- 客户端大量无超时查询堆积导致故障
- 慢查询堆积导致的雪崩，定位与排查
- 硬件故障导致的机器重启
- Docker同一数据目录启动两个实例导致数据损坏
- 级联复制的配置问题


--------------------

## Architecture / 内核架构

### **源码细节**
- [PostgresSQL变更数据捕获](src/logical-decoding.md)
- [PostgreSQL前后端协议概述](src/wire-protocol.md)
- [PostgreSQL的逻辑结构与物理结构](src/logical-arch.md)
- [PostgreSQL的事务隔离等级](src/isolation-level.md)
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
- [GIN索引关键词匹配的时间复杂度为什么是O(n2)](ker/gin.md)

### **架构设计**

### **扩展插件**

### **FDW**
- [FileFDW妙用无穷——从数据库读取系统信息](tool/file_fdw-intro.md)
- [RedisFDW Installation](tool/redis_fdw-install.md)
- [MongoFDW Installation](tool/mongo_fdw-install.md)
- IMPORT FOREIGN SCHEMA与远程元数据管理
- MongoFDW设计与实现
- HBase FDW设计与实现
- 基于Multicorn编写FDW


--------------------

## Gist / 笔记

> 用于解决某些特定问题的代码速查片段，临时笔记

### **工具速查**
- [查看系统任务 —— top](tool/unix-top.md)
- [查看内存使用 —— free](tool/unix-free.md)
- [查看虚拟内存使用 —— vmstat](tool/unix-vmstat.md)
- [查看IO —— iostat](tool/unix-iostat.md)


### **临时笔记**

- 逻辑复制常用命令速查
- 使用Githook实现远程网站部署
- 自动申请Let's Encrypt SSL证书
- [找出并清除表中重复的记录](http://blog.theodo.fr/2018/01/search-destroy-duplicate-rows-postgresql/)
- 为分区表添加索引
- 利用统计信息分批实现大表全表更新




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

