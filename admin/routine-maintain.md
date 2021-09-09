---
title: "PostgreSQL例行维护"
linkTitle: "PgSQL例行维护任务"
date: 2018-02-10
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  汽车需要上油，数据库也需要维护保养。对Pg而言，有三项比较重要的维护工作：备份、重整、清理
---

# PostgreSQL例行维护

汽车需要上油，数据库也需要维护保养。

## PG中的维护工作

对Pg而言，有三项比较重要的维护工作：备份、重整、清理


* **备份（backup）**：最重要的例行工作，生命线。
  * 制作基础备份
  * 归档增量WAL
* **重整（repack）**
  * 重整表与索引能消除其中的膨胀，节约空间，确保查询性能不会劣化。
* **清理（vacuum）**
  * 维护表与库的年龄，避免事务ID回卷故障。
  * 更新统计数据，生成更好的执行计划。
  * 回收死元组。节约空间，提高性能。



## 备份

备份可以使用`pg_backrest` 作为一条龙解决方案，但这里考虑使用脚本进行备份。

参考：[`pg-backup`](https://github.com/Vonng/pigsty/blob/master/roles/postgres/files/pg/pg-backup)



## 重整

重整使用`pg_repack`，PostgreSQL自带源里包含了pg_repack

参考：[`pg-repack`](https://github.com/Vonng/pigsty/blob/master/roles/postgres/files/pg/pg-repack)



## 清理

虽然有AutoVacuum，但手动执行Vacuum仍然有帮助。检查数据库的年龄，当出现老化时及时上报。

参考：[`pg-vacuum`](https://github.com/Vonng/pigsty/blob/master/roles/postgres/files/pg/pg-vacuum)