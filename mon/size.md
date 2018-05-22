# 监控PG中的表大小

### 表的空间布局

宽泛意义上的**表（Table）**，包含了**本体表**与**TOAST表**两个部分：

* 本体表，存储关系本身的数据，即狭义的关系，`relkind='r'`。
* TOAST表，与本体表一一对应，存储过大的字段，`relinkd='t'`。

而每个表，又由**主体**与**索引**两个**关系（Relation）**组成（对本体表而言，可以没有索引关系）

* 主体关系：存储元组。
* 索引关系：存储索引元组。

每个**关系**又可能会有**四种分支**：

* main: 关系的主文件，编号为0

* fsm：保存关于main分支中空闲空间的信息，编号为1
* vm：保存关于main分支中可见性的信息，编号为2
* init：用于不被日志记录（unlogged）的的表和索引，很少见的特殊分支，编号为3

每个分支存储为磁盘上的一到多个文件：超过1GB的文件会被划分为最大1GB的多个段。



综上所述，一个表并不是看上去那么简单，它由几个关系组成：

* 本体表的主体关系（单个）
* 本体表的索引（多个）
* TOAST表的主体关系（单个）
* TOAST表的索引（单个）

而每个关系实际上可能又包含了1~3个分支：`main`（必定存在），`fsm`，`vm`。



### 获取表的附属关系

使用下列查询，列出所有的分支oid。

```sql
select
  nsp.nspname,
  rel.relname,
  rel.relnamespace    as nspid,
  rel.oid             as relid,
  rel.reltoastrelid   as toastid,
  toastind.indexrelid as toastindexid,
  ind.indexes
from
  pg_namespace nsp
  join pg_class rel on nsp.oid = rel.relnamespace
  , LATERAL ( select array_agg(indexrelid) as indexes from pg_index where indrelid = rel.oid) ind
  , LATERAL ( select indexrelid from pg_index where indrelid = rel.reltoastrelid) toastind
where nspname not in ('pg_catalog', 'information_schema') and rel.relkind = 'r';
```

```
 nspname |  relname   |  nspid  |  relid  | toastid | toastindexid |      indexes
---------+------------+---------+---------+---------+--------------+--------------------
 public  | aoi        | 4310872 | 4320271 | 4320274 |      4320276 | {4325606,4325605}
 public  | poi        | 4310872 | 4332324 | 4332327 |      4332329 | {4368886}
```



### 统计函数

PG提供了一系列函数用于确定各个部分占用的空间大小。

| 函数                            | 统计口径                                 |
| ------------------------------- | ---------------------------------------- |
| `pg_total_relation_size(oid) `  | 整个关系，包括表，索引，TOAST等。        |
| `pg_indexes_size(oid) `         | 关系索引部分所占空间                     |
| `pg_table_size(oid)`            | 关系中除索引外部分所占空间               |
| `pg_relation_size(oid) `        | 获取一个关系主文件部分的大小（main分支） |
| `pg_relation_size(oid, 'main')` | 获取关系`main`分支大小                   |
| `pg_relation_size(oid, 'fsm')`  | 获取关系`fsm`分支大小                    |
| `pg_relation_size(oid, 'vm')`   | 获取关系`vm`分支大小                     |
| `pg_relation_size(oid, 'init')` | 获取关系`init`分支大小                   |

虽然在物理上一张表由这么多文件组成，但从逻辑上我们通常只关心两个东西的大小：表与索引。因此这里要用到的主要就是两个函数：`pg_indexes_size`与`pg_table_size`，对普通表其和为`pg_total_relation_size`。

而通常表大小的部分可以这样计算：

```sql
 pg_table_size(relid)
 	= pg_relation_size(relid, 'main') 
 	+ pg_relation_size(relid, 'fsm') 
 	+ pg_relation_size(relid, 'vm') 
 	+ pg_total_relation_size(reltoastrelid)
 	
 pg_indexes_size(relid)
 	= (select sum(pg_total_relation_size(indexrelid)) where indrelid = relid)
```

注意，TOAST表也有自己的索引，但有且仅有一个，因此使用`pg_total_relation_size(reltoastrelid)`可计算TOAST表的整体大小。



### 例：统计某一张表及其相关关系UDTF

```sql
SELECT
  oid,
  relname,
  relnamespace::RegNamespace::Text               as nspname,
  relkind                                        as relkind,
  reltuples                                      as tuples,
  relpages                                       as pages,
  pg_total_relation_size(oid)                    as size
  FROM pg_class
WHERE oid = ANY(array(SELECT 16418 as id -- main
UNION ALL SELECT indexrelid FROM pg_index WHERE indrelid = 16418 -- index
UNION ALL SELECT reltoastrelid FROM pg_class WHERE oid = 16418)); -- toast
```

可以将其包装为UDTF：`pg_table_size_detail`，便于使用：

```sql
CREATE OR REPLACE FUNCTION pg_table_size_detail(relation RegClass)
  RETURNS TABLE(
    id      oid,
    pid     oid,
    relname name,
    nspname text,
    relkind "char",
    tuples  bigint,
    pages   integer,
    size    bigint
  )
AS $$
BEGIN
  RETURN QUERY
  SELECT
    rel.oid,
    relation::oid,
    rel.relname,
    rel.relnamespace :: RegNamespace :: Text as nspname,
    rel.relkind                              as relkind,
    rel.reltuples::bigint                    as tuples,
    rel.relpages                             as pages,
    pg_total_relation_size(oid)              as size
  FROM pg_class rel
  WHERE oid = ANY (array(
      SELECT relation as id -- main
      UNION ALL SELECT indexrelid FROM pg_index WHERE indrelid = relation -- index
      UNION ALL SELECT reltoastrelid FROM pg_class WHERE oid = relation)); -- toast
END;
$$
LANGUAGE PlPgSQL;

SELECT * FROM pg_table_size_detail(16418);

```

返回结果样例：

```
geo=# select * from  pg_table_size_detail(4325625);
   id    |   pid   |        relname        | nspname  | relkind |  tuples  |  pages  |    size
---------+---------+-----------------------+----------+---------+----------+---------+-------------
 4325628 | 4325625 | pg_toast_4325625      | pg_toast | t       |   154336 |   23012 |   192077824
 4419940 | 4325625 | idx_poi_adcode_btree  | gaode    | i       | 62685464 |  172058 |  1409499136
 4419941 | 4325625 | idx_poi_cate_id_btree | gaode    | i       | 62685464 |  172318 |  1411629056
 4419942 | 4325625 | idx_poi_lat_btree     | gaode    | i       | 62685464 |  172058 |  1409499136
 4419943 | 4325625 | idx_poi_lon_btree     | gaode    | i       | 62685464 |  172058 |  1409499136
 4419944 | 4325625 | idx_poi_name_btree    | gaode    | i       | 62685464 |  335624 |  2749431808
 4325625 | 4325625 | gaode_poi             | gaode    | r       | 62685464 | 2441923 | 33714962432
 4420005 | 4325625 | idx_poi_position_gist | gaode    | i       | 62685464 |  453374 |  3714039808
 4420044 | 4325625 | poi_position_geohash6 | gaode    | i       | 62685464 |  172058 |  1409499136
```



### 例：关系大小详情汇总

```sql
select
  nsp.nspname,
  rel.relname,
  rel.relnamespace    as nspid,
  rel.oid             as relid,
  rel.reltoastrelid   as toastid,
  toastind.indexrelid as toastindexid,
  pg_total_relation_size(rel.oid)  as size,
  pg_relation_size(rel.oid) + pg_relation_size(rel.oid,'fsm') 
  + pg_relation_size(rel.oid,'vm') as relsize,
  pg_indexes_size(rel.oid)         as indexsize,
  pg_total_relation_size(reltoastrelid) as toastsize,
  ind.indexids,
  ind.indexnames,
  ind.indexsizes
from pg_namespace nsp
  join pg_class rel on nsp.oid = rel.relnamespace
  ,LATERAL ( select indexrelid from pg_index where indrelid = rel.reltoastrelid) toastind
  , LATERAL ( select  array_agg(indexrelid) as indexids,
                      array_agg(indexrelid::RegClass) as indexnames,
                      array_agg(pg_total_relation_size(indexrelid)) as indexsizes
              from pg_index where indrelid = rel.oid) ind
where nspname not in ('pg_catalog', 'information_schema') and rel.relkind = 'r';
```

