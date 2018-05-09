---
author: "Vonng"
description: ""
categories: ["Dev"]
tags: ["PostgreSQL","Timescale"]
type: "post"
---



# TimescaleDB 快速教程

* 官方网站：https://www.timescale.com


* 官方文档：https://docs.timescale.com/v0.9/main
* Github：https://github.com/timescale/timescaledb



[TOC]



## 为什么使用TimescaleDB

### 什么是时间序列数据？

我们一直在谈论什么是“时间序列数据”，以及与其他数据有何不同以及为什么？

许多应用程序或数据库实际上采用的是过于狭窄的视图，并将时间序列数据与特定形式的服务器度量值等同起来：

```
Name:    CPU

Tags:    Host=MyServer, Region=West

Data:
2017-01-01 01:02:00    70
2017-01-01 01:03:00    71
2017-01-01 01:04:00    72
2017-01-01 01:05:01    68
```

但实际上，在许多监控应用中，通常会收集不同的指标（例如，CPU，内存，网络统计数据，电池寿命）。因此，单独考虑每个度量并不总是有意义的。考虑这种替代性的“更广泛”的数据模型，它保持了同时收集的指标之间的相关性。

```
Metrics: CPU, free_mem, net_rssi, battery

Tags:    Host=MyServer, Region=West

Data:
2017-01-01 01:02:00    70    500    -40    80
2017-01-01 01:03:00    71    400    -42    80
2017-01-01 01:04:00    72    367    -41    80
2017-01-01 01:05:01    68    750    -54    79
```

这类数据属于**更广泛的**类别，无论是来自传感器的温度读数，股票价格，机器状态，甚至是登录应用程序的次数。

**时间序列数据是统一表示系统，过程或行为随时间变化的数据。**

### 时间序列数据的特征

如果仔细研究它是如何生成和摄入的，TimescaleDB等时间序列数据库通常具有以下重要特征：

- **以时间为中心**：数据记录始终有一个时间戳。
- **仅追加-**：数据是几乎完全追加只（插入）。
- **最近**：新数据通常是关于最近的时间间隔，我们更少更新或回填旧时间间隔的缺失数据。

尽管数据的频率或规律性并不重要，它可以每毫秒或每小时收集一次。它也可以定期或不定期收集（例如，当发生某些*事件*时，而不是在预先确定的时间）。

但是没有数据库很久没有时间字段？与标准关系“业务”数据等其他数据相比，时间序列数据（以及支持它们的数据库）之间的一个主要区别是**对数据的更改是插入而不是覆盖**。

### 时间序列数据无处不在

时间序列数据无处不在，但有些环境特别是在洪流中创建。

- **监控计算机系统**：虚拟机，服务器，容器指标（CPU，可用内存，网络/磁盘IOP），服务和应用程序指标（请求率，请求延迟）。
- **金融交易系统**：经典证券，较新的加密货币，支付，交易事件。
- **物联网**：工业机器和设备上的传感器，可穿戴设备，车辆，物理容器，托盘，智能家居的消费设备等的数据。
- **事件应用程序**：用户/客户交互数据，如点击流，综合浏览量，登录，注册等。
- **商业智能**：跟踪关键指标和业务的整体健康状况。
- **环境监测**：温度，湿度，压力，pH值，花粉计数，空气流量，一氧化碳（CO），二氧化氮（NO2），颗粒物质（PM10）。
- （和更多）



# 数据模型

TimescaleDB使用“宽表”数据模型，这在关系数据库中是非常普遍的。这使得Timescale与大多数其他时间序列数据库有所不同，后者通常使用“窄表”模型。

在这里，我们讨论为什么我们选择宽表模型，以及我们如何推荐将它用于时间序列数据，使用物联网（IoT）示例。

设想一个由1,000个IoT设备组成的分布式组，旨在以不同的时间间隔收集环境数据。这些数据可能包括：

- **标识符：** `device_id`，`timestamp`
- **元数据：** `location_id`，，，`dev_type``firmware_version``customer_id`
- **设备指标：** `cpu_1m_avg`，，，，，`free_mem``used_mem``net_rssi``net_loss``battery`
- **传感器指标：** `temperature`，，，，，`humidity``pressure``CO``NO2``PM10`

例如，您的传入数据可能如下所示：

| 时间戳              | 设备ID | cpu_1m_avg | Fri_mem | 温度 | LOCATION_ID | dev_type |
| ------------------- | ------ | ---------- | ------- | ---- | ----------- | -------- |
| 2017-01-01 01:02:00 | ABC123 | 80         | 500MB   | 72   | 335         | 领域     |
| 2017-01-01 01:02:23 | def456 | 90         | 400MB   | 64   | 335         | 屋顶     |
| 2017-01-01 01:02:30 | ghi789 | 120        | 0MB     | 56   | 77          | 屋顶     |
| 2017-01-01 01:03:12 | ABC123 | 80         | 500MB   | 72   | 335         | 领域     |
| 2017-01-01 01:03:35 | def456 | 95         | 350MB   | 64   | 335         | 屋顶     |
| 2017-01-01 01:03:42 | ghi789 | 100        | 100MB   | 56   | 77          | 屋顶     |

现在，我们来看看用这些数据建模的各种方法。

## 窄桌模型

大多数时间序列数据库将以下列方式表示这些数据：

- 代表每个指标作为一个单独的实体（例如，表示与作为两个不同的东西）`cpu_1m_avg``free_mem`
- 为该指标存储一系列“时间”，“值”对
- 将元数据值表示为与该指标/标记集组合关联的“标记集”

在这个模型中，每个度量/标签集组合被认为是包含一系列时间/值对的单独“时间序列”。

使用我们上面的例子，这种方法会导致9个不同的“时间序列”，每个“时间序列”由一组独特的标签定义。

```
1. {name:  cpu_1m_avg,  device_id: abc123,  location_id: 335,  dev_type: field}
2. {name:  cpu_1m_avg,  device_id: def456,  location_id: 335,  dev_type: roof}
3. {name:  cpu_1m_avg,  device_id: ghi789,  location_id:  77,  dev_type: roof}
4. {name:    free_mem,  device_id: abc123,  location_id: 335,  dev_type: field}
5. {name:    free_mem,  device_id: def456,  location_id: 335,  dev_type: roof}
6. {name:    free_mem,  device_id: ghi789,  location_id:  77,  dev_type: roof}
7. {name: temperature,  device_id: abc123,  location_id: 335,  dev_type: field}
8. {name: temperature,  device_id: def456,  location_id: 335,  dev_type: roof}
9. {name: temperature,  device_id: ghi789,  location_id:  77,  dev_type: roof}
```

这样的时间序列的数量与每个标签的基数的叉积（即，（＃名称）×（＃设备ID）×（＃位置ID）×（设备类型））的交叉积。

而且这些“时间序列”中的每一个都有自己的一组时间/值序列。

现在，如果您独立收集每个指标，而且元数据很少，则此方法可能有用。

但总的来说，我们认为这种方法是有限的。它会丢失数据中的固有结构，使得难以提出各种有用的问题。例如：

- 系统状态到0 时是什么状态？`free_mem`
- 如何关联？`cpu_1m_avg``free_mem`
- 平均值是多少？`temperature``location_id`

我们也发现这种方法认知混乱。我们是否真的收集了9个不同的时间序列，或者只是一个包含各种元数据和指标读数的数据集？

## 宽桌模型

相比之下，TimescaleDB使用宽表模型，它反映了数据中的固有结构。

我们的宽表模型看起来与初始数据流完全一样：

| 时间戳              | 设备ID | cpu_1m_avg | Fri_mem | 温度 | LOCATION_ID | dev_type |
| ------------------- | ------ | ---------- | ------- | ---- | ----------- | -------- |
| 2017-01-01 01:02:00 | ABC123 | 80         | 500MB   | 72   | 42          | 领域     |
| 2017-01-01 01:02:23 | def456 | 90         | 400MB   | 64   | 42          | 屋顶     |
| 2017-01-01 01:02:30 | ghi789 | 120        | 0MB     | 56   | 77          | 屋顶     |
| 2017-01-01 01:03:12 | ABC123 | 80         | 500MB   | 72   | 42          | 领域     |
| 2017-01-01 01:03:35 | def456 | 95         | 350MB   | 64   | 42          | 屋顶     |
| 2017-01-01 01:03:42 | ghi789 | 100        | 100MB   | 56   | 77          | 屋顶     |

在这里，每一行都是一个新的读数，在给定的时间里有一组度量和元数据。这使我们能够保留数据中的关系，并提出比以前更有趣或探索性更强的问题。

当然，这不是一种新的格式：这是在关系数据库中常见的。这也是为什么我们发现这种格式更直观的原因。

## 与关系数据联合

TimescaleDB的数据模型与关系数据库还有另一个相似之处：它支持JOIN。具体来说，可以将附加元数据存储在辅助表中，然后在查询时使用该数据。

在我们的示例中，可以有一个单独的位置表，映射到该位置的其他元数据。例如：`location_id`

| LOCATION_ID | name       | 纬度      | 经度      | 邮政编码 | 地区     |
| ----------- | ---------- | --------- | --------- | -------- | -------- |
| 42          | 大中央车站 | 40.7527°N | 73.9772°W | 10017    | NYC      |
| 77          | 大厅7      | 42.3593°N | 71.0935°W | 02139    | 马萨诸塞 |

然后在查询时，通过加入我们的两个表格，可以提出如下问题：10017 中我们的设备的平均值是多少？`free_mem``zip_code`

如果没有联接，则需要对数据进行非规范化并将所有元数据存储在每个测量行中。这造成数据膨胀，并使数据管理更加困难。

通过连接，可以独立存储元数据，并更轻松地更新映射。

例如，如果我们想更新我们的“区域”为77（例如从“马萨诸塞州”到“波士顿”），我们可以进行此更改，而不必返回并覆盖历史数据。`location_id`



# 架构与概念

## 概观

TimescaleDB作为PostgreSQL的扩展实现，这意味着Timescale数据库在整个PostgreSQL实例中运行。该扩展模型允许数据库利用PostgreSQL的许多属性，如可靠性，安全性以及与各种第三方工具的连接性。同时，TimescaleDB通过在PostgreSQL的查询规划器，数据模型和执行引擎中添加钩子，充分利用扩展可用的高度自定义。

从用户的角度来看，TimescaleDB公开了一些看起来像单数表的称为**hypertable的**表，它们实际上是一个抽象或许多单独表的虚拟视图，称为**块**。

![可改变和块](https://assets.iobeam.com/images/docs/illustration-hypertable-chunk.svg)

通过将hypertable的数据划分为一个或多个维度来创建块：所有可编程元素按时间间隔分区，并且可以通过诸如设备ID，位置，用户ID等的关键字进行分区。我们有时将此称为分区横跨“时间和空间”。

## 术语

### Hypertables

与数据交互的主要点是一个可以抽象化的跨越所有空间和时间间隔的单个连续表，从而可以通过标准SQL查询它。

实际上，所有与TimescaleDB的用户交互都是使用可调整的。创建表格和索引，修改表格，插入数据，选择数据等都可以（也应该）在hypertable上执行。[[跳转到基本的SQL操作] [jumpSQL]]

一个带有列名和类型的标准模式定义了一个hypertable，其中至少一列指定了一个时间值，另一列（可选）指定了一个额外的分区键。

> 提示：请参阅我们的[数据模型] []，以进一步讨论组织数据的各种方法，具体取决于您的使用情况; 最简单和最自然的就像许多关系数据库一样在“宽桌”中。

单个TimescaleDB部署可以存储多个可更改的超文本，每个超文本具有不同的架构。

在TimescaleDB中创建一个可超过的值需要两个简单的SQL命令:( 使用标准的SQL语法），后面跟着。`CREATE TABLE``SELECT create_hypertable()`

时间索引和分区键自动创建在hypertable上，尽管也可以创建附加索引（并且TimescaleDB支持所有PostgreSQL索引类型）。

### 大块

在内部，TimescaleDB自动将每个可分**区块**分割成**块**，每个块对应于特定的时间间隔和分区键空间的一个区域（使用散列）。这些分区是不相交的（非重叠的），这有助于查询计划人员最小化它必须接触以解决查询的组块集合。

每个块都使用标准数据库表来实现。（在PostgreSQL内部，这个块实际上是一个“父”可变的“子表”。）

块是正确的大小，确保表的索引的所有B树可以在插入期间驻留在内存中。这样可以避免在修改这些树中的任意位置时发生颠簸。

此外，通过避免过大的块，我们可以避免根据自动化保留策略删除删除的数据时进行昂贵的“抽真空”操作。运行时可以通过简单地删除块（内部表）来执行这些操作，而不是删除单独的行。

## 单节点与集群

TimescaleDB在**单节点**部署和**集群**部署（开发中）上执行这种广泛的分区。虽然分区传统上只用于在多台机器上扩展，但它也允许我们扩展到高写入速率（并改进了并行查询），即使在单台机器上也是如此。

TimescaleDB的当前开源版本仅支持单节点部署。值得注意的是，TimescaleDB的单节点版本已经在商用机器上基于超过100亿行高可用性进行了基准测试，而没有插入性能的损失。

## 单节点分区的好处

在单台计算机上扩展数据库性能的常见问题是内存和磁盘之间的显着成本/性能折衷。最终，我们的整个数据集不适合内存，我们需要将我们的数据和索引写入磁盘。

一旦数据足够大以至于我们无法将索引的所有页面（例如B树）放入内存中，那么更新树的随机部分可能会涉及从磁盘交换数据。像PostgreSQL这样的数据库为每个表索引保留一个B树（或其他数据结构），以便有效地找到该索引中的值。所以，当您索引更多列时，问题会复杂化。

但是，由于TimescaleDB创建的每个块本身都存储为单独的数据库表，因此其所有索引都只能建立在这些小得多的表中，而不是代表整个数据集的单个表。所以，如果我们正确地确定这些块的大小，我们可以将最新的表（和它们的B-树）完全放入内存中，并避免交换到磁盘的问题，同时保持对多个索引的支持。

有关TimescaleDB自适应空间/时间组块的动机和设计的更多信息，请参阅我们的[技术博客文章] [chunking]。



## TimescaleDB与PostgreSQL相比

TimescaleDB相对于存储时间序列数据的vanilla PostgreSQL或其他传统RDBMS提供了三大优势：

1. 数据采集率要高得多，尤其是在数据库规模较大的情况下。
2. 查询性能从相当于*数量级更大*。
3. 时间导向的功能。

而且由于TimescaleDB仍然允许您使用PostgreSQL的全部功能和工具 - 例如，与关系表联接，通过PostGIS进行地理空间查询，以及任何可以说PostgreSQL的连接器 - **都没**有理由**不**使用TimescaleDB来存储时间序列PostgreSQL节点中的数据。`pg_dump``pg_restore`

### 更高的摄取率

对于时间序列数据，TimescaleDB比PostgreSQL实现更高且更稳定的采集速率。正如我们的[架构讨论中](https://docs.timescale.com/introduction/architecture#benefits-chunking)所描述的那样，只要索引表不能再适应内存，PostgreSQL的性能就会显着下降。

特别是，无论何时插入新行，数据库都需要更新表中每个索引列的索引（例如B树），这将涉及从磁盘交换一个或多个页面。在这个问题上抛出更多的内存只会拖延不可避免的，一旦您的时间序列表达到数千万行，每秒10K-100K +行的吞吐量就会崩溃到每秒数百行。

TimescaleDB通过大量利用时空分区来解决这个问题，即使在*单台机器上*运行*也是如此*。因此，对最近时间间隔的所有写入操作仅适用于保留在内存中的表，因此更新任何二级索引的速度也很快。

基准测试显示了这种方法的明显优势。数据库客户端插入适度大小的包含时间，设备标记集和多个数字指标（在本例中为10）的批量数据，以下10亿行（在单台计算机上）的基准测试模拟常见监控方案。在这里，实验在具有网络连接的SSD存储的标准Azure VM（DS4 v2,8核心）上执行。

![img](https://assets.timescale.com/benchmarks/timescale-vs-postgres-insert-1B.jpg)

我们观察到PostgreSQL和TimescaleDB对于前20M请求的启动速度大约相同（分别为106K和114K），或者每秒超过1M指标。然而，在大约五千万行中，PostgreSQL的表现开始急剧下降。在过去的100M行中，它的平均值仅为5K行/秒，而TimescaleDB保留了111K行/秒的吞吐量。

简而言之，Timescale在PostgreSQL的总时间的**十五分**之一中加载了十亿行数据库，并且吞吐量超过了PostgreSQL在这些较大规模时的**20倍**。

我们的TimescaleDB基准测试表明，即使使用单个磁盘，它仍能保持超过10B行的恒定性能。

此外，用户在一台计算机上利用多个磁盘时，可以为数**以十亿计的行提供**稳定的性能，无论是采用RAID配置，还是使用TimescaleDB支持在多个磁盘上传播单个超级缓存（通过多个表空间传统的PostgreSQL表）。

### 卓越或类似的查询性能

在单磁盘机器上，许多只执行索引查找或表扫描的简单查询在PostgreSQL和TimescaleDB之间表现相似。

例如，在具有索引时间，主机名和CPU使用率信息的100M行表上，对于每个数据库，以下查询将少于5毫秒：

```
SELECT date_trunc('minute', time) AS minute, max(user_usage)
  FROM cpu
  WHERE hostname = 'host_1234'
    AND time >= '2017-01-01 00:00' AND time < '2017-01-01 01:00'
  GROUP BY minute ORDER BY minute;
```

涉及对索引进行基本扫描的类似查询在两者之间也是等效的：

```
SELECT * FROM cpu
  WHERE usage_user > 90.0
    AND time >= '2017-01-01' AND time < '2017-01-02';
```

涉及基于时间的GROUP BY的较大查询 - 在面向时间的分析中很常见 - 通常在TimescaleDB中实现卓越的性能。

例如，当整个（超）表为100M行时，接触33M行的以下查询在TimescaleDB中速度提高**5倍**，而在1B行时速度提高约**2**倍。

```
SELECT date_trunc('hour', time) as hour,
    hostname, avg(usage_user)
  FROM cpu
  WHERE time >= '2017-01-01' AND time < '2017-01-02'
  GROUP BY hour, hostname
  ORDER BY hour;
```

此外，可以约时间订购专理等查询可以*多*在TimescaleDB更好的性能。

例如，TimescaleDB引入了基于时间的“合并追加”优化，以最小化必须处理以执行以下操作的组的数量（考虑到时间已经被排序）。对于我们的100M行表，这导致查询延迟比PostgreSQL快**396**倍（82ms vs. 32566ms）。

```
SELECT date_trunc('minute', time) AS minute, max(usage_user)
  FROM cpu
  WHERE time < '2017-01-01'
  GROUP BY minute
  ORDER BY minute DESC
  LIMIT 5;
```

我们将很快发布PostgreSQL和TimescaleDB之间更完整的基准测试比较，以及复制我们基准的软件。

我们的查询基准测试的高级结果是，对于几乎**所有**我们已经尝试过的**查询**，TimescaleDB都可以为PostgreSQL 实现**类似或优越（或极其优越）的性能**。

与PostgreSQL相比，TimescaleDB的一项额外成本是更复杂的计划（假设单个可超集可由许多块组成）。这可以转化为几毫秒的计划时间，这对于非常低延迟的查询（<10ms）可能具有不成比例的影响。

### 时间导向的功能

TimescaleDB还包含许多在传统关系数据库中没有的时间导向功能。这些包括特殊查询优化（如上面的合并附加），它为面向时间的查询以及其他面向时间的函数（其中一些在下面列出）提供了一些巨大的性能改进。

#### 面向时间的分析

TimescaleDB包含面向时间分析的*新*功能，其中包括以下一些功能：

- **时间分段**：标准功能的更强大的版本，它允许任意的时间间隔（例如5分钟，6小时等），以及灵活的分组和偏移，而不仅仅是第二，分钟，小时等。`date_trunc`
- **最后**和**第一个**聚合：这些函数允许您按另一个列的顺序获取一列的值。例如，将返回基于组内时间的最新温度值（例如，一小时）。`last(temperature, time)`

这些类型的函数能够实现非常自然的面向时间的查询。例如，以下财务查询打印每个资产的开盘价，收盘价，最高价和最低价。

```
SELECT time_bucket('3 hours', time) AS period
    asset_code,
    first(price, time) AS opening, last(price, time) AS closing,
    max(price) AS high, min(price) AS low
  FROM prices
  WHERE time > NOW() - interval '7 days'
  GROUP BY period, asset_code
  ORDER BY period DESC, asset_code;
```

通过辅助列进行排序的能力（甚至不同于集合）能够实现一些强大的查询类型。例如，财务报告中常见的技术是“双时态建模”，它们分别从与记录观察时间有关的观察时间的原因出发。在这样的模型中，更正插入为新行（具有更新的*time_recorded*字段），并且不替换现有数据。`last`

以下查询返回每个资产的每日价格，按最新记录的价格排序。

```
SELECT time_bucket('1 day', time) AS day,
    asset_code,
    last(price, time_recorded)
  FROM prices
  WHERE time > '2017-01-01'
  GROUP BY day, asset_code
  ORDER BY day DESC, asset_code;
```

有关TimescaleDB当前（和增长中）时间功能列表的更多信息，请[参阅我们的API](https://docs.timescale.com/api#time_bucket)。

#### 面向时间的数据管理

TimescaleDB还提供了某些在PostgreSQL中不易获取或执行的数据管理功能。例如，在处理时间序列数据时，数据通常会很快建立起来。因此，您希望按照“仅存储一周原始数据”的方式编写*数据保留*策略。

实际上，将这与使用连续聚合相结合是很常见的，因此您可以保留两个可改写的数据：一个包含原始数据，另一个包含已经汇总为精细或小时聚合的数据。然后，您可能需要在两个（超）表上定义不同的保留策略，以长时间存储汇总的数据。

TimescaleDB允许通过其功能有效地删除**块**级别的旧数据，而不是行级别的旧数据。`drop_chunks`

```
SELECT drop_chunks(interval '7 days', 'conditions');
```

这将删除只包含比此持续时间早的数据的可超级“条件”中的所有块（文件），而不是删除块中的任何单独数据行。这避免了底层数据库文件中的碎片，这反过来又避免了在非常大的表格中可能过于昂贵的抽真空的需要。

有关更多详细信息，请参阅我们的[数据保留](https://docs.timescale.com/api/data-retention)讨论，包括如何自动执行数据保留策略。



## TimescaleDB之于NoSQL

与一般的NoSQL数据库（例如MongoDB，Cassandra）或更专门的时间导向数据库（例如InfluxDB，KairosDB）相比，TimescaleDB提供了定性和定量差异：

- **普通SQL**：即使在规模上，TimescaleDB也可以为时间序列数据提供标准SQL查询的功能。大多数（所有？）NoSQL数据库都需要学习新的查询语言或使用最好的“SQL-ish”（它仍然与现有工具兼容）。
- **操作简单**：使用TimescaleDB，您只需要为关系数据和时间序列数据管理一个数据库。否则，用户通常需要将数据存储到两个数据库中：“正常”关系数据库和第二个时间序列数据库。
- **JOIN**可以通过关系数据和时间序列数据执行。
- 对于不同的查询集，查询**性能**更快。在NoSQL数据库中，更复杂的查询通常是缓慢或全表扫描，而有些数据库甚至无法支持许多自然查询。
- **像PostgreSQL一样管理，**并继承对不同数据类型和索引（B树，哈希，范围，BRIN，GiST，GIN）的支持。
- **对地理空间数据的本地支持**：存储在TimescaleDB中的数据可以利用PostGIS的几何数据类型，索引和查询。
- **第三方工具**：TimescaleDB支持任何可以说SQL的东西，包括像Tableau这样的BI工具。

### 何时*不*使用TimescaleDB？

然后，如果以下任一情况属实，则可能不想使用TimescaleDB：

- **简单的读取要求**：如果您只需要快速键值查找或单列累积，则内存或列导向数据库可能更合适。前者显然不能扩展到相同的数据量，但是，后者的性能明显低于更复杂的查询。
- **非常稀疏或非结构化的数据**：尽管TimescaleDB利用PostgreSQL对JSON / JSONB格式的支持，并且相当有效地处理稀疏性（空值的位图），但在某些情况下，无模式体系结构可能更合适。
- **重要的压缩是一个优先事项**：基准测试显示在ZFS上运行的TimescaleDB获得约4倍的压缩率，但压缩优化的列存储可能更适合于更高的压缩率。
- **不频繁或离线分析**：如果响应时间较慢（或响应时间限于少量预先计算的度量标准），并且您不希望许多应用程序/用户同时访问该数据，则可以避免使用数据库，而只是将数据存储在分布式文件系统中。



## 安装

### Mac

直接使用brew安装，最省事的方法，可以连PostgreSQL和PostGIS一起装了。

```bash
# Add our tap
brew tap timescale/tap

# To install
brew install timescaledb

# Post-install to move files to appropriate place
/usr/local/bin/timescaledb_move.sh
```

### CentOS

```bash
sudo yum install -y https://download.postgresql.org/pub/repos/yum/9.6/redhat/fedora-7.2-x86_64/pgdg-redhat10-10-1.noarch.rpm


wget https://timescalereleases.blob.core.windows.net/rpm/timescaledb-0.9.0-postgresql-9.6-0.x86_64.rpm
# For PostgreSQL 10:
wget https://timescalereleases.blob.core.windows.net/rpm/timescaledb-0.9.0-postgresql-10-0.x86_64.rpm

# To install
sudo yum install timescaledb
```



## 配置

在`postgresql.conf`中添加以下配置，即可在PostgreSQL启动时加载该插件。

```ini
shared_preload_libraries = 'timescaledb'
```

在数据库中执行以下命令以创建timescaledb扩展。

```sql
CREATE EXTENSION timescaledb;
```



## 调参

对timescaledb比较重要的参数是锁的数量。

TimescaleDB在很大程度上依赖于表分区来扩展时间序列工作负载，这对[锁管理](https://www.postgresql.org/docs/current/static/runtime-config-locks.html)有影响。在查询过程中，可修改需要在许多块（子表）上获取锁，这会耗尽所允许的锁的数量的默认限制。这可能会导致如下警告：

```
psql: FATAL:  out of shared memory
HINT:  You might need to increase max_locks_per_transaction.
```

为了避免这个问题，有必要修改默认值（通常是64），增加最大锁的数量。由于更改此参数需要重新启动数据库，因此建议预估未来的增长。对大多数情况，推荐配置为：`max_locks_per_transaction`

```ini
max_locks_per_transaction = 2 * num_chunks
```

`num_chunks`是在**超级表（HyperTable)**中可能存在的**块（chunk）**数量上限。

这种配置是考虑到对超级表查询可能申请锁的数量粗略等于超级表中的块数量，如果使用索引的话还要翻倍。

注意这个参数并不是精确的限制，它只是控制每个事物中**平均**的对象锁数量。



## 创建超级表

### 创建超表

为了创建一个可改写的，你从一个普通的SQL表开始，然后通过函数（[API参考](https://docs.timescale.com/api#create_hypertable)）将它转换为一个可改写的。`create_hypertable`

以下示例创建一个可随时间跨越一系列设备来跟踪温度和湿度的可调整高度。

```
-- We start by creating a regular SQL table

CREATE TABLE conditions (
  time        TIMESTAMPTZ       NOT NULL,
  location    TEXT              NOT NULL,
  temperature DOUBLE PRECISION  NULL,
  humidity    DOUBLE PRECISION  NULL
);
```

接下来，把它变成一个超表：`create_hypertable`

```
-- This creates a hypertable that is partitioned by time
--   using the values in the `time` column.

SELECT create_hypertable('conditions', 'time');

-- OR you can additionally partition the data on another
--   dimension (what we call 'space partitioning').
-- E.g., to partition `location` into 4 partitions:

SELECT create_hypertable('conditions', 'time', 'location', 4);
```

### 插入和查询

通过普通的SQL 命令将数据插入到hypertable中，例如使用毫秒时间戳：`INSERT`

```
INSERT INTO conditions(time, location, temperature, humidity)
  VALUES (NOW(), 'office', 70.0, 50.0);
```

同样，查询数据是通过正常的SQL 命令完成的。`SELECT`

```
SELECT * FROM conditions ORDER BY time DESC LIMIT 100;
```

SQL 和命令也按预期工作。有关使用TimescaleDB标准SQL接口的更多示例，请参阅我们的[使用页面](https://docs.timescale.com/using-timescaledb)。`UPDATE``DELETE`