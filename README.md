# PG

> PostgreSQL是个好数据库
>
> —— Vonng





## 文章

- [x] [计算机系为什么要学数据库原理和设计？](misc/why-learn-database.md)
- [x] [PG好处都有啥？](misc/pg-yoxi.md)
- [x] [PostgreSQL开发规约](misc/pg-convention.md)
- [x] [并发异常那些事](src/concurrent-control.md)
- [x] [容器中的数据库是一个好主意吗？](misc/postgres-in-docker.md) / [Docker vs Bare Metal](misc/docker-vs-bare-metal.md)
- [x] [理解时间](sql/reason-about-time.md)
- [x] [区块链与分布式数据库](misc/blockchain-and-database.md)
- [x] [一致性：一个过载的术语](misc/consistency-linearizability.md)
- [x] [架构演化：成熟度模型](misc/maturity-model.md)
- [x] [杂文](misc/industry/README.md)



## 环境

PostgreSQL虚拟机测试集群搭建：[test](test/README.md)

常用PostgreSQL运维脚本：[test/bin](test/bin/)



## 管理

**管理方案**

- [x] [PostgreSQL安装部署](admin/install.md)
- [x] [PostgreSQL日志配置](admin/logging.md)
- [x] [PostgreSQL复制方案](admin/replication-plan.md)
- [x] [PostgreSQL备份方案](admin/backup-plan.md)
- [x] [PostgreSQL监控系统]((mon/overview.md))
- [x] [PostgreSQL报警系统](admin/alert-overview.md)
- [x] [PostgreSQL变更管理方案](admin/mange-change.md)
- [x] [PostgreSQL目录设计](admin/directory-design.md)

**备份与复制**

- [ ] [PostgreSQL备份与恢复概览](admin/backup-overview.md)
- [ ] [PostgreSQL复制延迟问题](admin/replication-delay.md)
- [ ] 日志传输副本：WAL段复制
- [ ] 复制拓扑设计：同步、异步、法定人数
- [ ] 逻辑复制：发布与订阅
- [ ] 故障切换，权衡，比可用性更重要的是完整性

**运维调优**
- [ ] 维护表：VACUUM配置、问题、原理与实践。
- [ ] 重建索引：细节与注意事项
- [ ] 备份：机制、流程、问题、方法。
- [ ] 逻辑备份：pg_dump
- [ ] PITR生产实践
- [ ] [PostgreSQL内存相关参数调谐](admin/tune-memory.md)
- [ ] [PostgreSQL检查点相关参数调谐](admin/tune-checkpoint.md)
- [ ] [PostgreSQL自动清理相关参数调谐](admin/tune-autovacuum.md)
- [ ] [操作系统内核参数调优](admin/tune-kernel.md)
- [ ] ErrorTracking系统设计概览

**配置**

- [ ] [PostgreSQL配置修改方式](admin/config.md)
- [ ] [PostgreSQL客户端认证](admin/hba-auth.md)
- [ ] [PostgreSQL角色权限](admin/privilege.md)

**升级迁移**
- [ ] [飞行中换引擎：PostgreSQL不停机数据迁移](admin/migration-without-downtime.md)
- [ ] 跨大版本升级PostgreSQL，10与先前版本的不兼容性统计
  

**扩展性**
- [ ] 垂直拆分，分库分表
- [ ] 水平拆分与分片
- [ ] 如何管理几百个PostgreSQL实例
  

**监控**

- [x] [监控PG中表的大小](mon/size.md)
- [x] [监控WAL生成速率](mon/wal-rate.md)
- [x] [关系膨胀：监控与处理](mon/bloat.md)
- [x] [PG中表占用磁盘空间](mon/size.md)
- [x] [使用pg_repack整理表与索引](tools/pg_repack.md)
- [ ] [监控表：空间，膨胀，年龄，IO](mon/table-bloat.md)
- [ ] [监控索引：空间，膨胀，重复，闲置](mon/index-bloat.md)
- [ ] 静态监控，配置项与角色
- [ ] 轻重缓急，快慢分离
- [ ] 操作系统监控
- [ ] 监控CPU使用
- [ ] 监控磁盘网络IO
- [ ] 监控数据库基本指标
- [ ] 监控死锁
- [ ] 监控连接
- [ ] 监控活动
- [ ] 监控复制延迟
- [ ] 系统级别监控
- [ ] 监控函数：调用量，时间
- [ ] 监控连接池：QPS，延迟，排队，连接
- [ ] 监控自动清理与检查点
- [ ] 系统视图详解
- [ ] 系统水位测量、经验值
- [ ] [判断表已经没有访问的方法](mon/table-have-access.md)

[**故障**](pit/)

- [x] [故障档案：移走负载导致的性能恶化故障](pit/download-failure.md)
- [x] [pg_dump导致的血案](pit/search_path.md)
- [x] [PostgreSQL数据页损坏修复](pit/page-corruption.md)
- [x] [故障档案：事务ID回卷故障](pit/xid-wrap-around.md)
- [x] [故障档案：pg_repack导致的故障](pit/pg_repack.md)
- [x] [故障档案：从删库到跑路](pit/drop-database.md)
- [x] [Template0的清理与修复](pit/vacuum-template0.md)
- [ ] [内存错误导致操作系统丢弃页面缓存](pit/drop-cache.md)
- [ ] 磁盘写满故障
- [ ] 救火：杀查询的正确姿势
- [ ] 存疑事务：提交日志损坏问题分析与修复
- [ ] 客户端大量无超时查询堆积导致故障
- [ ] 慢查询堆积导致的雪崩，定位与排查
- [ ] 硬件故障导致的机器重启
- [ ] Docker同一数据目录启动两个实例导致数据损坏
- [ ] 级联复制的配置问题




## 开发

**案例**

- [x] [KNN问题极致优化：以找出最近餐馆为例](dev/knn.md) 
- [x] [PostGIS高效解决行政区划归属查询问题](dev/adcode-geodecode.md)
- [x] [使用PostgreSQL实现简易推荐系统](dev/pg-recsys.md)
- [x] [使用PostgreSQL实现IP地理位置查询](dev/geoip.md)
- [x] [使用审计触发器自动记录数据变更](dev/audit-change.md)
- [x] [实现基于通知触发器的逻辑复制](dev/notify-trigger-based-repl.md)
- [ ] 标签管理系统元数据库设计
- [ ] 实时用户画像系统数据库设计
- [ ] 博客数据库设计
- [ ] 使用Pg监控Pg：元数据库设计
- [ ] 连接池：连接数背后的问题
- [ ] 选择合适的全局唯一ID生成方式
- [ ] QPS/TPS：一个容易误解的指标
- [ ] 使用三维/四维点存储时空轨迹
- [ ] 自动化后端：PostGraphQL, PgRest, PostgRest横向对比
- [ ] PostGraphQL：解放前后端生产力
- [ ] postgres_fdw应用：管理远程数据库

**SQL**

- [ ] PostgreSQL数据类型 —— 数值类型
- [ ] PostgreSQL数据类型 —— 文本类型
- [ ] PostgreSQL数据类型 —— 文本字面值
- [ ] PostgreSQL数据类型 —— 网络类型
- [x] [PostgreSQL中的触发器](sql/trigger.md)
- [x] [PostgreSQL中的锁](sql/lock.md)
- [ ] PostgreSQL的LOCALE与本地化
- [ ] PostgreSQL 12 JSON
- [ ] PostgreSQL中的时间与时区
- [ ] Sequence的方方面面
- [ ] 常见索引类型及其应用场景
- [ ] PostgreSQL中的JOIN
- [ ] 
- [ ] 子查询还是CTE？
- [ ] LATERAL JOIN
- [ ] DISTINCT ON子句与除重
- [ ] 递归查询
- [ ] Advanced SQL
- [ ] [找出并清除重复的记录](http://blog.theodo.fr/2018/01/search-destroy-duplicate-rows-postgresql/)
- [ ] Pl/PgSQL快速上手
- [ ] 函数的权限管理
- [x] [PostgreSQL函数易变性分类](feature/func-volatility.md)


**驱动**

- [x] [Golang的数据库标准接口教程：database/sql](tools/go-database-tutorial.md)
- [ ] PostgreSQL驱动横向评测：Go语言
- [ ] PostgreSQL Golang驱动介绍：pgx
- [ ] PostgreSQL Golang驱动介绍：go-pg
- [ ] PostgreSQL Python驱动介绍：psycopg2
- [ ] psycopg2的进阶包装，让Python访问Pg更敏捷。
- [ ] PostgreSQL Node.JS驱动介绍：node-postgres



## 原理

- [x] [PostgresSQL变更数据捕获](src/logical-decoding.md)
- [x] [PostgreSQL前后端协议概述](src/wire-protocol.md)
- [x] [PostgreSQL的逻辑结构与物理结构](src/logical-arch.md)
- [x] [事务隔离等级](src/isolation-level.md)
- [ ] 并发创建索引的实现方式（CREATE INDEX CONCURRENTLY）
- [ ] GIN索引的实现原理
- [ ] B树索引的原理与实现细节
- [ ] 查询处理原理
- [ ] JOIN类型及其内部实现
- [ ] VACUUM原理
- [ ] WAL：PostgreSQL WAL与检查点
- [ ] 流复制原理与实现细节
- [ ] 二阶段提交：原理与实践
- [ ] R树原理与实现细节
- [ ] PostgreSQL数据页结构
- [ ] FDW的结构与编写
- [ ] SSD Internal



## 工具

**命令行**

- [x] [psqlrc 使用基础](admin/psql.md)
- [x] [批量配置SSH免密登录](admin/ssh-add-key.md)
- [x] [组合使用psql与bash](admin/psql-and-bash.md)

**连接池**

- [x] [pgbouncer安装](tools/pgbouncer-install.md)
- [x] [pgbouncer配置文件](tools/pgbouncer-config.md)
- [x] [pgbouncer使用方法](tools/pgbouncer-usage.md)
- [ ] pgpool的应用方式

**操作系统**

- [x]  [查看系统任务 —— top](tools/unix-top.md)
- [x]  [查看内存使用 —— free](tools/unix-free.md)
- [x]  [查看虚拟内存使用 —— vmstat](tools/unix-vmstat.md)
- [x]  [查看IO —— iostat](tools/unix-iostat.md)
- [ ]  查看硬盘信息——smartctl
- [ ]  查看网卡信息——ethtool

**网络**

* [使用Wireshark抓包分析PostgreSQL协议](tools/wireshark-capture.md)

**性能测试**
- [ ] pgbench
- [ ] [sysbench](tools/sysbench.md)

**FDW**

- [x] [FileFDW妙用无穷——从数据库读取系统信息](tools/file_fdw-intro.md)
- [x] [RedisFDW Installation](tools/redis_fdw-install.md)
- [x] [MongoFDW Installation](tools/mongo_fdw-install.md)
- [ ] IMPORT FOREIGN SCHEMA与远程元数据管理
- [ ] MongoFDW设计与实现
- [ ] HBase FDW设计与实现
- [ ] 基于Multicorn编写FDW

**PostGIS**
- [x] [PostGIS安装](tools/postgis-install.md)
- [x] [Introduction to PostGIS](http://workshops.boundlessgeo.com/postgis-intro/index.html)
- [ ] [DE9IM](sql/de9im.md)
- [ ] 地理坐标系相关知识
- [ ] PostGIS空间相交：DE9IM
- [ ] Geometry还是Geography？
- [ ] QGIS安装与简单使用

- [ ] [TimescaleDB安装与使用](tools/timescale-install.md)

- [ ] [PipelineDB安装](tools/pipeline-intro.md)

- [ ] Citus安装

- [ ] [PgAdmin Server 安装](tools/pgadmin-install.md)

- [ ] [PgBackRest 中文文档](tools/pgbackrest.md)





## 参考文档

- [PostgreSQL Documentation](https://www.postgresql.org/docs/current/index.html)
  - [Current](https://www.postgresql.org/docs/current/index.html) ([11](https://www.postgresql.org/docs/11/index.html)) / [10](https://www.postgresql.org/docs/10/index.html) / [9.6](https://www.postgresql.org/docs/9.6/index.html) / [9.5](https://www.postgresql.org/docs/9.5/index.html) / [9.4](https://www.postgresql.org/docs/9.4/index.html) / [12beta](https://www.postgresql.org/docs/devel/index.html)

* [PostgreSQL 中文文档](http://www.postgres.cn/docs/11/)
  * [11](http://www.postgres.cn/docs/11/) / [10](http://www.postgres.cn/docs/10/)  / [9.6](http://www.postgres.cn/docs/9.6/) / (Docs4Dev- PostgresQL 11](https://www.docs4dev.com/docs/zh/postgre-sql/11.2/reference/bookindex.html)
* [PostgreSQL Commit Fest](https://commitfest.postgresql.org)

- [PostGIS 2.5 Documentation](https://postgis.net/docs/manual-2.5/)
- [Citus Documentation](https://docs.citusdata.com/en/v8.0/)
- [TimescaleDB Documentation](https://docs.timescale.com/v1.0/main)
- [PipelineDB Documentation](http://docs.pipelinedb.com)
- [Pgbouncer Documentation](https://pgbouncer.github.io/config.html)
- [PgPool-II Documentation](http://www.pgpool.net/docs/latest/en/html/)
- [PG-INTERNAL](http://www.interdb.jp/pg/)

