# PG

> PostgreSQL是个好数据库
>
> —— Vonng



## 杂文

- [计算机系为什么要学数据库原理和设计？](misc/why-learn-database.md)
- [区块链与分布式数据库](misc/blockchain-and-database.md)
- [一致性：一个过载的术语](misc/consistency-linearizability.md)

## 应用

### 案例

- [KNN问题极致优化：以找出最近餐馆为例](case/knn.md) 
- [使用PostGIS高效解决行政区划归属查询问题](case/adcode-geodecode.md)
- [使用PostgreSQL实现简易推荐系统](case/pg-recsys.md)
- 标签管理系统元数据库设计
- 实时用户画像系统数据库设计
- 博客站数据库设计


### 技术

* [使用审计触发器自动记录数据变更](tech/audit-change.md)
* [实现基于通知触发器的逻辑复制](tech/repl-based-on-notify-trigger.md)
* 连接池：连接数背后的问题
* 选择合适的全局唯一ID生成方式

- QPS/TPS：一个容易误解的指标
- 使用三维/四维点存储时空轨迹
- 自动化后端：PostGraphQL, PgRest, PostgRest横向对比
- PostGraphQL：解放前后端生产力
- postgres_fdw应用：管理远程数据库

### 功能

- PostgreSQL数据类型 —— 数值类型
- PostgreSQL数据类型 —— 文本类型
- PostgreSQL数据类型 —— 文本字面值
- PostgreSQL数据类型 —— 网络类型
- PostgreSQL数据类型 —— Date/Timestamp/TimstampTZ那些事


- PostgreSQL中的JOIN
- Sequence的方方面面
- [PostgreSQL中的锁及其应用](feature/lock.md)
- 子查询还是CTE？
- cube应用一例
- LATERAL JOIN
- 递归查询
- Advanced SQL
- [找出并清除重复的记录](http://blog.theodo.fr/2018/01/search-destroy-duplicate-rows-postgresql/)
- [PostgreSQL函数易变性分类](feature/func-volatility.md)
- PostGIS空间相交：DE9IM

### 驱动

- [Golang的数据库标准接口教程：database/sql](driver/go-database-tutorial.md)
- PostgreSQL驱动横向评测：Go语言
- PostgreSQL Golang驱动介绍：pgx
- PostgreSQL Golang驱动介绍：go-pg
- PostgreSQL Python驱动介绍：psycopg2
- psycopg2的进阶包装，让Python访问Pg更敏捷。
- PostgreSQL Node.JS驱动介绍：node-postgres



## 管理

- 安装PostgreSQL


- [批量配置SSH免密登录](admin/ssh-add-key.md)
- [组合使用psql与bash](admin/psql-and-bash.md)
- PostgreSQL角色权限管理
- 如何管理几百个PostgreSQL实例
- 修改PostgreSQL配置的各种方法
- [PostgreSQL客户端认证](admin/auth.md)
- PostgreSQL HBA配置
- [PostgreSQL 监控](admin/monitor.md)
- [PostgreSQL备份与恢复](admin/backup.md)
- PostgreSQL复制延迟
- PostgreSQL 高可用
- [分析PostgreSQL日志](admin/log-analyze.md)

- [飞行中换引擎：PostgreSQL不停机数据迁移](admin/migration-without-downtime.md)
- 跨大版本升级PostgreSQL，10与先前版本的不兼容性统计
- 级联复制：复制拓扑设计中的权衡

### 故障

- [故障档案：移走负载导致的性能恶化](fault/download-failure.md)
- [故障档案：事务ID回卷故障原理分析与处理](fault/xid-wrap-around.md)
- PostgreSQL脏数据修复
- 救火：杀查询的正确姿势
- 存疑事务：提交日志损坏问题分析与修复
- 客户端大量无超时查询堆积导致故障
- 慢查询堆积导致的雪崩，定位与排查

### 维护

- 重建索引：细节与注意事项
- VACUUM：配置、问题与实践。
- 日常备份：机制、流程、问题、方法。

### 监控

- [监控磁盘用量](monitor/disk.md)
- 使用PostgreSQL与Grafana搭建监控系统
- 使用Timescaledb存储Metrics。
- 监控节点基本信息：CPU与IO
- 监控连接池Pgbouncer
- 获取数据库服务器的基本配置
- 监控表膨胀与索引膨胀
- 监控当前活动
- 找出所有没有用过的索引
- 系统视图详解

### 调参

- PostgreSQL参数配置概览


- [PostgreSQL内存相关参数调谐](tune/memory.md)
- [PostgreSQL检查点相关参数调谐](tune/checkpoint.md)
- [PostgreSQL自动清理相关参数调谐](tune/autovacuum.md)
- [操作系统内核参数调优](tune/kernel.md)


### 原理

- [PostgreSQL事务隔离等级](internal/isolation-level.md)
- [PostgreSQL WAL与检查点](internal/wal-and-checkpoint.md)
- 二阶段提交：原理与实践
- PostgreSQL Wire Protocal：前后端交互协议
- B树原理与实现细节
- R树原理与实现细节
- PostgreSQL数据页结构



## 专题

### FDW

- [FileFDW妙用无穷——从数据库读取系统信息](fdw/file_fdw-intro.md)
- [RedisFDW Installation](fdw/redis_fdw-install.md)
- [MongoFDW Installation](fdw/mongo_fdw-install.md)
- IMPORT FOREIGN SCHEMA与远程元数据管理
- MongoFDW设计与实现
- HBase FDW设计与实现
- 基于Multicorn编写FDW

### Pgbouncer

* pgbouncer基础配置
* pgbouncer参数详解

### PgPool-II

* pgpool的应用方式

### PostGIS

- [PostGIS安装](pg/ext-postgis-install.md)
- [Introduction to PostGIS](http://workshops.boundlessgeo.com/postgis-intro/index.html)
- 地理坐标系相关知识
- Geometry还是Geography？
- QGIS安装与简单使用

### TimescaleDB

- TimescaleDB安装与使用

### PipelineDB

- PipelineDB安装

### Citus

- Citus安装


### PgAdmin

- PgAdmin Server 安装

### PgBackRest

- PgBackRest 中文文档

  ​



## 参考

- [PostgreSQL 9.6 中文文档](http://www.postgres.cn/docs/9.6/)
- [PostgreSQL 10.1 官方文档](https://www.postgresql.org/docs/10/static/index.html)


- [PostGIS 2.4 官方文档](https://postgis.net/docs/manual-2.4/)




