---
author: "Vonng"
description: "函数易变性等级分类"
tags: ["PostgreSQL","Function"]
type: "post"
---



# 函数易变性等级分类



## 核心种差

* `VOLATILE` : 有副作用，不可被优化。
* `STABLE`： 执行了数据库查询。
* `IMMUTABLE `: 纯函数，执行结果可能会在规划时被预求值并缓存。



## 什么时候用？

- `VOLATILE` : 有任何写入，有任何副作用，需要看到外部命令所做的变更，或者调用了任何`VOLATILE`的函数
- `STABLE`： 有数据库查询，但没有写入，或者函数的结果依赖于配置参数（例如时区）
- `IMMUTABLE `: 纯函数。



## 具体解释

每个函数都带有一个**易变性（Volatility）** 等级。可能的取值包括 `VOLATILE`、`STABLE`，以及`IMMUTABLE`。创建函数时如果没有指定易变性等级，则默认为 `VOLATILE`。易变性是函数对优化器的承诺：

- `VOLATILE`函数可以做任何事情，包括修改数据库状态。在连续调用时即使使用相同的参数，也可能会返回不同的结果。优化器不会优化掉此类函数，每次调用都会重新求值。
- `STABLE`函数不能修改数据库状态，且在**单条语句**中保证给定同样的参数一定能返回同样的结果，因而优化器可以将相同参数的多次调用优化成一次调用。在索引扫描条件中允许使用`STABLE`函数，但`VOLATILE`函数就不行。（一次索引扫描中只会对参与比较的值求值一次，而不是每行求值一次，因而在一个索引扫描条件中不能使用 `VOLATILE`函数）。
- `IMMUTABLE`函数不能修改数据库状态，并且保证任何时候给定输入永远返回相同的结果。这种分类允许优化器在一个查询用常量参数调用该函数 时提前计算该函数。例如，一个 `SELECT ... WHERE x = 2 + 2`这样的查询可以被简化为`SELECT ... WHERE x = 4`，因为整数加法操作符底层的函数被 标记为`IMMUTABLE`。



## STABLE与IMMUTABLE的区别

### 调用次数优化

以下面这个函数为例，它只是简单的返回常数2

```sql
CREATE OR REPLACE FUNCTION return2() RETURNS INTEGER AS
$$
BEGIN
RAISE NOTICE 'INVOKED';
RETURN 2;
END;
$$ LANGUAGE PLPGSQL STABLE;
```

当使用`STABLE`标签时，它会真的调用10次，而当使用`IMMUTABLE`标签时，它会被优化为一次调用。

```
vonng=# select return2() from generate_series(1,10);
NOTICE:  INVOKED
NOTICE:  INVOKED
NOTICE:  INVOKED
NOTICE:  INVOKED
NOTICE:  INVOKED
NOTICE:  INVOKED
NOTICE:  INVOKED
NOTICE:  INVOKED
NOTICE:  INVOKED
NOTICE:  INVOKED
 return2
---------
       2
       2
       2
       2
       2
       2
       2
       2
       2
       2
(10 rows)
```

这里将函数的标签改为`IMMUTABLE`

```sql
CREATE OR REPLACE FUNCTION return2() RETURNS INTEGER AS
$$
BEGIN
RAISE NOTICE 'INVOKED';
RETURN 2;
END;
$$ LANGUAGE PLPGSQL IMMUTABLE;
```

再执行同样的查询，这次函数只被调用了一次

```sql
vonng=# select return2() from generate_series(1,10);
NOTICE:  INVOKED
 return2
---------
       2
       2
       2
       2
       2
       2
       2
       2
       2
       2
(10 rows)
```

### 执行计划缓存

第二个例子是有关索引条件中的函数调用，假设我们有这么一张表，包含从1到1000的整数：

```sql
create table demo as select * from generate_series(1,1000) as id;
create index idx_id on demo(id);
```

现在创建一个`IMMUTABLE`的函数`mymax`

```sql
CREATE OR REPLACE FUNCTION mymax(int, int)
RETURNS int
AS $$
BEGIN
     RETURN CASE WHEN $1 > $2 THEN $1 ELSE $2 END;
END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;
```

我们会发现，当我们在索引条件中直接使用该函数时，执行计划中的索引条件被直接求值缓存并固化为了`id=2`

```sql
vonng=# EXPLAIN SELECT * FROM demo WHERE id = mymax(1,2);
                               QUERY PLAN
------------------------------------------------------------------------
 Index Only Scan using idx_id on demo  (cost=0.28..2.29 rows=1 width=4)
   Index Cond: (id = 2)
(2 rows)
```

而如果将其改为`STABLE`函数，则结果变为运行时求值：

```sql
vonng=# EXPLAIN SELECT * FROM demo WHERE id = mymax(1,2);
                               QUERY PLAN
------------------------------------------------------------------------
 Index Only Scan using idx_id on demo  (cost=0.53..2.54 rows=1 width=4)
   Index Cond: (id = mymax(1, 2))
(2 rows)
```





