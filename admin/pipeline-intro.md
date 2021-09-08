---
title: "PipelineDB快速上手"
date: 2018-09-07
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  PipelineDB是PostgreSQL的一个扩展插件，提供流式数据处理的相关功能。
---



## PipelineDB安装与配置

PipelineDB可以直接通过官方rpm包安装。

加载PipelineDB需要添加动态链接库，在`postgresql.conf`中修改配置项并重启：

````ini
shared_preload_libraries = 'pipelinedb'
max_worker_processes = 128
````

注意如果不修改`max_worker_processes`会报错。其他配置都参照标准的PostgreSQL



## PipelineDB使用样例 —— 维基PV数据

```sql
-- 创建Stream
CREATE FOREIGN TABLE wiki_stream (
        hour timestamp,
        project text,
        title text,
        view_count bigint,
        size bigint)
SERVER pipelinedb;

-- 在Stream上进行聚合
CREATE VIEW wiki_stats WITH (action=materialize) AS
SELECT hour, project,
        count(*) AS total_pages,
        sum(view_count) AS total_views,
        min(view_count) AS min_views,
        max(view_count) AS max_views,
        avg(view_count) AS avg_views,
        percentile_cont(0.99) WITHIN GROUP (ORDER BY view_count) AS p99_views,
        sum(size) AS total_bytes_served
FROM wiki_stream
GROUP BY hour, project;
```

然后，向Stream中插入数据：

```bash
curl -sL http://pipelinedb.com/data/wiki-pagecounts | gunzip | \
        psql -c "
        COPY wiki_stream (hour, project, title, view_count, size) FROM STDIN"
```



## 基本概念

PipelineDB中的基本抽象被称之为：**连续视图（Continuous View）**。

