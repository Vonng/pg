# BTree的原理与实现细节



## 1、摘要

pg中btree索引简单的可以想象为一个倒置树结构存储，每一个节点就是一个page，页面分为以下几种：

1、meta page，只有一页，存储元信息，page flag=8

2、root page，只有一页，page flag=2

3、leaf page，叶子页中真正存储指向table（heap page）的索引项，page flag = 1

4、branch page，分支页，page flag = 0

索引level代表索引的层级

level=0，代表只有meta page和root page，root page又是leaf page，这时root page flag = 3。

level=1，代表root page下面直接是leaf page，没有branch page。

level>1，代表root page和leaf page之间还有branch page。



## 2、观察meta page

meta page的page no一般是0，空索引一般只有一个meta page。

```sql
postgres=# create table t(id int, v text);
CREATE TABLE
postgres=# create index idx_t_id on t using btree(id);
CREATE INDEX
postgres=# \d+ t
                                     Table "public.t"
 Column |  Type   | Collation | Nullable | Default | Storage  | Stats target | Description
--------+---------+-----------+----------+---------+----------+--------------+------------
 id     | integer |           |          |         | plain    |              |
 v      | text    |           |          |         | extended |              |
Indexes:
    "idx_t_id" btree (id)

postgres=# select pg_relation_size('idx_t_id','main');
 pg_relation_size
------------------
             8192
(1 row)

postgres=# select * from bt_metap('idx_t_id');
 magic  | version | root | level | fastroot | fastlevel
--------+---------+------+-------+----------+-----------
 340322 |       2 |    0 |     0 |        0 |         0
(1 row)

postgres=# select * from bt_page_stats('idx_t_id', 0);
ERROR:  block 0 is a meta page
postgres=#
```

## 3、level=0的状态

​	level=0，代表只有meta page和root page，root page又是leaf page。索引结构示例图：


​	insert 10条数据，可见索引的大小为16KB，2个页，一个meta page和一个root page。根据bt_metap('idx_t_id')函数，可见root page no是root=1，level=0。根据bt_page_stats('idx_t_id', 1)，可见btpo_flags=3，btpo=0级表示最底层。

```sql
postgres=# insert into t select generate_series(1,10),md5(random()::text);
INSERT 0 10
postgres=# select pg_relation_size('idx_t_id','main');
 pg_relation_size
------------------
            16384
(1 row)

postgres=# select * from bt_metap('idx_t_id');
 magic  | version | root | level | fastroot | fastlevel
--------+---------+------+-------+----------+-----------
 340322 |       2 |    1 |     0 |        1 |         0
(1 row)
postgres=# \x
Expanded display is on.
postgres=#
postgres=# select * from bt_page_stats('idx_t_id', 1);
-[ RECORD 1 ]-+-----
blkno         | 1
type          | l
live_items    | 10
dead_items    | 0
avg_item_size | 16
page_size     | 8192
free_size     | 7948
btpo_prev     | 0
btpo_next     | 0
btpo          | 0
btpo_flags    | 3

postgres=# \x
Expanded display is off.
postgres=# select * from bt_page_items('idx_t_id', 1);
 itemoffset |  ctid  | itemlen | nulls | vars |          data
------------+--------+---------+-------+------+-------------------------
          1 | (0,1)  |      16 | f     | f    | 01 00 00 00 00 00 00 00
          2 | (0,2)  |      16 | f     | f    | 02 00 00 00 00 00 00 00
          3 | (0,3)  |      16 | f     | f    | 03 00 00 00 00 00 00 00
          4 | (0,4)  |      16 | f     | f    | 04 00 00 00 00 00 00 00
          5 | (0,5)  |      16 | f     | f    | 05 00 00 00 00 00 00 00
          6 | (0,6)  |      16 | f     | f    | 06 00 00 00 00 00 00 00
          7 | (0,7)  |      16 | f     | f    | 07 00 00 00 00 00 00 00
          8 | (0,8)  |      16 | f     | f    | 08 00 00 00 00 00 00 00
          9 | (0,9)  |      16 | f     | f    | 09 00 00 00 00 00 00 00
         10 | (0,10) |      16 | f     | f    | 0a 00 00 00 00 00 00 00
(10 rows)
```

再次insert10条数据，可以观察等值索引项的存储方式。

```
postgres=# select pg_relation_size('idx_t_id','main');
 pg_relation_size
------------------
            16384
(1 row)
postgres=# select * from bt_metap('idx_t_id');
 magic  | version | root | level | fastroot | fastlevel
--------+---------+------+-------+----------+-----------
 340322 |       2 |    1 |     0 |        1 |         0
(1 row)
postgres=# \x
Expanded display is on.
postgres=# select * from bt_page_stats('idx_t_id', 1);
-[ RECORD 1 ]-+-----
blkno         | 1
type          | l
live_items    | 20
dead_items    | 0
avg_item_size | 16
page_size     | 8192
free_size     | 7748
btpo_prev     | 0
btpo_next     | 0
btpo          | 0
btpo_flags    | 3

postgres=# \x
Expanded display is off.
postgres=# select * from bt_page_items('idx_t_id', 1);
 itemoffset |  ctid  | itemlen | nulls | vars |          data
------------+--------+---------+-------+------+-------------------------
          1 | (0,11) |      16 | f     | f    | 01 00 00 00 00 00 00 00
          2 | (0,1)  |      16 | f     | f    | 01 00 00 00 00 00 00 00
          3 | (0,12) |      16 | f     | f    | 02 00 00 00 00 00 00 00
          4 | (0,2)  |      16 | f     | f    | 02 00 00 00 00 00 00 00
          5 | (0,13) |      16 | f     | f    | 03 00 00 00 00 00 00 00
          6 | (0,3)  |      16 | f     | f    | 03 00 00 00 00 00 00 00
          7 | (0,14) |      16 | f     | f    | 04 00 00 00 00 00 00 00
          8 | (0,4)  |      16 | f     | f    | 04 00 00 00 00 00 00 00
          9 | (0,15) |      16 | f     | f    | 05 00 00 00 00 00 00 00
         10 | (0,5)  |      16 | f     | f    | 05 00 00 00 00 00 00 00
         11 | (0,16) |      16 | f     | f    | 06 00 00 00 00 00 00 00
         12 | (0,6)  |      16 | f     | f    | 06 00 00 00 00 00 00 00
         13 | (0,17) |      16 | f     | f    | 07 00 00 00 00 00 00 00
         14 | (0,7)  |      16 | f     | f    | 07 00 00 00 00 00 00 00
         15 | (0,18) |      16 | f     | f    | 08 00 00 00 00 00 00 00
         16 | (0,8)  |      16 | f     | f    | 08 00 00 00 00 00 00 00
         17 | (0,19) |      16 | f     | f    | 09 00 00 00 00 00 00 00
         18 | (0,9)  |      16 | f     | f    | 09 00 00 00 00 00 00 00
         19 | (0,20) |      16 | f     | f    | 0a 00 00 00 00 00 00 00
         20 | (0,10) |      16 | f     | f    | 0a 00 00 00 00 00 00 00
(20 rows)
```

## 4、level=1的状态

level=0，索引包括meta page，root page，leaf page。索引结构示例图：

insert  1000条数据，索引大小40KB 5个page，其中包括一个meta page，一个root page，三个leaf page。根据bt_metap('idx_t_id')函数，可见root page no是root=3，level=1。根据bt_page_stats('idx_t_id', 3)，可见btpo_flags=2，btpo=1级表示倒数第二层。live_items=3表示只有三个选项，分别指向三个leaf page，data为每个叶子节点的最小值，因为左起第一个leaf page的最小是无穷小，data为null。

```sql
postgres=# truncate table t;
TRUNCATE TABLE
postgres=# insert into t select generate_series(1,1000),md5(random()::text);
INSERT 0 1000
postgres=# select pg_relation_size('idx_t_id','main');
 pg_relation_size
------------------
            40960
(1 row)
postgres=# select * from bt_metap('idx_t_id');
 magic  | version | root | level | fastroot | fastlevel
--------+---------+------+-------+----------+-----------
 340322 |       2 |    3 |     1 |        3 |         1
(1 row)
postgres=# \x
Expanded display is on.
postgres=# select * from bt_page_stats('idx_t_id', 3);
-[ RECORD 1 ]-+-----
blkno         | 3
type          | r
live_items    | 3
dead_items    | 0
avg_item_size | 13
page_size     | 8192
free_size     | 8096
btpo_prev     | 0
btpo_next     | 0
btpo          | 1
btpo_flags    | 2
postgres=# select * from bt_page_items('idx_t_id', 3);
 itemoffset | ctid  | itemlen | nulls | vars |          data
------------+-------+---------+-------+------+-------------------------
          1 | (1,1) |       8 | f     | f    |
          2 | (2,1) |      16 | f     | f    | 6f 01 00 00 00 00 00 00
          3 | (4,1) |      16 | f     | f    | dd 02 00 00 00 00 00 00
(3 rows)
```

三个leaf节点的no分别为1，2，4（meta page = 0，root page=3），注意观察btpo_prev，btpo_next数据，btpo=0级表示最底层，btpo_flag=1表示叶子节点。

```sql
postgres=# select blkno,type,live_items,btpo_prev,btpo_next,btpo,btpo_flags from bt_page_stats('idx_t_id', 1);
 blkno | type | live_items | btpo_prev | btpo_next | btpo | btpo_flags
-------+------+------------+-----------+-----------+------+------------
     1 | l    |        367 |         0 |         2 |    0 |          1
(1 row)
postgres=# select blkno,type,live_items,btpo_prev,btpo_next,btpo,btpo_flags from bt_page_stats('idx_t_id', 2);
 blkno | type | live_items | btpo_prev | btpo_next | btpo | btpo_flags
-------+------+------------+-----------+-----------+------+------------
     2 | l    |        367 |         1 |         4 |    0 |          1
(1 row)
postgres=# select blkno,type,live_items,btpo_prev,btpo_next,btpo,btpo_flags from bt_page_stats('idx_t_id', 4);
 blkno | type | live_items | btpo_prev | btpo_next | btpo | btpo_flags
-------+------+------------+-----------+-----------+------+------------
     4 | l    |        268 |         2 |         0 |    0 |          1
(1 row)
postgres=#
```

观察三个leaf page

1、第一个索引项，都是下一个page的的最小索引项。

2、第二个索引项，都是本page的最小索引项。

3、最后一个leaf  page（本例子中page no=4)，因为没有下一个page，索引第一个多样项就是本page的最小索引项。

4、所以可以得出本page的索引项范围：小于第一个索引项，大于等于第二个索引项。（最后一个leaf page除外）

```
postgres=# select * from bt_page_items('idx_t_id',1) where itemoffset in(1,2,3,365,366,367);
 itemoffset | ctid  | itemlen | nulls | vars |          data
------------+-------+---------+-------+------+-------------------------
          1 | (3,7) |      16 | f     | f    | 6f 01 00 00 00 00 00 00
          2 | (0,1) |      16 | f     | f    | 01 00 00 00 00 00 00 00
          3 | (0,2) |      16 | f     | f    | 02 00 00 00 00 00 00 00
        365 | (3,4) |      16 | f     | f    | 6c 01 00 00 00 00 00 00
        366 | (3,5) |      16 | f     | f    | 6d 01 00 00 00 00 00 00
        367 | (3,6) |      16 | f     | f    | 6e 01 00 00 00 00 00 00
(6 rows)

postgres=# select * from bt_page_items('idx_t_id',2) where itemoffset in(1,2,3,365,366,367);
 itemoffset |  ctid  | itemlen | nulls | vars |          data
------------+--------+---------+-------+------+-------------------------
          1 | (6,13) |      16 | f     | f    | dd 02 00 00 00 00 00 00
          2 | (3,7)  |      16 | f     | f    | 6f 01 00 00 00 00 00 00
          3 | (3,8)  |      16 | f     | f    | 70 01 00 00 00 00 00 00
        365 | (6,10) |      16 | f     | f    | da 02 00 00 00 00 00 00
        366 | (6,11) |      16 | f     | f    | db 02 00 00 00 00 00 00
        367 | (6,12) |      16 | f     | f    | dc 02 00 00 00 00 00 00
(6 rows)

postgres=# select * from bt_page_items('idx_t_id',4) where itemoffset in(1,2,3,266,267,268);
 itemoffset |  ctid  | itemlen | nulls | vars |          data
------------+--------+---------+-------+------+-------------------------
          1 | (6,13) |      16 | f     | f    | dd 02 00 00 00 00 00 00
          2 | (6,14) |      16 | f     | f    | de 02 00 00 00 00 00 00
          3 | (6,15) |      16 | f     | f    | df 02 00 00 00 00 00 00
        266 | (8,38) |      16 | f     | f    | e6 03 00 00 00 00 00 00
        267 | (8,39) |      16 | f     | f    | e7 03 00 00 00 00 00 00
        268 | (8,40) |      16 | f     | f    | e8 03 00 00 00 00 00 00
(6 rows)
```

## 5、验证索引膨胀

在现有数据的基础上，page no = 2 页中最大索引项ID是732，最小索引项ID是367。删除最小值和最大值之间的数据，可以看到page no = 2 page中有大量空闲空间。

```
postgres=# select * from t where ctid = '(3,7)';
 id  |                v
-----+----------------------------------
 367 | b9d4b6de1a7edea0786452127883a5ad
(1 row)
postgres=# select * from t where ctid = '(6,12)';
 id  |                v
-----+----------------------------------
 732 | b9d00f416e523d7c8bacd682a707bcb9
(1 row)
postgres=# delete from t where id > 367 and id <732;
DELETE 364
postgres=# select * from bt_page_items('idx_t_id',2) where itemoffset in(1,2,3,365,366,367);
 itemoffset |  ctid  | itemlen | nulls | vars |          data
------------+--------+---------+-------+------+-------------------------
          1 | (6,13) |      16 | f     | f    | dd 02 00 00 00 00 00 00
          2 | (3,7)  |      16 | f     | f    | 6f 01 00 00 00 00 00 00
          3 | (3,8)  |      16 | f     | f    | 70 01 00 00 00 00 00 00
        365 | (6,10) |      16 | f     | f    | da 02 00 00 00 00 00 00
        366 | (6,11) |      16 | f     | f    | db 02 00 00 00 00 00 00
        367 | (6,12) |      16 | f     | f    | dc 02 00 00 00 00 00 00
(6 rows)
postgres=# vacuum t;
VACUUM
postgres=# select * from bt_page_items('idx_t_id',2);
 itemoffset |  ctid  | itemlen | nulls | vars |          data
------------+--------+---------+-------+------+-------------------------
          1 | (6,13) |      16 | f     | f    | dd 02 00 00 00 00 00 00
          2 | (3,7)  |      16 | f     | f    | 6f 01 00 00 00 00 00 00
          3 | (6,12) |      16 | f     | f    | dc 02 00 00 00 00 00 00
(3 rows)

```

再insert id为1001-1200之间的数据，可以看到，page no = 2 page的空间并没有得到利用。而是新开辟了no = 5的page。no=2的page依然只有3个索引项。

```sql
postgres=# insert into t select generate_series(1001,1200),md5(random()::text);
INSERT 0 200
postgres=# select pg_relation_size('idx_t_id','main');
 pg_relation_size
------------------
            49152
(1 row)
postgres=# select blkno,type,live_items,btpo_prev,btpo_next,btpo,btpo_flags from bt_page_stats('idx_t_id', 4);
 blkno | type | live_items | btpo_prev | btpo_next | btpo | btpo_flags
-------+------+------------+-----------+-----------+------+------------
     4 | l    |        367 |         2 |         5 |    0 |          1
(1 row)
postgres=# select blkno,type,live_items,btpo_prev,btpo_next,btpo,btpo_flags from bt_page_stats('idx_t_id', 5);
 blkno | type | live_items | btpo_prev | btpo_next | btpo | btpo_flags
-------+------+------------+-----------+-----------+------+------------
     5 | l    |        102 |         4 |         0 |    0 |          1
(1 row)
postgres=# select * from bt_page_items('idx_t_id', 2);
 itemoffset |  ctid  | itemlen | nulls | vars |          data
------------+--------+---------+-------+------+-------------------------
          1 | (6,13) |      16 | f     | f    | dd 02 00 00 00 00 00 00
          2 | (3,7)  |      16 | f     | f    | 6f 01 00 00 00 00 00 00
          3 | (6,12) |      16 | f     | f    | dc 02 00 00 00 00 00 00
(3 rows)
```

再insert id 再367到732之间的数据，观察no=2的page空间得到利用。

```sql
postgres=# insert into t values(368,'a'),(369,'b');
INSERT 0 2
postgres=# select * from bt_page_items('idx_t_id', 2);
 itemoffset |  ctid  | itemlen | nulls | vars |          data
------------+--------+---------+-------+------+-------------------------
          1 | (6,13) |      16 | f     | f    | dd 02 00 00 00 00 00 00
          2 | (3,7)  |      16 | f     | f    | 6f 01 00 00 00 00 00 00
          3 | (5,1)  |      16 | f     | f    | 70 01 00 00 00 00 00 00
          4 | (5,2)  |      16 | f     | f    | 71 01 00 00 00 00 00 00
          5 | (6,12) |      16 | f     | f    | dc 02 00 00 00 00 00 00
(5 rows)
postgres=#
```

## 5、验证索引空页vacuum回收与再利用

将no=2 page中的全部数据删掉，查看no=2的page并没有被OS回收。btpo_flags=0，type=d。现在no=1，4，5的leaf page链接在一起。形成3个叶子节点。

```sql
postgres=# delete from t where id >= 367 and id <=732;
DELETE 4
postgres=# vacuum t;
VACUUM
postgres=# select pg_relation_size('idx_t_id','main');
 pg_relation_size
------------------
            49152
(1 row)
postgres=# \x
Expanded display is on.
postgres=# select * from bt_page_stats('idx_t_id', 2);
-[ RECORD 1 ]-+-----
blkno         | 2
type          | d
live_items    | 0
dead_items    | 0
avg_item_size | 0
page_size     | 8192
free_size     | 0
btpo_prev     | -1
btpo_next     | -1
btpo          | 589
btpo_flags    | 0

postgres=# \x
Expanded display is off.
postgres=#
postgres=# select * from bt_page_items('idx_t_id', 2);
NOTICE:  page is deleted
 itemoffset |      ctid      | itemlen | nulls | vars | data
------------+----------------+---------+-------+------+------
          1 | (4294967295,0) |       8 | f     | f    |
(1 row)
postgres=# select blkno,type,live_items,btpo_prev,btpo_next,btpo,btpo_flags from bt_page_stats('idx_t_id', 1);
 blkno | type | live_items | btpo_prev | btpo_next | btpo | btpo_flags
-------+------+------------+-----------+-----------+------+------------
     1 | l    |        367 |         0 |         4 |    0 |          1
(1 row)

postgres=# select blkno,type,live_items,btpo_prev,btpo_next,btpo,btpo_flags from bt_page_stats('idx_t_id', 4);
 blkno | type | live_items | btpo_prev | btpo_next | btpo | btpo_flags
-------+------+------------+-----------+-----------+------+------------
     4 | l    |        367 |         1 |         5 |    0 |          1
(1 row)

postgres=# select blkno,type,live_items,btpo_prev,btpo_next,btpo,btpo_flags from bt_page_stats('idx_t_id', 5);
 blkno | type | live_items | btpo_prev | btpo_next | btpo | btpo_flags
-------+------+------------+-----------+-----------+------+------------
     5 | l    |        102 |         4 |         0 |    0 |          1
(1 row)

postgres=# select pg_relation_size('idx_t_id','main');
 pg_relation_size
------------------
            49152
(1 row)
```

再insert id为1201-1600之间的数据，可发现，no=2的leaf page被再次利用。叶子节点的排列顺序1，4，5，2。

```sql
postgres=# insert into t select generate_series(1201,1600),md5(random()::text);
INSERT 0 400
postgres=# select pg_relation_size('idx_t_id','main');
 pg_relation_size
------------------
            49152
(1 row)

postgres=# select blkno,type,live_items,btpo_prev,btpo_next,btpo,btpo_flags from bt_page_stats('idx_t_id', 5);
 blkno | type | live_items | btpo_prev | btpo_next | btpo | btpo_flags
-------+------+------------+-----------+-----------+------+------------
     5 | l    |        367 |         4 |         2 |    0 |          1
(1 row)

postgres=# select blkno,type,live_items,btpo_prev,btpo_next,btpo,btpo_flags from bt_page_stats('idx_t_id', 2);
 blkno | type | live_items | btpo_prev | btpo_next | btpo | btpo_flags
-------+------+------------+-----------+-----------+------+------------
     2 | l    |        136 |         5 |         0 |    0 |          1
(1 row)

postgres=# select blkno,type,live_items,btpo_prev,btpo_next,btpo,btpo_flags from bt_page_stats('idx_t_id', 1);
 blkno | type | live_items | btpo_prev | btpo_next | btpo | btpo_flags
-------+------+------------+-----------+-----------+------+------------
     1 | l    |        367 |         0 |         4 |    0 |          1
(1 row)

postgres=# select blkno,type,live_items,btpo_prev,btpo_next,btpo,btpo_flags from bt_page_stats('idx_t_id', 4);
 blkno | type | live_items | btpo_prev | btpo_next | btpo | btpo_flags
-------+------+------------+-----------+-----------+------+------------
     4 | l    |        367 |         1 |         5 |    0 |          1
(1 row)

postgres=# select blkno,type,live_items,btpo_prev,btpo_next,btpo,btpo_flags from bt_page_stats('idx_t_id', 5);
 blkno | type | live_items | btpo_prev | btpo_next | btpo | btpo_flags
-------+------+------------+-----------+-----------+------+------------
     5 | l    |        367 |         4 |         2 |    0 |          1
(1 row)

postgres=# select blkno,type,live_items,btpo_prev,btpo_next,btpo,btpo_flags from bt_page_stats('idx_t_id', 2);
 blkno | type | live_items | btpo_prev | btpo_next | btpo | btpo_flags
-------+------+------------+-----------+-----------+------+------------
     2 | l    |        136 |         5 |         0 |    0 |          1
(1 row)

postgres=#
```

## 6、验证索引存在fsm文件

```
postgres=# select pg_relation_size('idx_t_id','main');
 pg_relation_size
------------------
            49152
(1 row)

postgres=# select pg_relation_size('idx_t_id','fsm');
 pg_relation_size
------------------
            24576
(1 row)
```

## 7、结论

