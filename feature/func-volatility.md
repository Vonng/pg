---
author: "Vonng"
description: "PostgreSQL中锁的类型，加锁的方法"
categories: ["Dev"]
tags: ["PostgreSQL","SQL", "Lock"]
type: "post"
---



# 函数易变性等级分类



函数易变性等级分为三类：

- VOLATILE : 不管输入是否相同，输出都是不确定的，默认等级。
- STABLE : 在同一个事务中，输入相同，输出就是相同的。
- IMMUTABLE : 输入相同，输出就相同。


## STABLE：稳定

特别注意的是`now`这个函数，标记为Stable，这意味着在同一个事务中输出是一样的

```sql
postgres=# begin;
BEGIN
postgres=# select now();
              now
-------------------------------
 2018-01-30 14:12:56.915239+08
(1 row)

postgres=# select now();
              now
-------------------------------
 2018-01-30 14:12:56.915239+08
(1 row)

postgres=# select now();
              now
-------------------------------
 2018-01-30 14:12:56.915239+08
```

所以同一个事务中使用now获取的时间戳是一样的。



## IMMUTABLE：不变

IMMUTABLE : 不管是不是在同一个事务中，输入相同输出就是相同的

比如一些数学函数，`cos,sin,tan`。

使用合适的函数易变性等级能有效提升性能。

例如：使用IMMUTABLE

```sql
postgres=# create table demo as select * from generate_series(1,1000) as id;
SELECT 1000
postgres=# \d
        List of relations
 Schema | Name | Type  |  Owner
--------+------+-------+----------
 public | demo | table | postgres
(1 row)

postgres=# create index idx_id on demo(id);
CREATE INDEX
postgres=# explain select * from demo where id = 20;
                               QUERY PLAN
------------------------------------------------------------------------
 Index Only Scan using idx_id on demo  (cost=0.28..8.29 rows=1 width=4)
   Index Cond: (id = 20)
(2 rows)

postgres=# explain select * from demo where id = mymax(20,20);
                      QUERY PLAN
------------------------------------------------------
 Seq Scan on demo  (cost=0.00..267.50 rows=1 width=4)
   Filter: (id = mymax(20, 20))
(2 rows)

postgres=# drop function mymax ;
DROP FUNCTION
postgres=# CREATE OR REPLACE FUNCTION mymax(int, int)
RETURNS int
AS
$$
  BEGIN
       RETURN CASE WHEN $1 > $2 THEN $1 ELSE $2 END;
  END;
$$ LANGUAGE 'plpgsql'IMMUTABLE;
CREATE FUNCTION
postgres=# explain select * from demo where id = mymax(20,20);
                               QUERY PLAN
------------------------------------------------------------------------
 Index Only Scan using idx_id on demo  (cost=0.28..8.29 rows=1 width=4)
   Index Cond: (id = 20)
(2 rows)
```

