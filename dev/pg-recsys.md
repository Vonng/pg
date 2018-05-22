---
title: "纯PostgreSQL-5分钟实现推荐系统"
date: "2017-04-05"
author: "Vonng"
description: "用PostgreSQL 5分钟实现一个最简单ItemCF推荐系统"
categories: ["Dev"]
tags: ["Postgres"]
type: "post"
---



# 纯PostgreSQL-5分钟实现推荐系统

推荐系统大家都熟悉，猜你喜欢，淘宝个性化什么的，前年双十一搞了个大新闻，还拿了CEO特别贡献奖。

今天就来说说怎么用PostgreSQL 5分钟实现一个最简单ItemCF推荐系统，以推荐系统最喜闻乐见的[movielens数据集](https://grouplens.org/datasets/movielens/)为例。


## 原理

ItemCF的原理可以看项亮的《推荐系统实战》，不过还是稍微提一下吧，了解的直接跳过就好。

Item CF，全称Item Collaboration Filter，即基于物品的协同过滤，是目前业界应用最多的推荐算法。ItemCF不需要物品与用户的标签、属性，只要有用户对物品的行为日志就可以了，同时具有很好的可解释性。所以无论是亚马逊，Hulu，YouTube，balabala用的都是该算法。

ItemCF算法的核心思想是：给用户推荐那些和他们之前**喜欢**的物品**相似**的物品。

这里有两个要点：

* 用户喜欢物品怎么表示？
* 物品的相似度怎样表示？

### 用户评分表

可以通过用户评分表来判断用户对物品的喜爱程度，例如电影数据的5分制：5分表示非常喜欢，1分表示不喜欢。

用户评分表有三个核心字段：`user_id, movie_id, rating`，分别是用户ID，物品ID，用户对物品的评分。

怎样得到这个表呢？如果本来就是评论打分网站在做推荐系统，直接有用户对电影，音乐，小说的评分记录那是最好不过。其他的场景，比如电商，社交网络，则可以通过**用户对物品的行为日志**生成这张评分表。例如可以为“浏览”，“点击”，“收藏”，“购买”，点击“我不喜欢”按钮这些行为分别设一个喜好权重：`0.1, 0.2, 0.3, 0.4, -100`。将所有行为评分加权求和，最终得到这张用户对物品的评分表来，事就成了一半了。

### 物品相似度

还需要解决的一个问题是物品相似度的**计算**与**表示**。

假设一共有$N$个物品，则物品相似度数据可以表示为一个$N \times N$的矩阵，第$i$行$j$列的值表示物品$i$与物品$j$之间的相似度。这样相似度**表示**的问题就解决了。

第二个问题是物品相似度矩阵的计算。

但在计算前，首先必须定义，什么是物品的相似度？

两个物品之间的相似度有很多种定义与计算方式，如果我们有物品的各种属性数据(类型，大小，价格，风格，标签)的话，就可以在属性空间定义各式各样的“距离”，来定义相似度。但ItemCF的亮点就在于，不需要物品的属性标签数据也可以计算其相似度来。其核心思想是：如果一对物品被很多人同时喜欢，则认为这一对物品更为相似。

令$N(i)$为喜欢物品$i$的用户集合，$|N(i)|$为喜欢物品$i$的人数，$|N(i) \cap N(j)|$为同时喜欢物品$i,j$的人数，则物品$i,j$之间的相似度$_{ij}$可w以表示为：

$$
w_{ij} = \frac{|N(i) \cap N(j)|}{ \sqrt{ |N(i)| * |N(j)|}}
$$


即：同时喜欢物品$i,j$的人数，除以喜爱物品$i$人数和喜爱物品$j$人数的几何平均数。

这样，就可以通过用户对物品的行为日志，导出一份物品之间的相似矩阵数据来。

### 推荐物品

现在有一个用户$u$，他对物品$j$的评分可以通过以下公式计算：

$$
\displaystyle
p_{uj} = \sum_{i \in N(u) \cap S(i, K)} w_{ji}r_{ui}
$$

其中，用户$i$对物品$i_1,i_2,\cdots,i_n$的评分分别为$r_1,r_2,…,r_n$，而物品$i_1,i_2,\cdots,i_n$与目标物品$j$的相似度分别为$w_1,w_2,\cdots,w_n$。以用户$u$评分过的物品集合作为纽带，按照评分以相似度加权求和，就可以得到用户$u$对物品$j$的评分了。

对这个预测评分$p$排序取TopN，就得到了用户$u$的推荐物品列表





## 实践

说了这么多废话，赶紧燥起来。

### 第一步：准备数据

下载[Movielens数据集](https://grouplens.org/datasets/movielens/)，开发测试的话选小规模的(100k)就可以。对于ItemCF来说，有用的数据就是用户行为日志，即文件`ratings.csv`：[地址](http://files.grouplens.org/datasets/movielens/ml-latest-small.zip)

```sql
-- movielens 用户评分数据集
CREATE TABLE mls_ratings (
  user_id   INTEGER,
  movie_id  INTEGER,
  rating    TEXT,
  timestamp INTEGER,
  PRIMARY KEY (user_id, movie_id)
);

-- 从CSV导入数据，并将评分乘以2变为2~10的整数便于处理，将Unix时间戳转换为日期类型
COPY mls_ratings FROM '/Users/vonng/Dev/recsys/ml-latest-small/ratings.csv' DELIMITER ',' CSV HEADER;
ALTER TABLE mls_ratings
  ALTER COLUMN rating SET DATA TYPE INTEGER USING (rating :: DECIMAL * 2) :: INTEGER;
ALTER TABLE mls_ratings
  ALTER COLUMN timestamp SET DATA TYPE TIMESTAMPTZ USING to_timestamp(timestamp :: DOUBLE PRECISION);
```

得到的数据长这样：第一列用户ID列表，第二列电影ID列表，第三列是评分，最后是时间戳。一共十万条

```
movielens=# select * from mls_ratings limit 10;
 user_id | movie_id | rating |       timestamp
---------+----------+--------+------------------------
       1 |       31 |      5 | 2009-12-14 10:52:24+08
       1 |     1029 |      6 | 2009-12-14 10:52:59+08
       1 |     1061 |      6 | 2009-12-14 10:53:02+08
       1 |     1129 |      4 | 2009-12-14 10:53:05+08
```



### 第二步：计算物品相似度

#### 物品相似度的DDL

```sql
-- 物品相似度表，这是把矩阵用<i,j,M_ij>的方式在数据库中表示。
CREATE TABLE mls_similarity (
  i INTEGER,
  j INTEGER,
  p FLOAT,
  PRIMARY KEY (i, j)
);
```

物品相似度是一个矩阵，虽说PostgreSQL里提供了数组，多维数组，自定义数据结构，不过这里为了方便起见还是使用了最传统的矩阵表示方法：坐标索引法$(i,j,m_{ij})$。其中前两个元素为矩阵下标，各自表示物品的ID。最后一个元素存储了这一对物品的相似度。

#### 物品相似度的计算

计算物品相似度，要计算两个中间数据：

* 每个物品被用户喜欢的次数：$|N(i)|$
* 每对物品共同被同一个用户喜欢的次数 $|N(i) \cap N(j)|$

如果是用编程语言，那自然可以一趟(One-Pass)解决两个问题。不过SQL就要稍微麻烦点了，好处是不用操心撑爆内存的问题。

这里可以使用PostgreSQL的With子句功能，计算两个临时结果供后续使用，一条SQL就搞定相似矩阵计算：

```sql
-- 计算物品相似度矩阵: 3m 53s
WITH mls_occur AS ( -- 中间表：计算每个电影被用户看过的次数
    SELECT
      movie_id,     -- 电影ID: i
      count(*) AS n -- 看过电影i的人数: |N(i)|
    FROM mls_ratings
    GROUP BY movie_id
),
    mls_common AS ( -- 中间表：计算每对电影被用户同时看过的次数
      SELECT
        a.movie_id AS i, -- 电影ID: i
        b.movie_id AS j, -- 电影ID: j
        count(*)   AS n  -- 同时看过电影i和j的人数: |N(i) ∩ N(j)|
      FROM mls_ratings a INNER JOIN mls_ratings b ON a.user_id = b.user_id
      GROUP BY i, j
  )
INSERT INTO mls_similarity
  SELECT
    i,
    j,
    n / sqrt(n1 * n2) AS p  -- 距离公式
  FROM
    mls_common c,
    LATERAL (SELECT n AS n1 FROM mls_occur WHERE movie_id = i) n1,
    LATERAL (SELECT n AS n2 FROM mls_occur WHERE movie_id = j) n2;
```

物品相似度表大概长这样：

```
movielens=# SELECT * FROM mls_similarity LIMIT 10;
   i    | j |         p
--------+---+--------------------
 140267 | 1 |  0.110207753755597
   2707 | 1 |  0.180280682843137
 140174 | 1 |  0.113822078644894
   7482 | 1 | 0.0636284762975778
```

实际上还可以修剪修剪，比如计算时非常小的相似度干脆可以直接删掉。也可以用整个表中相似度的最大值作为单位1，进行归一化。这里都不弄了。



### 第三步：进行推荐！

现在假设我们为ID为10的用户推荐10部他没看过的电影，该怎么做呢？

```sql
WITH seed AS	-- 10号用户评分过的影片作为种子集合
  (SELECT movie_id,rating FROM mls_ratings WHERE user_id = 10)
SELECT
  j as movie_id,	-- 所有待预测评分的电影ID
  sum(seed.rating * p) AS score -- 预测加权分，按此字段降序排序取TopN
FROM
  seed LEFT JOIN mls_similarity s ON seed.movie_id = s.i 
  WHERE j not in (SELECT DISTINCT movie_id FROM seed) -- 去除已经看过的电影(可选)
GROUP BY j ORDER BY score DESC LIMIT 10; -- 聚合，排序，取TOP
```

推荐结果如下：

```
 movie_id |      score
----------+------------------
     1270 | 121.487735902517
     1214 | 116.146138947698
     1580 | 116.015331936539
     2797 | 115.144083402858
     1265 | 114.959033115913
      260 | 114.313571128143
     2716 | 113.087151014987
     1097 |  113.07771922959
     1387 | 112.869891345883
     2916 |  112.84326997566
```

可以进一步包装一下，把它变成一个存储过程`get_recommendation`

```sql
CREATE OR REPLACE FUNCTION get_recommendation(userid INTEGER)
  RETURNS JSONB AS $$ BEGIN
  RETURN (SELECT jsonb_agg(movie_id)
          FROM (WITH seed AS
          (SELECT movie_id,rating FROM mls_ratings WHERE user_id = userid)
                SELECT
                  j as movie_id,
                  sum(seed.rating * p) AS score
                FROM
                  seed LEFT JOIN mls_similarity s ON seed.movie_id = s.i
                WHERE j not in (SELECT DISTINCT movie_id FROM seed)
                GROUP BY j ORDER BY score DESC LIMIT 10) res);
END $$ LANGUAGE plpgsql STABLE;
```

这样用起来更方便啦，同时也可以在这里加入一些其他的处理逻辑：比如过滤掉禁片黄片，去除用户明确表示过不喜欢的电影，加入一些热门电影，引入一些随机惊喜，打点小广告之类的。

```
movielens=# SELECT get_recommendation(11) as res;
                                  res
-----------------------------------------------------------------------
 [80489, 96079, 79132, 59315, 91529, 69122, 58559, 59369, 1682, 71535]
```

最后写个应用把这个存储过程作为OpenAPI开放出去，事就这样成了。

关于这一步可以参考前一篇：[当PostgreSQL遇上GraphQL：Postgraphql](https://www.atatech.org/articles/70532)中的做法，直接由存储过程生成GraphQL API，啥都不用操心了。



### What's more

几行SQL一条龙执行下来，加上下载数据的时间，总共也就五分钟吧。一个简单的推荐系统就这样搭建起来了。

但一个真正的生产系统还需要考虑许许多多其他问题，例如，性能。

这里比如说计算相似度矩阵的时候，才100k条记录花了三四分钟，不太给力。而且这么多SQL写起来，管理起来也麻烦，有没有更好的方案？

这儿有个基于PostgreSQL源码魔改的推荐数据库：[RecDB](http://www-users.cs.umn.edu/~sarwat/RecDB/)，直接用C实现了推荐系统相关的功能扩展，性能看起来杠杠地；同时还包装了SQL语法糖，一行SQL建立推荐系统！再一行SQL就开始使用啦。

```sql
-- 计算推荐所需的信息
CREATE RECOMMENDER MovieRec ON ml_ratings
USERS FROM userid
ITEMS FROM itemid
EVENTS FROM ratingval
USING ItemCosCF

-- 进行推荐！
SELECT * FROM ml_ratings R
RECOMMEND R.itemid TO R.userid ON R.ratingval USING ItemCosCF
WHERE R.userid = 1
ORDER BY R.ratingval
LIMIT 10
```

PostgreSQL能干的事情太多了，最先进的开源关系数据库确实不是吹的，其实真的可以试一试。