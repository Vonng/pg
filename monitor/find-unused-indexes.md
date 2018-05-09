---
author: "Vonng"
description: "找出PostgreSQL中未被使用的索引"
date: "2018-04-18"
categories: ["DBA"]
tags: ["PostgreSQL","Ops"]
type: "post"
---



# 找出PostgreSQL中未被使用的索引

大家都知道数据库索引是一件好事，因为它可以加速SQL查询。但这不是免费的。

索引的缺点是：

索引占用空间。数据库索引使用与数据本身一样多的存储空间并不罕见。数据库所需的可靠，快速存储不一定便宜。
索引使用的空间也增加了物理备份的大小和持续时间。
索引减慢数据修改。无论何时从表中插入或删除，除了表本身（“堆”）外，还必须修改所有索引。
修改一个索引的复杂数据结构比堆本身要昂贵得多，因为它本身的名字恰恰是因为它基本上是一个无序的“堆”数据（并且大家都知道，维护顺序比拥有乱）。修改索引表很容易比修改无索引表的成本高出一个数量级。
索引阻止HOT更新。由于PostgreSQL的体系结构，每个UPDATE都会导致写入一个新的行版本（“元组”），并在该表的每个索引中产生一个新条目。
这种行为被称为“写作放大”，引起了很大的冲击。如果a）新元组与旧元组相匹配，并且b）没有索引行被修改，则可以避免这种不希望的影响。然后PostgreSQL将这个新元组创建为“Heap Only Tuple”（因此为HOT），效率更高，同时也减少了VACUUM所要做的工作。
索引的许多用途

现在我们知道我们不想要不必要的索引。问题在于索引有很多用途，因此很难确定是否需要某个索引。

以下列出了PostgreSQL中所有索引的优点：

索引可以加速在WHERE子句中使用索引列（或表达式）的查询。
大家都知道那个！
传统的B树索引支持<，<=，=，> =和>运算符，而PostgreSQL中的许多其他索引类型可以支持更多的奇特运算符，如“重叠”（范围或几何），“距离”单词）还是正则表达式匹配。
B树索引可以加速max（）和min（）聚合。
B-tree索引可以加速ORDER BY子句。
索引可以加速连接。这取决于优化器选择的“连接策略”：例如，散列连接将永远不会使用索引。
在FOREIGN KEY约束的起源处的B树索引避免了在目标表中删除（或修改了键）行时的顺序扫描。对约束起源的扫描是必要的，以确保约束不会被违反修改。
索引用于强制约束。唯一的B树索引用于强制执行PRIMARY KEY和UNIQUE约束，而排除约束使用GiST索引。
索引可以为优化器提供更好的价值分布统计信息。
如果在表达式上创建索引，则ANALYZE和autoanalyze守护程序不仅会收集表列中数据分布的统计信息，还会收集索引中发生的每个表达式的统计信息。这有助于优化器对包含索引表达式的复杂条件的“选择性”做出很好的估计，这会导致更好的计划被选择。这是索引广泛忽略的好处！
找到未使用的索引！

我们在Cyber​​tec使用的以下查询将显示所有不符合上述目的的索引。

它利用了上述列表中索引的所有用法，除了最后两个索引扫描之外。

为了完整起见，我必须补充说明，参数track_counts必须保持“开启”才能使查询生效，否则，不会在pg_stat_user_indexes中跟踪索引使用情况。但是，您不能改变该参数，否则autovacuum将停止工作。

要查找自上次使用pg_stat_reset（）重置统计信息以来从未使用的索引，请使用



不要在测试数据库上这样做，而是在生产数据库上这样做！
如果您的软件在多个客户站点上运行，请在所有这些站点上运行查询。
不同的用户有不同的使用软件的方式，这会导致使用不同的索引。
您可以用不同的条件替换查询中的s.idx_scan = 0，例如s.idx_scan <10.很少使用的索引也适用于remov





```sql
SELECT s.schemaname,
       s.relname AS tablename,
       s.indexrelname AS indexname,
       pg_relation_size(s.indexrelid) AS index_size
FROM pg_catalog.pg_stat_user_indexes s
   JOIN pg_catalog.pg_index i ON s.indexrelid = i.indexrelid
WHERE s.idx_scan = 0      -- has never been scanned
  AND 0 <>ALL (i.indkey)  -- no index column is an expression
  AND NOT EXISTS          -- does not enforce a constraint
         (SELECT 1 FROM pg_catalog.pg_constraint c
          WHERE c.conindid = s.indexrelid)
ORDER BY pg_relation_size(s.indexrelid) DESC;
```

