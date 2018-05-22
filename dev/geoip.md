---
author: "Vonng"
title: "使用PostgreSQL实现IP地理逆查询"
description: ""
categories: ["Dev"]
tags: ["PostgreSQL","GeoIP"]
type: "post"
---

# IP归属地查询的高效实现

​	在应用开发中，一个‘很常见’的需求就是GeoIP转换。将请求的来源IP转换为相应的地理坐标，或者行政区划（国家-省-市-县-乡-镇）。这种功能有很多用途，譬如分析网站流量的地理来源，或者干一些坏事。使用PostgreSQL可以多快好省，优雅高效地实现这一需求。

## 0x01 思路方法

​	通常网上的IP地理数据库的形式都是：`start_ip, stop_ip , longitude, latitude`，再缀上一些国家代码，城市代码，邮编之类的属性字段。大概长这样：

| Column       | Type |
| ------------ | ---- |
| start_ip     | text |
| end_ip       | text |
| longitude    | text |
| latitude     | text |
| country_code | text |
| ……           | text |

说到底，其核心是从**IP地址段**到**地理坐标点**的映射。

典型查询实际上是给出一个IP地址，返回该地址对应的地理范围。其逻辑用SQL来表示差不多长这样：

```sql
SELECT longitude, latitude FROM geoip 
WHERE start_ip <= target_ip AND target_ip <= stop_ip;
```

不过，想直接提供服务，还有几个问题需要解决：

* 第一个问题：虽然IPv4实际上是一个`uint32`，但我们已经完全习惯了`123.123.123.123`这种文本表示形式。而这种文本表示形式是无法比较大小的。
* 第二个问题：这里的IP范围是用两个IP边界字段表示的范围，那么这个范围是开区间还是闭区间呢？是不是还需要一个额外字段来表示？
* 第三个问题：想要高效地查询，那么在两个字段上的索引又该如何建立？
* 第四个问题：我们希望所有的IP段相互之间不会出现重叠，但简单的建立在`(start_ip, stop_ip)`上的唯一约束并无法保证这一点，那又如何是好？

令人高兴的是，对于PostgreSQL而言，这些都不是问题。上面四个问题，可以轻松使用PostgreSQL的特性解决。

* 网络数据类型：高性能，紧凑，灵活的网络地址表示。
* 范围类型：对区间的良好抽象，对区间查询与操作的良好支持。
* GiST索引：既能作用于IP地址段，也可以用于地理位置点。
* Exclude约束：泛化的高级UNIQUE约束，从根本上确保数据完整性。



## 0x01 网络地址类型

​		PostgreSQL提供用于存储 IPv4、IPv6 和 MAC 地址的数据类型。包括`cidr`，`inet`以及`macaddr`，并且提供了很多常见的操作函数，不需要再在程序中去实现一些繁琐重复的功能。

​	最常见的网络地址就是IPv4地址，对应着PostgreSQL内建的`inet`类型，inet类型可以用来存储IPv4，IPv6地址，或者带上一个可选的子网。当然这些细节操作都可以[参阅文档](http://www.postgres.cn/docs/9.6/datatype-net-types.html)，在此不详细展开。

​	一个需要注意的点就是，虽然我们知道IPv4实质上是一个`Unsigned Integer`，但在数据库中实际存储成`INTEGER`其实是不行的，因为SQL标准并不支持`Unsigned`这种用法，所以有一半的IP地址的表示就会被解释为负数，在比大小的时候产生令人惊异的结果，真要这么存请使用`BIGINT`。此外，直接面对一堆长长的整数也是相当令人头大的问题，`inet`是最佳的选择。

​	如果需要将IP地址（`inet`类型）与对应的整数相互转换，只要与`0.0.0.0`做加减运算即可；当然也可以使用以下函数，并创建一个类型转换，然后就能直接在`inet`与`bigint`之间来回转换：

```sql
-- inet to bigint
CREATE FUNCTION inet2int(inet) RETURNS bigint AS $$
SELECT $1 - inet '0.0.0.0';
$$ LANGUAGE SQL  IMMUTABLE RETURNS NULL ON NULL INPUT;

-- bigint to inet
CREATE FUNCTION int2inet(bigint) RETURNS inet AS $$
SELECT inet '0.0.0.0' + $1;
$$ LANGUAGE SQL  IMMUTABLE RETURNS NULL ON NULL INPUT;

-- create type conversion
CREATE CAST (inet AS bigint) WITH FUNCTION inet2int(inet);
CREATE CAST (bigint AS inet) WITH FUNCTION int2inet(bigint);

-- test
SELECT 123456::BIGINT::INET;
SELECT '1.2.3.4'::INET::BIGINT;

-- 生成随机的IP地址
SELECT (random() * 4294967295)::BIGINT::INET;
```

`inet`之间的大小比较也相当直接，直接使用大小比较运算符就可以了。实际比较的是底下的整数值。这就解决了第一个问题。



## 0x02 范围类型

​	PostgreSQL的Range类型是一种很实用的功能，它与数组类似，属于一种**泛型**。只要是能被B树索引（可以比大小）的数据类型，都可以作为范围类型的基础类型。它特别适合用来表示区间：整数区间，时间区间，IP地址段等等。而且对于开区间，闭区间，区间索引这类问题有比较细致的考虑。

​	PostgreSQL内置了预定义的`int4range, int8range, numrange, tsrange, tstzrange, daterange`，开箱即用。但没有提供网络地址对应的范围类型，好在自己造一个非常简单：

```sql
CREATE TYPE inetrange AS RANGE(SUBTYPE = inet)
```

当然为了高效地支持GiST索引查询，还需要实现一个距离度量，告诉索引两个`inet`之间的距离应该如何计算：

```sql
-- 定义基本类型间的距离度量
CREATE FUNCTION inet_diff(x INET, y INET) RETURNS FLOAT AS $$
  SELECT (x - y) :: FLOAT;
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- 重新创建inetrange类型，使用新定义的距离度量。
CREATE TYPE inetrange AS RANGE(
  SUBTYPE = inet,
  SUBTYPE_DIFF = inet_diff
)
```

幸运的是，俩网络地址之间的距离定义天然就有一个很简单的计算方法，减一下就好了。

这个新定义的类型使用起来也很简单，构造函数会自动生成：

```bash
geo=# select misc.inetrange('64.60.116.156','64.60.116.161','[)');
inetrange | [64.60.116.156,64.60.116.161)

geo=# select '[64.60.116.156,64.60.116.161]'::inetrange;
inetrange | [64.60.116.156,64.60.116.161]
```

方括号和圆括号分别表示闭区间和开区间，与数学中的表示方法一致。

同时，检测一个IP地址是否落在给定的IP范围内也是很直接的：

```bash
geo=# select '[64.60.116.156,64.60.116.161]'::inetrange @> '64.60.116.160'::inet as res;
res | t
```

有了范围类型，就可以着手构建我们的数据表了。



## 0x03 范围索引

实际上，找一份IP地理对应数据花了我一个多小时，但完成这个需求只用了几分钟。

假设已经有了这样一份数据：

```sql
create table geoips
(
  ips          inetrange,
  geo          geometry(Point),
  country_code text,
  region_code  text,
  city_name    text,
  ad_code      text,
  postal_code  text
);
```

里面的数据大概长这样：

```bash
SELECT ips,ST_AsText(geo) as geo,country_code FROM geoips

 [64.60.116.156,64.60.116.161] | POINT(-117.853 33.7878) | US
 [64.60.116.139,64.60.116.154] | POINT(-117.853 33.7878) | US
 [64.60.116.138,64.60.116.138] | POINT(-117.76 33.7081)  | US
```

那么查询包含某个IP地址的记录就可以写作：

```sql
SELECT * FROM ip WHERE ips @> inet '67.185.41.77';
```

对于600万条记录，约600M的表，在笔者的机器上暴力扫表的平均用时是900ms，差不多单核QPS是1.1，48核生产机器也就差不多三四十的样子。肯定是没法用的。

```sql
CREATE INDEX ON geoips USING GiST(ips);
```

查询用时从1秒变为340微秒，差不多3000倍的提升。

```bash
-- pgbench
\set ip random(0,4294967295)
SELECT * FROM geoips WHERE ips @> :ip::BIGINT::INET;

-- result
latency average = 0.342 ms
tps = 2925.100036 (including connections establishing)
tps = 2926.151762 (excluding connections establishing)
```

折算成生产QPS差不多是十万QPS，啧啧啧，美滋滋。

如果需要把地理坐标转换为行政区划，可以参考上一篇文章：使用PostGIS高效解决行政区划归属地理编码问题。

一次地理编码也就是100微秒，从IP转换为省市区县整个的QPS，单机几万基本问题不大（全天满载相当于七八十亿次调用，根本用不满）。



## 0x04 EXCLUDE约束

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



## 0x05 小结

​	本文介绍了如何使用PostgreSQL特性高效而优雅地解决IP归属地查询的问题。性能表现优异，600w记录0.3ms定位；复杂度低到发指：只要一张表DDL，连索引都不用显式创建就解决了这一问题；数据完整性有充分的保证：百行代码才能解决的问题现在只要添加约束即可，从根本上保证数据完整性。	

​	 PostgreSQL这么棒棒，快快学起来用起来吧~。

​	什么？你问我数据哪里找？搜索MaxMind有真相，在隐秘的小角落能够找到不要钱的GeoIP数据。