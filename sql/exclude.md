

Exclude约束是一个PostgreSQL扩展，它可以实现一些更高级，更巧妙的的数据库约束。

## 

数据完整性是极其重要的，但由应用保证的数据完整性并不总是那么靠谱：人会犯傻，程序会出错。如果能通过数据库约束来强制数据完整性那是再好不过了：后端程序员不用再担心竞态条件导致的微妙错误，数据分析师也可以对数据质量充满信心，不需要验证与清洗。

关系型数据库通常会提供`PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `CHECK`约束，然而并不是所有的业务约束都可以用这几种约束表达。一些约束会稍微复杂一些，例如确保IP网段表中的IP范围不发生重叠，确保同一个会议室不会出现预定时间重叠，确保地理区划表中各个城市的边界不会重叠。传统上要实现这种保证是相当困难的：譬如`UNIQUE`约束就无法表达这种语义，`CHECK`与存储过程或者触发器虽然可以实现这种检查，但也相当tricky。PostgreSQL提供的`EXCLUDE`约束可以优雅地解决这一类问题。

例1 会议室预定

假设我们想要设计一个会议室预定系统，并希望在数据库层面确保不会有冲突的会议室预定出现：即，对于同一个会议室，不允许同时存在两条预定时间范围上存在重叠的记录。那么数据库表可以这样设计：

```sql
-- PostgreSQL自带扩展，为普通类型添加GIST索引运算符支持
CREATE EXTENSION btree_gist;

-- 会议室预定表
CREATE TABLE meeting_room
(
    id      SERIAL PRIMARY KEY,
    user_id INTEGER,
    room_id INTEGER,
    range   tsrange,
    EXCLUDE USING GIST(room_id WITH = , range WITH &&)
);
```

这里`EXCLUDE USING GIST(room_id WITH = , range WITH &&)`指明了一个排它约束：不允许存在`room_id`相等，且`range`相互重叠的多条记录。

```sql
-- 用户1预定了101号房间，从早上10点到下午6点
INSERT INTO meeting_room(user_id, room_id, range) 
VALUES (1,101, tsrange('2019-01-01 10:00', '2019-01-01 18:00'));

-- 用户2也尝试预定101号房间，下午4点到下午6点
INSERT INTO meeting_room(user_id, room_id, range) 
VALUES (2,101, tsrange('2019-01-01 16:00', '2019-01-01 18:00'));

-- 用户2的预定报错，违背了排它约束
ERROR:  conflicting key value violates exclusion constraint "meeting_room_room_id_range_excl"
DETAIL:  Key (room_id, range)=(101, ["2019-01-01 16:00:00","2019-01-01 18:00:00")) conflicts with existing key (room_id, range)=(101, ["2019-01-01 10:00:00","2019-01-01 18:00:00")).
```





这里的`EXCLUDE`约束会自动创建一个相应的GIST索引：

```sql
"meeting_room_room_id_range_excl" EXCLUDE USING gist (room_id WITH =, range WITH &&)
```





```sql
 EXCLUDE [ USING index_method ] ( exclude_element WITH operator [, ... ] ) index_parameters [ WHERE ( predicate ) ] |
 
exclude_element in an EXCLUDE constraint is:
{ column_name | ( expression ) } [ opclass ] [ ASC | DESC ] [ NULLS { FIRST | LAST } ]
```



EXCLUDE [ USING *index_method* ] ( *exclude_element* WITH *operator* [, ... ] ) *index_parameters* [ WHERE ( *predicate* ) ]

```
EXCLUDE [ USING *index_method* ] ( *exclude_element* WITH *operator* [, ... ] ) *index_parameters* [ WHERE ( *predicate* ) ]
```

`EXCLUDE`子句定一个排除约束，它保证如果任意两行在指定列或表达式上使用指定操作符进行比较，不是所有的比较都将会返回`TRUE`。如果所有指定的操作符都测试相等，这就等价于一个`UNIQUE`约束，尽管一个普通的唯一约束将更快。不过，排除约束能够指定比简单相等更通用的约束。例如，你可以使用`&&`操作符指定一个约束，要求表中没有两行包含相互覆盖的圆（见 [Section 8.8](http://www.postgres.cn/docs/11/datatype-geometric.html)）。

排除约束使用一个索引实现，这样每一个指定的操作符必须与用于索引访问方法*index_method*的一个适当的操作符类（见[Section 11.9](http://www.postgres.cn/docs/11/indexes-opclass.html)）相关联。操作符被要求是交换的。每一个*exclude_element*可以选择性地指定一个操作符类或者顺序选项，这些在[???](http://www.postgres.cn/docs/11/SQL-CREATETABLE.html)中有完整描述。

访问方法必须支持`amgettuple`（见[Chapter 61](http://www.postgres.cn/docs/11/indexam.html)），目前这意味着GIN无法使用。尽管允许，但是在一个排除约束中使用 B-树或哈希索引没有意义，因为它无法做得比一个普通唯一索引更出色。因此在实践中访问方法将总是GiST或SP-GiST。

*predicate*允许你在该表的一个子集上指定一个排除约束。在内部这会创建一个部分索引。注意在为此周围的圆括号是必须的。

```

```

The `EXCLUDE` clause defines an exclusion constraint, which guarantees that if any two rows are compared on the specified column(s) or expression(s) using the specified operator(s), not all of these comparisons will return `TRUE`. If all of the specified operators test for equality, this is equivalent to a `UNIQUE` constraint, although an ordinary unique constraint will be faster. However, exclusion constraints can specify constraints that are more general than simple equality. For example, you can specify a constraint that no two rows in the table contain overlapping circles (see [Section 8.8](datatype-geometric.html)) by using the `&&` operator.

Exclusion constraints are implemented using an index, so each specified operator must be associated with an appropriate operator class (see [Section 11.10](indexes-opclass.html)) for the index access method *index_method*. The operators are required to be commutative. Each *exclude_element* can optionally specify an operator class and/or ordering options; these are described fully under [CREATE INDEX](sql-createindex.html).

The access method must support `amgettuple` (see [Chapter 61](indexam.html)); at present this means GIN cannot be used. Although it's allowed, there is little point in using B-tree or hash indexes with an exclusion constraint, because this does nothing that an ordinary unique constraint doesn't do better. So in practice the access method will always be GiST or SP-GiST.

The *predicate* allows you to specify an exclusion constraint on a subset of the table; internally this creates a partial index. Note that parentheses are required around the predicate.







​	问题至此已经基本解决了，不过还有一个问题。如何避免一个IP查出两条记录的尴尬情况？

​	数据完整性是极其重要的，但由应用保证的数据完整性并不总是那么靠谱：人会犯傻，程序会出错。如果能通过数据库约束来Enforce数据完整性，那是再好不过了。

​	然而，有一些约束是相当复杂的，例如确保表中的IP范围不发生重叠，类似的，确保地理区划表中各个城市的边界不会重叠。传统上要实现这种保证是相当困难的：譬如`UNIQUE`约束就无法表达这种语义，`CHECK`与存储过程或者触发器虽然可以实现这种检查，但也相当tricky。PostgreSQL提供的`EXCLUDE`约束可以优雅地解决这个问题。修改我们的`geoips`表：

```sql
create table geoips
(
  ips          inetrange,
  geo          geometry(Point),
  country_code text,
  region_code  text,
  city_name    text,
  ad_code      text,
  postal_code  text,
  EXCLUDE USING gist (ips WITH &&) DEFERRABLE INITIALLY DEFERRED 
);
```

​	这里`EXCLUDE USING gist (ips WITH &&)  ` 的意思就是`ips`字段上不允许出现范围重叠，即新插入的字段不能与任何现存范围重叠（`&&`为真）。而`DEFERRABLE INITIALLY IMMEDIATE `表示在语句结束时再检查所有行上的约束。创建该约束会自动在`ips`字段上创建GIST索引，因此无需手工创建了。





## 例子

```
=> CREATE TABLE zoo (  
  cage   INTEGER,  
  animal TEXT,  
  EXCLUDE USING GIST (cage WITH =, animal WITH <>)  
);  
  
=> INSERT INTO zoo VALUES(123, 'zebra');  
INSERT 0 1  
=> INSERT INTO zoo VALUES(123, 'zebra');  
INSERT 0 1  
=> INSERT INTO zoo VALUES(123, 'lion');  
ERROR:  conflicting key value violates exclusion constraint "zoo_cage_animal_excl"  
DETAIL:  Key (cage, animal)=(123, lion) conflicts with existing key (cage, animal)=(123, zebra).  
=> INSERT INTO zoo VALUES(124, 'lion');  
INSERT 0 1  
```

以上例子，当cage=123固定之后，animal的值也固定了。

除此以外，exclude约束还可以用于几何类型，GIS类型的排他约束，例如地图中的多边形，不能有相交，存入一个多边形时，必须保证它和已有记录中的多边形不相交。