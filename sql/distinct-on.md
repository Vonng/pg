# 找出分组内具有最大最小值的记录

找出分组内具有最大最小值的记录，这是一个非常常见的需求。用传统SQL当然有办法解决，但是都不够优雅，PostgreSQL的SQL扩展语法Distinct ON能一步到位解决这一类问题。

## DISTINCT ON 子句

```sql
SELECT DISTINCT ON (expression [, expression ...]) select_list ...
```

Here *expression* is an arbitrary value expression that is evaluated for all rows. A set of rows for which all the expressions are equal are considered duplicates, and only the first row of the set is kept in the output. Note that the “first row” of a set is unpredictable unless the query is sorted on enough columns to guarantee a unique ordering of the rows arriving at the `DISTINCT` filter. (`DISTINCT ON` processing occurs after `ORDER BY` sorting.)



## 例子

例如，找出每台机器的最新日志在日志表中，取出按照机器node_id分组，时间戳`ts`最大的的日志记录。

```sql
CREATE TABLE nodes(node_id INTEGER, ts TIMESTAMP);

INSERT INTO test_data
SELECT (random() * 10)::INTEGER as node_id, t
FROM generate_series('2019-01-01'::TIMESTAMP, '2019-05-01'::TIMESTAMP, '1h'::INTERVAL) AS t;
```

这里可以制造一些随机数据

```
5	2019-01-01 00:00:00.000000
0	2019-01-01 01:00:00.000000
9	2019-01-01 02:00:00.000000
1	2019-01-01 03:00:00.000000
7	2019-01-01 04:00:00.000000
2	2019-01-01 05:00:00.000000
8	2019-01-01 06:00:00.000000
3	2019-01-01 07:00:00.000000
1	2019-01-01 08:00:00.000000
4	2019-01-01 09:00:00.000000
9	2019-01-01 10:00:00.000000
0	2019-01-01 11:00:00.000000
3	2019-01-01 12:00:00.000000
6	2019-01-01 13:00:00.000000
9	2019-01-01 14:00:00.000000
1	2019-01-01 15:00:00.000000
7	2019-01-01 16:00:00.000000
8	2019-01-01 17:00:00.000000
9	2019-01-01 18:00:00.000000
10	2019-01-01 19:00:00.000000
5	2019-01-01 20:00:00.000000
4	2019-01-01 21:00:00.000000
```



现在使用DistinctON，这里Distinct On后面的括号里代表了记录需要按哪一个键进行除重，在括号内的表达式列表上有着相同取值的记录会只保留一条记录。（当然保留哪一条是随机的，因为分组内哪一条记录先返回是不确定的）

```sql
SELECT DISTINCT ON (node_id) * FROM test_data

0	2019-04-30 17:00:00.000000
1	2019-04-30 22:00:00.000000
2	2019-04-30 23:00:00.000000
3	2019-04-30 13:00:00.000000
4	2019-05-01 00:00:00.000000
5	2019-04-30 20:00:00.000000
6	2019-04-30 11:00:00.000000
7	2019-04-30 15:00:00.000000
8	2019-04-30 16:00:00.000000
9	2019-04-30 21:00:00.000000
10	2019-04-29 18:00:00.000000
```

DistinctON有一个配套的ORDER BY子句，用于指明分组内哪一条记录将被保留，排序第一条记录会留下，因此如果我们想要每台机器上的最新日志，可以这样写。

```sql
SELECT DISTINCT ON (node_id) * FROM test_data ORDER BY node_id, ts DESC NULLS LAST

0	2019-04-30 17:00:00.000000
1	2019-04-30 22:00:00.000000
2	2019-04-30 23:00:00.000000
3	2019-04-30 13:00:00.000000
4	2019-05-01 00:00:00.000000
5	2019-04-30 20:00:00.000000
6	2019-04-30 11:00:00.000000
7	2019-04-30 15:00:00.000000
8	2019-04-30 16:00:00.000000
9	2019-04-30 21:00:00.000000
10	2019-04-29 18:00:00.000000
```



## 索引

Distinct On查询当然可以被索引加速，例如以下索引就可以让上面的查询用上索引

```sql
CREATE INDEX ON test_data USING btree(node_id, ts DESC NULLS LAST);

set enable_seqscan = off;
explain SELECT DISTINCT ON (node_id) * FROM test_data ORDER BY node_id, ts DESC NULLS LAST;
Unique  (cost=0.28..170.43 rows=11 width=12)
  ->  Index Only Scan using test_data_node_id_ts_idx on test_data  (cost=0.28..163.23 rows=2881 width=12)

```

注意，排序的时候一定要确保NULLS FIRST|LAST与查询时实际使用的规则匹配。否则可能用不上索引。