---
title: "PG14 RC新特性"
date: 2021-09-29
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  PG 14 RC1 发布了 https://www.postgresql.org/docs/14/release-14.html
---



# PG14 RC新特性

**Release date:** 2021-??-?? (AS OF 2021-09-18)

原文：https://www.postgresql.org/docs/14/release-14.html



## 1 概览

PostgreSQL 14 包含了大量新特新与改进，如下所述。



## 2 迁移

对于那些希望从以前的版本迁移数据的用户，需要使用[pg_dumpall](https://www.postgresql.org/docs/14/app-pg-dumpall.html)进行转储/恢复，或者使用[pg_upgrade](https://www.postgresql.org/docs/14/pgupgrade.html)或逻辑复制。关于迁移到新的主要版本的一般信息，见[第19.6节](https://www.postgresql.org/docs/14/upgrading.html)。

第14版包含了一些可能影响与以前版本兼容性的变化。请注意以下不兼容的地方。

- 引用某些内置数组函数及其参数类型的用户定义对象必须重新创建(Tom Lane)

  具体来说，[`array_append()`](https://www.postgresql.org/docs/14/functions-array.html), `array_prepend()`, `array_cat()`, `array_position()`, `array_positions()`, `array_remove()`, `array_replace()`, 和 [`width_bucket()`](https://www.postgresql.org/docs/14/functions-math.html) 以前使用`anyarray`参数，现在使用`anycompatiblearray`。因此，用户定义的对象（如聚合体）和引用这些数组函数签名的操作符必须在升级前放弃，并在升级完成后重新创建。

- 为内置的 [geometric data types](https://www.postgresql.org/docs/14/functions-geometry.html) 和 contrib 模块 [cube](https://www.postgresql.org/docs/14/cube.html), [hstore](https://www.postgresql.org/docs/14/hstore.html), [intarray](https://www.postgresql.org/docs/14/intarray.html) 和 [seg](https://www.postgresql.org/docs/14/seg.html) 删除废弃的包含操作符 `@`和`~` (Justin Pryzby)

  更一致的命名`<@`和`@>`已经被推荐了很多年。

- 修正 [`to_tsquery()`](https://www.postgresql.org/docs/14/functions-textsearch.html) 和 `websearch_to_tsquery()`，以正确解析含有被丢弃标记的查询文本 (Alexander Korotkov)

  某些被丢弃的标记，如下划线，导致这些函数的输出产生不正确的tsquery输出，例如，`websearch_to_tsquery('"pg_class pg")`和`to_tsquery('pg_class <-> pg')`曾经输出`( 'pg' & 'class' ) <-> 'pg'，但是现在都输出`'pg' <-> 'class' <-> 'pg'。

- 修正[`websearch_to_tsquery()`](https://www.postgresql.org/docs/14/functions-textsearch.html)，以正确解析引号中多个相邻的废弃标记(Alexander Korotkov)

  以前，包含多个相邻废弃标记的引号文本被视为多个标记，导致不正确的tsquery输出，例如，`websearch_to_tsquery('"aaa: bbb")'曾经输出`'aaa' <2> 'bbb'，但现在输出`'aaa' <-> 'bbb'。

- 修改 [`EXTRACT()`](https://www.postgresql.org/docs/14/functions-datetime.html)，返回类型为`numeric`而不是`float8`(Peter Eisentraut)

  这避免了某些使用中的精度损失问题。旧的行为仍然可以通过使用旧的底层函数`date_part()`获得。

  另外，`EXTRACT(date)`现在对不属于`date`数据类型的单位抛出一个错误。

- 更改[`var_samp()`](https://www.postgresql.org/docs/14/functions-aggregate.html)和`stddev_samp()`的数字参数，当输入的是一个NaN值时，返回NULL (Tom Lane)

  以前是返回`NaN`。

- 当使用属性号时，对不存在或被放弃的列进行的[`has_column_privilege()`](https://www.postgresql.org/docs/14/functions-info.html)检查返回false (Joe Conway)

  以前这样的属性号会返回一个无效列的错误。

- 修正对无限[窗口函数](https://www.postgresql.org/docs/14/sql-expressions.html#SYNTAX-WINDOW-FUNCTIONS)范围的处理(Tom Lane)

  以前这样的属性号会返回一个无效的错误。

- 删除阶乘运算符`!`和`!!`，以及函数`numeric_fac()`(Mark Dilger)

  仍然支持[`fractorial()`](https://www.postgresql.org/docs/14/functions-math.html)函数。

- 不允许对负数`fractorial()`(Peter Eisentraut)

  以前这种情况会返回1。

- 移除对[postfix](https://www.postgresql.org/docs/14/sql-createoperator.html)（右单操作数）运算符的支持(Mark Dilger)

  pg_dump和pg_upgrade会在postfix操作符被转储时发出警告。

- 允许`D`和`W`速记符在[regular expression](https://www.postgresql.org/docs/14/functions-matching.html#FUNCTIONS-POSIX-REGEXP)换行敏感模式下匹配换行(Tom Lane)

  以前它们在这种模式下不匹配换行，但这与其他常见的正则表达式引擎的行为不一致。`[^[:digit:]]`或`[^[:word:]]`可以用来获得旧的行为。

- 匹配正则表达式时不考虑约束条件 [back-references](https://www.postgresql.org/docs/14/functions-matching.html#POSIX-ESCAPE-SEQUENCES) (Tom Lane)

  例如，在`(^\d+).*\1`中，`^`约束应该应用在字符串的开头，但在匹配`1`时不应用。

- 不允许`w`作为正则表达式字符类的开始或结束范围 (Tom Lane)

  这在以前是允许的，但产生了意外的结果。

- 要求[自定义服务器参数](https://www.postgresql.org/docs/14/runtime-config-custom.html)名称只使用在未引用的SQL标识符中有效的字符(Tom Lane)

- 改变[password_encryption](https://www.postgresql.org/docs/14/runtime-config-connection.html#GUC-PASSWORD-ENCRYPTION)服务器参数的默认值为`scram-sha-256`(Peter Eisentraut)

  以前是`md5`。所有新的密码都将被存储为SHA256，除非这个服务器设置被改变或者密码被指定为MD5格式。同时，不再接受以前`md5`的同义词--传统的（和无记录的）布尔值。

- 删除服务器参数`vacuum_cleanup_index_scale_factor` (Peter Geoghegan)

  从PostgreSQL 13.3版开始，这个设置被忽略了。

- 删除服务器参数`operator_precedence_warning` (Tom Lane)

  这个设置是用来警告应用程序关于PostgreSQL 9.5的变化。

- 彻底修改[`pg_hba.conf`](https://www.postgresql.org/docs/14/auth-pg-hba-conf.html)中`clientcert`的规范 (Kyotaro Horiguchi)

  不再支持`1`/`0`/`no-verify`值；只能使用字符串`verify-ca`和`verify-full`。另外，如果启用了cert认证，不允许`verify-ca`，因为cert需要`verify-full`检查。

- 删除对[SSL](https://www.postgresql.org/docs/14/runtime-config-connection.html#RUNTIME-CONFIG-CONNECTION-SSL)压缩的支持 (Daniel Gustafsson, Michael Paquier)

  这在以前的PostgreSQL版本中已经默认禁用，而且大多数现代OpenSSL和TLS版本不再支持它。

- 删除服务器和[libpq](https://www.postgresql.org/docs/14/libpq.html)对第二版[wire协议](https://www.postgresql.org/docs/14/protocol.html)的支持 (Heikki Linnakangas)

  这是在PostgreSQL 7.3（2002年发布）中最后一次作为默认使用。

- 在[`CREATE/DROP LANGUAGE`](https://www.postgresql.org/docs/14/sql-createlanguage.html)命令中不允许语言名称的单引号 (Peter Eisentraut)

- 删除以前为序列和Toast表创建的[复合类型](https://www.postgresql.org/docs/14/xfunc-sql.html#XFUNC-SQL-COMPOSITE-FUNCTIONS) (Tom Lane)

- 正确处理 [ecpg](https://www.postgresql.org/docs/14/ecpg.html) SQL命令字符串中的双引号 (Tom Lane)

  以前`'abc'`, `'def'`被作为`'abc'def'` 传递给服务器，而`"abc""def"`被作为`"abc "def"`'传递，导致语法错误。

- 防止[intarray](https://www.postgresql.org/docs/14/intarray.html)的包含操作符（`<@`和`@>`）使用GiST索引（Tom Lane）。

  以前需要进行完整的GiST索引扫描，所以只要避免这一点，扫描堆就可以了，这样更快。应该删除为此目的而创建的索引。

- 删除contrib程序pg_standby (Justin Pryzby)

- 防止[tablefunc](https://www.postgresql.org/docs/14/tablefunc.html)的函数`normal_rand()`接受负值(Ashutosh Bapat)

  负值产生了不理想的结果。






## 3. 变化

下面你将看到PostgreSQL 14和上一个大版本之间的变化的详细说明。

### 3.1. 服务端

- 增加预定义角色[`pg_read_all_data`](https://www.postgresql.org/docs/14/predefined-roles.html) 和`pg_write_all_data`(Stephen Frost)

  这些非登录角色可以用来给所有的表、视图和序列以读或写的权限。

- 添加预定义角色[`pg_database_owner`](https://www.postgresql.org/docs/14/predefined-roles.html)，只包含当前数据库的所有者(Noah Misch)

  这在模板数据库中特别有用。

- 后台崩溃后删除临时文件 (Euler Taveira)

  以前，这类文件是为调试目的而保留的。如果有必要，可以通过新的服务器参数[`remove_temp_files_after_crash`](https://www.postgresql.org/docs/14/runtime-config-developer.html#GUC-REMOVE-TEMP-FILES-AFTER-CRASH)来禁止删除。

- 如果客户端断开连接，允许取消长期运行的查询 (Sergey Cherkashin, Thomas Munro)

  服务器参数 [`client_connection_check_interval`](https://www.postgresql.org/docs/14/runtime-config-connection.html#GUC-CLIENT-CONNECTION-CHECK-INTERVAL) 允许控制是否在查询过程中检查失去连接的问题。(这在Linux和其他一些操作系统上是支持的）。)

- 为[`pg_terminate_backend()`](https://www.postgresql.org/docs/14/functions-admin.html#FUNCTIONS-ADMIN-SIGNAL)增加一个可选的超时参数。

- 允许宽元组总是被添加到几乎空的堆页中（John Naylor, Floris van Nee)

  以前，如果插入的元组超过了页面的[fill factor](https://www.postgresql.org/docs/14/sql-createtable.html)，则会被添加到新的页面。

- 在SSL连接数据包中添加服务器名称指示（SNI）(Peter Eisentraut)

  可以通过关闭客户端连接选项[`sslsni`](https://www.postgresql.org/docs/14/libpq-connect.html#LIBPQ-PARAMKEYWORDS) 来禁用。

#### 3.1.1. [垃圾清理](https://www.postgresql.org/docs/14/routine-vacuuming.html)

- 当可移动的索引条目数量不多时，允许垃圾清理跳过索引清理(Masahiko Sawada, Peter Geoghegan)

  清理参数[`INDEX_CLEANUP`](https://www.postgresql.org/docs/14/sql-vacuum.html)有一个新的默认值`auto`，可以启用这个优化。

- 允许清理更急切地将删除的btree页面添加到自由空间映射中(Peter Geoghegan)

  以前，清理只能将被以前的真空标记为已删除的页面添加到自由空间映射中。

- 允许清理回收未使用的堆尾部行指针所使用的空间（Matthias van de Meent, Peter Geoghegan)

- 允许清理在最小锁定索引操作中更积极地删除死元组（Álvaro Herrera）。

  具体来说，`CREATE INDEX CONCURRENTLY`和`REINDEX CONCURRENTLY`不再限制对其他关系的死行清除。

- 加快对有许多关系的数据库进行吸尘 (Tatsuhito Kasahara)

- 降低 [vacuum_cost_page_miss](https://www.postgresql.org/docs/14/runtime-config-resource.html#GUC-VACUUM-COST-PAGE-MISS) 的默认值，以更好地反映当前的硬件能力（Peter Geoghegan）。

- 增加跳过TOAST表清理的功能(Nathan Bossart)

  [`VACUUM`](https://www.postgresql.org/docs/14/sql-vacuum.html)现在有一个`PROCESS_TOAST`选项，可以设置为false以禁用TOAST处理，[ vacuumdb](https://www.postgresql.org/docs/14/app-vacuumdb.html) 有一个`--no-process-toast`选项。

- 让[`COPY FREEZE`](https://www.postgresql.org/docs/14/sql-copy.html)适当地更新页面可见性位(Anastasia Lubennikova, Pavan Deolasee, Jeff Janes)

- 如果表接近xid或multixact wraparound，使清理操作更加积极（Masahiko Sawada, Peter Geoghegan）。

  这由 [`vacuum_failsafe_age`](https://www.postgresql.org/docs/14/runtime-config-client.html#GUC-VACUUM-FAILSAFE-AGE) 和 [`vacuum_multixact_failsafe_age`](https://www.postgresql.org/docs/14/runtime-config-client.html#GUC-MULTIXACT-FAILSAFE-AGE) 和 [`vacuum_multixact_failsafe_age`](https://www.postgresql.org/docs/14/runtime-config-client.html#GUC-MULTIXACT-FAILSAFE-AGE) 控制。

- 增加事务ID和多事务包裹前的警告时间和硬限制（Noah Misch）

  这应该可以减少在没有发出wraparound警告的情况下发生故障的可能性。

- 在[autovacuum日志输出](https://www.postgresql.org/docs/14/runtime-config-logging.html#GUC-LOG-AUTOVACUUM-MIN-DURATION) 中增加每个索引的信息 (Masahiko Sawada)

#### 3.1.2. [分区](https://www.postgresql.org/docs/14/ddl-partitioning.html)

- 提高具有许多分区的分区表的更新和删除的性能(Amit Langote, Tom Lane)

  这一变化大大降低了规划器在这种情况下的开销，同时也允许分区表的更新/删除使用运行时分区剪枝。

- 允许分区以非阻塞的方式[detached](https://www.postgresql.org/docs/14/sql-altertable.html)(Álvaro Herrera)

  语法是 `ALTER TABLE ... 脱离分区... CONCURRENTLY`，和`FINALIZE`。

- 忽略分区边界值中的`COLLATE`子句 (Tom Lane)

  以前，任何这样的子句都必须与分区键的排序相匹配；但考虑到它会自动强制到分区键的排序，这就更加一致了。

#### 3.1.3. 索引

- 允许btree索引的添加[删除过期的索引条目](https://www.postgresql.org/docs/14/btree-implementation.html#BTREE-DELETION)，以防止页面分裂(Peter Geoghegan)

  这对于减少索引列经常更新的表的索引膨胀特别有帮助。

- 允许 [BRIN](https://www.postgresql.org/docs/14/brin.html) 索引记录每个范围的多个最小/最大值（Tomas Vondra）。

  如果每个页面范围内有多组数值，这就很有用。

- 允许BRIN索引使用Bloom过滤器(Tomas Vondra)

  这使得BRIN索引可以有效地用于在堆中没有很好定位的数据。

- 允许一些[GiST](https://www.postgresql.org/docs/14/gist.html)索引通过预排序数据来建立(Andrey Borodin)

  预排序会自动发生，并允许更快的索引创建和更小的索引。

- 允许[SP-GiST](https://www.postgresql.org/docs/14/spgist.html)索引包含`INCLUDE'列(Pavel Borisov)


#### 3.1.4. 优化器

- 允许对有许多常量的`IN`子句进行散列查找（James Coleman, David Rowley)

  以前的代码总是按顺序扫描值列表。

- 增加[扩展统计](https://www.postgresql.org/docs/14/planner-stats.html#PLANNER-STATS-EXTENDED)可用于`OR`子句估计的地方(Tomas Vondra, Dean Rasheed)

- 允许对表达式进行扩展统计 (Tomas Vondra)

  这允许对一组表达式和列进行统计，而不是像以前那样只统计列。系统视图[`pg_stats_ext_exprs`](https://www.postgresql.org/docs/14/view-pg-stats-ext-exprs.html)报告这样的统计数据。

- 允许对一系列的[`TIDs`](https://www.postgresql.org/docs/14/datatype-oid.html#DATATYPE-OID-TABLE) 进行有效的堆扫描(Edmund Horner, David Rowley)

  以前，对于不平等的`TID'规范，需要进行顺序扫描。

- 修正[`EXPLAIN CREATE TABLE AS`](https://www.postgresql.org/docs/14/sql-explain.html)和`EXPLAIN CREATE MATERIALIZED VIEW`，以尊重`IF NOT EXISTS`(Bharath Rupireddy)

  以前，如果对象已经存在，`EXPLAIN`会失败。

#### 3.1.5. 一般性能

- 提高在有许多CPU和高会话数的系统上计算MVCC[可视性快照](https://www.postgresql.org/docs/14/mvcc.html)的速度(Andres Freund)

  这也提高了有许多空闲会话时的性能。

- 增加执行器方法，以记忆来自嵌套循环连接内侧的结果（David Rowley）。

  如果只有一小部分行在内侧被检查，这很有用。可以通过服务器参数[enable_memoize](https://www.postgresql.org/docs/14/runtime-config-query.html#GUC-ENABLE-MEMOIZE)禁用它。

- 允许[窗口函数](https://www.postgresql.org/docs/14/functions-window.html)执行增量排序(David Rowley)

- 提高并行顺序扫描的I/O性能(Thomas Munro, David Rowley)

  这是通过将块分组分配给[并行工作者](https://www.postgresql.org/docs/14/runtime-config-resource.html#GUC-MAX-PARALLEL-WORKERS)来实现的。

- 允许引用多个[外域表](https://www.postgresql.org/docs/14/sql-createforeigntable.html)的查询并行地执行外域表扫描(Robert Haas, Kyotaro Horiguchi, Thomas Munro, Etsuro Fujita)

  [postgres_fdw](https://www.postgresql.org/docs/14/postgres-fdw.html) 如果设置了`async_capable`，就支持这种类型的扫描。

- 允许[analyze](https://www.postgresql.org/docs/14/routine-vacuuming.html#VACUUM-FOR-STATISTICS)进行页面预取(Stephen Frost)

  这是由[maintain_io_concurrency](https://www.postgresql.org/docs/14/runtime-config-resource.html#GUC-MAINTENANCE-IO-CONCURRENCY)控制的。

- 提高[regular expression](https://www.postgresql.org/docs/14/functions-matching.html#FUNCTIONS-POSIX-REGEXP)搜索的性能（Tom Lane）。

- 大幅改善Unicode规范化（John Naylor）。

  这加快了 [`normalize()`](https://www.postgresql.org/docs/14/functions-string.html) 和 `IS NORMALIZED` 的速度。

- 增加对TOAST数据使用[LZ4压缩](https://www.postgresql.org/docs/14/sql-createtable.html)的能力(Dilip Kumar)

  这可以在列级设置，或通过服务器参数[default_toast_compression](https://www.postgresql.org/docs/14/runtime-config-client.html#GUC-DEFAULT-TOAST-COMPRESSION)设置为默认。服务器必须用[`--with-lz4`](https://www.postgresql.org/docs/14/install-procedure.html#CONFIGURE-OPTIONS-FEATURES)编译才能支持这个功能。默认设置仍然是PGLZ。


#### 3.1.6. 监控

- 如果服务器参数[`compute_query_id`](https://www.postgresql.org/docs/14/runtime-config-statistics.html#GUC-COMPUTE-QUERY-ID)被启用，在[`pg_stat_activity`](https://www.postgresql.org/docs/14/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW)、[`EXPLAIN VERBOSE`](https://www.postgresql.org/docs/14/sql-explain.html)被启用，在[`pg_stat_activity`](https://www.postgresql.org/docs/14/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW)、[`EXPLAIN VERBOSE`](https://www.postgresql.org/docs/14/sql-explain.html)、[csvlog](https://www.postgresql.org/docs/14/runtime-config-logging.html)中显示查询ID，并可选择在[log_line_prefix](https://www.postgresql.org/docs/14/runtime-config-logging.html#GUC-LOG-LINE-PREFIX)中显示(Julien Rouhaud)

  由扩展计算的查询ID也将被显示。

- 改进[auto-vacuum](https://www.postgresql.org/docs/14/routine-vacuuming.html#AUTOVACUUM)和auto-analyze的日志记录(Stephen Frost, Jakub Wartak)

  如果[track_io_timing](https://www.postgresql.org/docs/14/runtime-config-statistics.html#GUC-TRACK-IO-TIMING)被启用，这将报告自动清理和自动分析的I/O时间。同时，报告自动分析的缓冲区读取和脏污率。

- 在 [log_connections](https://www.postgresql.org/docs/14/runtime-config-logging.html#GUC-LOG-CONNECTIONS) 的输出中增加客户提供的原始用户名的信息 (Jacob Champion)

#### 3.1.7. 系统视图

- 增加系统视图 [`pg_stat_progress_copy`](https://www.postgresql.org/docs/14/progress-reporting.html#COPY-PROGRESS-REPORTING) 以报告`COPY`的进度 (Josef Šimánek, Matthias van de Meent)

- 添加系统视图 [`pg_stat_wal`](https://www.postgresql.org/docs/14/monitoring-stats.html#MONITORING-PG-STAT-WAL-VIEW) 以报告WAL活动 (Masahiro Ikeda)

- 添加系统视图 [`pg_stat_replication_slots`](https://www.postgresql.org/docs/14/monitoring-stats.html#MONITORING-PG-STAT-REPLICATION-SLOTS-VIEW) 以报告复制槽活动 (Sawada Masahiko, Amit Kapila, Vignesh C)

  函数[`pg_stat_reset_replication_slot()`](https://www.postgresql.org/docs/14/monitoring-stats.html#MONITORING-STATS-FUNCTIONS)重置了槽的统计数据。

- 增加系统视图 [`pg_backend_memory_contexts`](https://www.postgresql.org/docs/14/view-pg-backend-memory-contexts.html) 以报告会话内存的使用情况 (Atsushi Torikoshi, Fujii Masao)

- 增加函数 [`pg_log_backend_memory_contexts()`](https://www.postgresql.org/docs/14/functions-admin.html#FUNCTIONS-ADMIN-SIGNAL) 以输出任意后端内存上下文 (Atsushi Torikoshi)

- 在[`pg_stat_database`](https://www.postgresql.org/docs/14/monitoring-stats.html#MONITORING-PG-STAT-DATABASE-VIEW)系统视图中添加会话统计数据(Laurenz Albe)

- 在[`pg_prepared_statements`](https://www.postgresql.org/docs/14/view-pg-prepared-statements.html)中增加列，以报告通用和自定义计划数(Atsushi Torikoshi, Kyotaro Horiguchi)

- 在[`pg_locks`](https://www.postgresql.org/docs/14/view-pg-locks.html)中增加锁等待开始时间 (Atsushi Torikoshi)

- 在`pg_stat_activity`中使存档者进程可见 (Kyotaro Horiguchi)

- 添加等待事件 [`WalReceiverExit`](https://www.postgresql.org/docs/14/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW) 以报告WAL接收器退出的等待时间 (Fujii Masao)

- 实现信息模式视图[`routine_column_usage`](https://www.postgresql.org/docs/14/infoschema-routine-column-usage.html)以跟踪函数和存储过程默认表达式引用的列(Peter Eisentraut)

#### 3.1.8. 认证

- 允许SSL证书的区分名称(DN)与客户端证书认证相匹配(Andrew Dunstan)

  新的[`pg_hba.conf`](https://www.postgresql.org/docs/14/auth-pg-hba-conf.html)选项`clientname=DN`允许与`CN`以外的证书属性进行比较，并可以与身份映射相结合。

- 允许`pg_hba.conf`和[`pg_ident.conf`](https://www.postgresql.org/docs/14/auth-username-maps.html)记录跨越多行 (Fabien Coelho)

  行末的反斜杠允许记录内容在下一行继续。

- 允许指定证书撤销列表（CRL）目录 (Kyotaro Horiguchi)

  这由服务器参数[ssl_crl_dir](https://www.postgresql.org/docs/14/runtime-config-connection.html#GUC-SSL-CRL-DIR)和libpq连接选项[sslcrldir](https://www.postgresql.org/docs/14/libpq-connect.html#LIBPQ-CONNECT-SSLCRLDIR)控制。以前只能指定单个CRL文件。

- 允许任意长度的密码 (Tom Lane, Nathan Bossart)


#### 3.1.9. 服务器配置

- 增加服务器参数[idle_session_timeout](https://www.postgresql.org/docs/14/runtime-config-client.html#GUC-IDLE-SESSION-TIMEOUT)以关闭空闲会话(Li Japin)

  这与[idle_in_transaction_session_timeout](https://www.postgresql.org/docs/14/runtime-config-client.html#GUC-IDLE-IN-TRANSACTION-SESSION-TIMEOUT)类似。

- 将 [checkpoint_completion_target](https://www.postgresql.org/docs/14/runtime-config-wal.html#GUC-CHECKPOINT-COMPLETION-TARGET) 默认值改为 0.9 (Stephen Frost)

  之前的默认值是0.5。

- 允许 [log_line_prefix](https://www.postgresql.org/docs/14/runtime-config-logging.html#GUC-LOG-LINE-PREFIX) 中的 `%P` 报告一个并行工作者的并行组长的 PID (Justin Pryzby)

- 允许 [unix_socket_directories](https://www.postgresql.org/docs/14/runtime-config-connection.html#GUC-UNIX-SOCKET-DIRECTORIES) 将路径指定为单独的、以逗号分隔的引号字符串 (Ian Lawrence Barwick)

  以前，所有的路径都必须在一个引号字符串中。

- 允许启动时分配动态共享内存 (Thomas Munro)

  这是由[`min_dynamic_shared_memory`](https://www.postgresql.org/docs/14/runtime-config-resource.html#GUC-MIN-DYNAMIC-SHARED-MEMORY)控制的。这允许更多地使用大页。

- 增加服务器参数 [huge_page_size](https://www.postgresql.org/docs/14/runtime-config-resource.html#GUC-HUGE-PAGE-SIZE) 来控制Linux上使用的巨大页面的大小 (Odin Ugedal)

### 3.2. 流式复制和恢复

- 允许通过 [pg_rewind](https://www.postgresql.org/docs/14/app-pgrewind.html) 对备用服务器进行回溯 (Heikki Linnakangas)

- 允许在服务器重载配置期间改变 [restore_command](https://www.postgresql.org/docs/14/runtime-config-wal.html#GUC-RESTORE-COMMAND) 设置 (Sergei Kornilov)

  你也可以把`restore_command`设置为空字符串，然后重新加载，强制恢复只从[`pg_wal`](https://www.postgresql.org/docs/14/storage-file-layout.html)目录下读取。

- 增加服务器参数 [log_recovery_conflict_waits](https://www.postgresql.org/docs/14/runtime-config-logging.html#GUC-LOG-RECOVERY-CONFLICT-WAITS) 以报告较长的恢复冲突等待时间 (Bertrand Drouvot, Masahiko Sawada)

- 如果主服务器改变了它的参数，防止了在备用服务器上的重放，则暂停热备用服务器的恢复（Peter Eisentraut）。

  此前，备用服务器会立即关闭。

- 添加函数 [`pg_get_wal_replay_pause_state()`](https://www.postgresql.org/docs/14/functions-admin.html#FUNCTIONS-RECOVERY-CONTROL) 以报告恢复状态(Dilip Kumar)

  它比[`pg_is_wal_replay_paused()`](https://www.postgresql.org/docs/14/functions-admin.html#FUNCTIONS-RECOVERY-CONTROL)提供更详细的信息，后者仍然存在。

- 增加新的只读服务器参数 [in_hot_standby](https://www.postgresql.org/docs/14/runtime-config-preset.html#GUC-IN-HOT-STANDBY) (Haribabu Kommi, Greg Nancarrow, Tom Lane)

  这使得客户端可以很容易地检测到他们是否连接到一个热备用服务器。

- 在具有大量共享缓冲区的集群上，在恢复期间加速截断小表（Kirk Jamison）。

- 允许在Linux上的崩溃恢复开始时进行文件系统同步（Thomas Munro）。

  默认情况下，PostgreSQL会在崩溃恢复开始时打开数据库集群中的每个数据文件并进行fsync。一个新的设置，[recovery_init_sync_method](https://www.postgresql.org/docs/14/runtime-config-error-handling.html#GUC-RECOVERY-INIT-SYNC-METHOD)`=syncfs`，取代了同步集群使用的每个文件系统。这允许在有许多数据库文件的系统上更快恢复。

- 增加函数[`pg_xact_commit_timestamp_origin()`](https://www.postgresql.org/docs/14/functions-info.html)，以返回指定事务的提交时间戳和复制起源(Movead Li)

- 在[`pg_last_committed_xact()`](https://www.postgresql.org/docs/14/functions-info.html)返回的记录中添加复制原点 (Movead Li)

- 允许使用标准函数权限控制复制[origin functions](https://www.postgresql.org/docs/14/functions-admin.html#FUNCTIONS-REPLICATION)(Martín Marqués)

  以前这些函数只能由超级用户执行，这仍然是默认的。


#### 3.2.1. [逻辑复制](https://www.postgresql.org/docs/14/logical-replication.html)

- 允许逻辑复制将长的进行中的事务流向用户（Dilip Kumar, Amit Kapila, Ajin Cherian, Tomas Vondra, Nikhil Sontakke, Stas Kelvich)

  以前超过[logical_decoding_work_mem](https://www.postgresql.org/docs/14/runtime-config-resource.html#GUC-LOGICAL-DECODING-WORK-MEM)的事务被写入磁盘，直到事务完成。

- 增强逻辑复制API，以允许流式传输正在进行的大型事务（Tomas Vondra, Dilip Kumar, Amit Kapila）。

  输出函数以[`stream`](https://www.postgresql.org/docs/14/logicaldecoding-output-plugin.html#LOGICALDECODING-OUTPUT-PLUGIN-STREAM-START)开头。test_decoding也支持这些。

- 在逻辑复制的表同步过程中允许多个事务（Peter Smith, Amit Kapila, and Takamichi Osumi)

- 立即将WAL-log子事务和顶层的`XID'关联起来(Tomas Vondra, Dilip Kumar, Amit Kapila)

  这对逻辑解码很有用。

- 增强逻辑解码API以处理两阶段提交（Ajin Cherian, Amit Kapila, Nikhil Sontakke, Stas Kelvich)

  这通过[`pg_create_logical_replication_slot()`](https://www.postgresql.org/docs/14/functions-admin.html#FUNCTIONS-REPLICATION)控制。

- 当使用逻辑复制时，在命令完成期间生成WAL无效信息(Dilip Kumar, Tomas Vondra, Amit Kapila)

  当逻辑复制被禁用时，在交易完成时生成WAL无效信息。这允许正在进行的交易的逻辑流。

- 允许逻辑解码以更有效地处理缓存无效信息（Dilip Kumar）。

  这允许[逻辑解码](https://www.postgresql.org/docs/14/logicaldecoding.html)在有大量DDL的情况下有效地工作。

- 允许控制逻辑解码消息是否被发送到复制流（David Pirotte, Euler Taveira）。

- 允许逻辑复制订阅使用二进制传输模式（Dave Cramer）。

  这比文本模式更快，但稳定性稍差。

- 允许逻辑解码按xid过滤（Markus Wanner）。

### 3.3. [`select`](https://www.postgresql.org/docs/14/sql-select.html), [`insert`](https://www.postgresql.org/docs/14/sql-insert.html)

- 减少在没有`AS`的情况下不能作为列标签的关键词数量(Mark Dilger)

  现在限制的关键词减少了90%。

- 允许为`JOIN`的`USING`子句指定一个别名 (Peter Eisentraut)

  别名是通过在`USING`子句后面写`AS`来创建的。它可以作为合并后的`USING'列的表资格。

- 允许`DISTINCT`被添加到`GROUP BY`中，以消除重复的 `GROUPING SET`组合 (Vik Fearing)

  例如，`GROUP BY CUBE (a,b), CUBE (b,c)`将产生重复的分组组合，而没有`DISTINCT`。

- 正确处理`INSERT`中多行`VALUES`列表中的`DEFAULT`条目 (Dean Rasheed)

  这种情况曾经抛出一个错误。

- 添加SQL标准的`SEARCH`和`CYCLE`子句用于[普通表表达式](https://www.postgresql.org/docs/14/queries-with.html) (Peter Eisentraut)

  使用现有的语法可以实现同样的结果，但要方便的多。

- 允许 "ON CONFLICT "的 "WHERE "子句中的列名是符合表条件的 (Tom Lane)

  然而，只有目标表可以被引用。


### 3.4. 实用命令

- 允许 [`REFRESH MATERIALIZED VIEW`](https://www.postgresql.org/docs/14/sql-refreshmaterializedview.html) 使用并行性 (Bharath Rupireddy)

- 允许 [`REINDEX`](https://www.postgresql.org/docs/14/sql-reindex.html) 改变新索引的表空间 (Alexey Kondratov, Michael Paquier, Justin Pryzby)

  这是通过指定一个`TABLESPACE`子句来实现的。在[reindexdb](https://www.postgresql.org/docs/14/app-reindexdb.html)中也增加了一个`--tablespace`选项来控制这个。

- 允许`REINDEX`处理一个分区关系的所有子表或索引(Justin Pryzby, Michael Paquier)

- 允许使用`CONCURRENTLY`的索引命令，避免等待其他使用`CONCURRENTLY`的操作完成 (Álvaro Herrera)

- 提高二进制模式下[`COPY FROM`](https://www.postgresql.org/docs/14/sql-copy.html)的性能 (Bharath Rupireddy, Amit Langote)

- 在[view definitions](https://www.postgresql.org/docs/14/sql-createview.html)中为SQL定义的函数保留SQL标准语法(Tom Lane)

  以前，对SQL标准函数的调用，如[`EXTRACT()`](https://www.postgresql.org/docs/14/functions-datetime.html#FUNCTIONS-DATETIME-EXTRACT)是以普通的函数调用语法显示的。现在在显示视图或规则时，保留了原来的语法。

- 在[`GRANT`](https://www.postgresql.org/docs/14/sql-grant.html)和[`REVOKE`](https://www.postgresql.org/docs/14/sql-revoke.html)中增加SQL标准子句`GRANTED BY`(Peter Eisentraut)

- 为[`CREATE TRIGGER`](https://www.postgresql.org/docs/14/sql-createtrigger.html)增加`OR REPLACE`选项 (Takamichi Osumi)

  这允许预先存在的触发器被有条件地替换。

- 允许 [`TRUNCATE`](https://www.postgresql.org/docs/14/sql-truncate.html) 在外域表上操作 (Kazutaka Onishi, Kohei KaiGai)

  [postgres_fdw](https://www.postgresql.org/docs/14/postgres-fdw.html) 模块现在也支持这个功能。

- 允许更容易地将出版物添加到订阅中或从订阅中删除(Japin Li)

  新的语法是[`ALTER SUBSCRIPTION ... ADD/DROP PUBLICATION`](https://www.postgresql.org/docs/14/sql-altersubscription.html)。这就避免了必须指定所有出版物来添加/删除条目。

- 为[系统目录](https://www.postgresql.org/docs/14/catalogs.html) 增加主键、唯一约束和外键 (Peter Eisentraut)

  这些变化有助于GUI工具分析系统目录。现有的目录的唯一索引现在有相关的`UNIQUE`或`PRIMARY KEY`约束。外键关系实际上没有被存储或实现为约束条件，但可以从函数[pg_get_catalog_foreign_keys()](https://www.postgresql.org/docs/14/functions-info.html#FUNCTIONS-INFO-CATALOG-TABLE)中获得显示。

- 在接受 "CURRENT_ROLE "的地方都允许[`CURRENT_ROLE`](https://www.postgresql.org/docs/14/functions-info.html) (Peter Eisentraut)



### 3.5. 数据类型

- 允许扩展和内置数据类型实现[下标](https://www.postgresql.org/docs/14/sql-altertype.html) (Dmitry Dolgov)

  以前，下标处理被硬编码到服务器中，所以下标只能应用于数组类型。这个变化允许下标符号被用来提取或分配任何类型的值的部分，对于这个概念是有意义的。

- 允许对[`JSONB`](https://www.postgresql.org/docs/14/datatype-json.html) 进行下标 (Dmitry Dolgov)

  `JSONB`的下标可以用来提取和分配给`JSONB`文件的部分。

- 增加对[多区间数据类型](https://www.postgresql.org/docs/14/rangetypes.html) 的支持(Paul Jungwirth, Alexander Korotkov)

  这些就像范围数据类型，但它们允许指定多个、有序、不重叠的范围。每个范围类型都会自动创建一个相关的多范围类型。

- 增加对亚美尼亚语、巴斯克语、加泰罗尼亚语、印地语、塞尔维亚语和意第绪语的[词干](https://www.postgresql.org/docs/14/textsearch-dictionaries.html#TEXTSEARCH-SNOWBALL-DICTIONARY)的支持 (Peter Eisentraut)

- 允许[tsearch数据文件](https://www.postgresql.org/docs/14/textsearch-intro.html#TEXTSEARCH-INTRO-CONFIGURATIONS)具有无限的行长(Tom Lane)

  以前的限制是4K字节。同时删除函数`t_readline()`。

- 在[numeric data type](https://www.postgresql.org/docs/14/datatype-numeric.html)中增加对`Infinity`和`Infinity`值的支持 (Tom Lane)

  浮点数据类型已经支持这些。

- 增加[点运算符](https://www.postgresql.org/docs/14/functions-geometry.html) `<<|`和`|>>`代表严格的上/下限测试 (Emre Hasegeli)

  以前这些被称为`>^`和`<^`，但这种命名与其他几何数据类型不一致。旧的名称仍然可用，但可能有一天会被删除。

- 增加运算符来加减[`LSN`](https://www.postgresql.org/docs/14/datatype-pg-lsn.html)和数字（字节）值 (Fujii Masao)

- 允许[二进制数据传输](https://www.postgresql.org/docs/14/protocol-overview.html#PROTOCOL-FORMAT-CODES)对阵列和记录`OID`不匹配的情况更加宽容(Tom Lane)

- 为系统目录创建复合数组类型 (Wenjing Zeng)

  长期以来，用户定义的关系都有与之相关的复合类型，以及这些复合类型的数组类型。现在系统目录也是如此。这一变化也修复了一个不一致的问题，即在单用户模式下创建一个用户定义的表将无法创建一个复合阵列类型。



#### 3.6. 函数

- 允许SQL语言的[函数](https://www.postgresql.org/docs/14/sql-createfunction.html)和[过程](https://www.postgresql.org/docs/14/sql-createprocedure.html)使用SQL标准的函数体(Peter Eisentraut)

  以前只支持字符串字面的函数体。当用SQL标准语法编写函数或过程时，函数体被立即解析并作为解析树存储。这样可以更好地跟踪函数的依赖关系，并且可以带来安全方面的好处。

- 允许[程序](https://www.postgresql.org/docs/14/sql-createprocedure.html)有`OUT`参数(Peter Eisentraut)

- 允许一些数组函数对兼容的数据类型进行混合操作(Tom Lane)

  函数 [`array_append()`](https://www.postgresql.org/docs/14/functions-array.html), `array_prepend()`, `array_cat()`, `array_position()`, `array_positions()`, `array_remove()`, `array_replace()`, 和 [`width_bucket()`](https://www.postgresql.org/docs/14/functions-math.html) 现在接受`anycompatiblearray`而不是`anyarray`参数. 这使得它们对参数类型的精确匹配不那么挑剔。

- 添加SQL标准的 [`trim_array()`](https://www.postgresql.org/docs/14/functions-array.html) 函数 (Vik Fearing)

  这已经可以用数组切片来完成，但不太容易。

- 增加[`ltrim()`](https://www.postgresql.org/docs/14/functions-binarystring.html)和`rtrim()`的`bytea`等价物 (Joel Jacobson)

- 在 [`split_part()`](https://www.postgresql.org/docs/14/functions-string.html) 中支持负数索引 (Nikhil Benesch)

  负值从最后一个字段开始，向后数。

- 增加[`string_to_table()`](https://www.postgresql.org/docs/14/functions-string.html)函数，在定界符上分割字符串 (Pavel Stehule)

  这与[`regexp_split_to_table()`](https://www.postgresql.org/docs/14/functions-string.html)函数类似。

- 增加[`unistr()`](https://www.postgresql.org/docs/14/functions-string.html)函数，允许Unicode字符被指定为字符串中的反斜线-hex转义 (Pavel Stehule)

  这类似于在字面字符串中指定Unicode的方式。

- 增加 [`bit_xor()`](https://www.postgresql.org/docs/14/functions-aggregate.html) XOR聚合函数 (Alexey Bashtanov)

- 增加函数 [`bit_count()`](https://www.postgresql.org/docs/14/functions-binarystring.html)，以返回比特或字节字符串中设置的比特数 (David Fetter)

- 增加 [`date_bin()`](https://www.postgresql.org/docs/14/functions-datetime.html#FUNCTIONS-DATETIME-BIN) 函数 (John Naylor)

  这个函数对输入的时间戳进行 "分档"，将它们分组为统一长度的区间，并与指定的原点对齐。

- 允许[`make_timestamp()`](https://www.postgresql.org/docs/14/functions-datetime.html)/`make_timestamptz()`接受负数年份 (Peter Eisentraut)

  负值被解释为`BC`年。

- 增加新的正则表达式 [`substring()`](https://www.postgresql.org/docs/14/functions-string.html) 语法 (Peter Eisentraut)

  新的SQL标准语法是`SUBSTRING(text SIMILAR pattern ESCAPE escapechar)`。以前的标准语法是`SUBSTRING(text FROM pattern FOR escapechar)`，PostgreSQL仍然接受这种语法。

- 允许在正则表达式的括号内补充字符类转义[`D](https://www.postgresql.org/docs/14/functions-matching.html#POSIX-ESCAPE-SEQUENCES)、`S`和`W`(Tom Lane)

- 添加 [`[[:word:\]]`](https://www.postgresql.org/docs/14/functions-matching.html#POSIX-BRACKET-EXPRESSIONS) 作为正则表达式字符类，等同于 `w` (Tom Lane)

- 允许[`lead()`](https://www.postgresql.org/docs/14/functions-window.html)和`lag()`窗口函数的默认值有更灵活的数据类型 (Vik Fearing)

- 使非零的[浮点值](https://www.postgresql.org/docs/14/datatype-numeric.html#DATATYPE-FLOAT)除以无穷大时返回零 (Kyotaro Horiguchi)

  以前这种操作会产生下溢错误。

- 让NaN的浮点除以0返回NaN(Tom Lane)

  此前，这将返回一个错误。

- 使[`exp()`](https://www.postgresql.org/docs/14/functions-math.html)和`power()`的负无穷指数返回0 (Tom Lane)

  以前它们经常返回下溢错误。

- 提高涉及无穷大的几何计算的准确性(Tom Lane)

- 在可能的情况下，将内置的类型协整函数标记为防漏（Tom Lane）。

  这允许在安全敏感的情况下更多地使用需要类型转换的函数。

- 修改 [`pg_describe_object()`](https://www.postgresql.org/docs/14/functions-info.html), `pg_identify_object()`, 和 `pg_identify_object_as_address()`，以便对不存在的对象总是报告有用的错误信息 (Michael Paquier)



#### 3.7. [PL/PGSQL](https://www.postgresql.org/docs/14/plpgsql.html)

- 改进PL/pgSQL的[表达式](https://www.postgresql.org/docs/14/plpgsql-expressions.html)和[赋值](https://www.postgresql.org/docs/14/plpgsql-statements.html#PLPGSQL-STATEMENTS-ASSIGNMENT)解析(Tom Lane)

  这一变化允许对数组片断和嵌套记录字段进行赋值。

- 允许 plpgsql 的 [`RETURN QUERY`](https://www.postgresql.org/docs/14/plpgsql-control-structures.html) 使用并行方式执行其查询 (Tom Lane)

- 提高plpgsql过程中重复[CALL](https://www.postgresql.org/docs/14/plpgsql-transactions.html)的性能(Pavel Stehule, Tom Lane)

#### 3.8. 客户端接口

- 在libpq中增加[管道](https://www.postgresql.org/docs/14/libpq-pipeline-mode.html#LIBPQ-PIPELINE-SENDING)模式(Craig Ringer, Matthieu Garrigues, Álvaro Herrera)

  这允许发送多个查询，只在发送特定的同步消息时等待完成。

- 增强libpq的[`target_session_attrs`](https://www.postgresql.org/docs/14/libpq-connect.html#LIBPQ-PARAMKEYWORDS)参数选项 (Haribabu Kommi, Greg Nancarrow, Vignesh C, Tom Lane)

  新的选项是 "只读"、"主要"、"备用 "和 "首选-备用"。

- 改进libpq的[`PQtrace()`](https://www.postgresql.org/docs/14/libpq-control.html)的输出格式 (Aya Iwata, Álvaro Herrera)

- 允许ECPG SQL标识符与特定的连接相联系(Hayato Kuroda)

  这是通过[`DECLARE ... STATEMENT`](https://www.postgresql.org/docs/14/ecpg-sql-declare-statement.html)实现的。

#### 3.9. 客户端应用

- 允许 [ vacuumdb](https://www.postgresql.org/docs/14/app-vacuumdb.html) 跳过索引清理和截断 (Nathan Bossart)

  选项是`--no-index-cleanup`和`--no-truncate`。

- 允许 [pg_dump](https://www.postgresql.org/docs/14/app-pgdump.html) 只转储某些扩展 (Guillaume Lelarge)

  这是由选项`--extension`控制的。

- 增加 [pgbench](https://www.postgresql.org/docs/14/pgbench.html) `permute()`函数，以随机洗牌 (Fabien Coelho, Hironobu Suzuki, Dean Rasheed)

- 在pgbench用`-C`测量的重连开销中包括断开时间 (Yugo Nagata)

- 允许多个粗略的选项规格（`-v`）来增加日志的粗略程度（Tom Lane）。

  [pg_dump](https://www.postgresql.org/docs/14/app-pgdump.html)、[pg_dumpall](https://www.postgresql.org/docs/14/app-pg-dumpall.html)和[pg_restore](https://www.postgresql.org/docs/14/app-pgrestore.html)支持这一行为。

##### 3.9.1. [psql](https://www.postgresql.org/docs/14/app-psql.html)

- 允许psql的`df`和`do`命令指定函数和操作符的参数类型（Greg Sabino Mullane，Tom Lane

  这有助于减少为重载名称打印的匹配数量。

- 在psql的`\d[i|m|t]+`输出中增加一个访问方法列（Georgios Kokolatos

- 允许psql的`dt`和`di`显示TOAST表及其索引（Justin Pryzby）。

- 增加psql命令`dX`以列出扩展统计对象（Tatsuro Yamada）。

- 修复psql的`dT`以理解数组语法和后台语法别名，如`int`为`integer`（Greg Sabino Mullane，Tom Lane）。

- 当用psql的`e`编辑前一个查询或文件时，或使用`ef`和`ev`时，如果编辑器没有保存就退出，则忽略结果（Laurenz Albe）。

  以前，这样的编辑会将之前的查询加载到查询缓冲区，并且通常会立即执行它。这被认为可能不是用户想要的。

- 改进标签完成（Vignesh C, Michael Paquier, Justin Pryzby, Georgios Kokolatos, Julien Rouhaud)

#### 3.10. 服务器应用

- 添加命令行工具 [pg_amcheck](https://www.postgresql.org/docs/14/app-pgamcheck.html) 以简化在许多关系上运行 `contrib/amcheck`测试 (Mark Dilger)

- 在 [initdb](https://www.postgresql.org/docs/14/app-initdb.html) 中添加 `--no-instructions` 选项 (Magnus Hagander)

  这抑制了通常打印的服务器启动指令。

- 停止 [pg_upgrade](https://www.postgresql.org/docs/14/pgupgrade.html) 创建`analyze_new_cluster`脚本 (Magnus Hagander)

  取而代之的是，给出可比较的 [ vacuumdb](https://www.postgresql.org/docs/14/app-vacuumdb.html) 说明。

- 移除对 [postmaster](https://www.postgresql.org/docs/14/app-postgres.html) `-o`选项的支持 (Magnus Hagander)

  这个选项是不必要的，因为所有通过的选项已经可以直接指定。

#### 3.11. 文档

- 将 "Default Roles "更名为["Predefined Roles"](https://www.postgresql.org/docs/14/predefined-roles.html) (Bruce Momjian, Stephen Frost)

- 增加[`factorial()`](https://www.postgresql.org/docs/14/functions-math.html#FUNCTION-FACTORIAL)函数的文档 (Peter Eisentraut)

  由于在这个版本中删除了 `!` 操作符，`factorial()`是计算阶乘的唯一内置方法。

#### 3.12. 源代码

- 增加配置选项 [`--with-ssl={openssl}`](https://www.postgresql.org/docs/14/install-procedure.html#CONFIGURE-OPTIONS-FEATURES)，允许将来选择使用SSL库(Daniel Gustafsson, Michael Paquier)

  为了兼容，保留了`--with-openssl`的拼写。

- 增加对 [abstract Unix-domain sockets] 的支持(https://www.postgresql.org/docs/14/runtime-config-connection.html#GUC-UNIX-SOCKET-DIRECTORIES) (Peter Eisentraut)

  目前在Linux和Windows上都支持。

- 允许Windows正确处理大于四千兆字节的文件(Juan José Santamaría Flecha)

  例如这允许 [`COPY,`](https://www.postgresql.org/docs/14/sql-copy.html) [WAL](https://www.postgresql.org/docs/14/install-procedure.html#CONFIGURE-OPTIONS-MISC) 文件，以及关系段文件大于四千兆字节。

- 增加服务器参数 [debug_discard_caches](https://www.postgresql.org/docs/14/runtime-config-developer.html#GUC-DEBUG-DISCARD-CACHES)，为测试目的控制缓存刷新(Craig Ringer)

  以前这种行为只能在编译时设置。要在initdb中调用它，请使用新的选项`--discard-caches`。

- Valgrind错误检测能力的各种改进（Álvaro Herrera, Peter Geoghegan)

- 为正则表达式包添加测试模块（Tom Lane）。

- 增加对LLVM第12版的支持（Andres Freund

- 将SHA1、SHA2和MD5的哈希计算改为使用OpenSSL的EVP API（Michael Paquier）。

  这更现代，而且支持FIPS模式。

- 删除对随机数生成器选择的单独构建时间控制（Daniel Gustafsson）。

  现在它总是由SSL库的选择决定。

- 增加 EUC_TW 和 Big5 编码之间的直接转换程序 (Heikki Linnakangas)

- 增加对FreeBSD的整理版本支持 (Thomas Munro)

- 在索引访问方法API中增加[`amadjustmembers`](https://www.postgresql.org/docs/14/index-api.html) (Tom Lane)

  这允许索引访问方法在创建新的运算符类或族时提供有效性检查。

- 在`libpq-fe.h`中为最近添加的libpq特性提供特性测试宏(Tom Lane, Álvaro Herrera)

  历史上，应用程序通常使用编译时检查`PG_VERSION_NUM`来测试一个功能是否可用。但这通常是服务器的版本，对libpq的版本可能不是一个好的指导。`libpq-fe.h`现在提供了`#define`符号，表示v14中增加的应用程序可见的特性；目的是在未来的版本中继续增加这些特性的符号。

#### 3.13. 附加模块

- 允许对[hstore](https://www.postgresql.org/docs/14/hstore.html)值进行下标 (Tom Lane, Dmitry Dolgov)

- 允许GiST/GIN [pg_trgm](https://www.postgresql.org/docs/14/pgtrgm.html)索引做等价查找 (Julien Rouhaud)

  这与`LIKE`类似，只是不接受通配符。

- 允许 [cube](https://www.postgresql.org/docs/14/cube.html) 数据类型以二进制模式传输 (KaiGai Kohei)

- 允许 [`pgstattuple_approx()`](https://www.postgresql.org/docs/14/pgstattuple.html) 报告TOAST表(Peter Eisentraut)

- 添加contrib模块[pg_surgery](https://www.postgresql.org/docs/14/pgsurgery.html)，允许改变行的可见性(Ashutosh Sharma)

  这对纠正数据库损坏很有用。

- 添加contrib模块[old_snapshot](https://www.postgresql.org/docs/14/oldsnapshot.html)，报告活动的[old_snapshot_threshold](https://www.postgresql.org/docs/14/runtime-config-resource.html#GUC-OLD-SNAPSHOT-THRESHOLD)所使用的`XID`/时间映射。(Robert Haas)

- 允许 [amcheck](https://www.postgresql.org/docs/14/amcheck.html) 也检查堆页 (Mark Dilger)

  以前它只检查B-Tree索引页。

- 允许 [pageinspect](https://www.postgresql.org/docs/14/pageinspect.html) 检查 GiST 索引(Andrey Borodin, Heikki Linnakangas)

- 将pageinspect块的编号改为[`bigints`](https://www.postgresql.org/docs/14/datatype-numeric.html#DATATYPE-INT) (Peter Eisentraut)

- 将 [btree_gist](https://www.postgresql.org/docs/14/btree-gist.html) 函数标记为并行安全 (Steven Winfield)

##### 3.13.1. [pg_stat_statements](https://www.postgresql.org/docs/14/pgstatstatements.html)

- 将查询哈希计算从pg_stat_statements移到核心服务器(Julien Rouhaud)

  新的服务器参数[compute_query_id](https://www.postgresql.org/docs/14/runtime-config-statistics.html#GUC-COMPUTE-QUERY-ID)的默认值为`auto`，当这个扩展被加载时，将自动启用查询ID计算。

- 导致pg_stat_statements分别跟踪顶部和嵌套语句(Julien Rohaud)

  以前，当跟踪所有的语句时，相同的顶层和嵌套语句被作为一个条目来跟踪；但把这些使用分开似乎更有用。

- 在pg_stat_statements中增加实用命令的行数（Fujii Masao, Katsuragi Yuta, Seino Yuki）。

- 添加`pg_stat_statements_info`系统视图以显示pg_stat_statements的活动 (Katsuragi Yuta, Yuki Seino, Naoki Nakamichi)

##### 3.13.2. [postgres_fdw](https://www.postgresql.org/docs/14/postgres-fdw.html)

- 允许postgres_fdw批量`INSERT`行 (Takayuki Tsunakawa, Tomas Vondra, Amit Langote)

- 如果通过[`IMPORT FOREIGN SCHEMA ... LIMIT TO`](https://www.postgresql.org/docs/14/sql-importforeignschema.html)指定，允许postgres_fdw导入表分区(Matthias van de Meent)

  默认情况下，只有分区表的根部被导入。

- 增加postgres_fdw函数`postgres_fdw_get_connections()`来报告开放的外服务器连接 (Bharath Rupireddy)

- 允许控制外部服务器在事务完成后是否保持连接打开 (Bharath Rupireddy)

  这是由`keep_connections`控制的，默认为开。

- 允许postgres_fdw在必要时重新建立外部服务器连接 (Bharath Rupireddy)

  以前外部服务器重新启动可能会导致外部表访问错误。

- 增加postgres_fdw函数来丢弃缓存的连接(Bharath Rupireddy)

### 4. 鸣谢

以下人员（按字母顺序排列）作为补丁作者、提交者、审查者、测试者或问题报告者对该版本做出了贡献。

……
