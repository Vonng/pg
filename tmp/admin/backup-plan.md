---
title: "PgSQL备份方案"
date: 2019-03-02
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  备份有各种各样的策略，物理备份通常可以分为四种。
---

备份是DBA的安身立命之本，也是数据库管理中最为关键的工作之一。有各种各样的备份，但今天这里讨论的备份都是物理备份。物理备份通常可以分为以下四种：

* 热备（Hot Standby）：与主库一模一样，当主库出现故障时会接管主库的工作，同时也会用于承接线上只读流量。
* 温备（Warm Standby）：与热备类似，但不承载线上流量。通常数据库集群需要一个延迟备库，以便出现错误（例如误删数据）时能及时恢复。在这种情况下，因为延迟备库与主库内容不一致，因此不能服务线上查询。
* 冷备（Code Backup）：冷备数据库以数据目录静态文件的形式存在，是数据库目录的二进制备份。便于制作，管理简单，便于放到其他AZ实现容灾。是数据库的最终保险。
* 异地副本（Remote Standby）：所谓X地X中心，通常指的就是放在其他AZ的热备实例。

![](/img/blog/backup-types.png)

通常我们所说的备份，指的是冷备和温备。它们与热备的重要区别是：它们通常不是最新的。当服务线上查询时，这种滞后是一个缺陷，但对于故障恢复而言，这是一个非常重要的特性。同步的备库是不足以应对所有的问题。设想这样一种情况：一些人为故障或者软件错误把整个数据表甚至整个数据库删除了，这样的变更会立刻应用到同步从库上。这种情况只能通过从延迟温备中查询，或者从冷备重放日志来恢复。因此无论有没有从库，冷/温备都是必须的。

参考：[PostgreSQL复制方案](/zh/blog/2019/03/29/postgresql标准复制方案/)



## 温备方案

通常我比较建议采用延时日志传输备库的方式做温备，从而快速响应故障，并通过异地云存储冷备的方式做容灾。

温备方案有一些显著的优势：

* **可靠**：温备实际上在运行过程中，就在不断地进行“恢复测试”，因此只要温备工作正常没报错，你总是能够相信它是一个可用的备份，但冷备就不一定了。同时，采用同步提交`pg_receivewal`与日志传输的离线实例，一方面能够降低主库因为单一同步从库故障而挂点的风险，另一方面也消除了备库活动影响主库的风险。
* **管理简单**：温备的管理方式基本与普通从库类似，因此如果已经有了主从配置，部署一个温备是很简单的事；此外，用到的工具都是PostgreSQL官方提供的工具：`pg_basebackup`与`pg_receivewal`。温备的延时窗口可以通过参数简单地调整。
* **响应快速**：在延迟备库的延时窗口内发生的故障（删库），都可以快速地恢复：从延迟备库中查出来灌回主库，或者直接将延迟备库步进至特定时间点并提升为新主库。同时，采用温备的方式，就不用每天或每周从主库上拉去全量备份了，更省带宽，执行也更快。

### 步骤概览

![](/img/blog/backu-setup.png)

### 日志归档

如何归档主库生成的WAL日志，传统上通常是通过配置主库上的`archive_command`实现的。不过最近版本的PostgreSQL提供了一个相当实用的工具：`pg_receivewal`（10以前的版本称为`pg_receivexlog`）。对于主库而言，这个客户端应用看上去就像一个从库一样，主库会不断发送最新的WAL日志，而`pg_receivewal`会将其写入本地目录中。这种方式相比`archive_command`的一个显著优势就是，`pg_receivewal`不会等到PostgreSQL写满一个WAL段文件之后再进行归档，因此可以在同步提交的情况下做到故障不丢数据。

`pg_receivewal`使用起来也非常简单：

```bash
# create a replication slot named walarchiver
pg_receivewal --slot=walarchiver --create-slot --if-not-exists

# add replicator credential to /home/postgres/.pgpass 0600
# start archiving (with proper supervisor/init scritpts)
pg_receivewal \
  -D /pg/arcwal \
  --slot=walarchiver \
  --compress=9\
  -d'postgres://replicator@master.csq.tsa.md/postgres'
```

当然在实际生产环境中，为了更为鲁棒地归档，通常我们会将其注册为服务，并保存一些命令状态。这里给出了生产环境中使用的一个`pg_receivewal`命令包装：[`walarchiver`](https://github.com/Vonng/pg/blob/master/test/pkg/walarchiver)

### 相关脚本

这里提供了一个初始化PostgreSQL Offline Instance的脚本，可以作为参考：

[`pg/test/bin/init-offline.sh`](https://github.com/Vonng/pg/blob/master/test/bin/init-offline.sh)





## 备份测试

面对故障时如何充满信心？只要备份还在，再大的问题都能恢复。但如何确保你的备份方案真正有效，这就需要我们事先进行充分的测试。

让我们来设想一些故障场景，以及在本方案下应对这些故障的方式

* `pg_receive`进程终止
* 离线节点重启
* 主库节点重启
* 干净的故障切换
* 脑裂的故障切换
* 误删表一张
* 误删库

To be continue

