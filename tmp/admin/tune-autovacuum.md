# Autovacuum Tuning Basics [译]

原文：https://blog.2ndquadrant.com/autovacuum-tuning-basics/#PostgreSQL%20Performance%20Tuning

几个星期前，我介绍了调优检查点的基础知识，在那篇文章中，我还提到了性能问题的第二个常见原因是autovacuum（根据我们在邮件列表和我们的客户支持下看到的）。所以让我跟随这个帖子关于自动调谐的基础知识。我将非常简要地解释必要的理论（死元组，膨胀和autovacuum如何处理它），但是这篇博文的主要重点是调优 - 那里有什么配置选项，经验法则等等。

### 死元组

首先，让我们简单地解释一下“死亡元组”和“膨胀”（如果你想得到更详细的解释，可以阅读Joe Nelson的文章，详细讨论这个）。

当您在PostgreSQL中执行DELETE时，行（又名元组）不会立即从数据文件中删除。相反，它只能通过在行首部中设置xmax字段来标记为已删除。对于UPDATE，也可以看作PostgreSQL中的DELETE + INSERT。

这是PostgreSQL MVCC背后的基本思想之一，因为它允许更大的并发性，只需在不同的进程之间进行最小程度的锁定。这个MVCC实现的缺点当然是它留下了被删除的元组，甚至在所有可能看到这些版本的事务完成之后。

如果不清理，这些“死元组”（对于任何事务实际上是不可见的）将永远停留在数据文件中，浪费磁盘空间，而对于有许多DELETE和UPDATE的表，死元组可能会占用绝大部分磁盘空间。当然，这些死元组也会被索引引用，进一步增加了浪费的磁盘空间。这就是我们在PostgreSQL中所谓的“膨胀”。当然，查询必须处理的数据越多（即使99％的数据立即被“抛弃”），查询就越慢。

### Vacuum和AutoVacuum

回收死元组占用的空间的最直接的方法是（通过手动运行VACUUM命令）。这个维护命令将扫描表并从表和索引中删除死元组 - 它通常不会将磁盘空间返回给操作系统，但会使其可用于新行。

注意：`VACUUM FULL`会回收空间并将其返回给操作系统，但是有一些缺点。首先它获得对表的**独占锁(Access Exclusive)**，阻止所有操作（包括SELECT）。其次，它本质上创建了表的副本，使所需的磁盘空间增加了一倍，所以当磁盘空间已经不足时不太实际。

`VACUUM`的麻烦在于它完全是手动操作 - 只有在您决定运行时才会发生，而不是在需要时才会发生。你可以把它放到cron中，每5分钟在所有的表上运行一次，但是大部分运行的机会并不会真正清理任何东西，唯一的影响是CPU和I / O在系统上的使用率会更高。或者你可能每天晚上只运行一次，在这种情况下，你可能会累积更多你想要的死元组。

这是我们使用**自动清理（AutoVacuum）**的主要目的;根据需要进行清理，以控制浪费空间的数量。数据库确实知道随着时间的推移生成了多少个死元组（每个事务都报告它删除和更新的元组的数量），当表累积了一定数量的死元组时，可以触发清理工作（默认情况下是20％表，我们将会看到）。所以在繁忙的时候会更频繁地执行，而当数据库大部分空闲的时候则更少。

### autoanalyze

清理死元组不是自动清理的唯一任务。它还负责更新优化程序在规划查询时使用的数据分布统计信息。您可以通过运行ANALYZE来手动收集这些数据，但是会遇到与VACUUM类似的问题 - 您可能会经常运行或不经常运行。

解决方案也是类似的 - 数据库可以观察表中有多少行更改，并自动运行ANALYZE。

注意：ANALYZE的开销要大一点，因为虽然VACUUM的成本与死元组的数量成正比（开销很小，当死元组数量很少时/没有），ANALYZE必须在每次执行时从头开始重建统计数据。另一方面，如果你不是经常运行它，那么不好的计划选择的代价可能同样严重。

为了简洁起见，我会在后面的文章中大部分忽略这个自动清理任务 - 配置与清理非常相似，并且遵循大致相同的推理。

### 监控

在进行任何调整之前，您需要能够收集相关数据，否则您怎么能说您需要进行任何调整，或评估配置更改的影响？

换句话说，你应该有一些基本的监控，从数据库中收集指标。为了清理，你至少要看这些值：


* `pg_stat_all_tables.n_dead_tup` ：每个表中的死元组数（用户表和系统目录）
* `(n_dead_tup / n_live_tup)` ： 每个表中死/活元组的比率
* `(pg_class.relpages / pg_class.reltuples)`： 每行空格


如果您已经部署了监控系统（应该的），那么您很有可能已经收集了这些指标。总体目标是获得稳定的行为，这些指标没有突然或显着的变化。

还有一个方便的pgstattuple扩展，允许您对表和索引执行分析，包括计算可用空间量，死元组等。

### 调整目标

在查看实际配置参数之前，让我们简要讨论一下高级调优目标，即更改参数时要实现的目标：

清理死元组 - 保持合理低的磁盘空间量，而不是浪费不合理的磁盘空间量，防止索引膨胀并保持查询速度。
最大限度地减少清理的影响 - 不要经常执行清理工作，因为这会浪费资源（CPU，I / O和RAM），并可能会严重影响性能。

也就是说，你需要找到适当的平衡 - 经常运行可能会不够经常运行。天平在很大程度上取决于您所管理的数据量，您正在处理的工作负载类型（DELETE / UPDATE数量）。

`postgresql.conf`中的大多数默认值是相当保守的，原因有二。首先，根据当时常见的资源（CPU，RAM，...），默认值是几年前决定的。其次，我们希望默认配置可以在任何地方工作，包括树莓派（Raspberry Pi）或小型VPS服务器等小型机器。对于许多部署（特别是较小的部署和/或处理大部分读取工作负载），默认的配置参数将工作得很好。

随着数据库大小和/或写入数量的增加，问题开始出现。典型的问题是清理不经常发生，当发生这种情况时会大大地干扰性能，因为它必须处理大量的垃圾。如果这些情况你应该遵循这个简单的规则：

* 如果它造成了损失，你不会经常这样做。


* 也就是说，调整参数，使得清理更频繁，每次处理更少量的死元组。

注意：人们有时遵循不同的规则 - 如果伤害了，不要这样做。 - 完全禁用自动清理。除非你真的（真的）知道你在做什么，并且有定期的清理脚本，否则请不要这样做。否则，你正在画一个角落，而不是性能有些下降，你将不得不面对严重退化的表现，甚至可能是停机。

所以，现在我们知道我们想要通过调谐实现什么，让我们看看配置参数...

### 阈值和比例因子

当然，你可能会调整的第一件事情是当清理被触发，这是受两个参数的影响：

autovacuum_vacuum_threshold = 50
autovacuum_vacuum_scale_factor = 0.2
并且每当无用元组的数目（你可以看到pg_stat_all_tables.n_dead_tup）超过

阈值+ pg_class.reltuples * scale_factor

该表将被视为需要清理。该公式基本上说，高达20％的表可能是清理前的死元组（50行的阈值是为了防止对小表进行非常频繁的清理）。

默认比例因子适用于中小型的表格，但对于非常大型的表格来说效果并不理想 - 在10GB的表格上，这大概是2GB的死元组，而在1TB的表格上则是200GB。

这是一个积累了大量死元组的例子，并且一次处理所有的元组，这将会受到伤害。根据之前提到的规则，解决方案是通过显着降低比例因子来更频繁地执行此操作，甚至可能是这样：

autovacuum_vacuum_scale_factor = 0.01

这将限制仅减少到表格的1％。另一种解决方法是完全放弃比例因子，仅使用阈值

autovacuum_vacuum_scale_factor = 0
autovacuum_vacuum_threshold = 10000

这应该在产生10000个死元组之后触发清理。

一个麻烦的问题是postgresql.conf中的这些变化会影响到所有表（实际上是整个集群），并且可能会对小型表（包括系统目录）的清理产生不利影响。

当小桌子被更频繁地清理时，最简单的解决办法就是完全忽略这个问题。小桌子的清理将是相当便宜的，并改善工人数量

还没有提到的一个配置选项是autovacuum_max_workers，那是什么意思？那么，清理不会发生在一个自动清理过程中，但是数据库可以启动到实际清理不同数据库/表的autovacuum_max_workers进程。

这很有用，因为例如你不想停止清理小表，直到完成一个大表的清理（这可能需要相当多的时间，因为节流）。

麻烦的是用户假定工作人员的数量与可能发生的清理量成正比。如果将自动清扫工人的数量增加到6人，那么与默认的3人相比，工作量肯定会增加一倍，对吧？

那么，不。几段前面描述的成本上限是全球性的，所有的汽车真空工人都是共同的。每个工作进程只获得总成本限制的1 / autovacuum_max_workers，所以增加工作者数量只会使他们变慢。

这有点像高速公路 - 车辆数量增加一倍，但速度减半，只能让你每小时到达目的地的人数相同。

所以如果你的数据库的清理跟不上用户的活动，那么增加工作者的数量并不是一个解决方案，除非你也调整了其他的参数。

### 按表限流

实际上，当我说成本限制是全局的，所有的自动清理Worker共同分担的时候，我一直在说谎。与缩放因子和阈值类似，可以设置每个表的成本限制和延迟：

```sql
ALTER TABLE t SET (autovacuum_vacuum_cost_limit = 1000);
ALTER TABLE t SET (autovacuum_vacuum_cost_delay = 10);
```

全球成本计算中不包括处理这些表的工人，而是独立地进行限制。

这给了你相当多的灵活性和权力，但不要忘记 - 拥有巨大的权力是很大的责任！

在实践中，我们几乎从不使用这个功能，有两个基本的原因。首先，您通常希望在后台清理上使用单个全局限制。其次，多个工人有时被扼杀在一起，有时独立地使监督和分析系统的行为变得更加困难。

### 概要

所以这就是你调整自动清理的方法。如果我必须把它归纳成几条基本规则，那就是这五条：

* 说真的，不要禁用autovacuum，除非你真的知道你在做什么。
* 在繁忙的数据库上（做大量更新和删除），特别是大数据库，你可能应该减小比例因子，这样更频繁地进行清理。
* 在合理的硬件（良好的存储，多核心）上，你应该增加节流参数，以便清理能够跟上。
* 单独增加autovacuum_max_workers在大多数情况下并不会真的有帮助。你会得到更多的进程变慢。
* 你可以使用ALTER TABLE来设置每个表的参数，但是如果你真的需要的话，可以考虑一下。这使得系统更复杂，更难以检查。

我原本包括几个部分，解释什么时候autovacuum没有真正的工作，以及如何检测它们（以及什么是最好的解决方案），但博客文章已经太长了，所以我会在几天后分开发布。



https://www.percona.com/blog/2018/08/10/tuning-autovacuum-in-postgresql-and-autovacuum-internals/

# Tuning Autovacuum in PostgreSQL and Autovacuum Internals

[Avinash Vallarapu](https://www.percona.com/blog/author/avi-vallarapu/) and [Jobin Augustine](https://www.percona.com/blog/author/jobin-augustine/) | August 10, 2018 |  Posted In: [Insight for DBAs](https://www.percona.com/blog/category/dba-insight/), [Performance Tuning](https://www.percona.com/blog/category/performance-tuning/), [PostgreSQL](https://www.percona.com/blog/category/postgresql/)

The performance of a PostgreSQL database can be compromised by dead tuples, since they continue to occupy space and can lead to bloat. We provided an introduction to VACUUM and bloat in an [earlier blog post.](https://www.percona.com/blog/2018/08/06/basic-understanding-bloat-vacuum-postgresql-mvcc/) Now, though, it’s time to look at autovacuum for postgres, and the internals you to know to maintain a high performance PostgreSQL database needed by demanding applications.

### What is autovacuum ?

Autovacuum is one of the background utility processes that starts automatically when you start PostgreSQL. As you see in the following log, the postmaster (parent PostgreSQL process) with pid 2862 has started the autovacuum launcher process with pid 2868. To start autovacuum, you must have the parameter autovacuum set to ON. In fact, you should not set it to OFF in a production system unless you are 100% sure about what you are doing and its implications.

Shell

| 1234 | avi@percona:~$ps -eaf \| egrep "/post\|autovacuum"postgres  2862     1  0 Jun17 pts/0    00:00:11 /usr/pgsql-10/bin/postgres -D /var/lib/pgsql/10/datapostgres  2868  2862  0 Jun17 ?        00:00:10 postgres: autovacuum launcher process   postgres 15427  4398  0 18:35 pts/1    00:00:00 grep -E --color=auto /post\|autovacuum |
| ---- | ------------------------------------------------------------ |
|      |                                                              |

### Why is autovacuum needed ? 

We need VACUUM to remove dead tuples, so that the space occupied by dead tuples can be re-used by the table for future inserts/updates. To know more about dead tuples and bloat, please read our [previous blog post. ](https://www.percona.com/blog/2018/08/06/basic-understanding-bloat-vacuum-postgresql-mvcc/)We also need ANALYZE on the table that updates the table statistics, so that the optimizer can choose optimal execution plans for an SQL statement. It is the autovacuum in postgres that is responsible for performing both vacuum and analyze on tables.

There exists another background process in postgres called` Stats Collector` that tracks the usage and activity information. The information collected by this process is used by autovacuum launcher to identify the list of candidate tables for autovacuum. PostgreSQL identifies the tables needing vacuum or analyze automatically, but only when autovacuum is enabled. This ensures that postgres heals itself and stops the database from developing more bloat/fragmentation.

Parameters needed to enable autovacuum in PostgreSQL are :

Shell

| 12   | autovacuum = on  # ( ON by default )track_counts = on # ( ON by default ) |
| ---- | ------------------------------------------------------------ |
|      |                                                              |

track_counts  is used by the stats collector. Without that in place, autovacuum cannot access the candidate tables.

### Logging autovacuum

Eventually, you may want to log the tables on which autovacuum spends more time. In that case, set the parameter `log_autovacuum_min_duration` to a value (defaults to milliseconds), so that any autovacuum that runs for more than this value is logged to the PostgreSQL log file. This may help tune your table level autovacuum settings appropriately.

Shell

| 12   | # Setting this parameter to 0 logs every autovacuum to the log file.log_autovacuum_min_duration = '250ms' # Or 1s, 1min, 1h, 1d |
| ---- | ------------------------------------------------------------ |
|      |                                                              |

Here is an example log of autovacuum vacuum and analyze

Shell

| 1234567 | < 2018-08-06 07:22:35.040 EDT > LOG: automatic vacuum of table "vactest.scott.employee": index scans: 0pages: 0 removed, 1190 remain, 0 skipped due to pins, 0 skipped frozentuples: 110008 removed, 110008 remain, 0 are dead but not yet removablebuffer usage: 2402 hits, 2 misses, 0 dirtiedavg read rate: 0.057 MB/s, avg write rate: 0.000 MB/ssystem usage: CPU 0.00s/0.02u sec elapsed 0.27 sec< 2018-08-06 07:22:35.199 EDT > LOG: automatic analyze of table "vactest.scott.employee" system usage: CPU 0.00s/0.02u sec elapsed 0.15 sec |
| ------- | ------------------------------------------------------------ |
|         |                                                              |

### When does PostgreSQL run autovacuum on a table ? 

As discussed earlier, autovacuum in postgres refers to both automatic VACUUM and ANALYZE and not just VACUUM. An automatic vacuum or analyze runs on a table depending on the following mathematic equations.

The formula for calculating the effective table level autovacuum threshold is :

Shell

| 1    | Autovacuum VACUUM thresold for a table = autovacuum_vacuum_scale_factor * number of tuples + autovacuum_vacuum_threshold |
| ---- | ------------------------------------------------------------ |
|      |                                                              |

With the equation above, it is clear that if the actual number of dead tuples in a table exceeds this effective threshold, due to updates and deletes, that table becomes a candidate for autovacuum vacuum.

Shell

| 1    | Autovacuum ANALYZE threshold for a table = autovacuum_analyze_scale_factor * number of tuples + autovacuum_analyze_threshold |
| ---- | ------------------------------------------------------------ |
|      |                                                              |

The above equation says that any table with a total number of inserts/deletes/updates exceeding this threshold—since last analyze—is eligible for an autovacuum analyze.

Let’s understand these parameters in detail.

- `**autovacuum_vacuum_scale_factor**` Or **autovacuum_analyze_scale_factor** : Fraction of the table records that will be added to the formula. For example, a value of 0.2 equals to 20% of the table records.
- **autovacuum_vacuum_threshold** Or **autovacuum_analyze_threshold** : Minimum number of obsolete records or dml’s needed to trigger an autovacuum.

Let’s consider a table: percona.employee with 1000 records and the following autovacuum parameters.

Shell

| 1234 | autovacuum_vacuum_scale_factor = 0.2autovacuum_vacuum_threshold = 50autovacuum_analyze_scale_factor = 0.1autovacuum_analyze_threshold = 50 |
| ---- | ------------------------------------------------------------ |
|      |                                                              |

Using the above mentioned mathematical formulae as reference,

Shell

| 12   | Table : percona.employee becomes a candidate for autovacuum Vacuum when,Total number of Obsolete records = (0.2 * 1000) + 50 = 250 |
| ---- | ------------------------------------------------------------ |
|      |                                                              |

Shell

| 12   | Table : percona.employee becomes a candidate for autovacuum ANALYZE when,Total number of Inserts/Deletes/Updates = (0.1 * 1000) + 50 = 150 |
| ---- | ------------------------------------------------------------ |
|      |                                                              |

### Tuning Autovacuum in PostgreSQL

We need to understand that these are global settings. These settings are applicable to all the databases in the instance. This means, regardless of the table size, if the above formula is reached, a table is eligible for autovacuum vacuum or analyze.

#### Is this a problem ?

Consider a table with ten records versus a table with a million records. Even though the table with a million records may be involved in transactions far more often, the frequency at which a vacuum or an analyze runs automatically could be greater for the table with just ten records.

Consequently, PostgreSQL allows you to configure individual table level autovacuum settings that bypass global settings.

Shell

| 1    | ALTER TABLE scott.employee SET (autovacuum_vacuum_scale_factor = 0, autovacuum_vacuum_threshold = 100); |
| ---- | ------------------------------------------------------------ |
|      |                                                              |

Shell

| 12345678 | Output Log----------avi@percona:~$psql -d perconapsql (10.4)Type "help" for help. percona=# ALTER TABLE scott.employee SET (autovacuum_vacuum_scale_factor = 0, autovacuum_vacuum_threshold = 100);ALTER TABLE |
| -------- | ------------------------------------------------------------ |
|          |                                                              |

The above setting runs autovacuum vacuum on the table scott.employee only once there is more than 100 obsolete records.

### How do we identify the tables that need their autovacuum settings tuned ? 

In order to tune autovacuum for tables individually, you must know the number of inserts/deletes/updates on a table for an interval. You can also view the postgres catalog view : pg_stat_user_tables to get that information.

Shell

| 1234567 | percona=# SELECT n_tup_ins as "inserts",n_tup_upd as "updates",n_tup_del as "deletes", n_live_tup as "live_tuples", n_dead_tup as "dead_tuples"FROM pg_stat_user_tablesWHERE schemaname = 'scott' and relname = 'employee'; inserts \| updates \| deletes \| live_tuples \| dead_tuples ---------+---------+---------+-------------+-------------      30 \|      40 \|       9 \|          21 \|          39(1 row) |
| ------- | ------------------------------------------------------------ |
|         |                                                              |

As observed in the above log, taking a snapshot of this data for a certain interval should help you understand the frequency of DMLs on each table. In turn, this should help you with tuning your autovacuum settings for individual tables.

### How many autovacuum processes can run at a time ? 

There cannot be more than `autovacuum_max_workers` number of autovacuum processes running at a time, across the instance/cluster that may contain more than one database. Autovacuum launcher background process starts a worker process for a table that needs a vacuum or an analyze. If there are four databases with autovacuum_max_workers set to 3, then, the 4th database has to wait until one of the existing worker process gets free.

Before starting the next autovacuum, it waits for `autovacuum_naptime`, the default is 1 min on most of the versions. If you have three databases, the next autovacuum waits for 60/3 seconds. So, the wait time before starting next autovacuum is always (autovacuum_naptime/N) where N is the total number of databases in the instance.

**Does increasing autovacuum_max_workers alone increase the number of autovacuum processes that can run in parallel ?**
NO. This is explained better in next few lines.

### Is VACUUM IO intensive? 

Autovacuum can be considered as a cleanup. As discussed earlier, we have 1 worker process per table. Autovacuum reads 8KB (default block_size) pages of a table from disk and modifies/writes to the pages containing dead tuples. This involves both read and write IO. Thus, this could be an IO intensive operation, when there is an autovacuum running on a huge table with many dead tuples, during a peak transaction time. To avoid this issue, we have a few parameters that are set to minimize the impact on IO due to vacuum.

The following are the parameters used to tune autovacuum IO

- **autovacuum_vacuum_cost_limit** : total cost limit autovacuum could reach (combined by all autovacuum jobs).
- **autovacuum_vacuum_cost_delay** : autovacuum will sleep for these many milliseconds when a cleanup reaching autovacuum_vacuum_cost_limit cost is done.
- **vacuum_cost_page_hit** : Cost of reading a page that is already in shared buffers and doesn’t need a disk read.
- **vacuum_cost_page_miss** : Cost of fetching a page that is not in shared buffers.
- **vacuum_cost_page_dirty** : Cost of writing to each page when dead tuples are found in it.

Shell

| 1234567 | Default Values for the parameters discussed above.------------------------------------------------------autovacuum_vacuum_cost_limit = -1 (So, it defaults to vacuum_cost_limit) = 200autovacuum_vacuum_cost_delay = 20msvacuum_cost_page_hit = 1vacuum_cost_page_miss = 10vacuum_cost_page_dirty = 20 |
| ------- | ------------------------------------------------------------ |
|         |                                                              |

Consider autovacuum VACUUM running on the table percona.employee.

Let’s imagine what can happen in 1 second. (1 second = 1000 milliseconds)

In a best case scenario where read latency is 0 milliseconds, autovacuum can wake up and go for sleep 50 times (1000 milliseconds / 20 ms) because the delay between wake-ups needs to be 20 milliseconds.

Shell

| 1    | 1 second = 1000 milliseconds = 50 * autovacuum_vacuum_cost_delay |
| ---- | ------------------------------------------------------------ |
|      |                                                              |

Since the cost associated per reading a page in shared_buffers is 1, in every wake up 200 pages can be read, and in 50 wake-ups 50*200 pages can be read.

If all the pages with dead tuples are found in shared buffers, with an autovacuum_vacuum_cost_delay of 20ms, then it can read: ((200 / `vacuum_cost_page_hit`) * 8) KB in each round that needs to wait for`autovacuum_vacuum_cost_delay`amount of time.

Thus, at the most, an autovacuum can read : 50 * 200 * 8 KB = 78.13 MB per second (if blocks are already found in shared_buffers), considering the block_size as 8192 bytes.

If the blocks are not in shared buffers and need to fetched from disk, an autovacuum can read : 50 * ((200 / `vacuum_cost_page_miss`) * 8) KB = 7.81 MB per second.

All the information we have seen above is for read IO.

Now, in order to delete dead tuples from a page/block, the cost of a write operation is : `vacuum_cost_page_dirty`, set to 20 by default.

At the most, an autovacuum can write/dirty : 50 * ((200 / `vacuum_cost_page_dirty`) * 8) KB = 3.9 MB per second.

Generally, this cost is equally divided to all the `autovacuum_max_workers` number of autovacuum processes running in the Instance. So, increasing the `autovacuum_max_workers` may delay the autovacuum execution for the currently running autovacuum workers. And increasing the `autovacuum_vacuum_cost_limit` may cause IO bottlenecks. An important point to note is that this behaviour can be overridden by setting the storage parameters of individual tables, which would subsequently ignore the global settings.

Shell

| 1234567891011 | postgres=# alter table percona.employee set (autovacuum_vacuum_cost_limit = 500);ALTER TABLEpostgres=# alter table percona.employee set (autovacuum_vacuum_cost_delay = 10);ALTER TABLEpostgres=# postgres=# \d+ percona.employeeTable "percona.employee"Column \| Type \| Collation \| Nullable \| Default \| Storage \| Stats target \| Description --------+---------+-----------+----------+---------+---------+--------------+-------------id \| integer \| \| \| \| plain \| \| Options: autovacuum_vacuum_threshold=10000, autovacuum_vacuum_cost_limit=500, autovacuum_vacuum_cost_delay=10 |
| ------------- | ------------------------------------------------------------ |
|               |                                                              |

Thus, on a busy OLTP database, always have a strategy to implement manual VACUUM on tables that are frequently hit with DMLs, during a low peak window. You may have as many parallel vacuum jobs as possible when you run it manually after setting relevant autovacuum_* settings. For this reason, a scheduled manual Vacuum Job is always recommended alongside finely tuned autovacuum settings.