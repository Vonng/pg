---
title: "PostgreSQL高级模糊查询"
date: 2021-03-05
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  如何在PostgreSQL中实现比较复杂的模糊查询逻辑？
---


# PostgreSQL高级模糊查询

日常开发中，经常见到有模糊查询的需求。今天就简单聊一聊如何用PostgreSQL实现一些高级一点的模糊查询。

当然这里说的模糊查询，不是`LIKE`表达式前模糊后模糊两侧模糊，这种老掉牙的东西。让我们直接用一个具体的例子开始吧。



## 问题

现在，假设我们做了个应用商店，想给用户提供**搜索功能**。用户随便输入点什么，找出所有与输入内容匹配的应用，排个序返回给用户。

严格来说，这种需求其实是需要一个搜索引擎，最好还是用专用软件，例如ElasticSearch来搞。但实际上只要不是特别复杂的逻辑，也可以很好的用PostgreSQL实现。

### 数据

样例数据如下所示，一张应用表。抽除了所有无关字段，就留下一个应用名称`name`作为主键。

```sql
CREATE TABLE app(name TEXT PRIMARY KEY); 
-- COPY app FROM '/tmp/app.csv';
```

里面的数据差不多长这样，中英混杂，共计150万条。

```ini
Rome travel guide, rome italy map rome tourist attractions directions to colosseum, vatican museum, offline ATAC city rome bus tram underground train maps, 罗马地图,罗马地铁,罗马火车,罗马旅行指南"""
Urban Pics - 游戏俚语词典
世界经典童话故事大全(6到12岁少年儿童睡前故事英语亲子软件) 2 - 高级版
星征服者
客房控制系统
Santa ME! - 易圣诞老人,小精灵快乐的脸效果！
```

### 输入

用户在搜索框可能输入的东西，差不多就跟你自己在应用商店搜索框里会键入的东西差不多。“天气”，“外卖”，“交友”……

而我们想做到的效果，跟你对应用商店查询返回结果的期待也差不多。当然是越准确越好，最好还能按相关度排个序。

当然，作为一个生产级的应用，还必须能及时响应。不可以全表扫描，得用到索引。

那么，这类问题怎么解呢？



## 解题思路

针对这一问题，有三种解题思路。

* 基于`LIKE`的模式匹配。
* 基于`pg_trgm`的字符串相似度的匹配
* 基于自定义分词与倒排索引的模糊查询



## LIKE模式匹配

最简单粗暴的方式就是使用 `LIKE '%'` 模式匹配查询。

老生常谈，没啥技术含量。把用户输入的关键词前后加一个百分号，然后执行这种查询：

```sqlite
SELECT * FROM app WHERE name LIKE '%支付宝%';
```

前后模糊的查询可以通过常规的Btree索引进行加速，注意在PostgreSQL中使用 `LIKE`查询时不要掉到LC_COLLATE的坑里去了，详情参考这篇文章：[**PG中的本地化排序规则**](/zh/blog/2021/03/05/pg中的本地化排序规则/)。

```sql
CREATE INDEX ON app(name COLLATE "C");          -- 后模糊
CREATE INDEX ON app(reverse(name) COLLATE "C"); -- 前模糊
```

如果用户的输入非常**精准清晰**，这样的方式也不是不可以。响应速度也不错。但有两个问题：

* 太机械死板，假设应用厂商发了个名字，在原来的关键词里面加了个空格或者什么符号，这种查询立刻就失效了。
* 没有距离度量，我们没有一个合适的度量，来排序返回的结果。说如果返回几百个结果没有排序，那很难让用户满意的。

* 有时候准确度还是不行，比如一些应用做SEO，把各种头部应用的名字都嵌到自己的名字中来提高搜索排名。



## PG TRGM

PostgreSQL自带了一个名为[`pg_trgm`](http://www.postgres.cn/docs/13/pgtrgm.html)的扩展，提供的基于三字符语素的模糊查询。

`pg_trgm`模块提供用于决定基于 trigram 匹配的字母数字文本相似度的函数和操作符，以及支持快速搜索相似字符串的索引操作符类。

### 使用方式

```sql
-- 使用trgm操作符提取关键词素，并建立gist索引
CREATE INDEX ON app USING gist (name gist_trgm_ops);
```

查询方式也很直观，直接使用`%` 运算符即可，比如从应用表中查到与支付宝相关的应用。

```sql
SELECT name, similarity(name, '支付宝') AS sim FROM app 
WHERE name % '支付宝'  ORDER BY 2 DESC;

         name          |     sim
-----------------------+------------
 支付宝 - 让生活更简单 | 0.36363637
 支付搜                | 0.33333334
 支付社                | 0.33333334
 支付啦                | 0.33333334
(4 rows)

Time: 231.872 ms

Sort  (cost=177.20..177.57 rows=151 width=29) (actual time=251.969..251.970 rows=4 loops=1)
"  Sort Key: (similarity(name, '支付宝'::text)) DESC"
  Sort Method: quicksort  Memory: 25kB
  ->  Index Scan using app_name_idx1 on app  (cost=0.41..171.73 rows=151 width=29) (actual time=145.414..251.956 rows=4 loops=1)
        Index Cond: (name % '支付宝'::text)
Planning Time: 2.331 ms
Execution Time: 252.011 ms
```

**该方式的优点是**：

* 提供了字符串的距离函数`similarity`，可以给出两个字符串之间相似程度的定性度量。因此可以排序。
* 提供了基于3字符组合的分词函数`show_trgm`。
* 可以利用索引加速查询。
* SQL查询语句非常简单清晰，索引定义也很简单明了，维护简单

**该方式的缺点**是：

* 关键词很短的情况（1-2汉字）的情况下召回率很差，**特别是只有一个字时，是无法查询出结果的** 
* 执行效率较低，例如上面这个查询使用了200ms
* 定制性太差，只能使**用它自己定义的逻辑来定义字符串的相似度**，而且这个度量对于中文的效果相当存疑（中文三字词频率很低）
* 对`LC_CTYPE`有特殊的要求，默认`LC_CTYPE = C` 无法正确对中文进行分词。

### 特殊问题

是`pg_trgm`的最大问题是，无法在`LC_CTYPE = C`的实例上针对中文使用。因为 `LC_CTYPE=C` 缺少一些字符的分类定义。不幸的是`LC_CTYPE`一旦设置，**基本除了重新建库是没法更改的**。

通常来说，PostgreSQL的Locale应当设置为`C`，或者至少将本地化规则中的排序规则`LC_COLLATE` 设置为C，以避免巨大的性能损失与功能缺失。但是因为`pg_trgm`的这个“问题”，您需要在创建库时，即指定`LC_CTYPE = <non-C-locale>`。这里基于`i18n`的LOCALE从原理上应该都可以使用。常见的`en_US`与`zh_CN`都是可以的。但注意特别注意，macOS上对Locale的支持存在问题。过于依赖LOCALE的行为会降低代码的可移植性。





## 高级模糊查询

实现一个高级的模糊查询，需要两样东西：**分词**，**倒排索引**。

高级模糊查询，或者说全文检索基于以下思路实现：

* 分词：在维护阶段，每一个被模糊搜索的字段（例如应用名称），都会被**分词**逻辑加工处理成一系列关键词。
* 索引：在数据库中建立关键词到表记录的倒排索引
* 查询：将查询同样拆解为关键词，然后利用查询关键词通过倒排索引找出相关的记录来。

PostgreSQL内建了很多语言的分词程序，可以自动将文档拆分为一系列的关键词，是为全文检索功能。可惜中文还是比较复杂，PG并没有内建的中文分词逻辑，虽然有一些第三方扩展，诸如 pg_jieba, zhparser等，但也年久失修，在新版本的PG上能不能用还是一个问题。

但是这并不影响我们利用PostgreSQL提供的基础设施实现高级模糊查询。实际上上面说的分词逻辑是为了从一个很大的文本（例如网页）中抽取摘要信息（关键字）。而我们的需求恰恰相反，不仅不是抽取摘要进行概括精简，而且需要将关键词扩充，以实现特定的模糊需求。例如，我们完全可以在抽取应用名称关键词的过程中，把这些关键词的汉语拼音，首音缩写，英文缩写一起放进关键词列表中，甚至把作者，公司，分类，等一系列用户可能感兴趣的东西放进去。这样搜索的时候就可以使用丰富的输入了。

### 基本框架

我们先来构建整个问题解决的框架。

1. 编写一个自定义的分词函数，从名称中抽取关键词（每个字，每个二字短语，拼音，英文缩写，放什么都可以）
2. 在目标表上创建一个使用分词函数的函数表达式GIN索引。
3. 通过数组操作或 `tsquery` 等方式定制你的模糊查询

```sql
-- 创建一个分词函数
CREATE OR REPLACE FUNCTION tokens12(text) returns text[] as $$....$$;

-- 基于该分词函数创建表达式索引
CREATE INDEX ON app USING GIN(tokens12(name));

-- 使用关键词进行复杂的定制查询（关键词数组操作）
SELECT * from app where split_to_chars(name) && ARRAY['天气'];

-- 使用关键词进行复杂的定制查询（tsquery操作）
SELECT * from app where to_tsvector123(name) @@ 'BTC &! 钱包 & ! 交易 '::tsquery;
```

PostgreSQL 提供了GIN索引，可以很好的支持**倒排索引**的功能，比较麻烦的是寻找一种比较合适的**中文分词插件**。将应用名称分解为一系列关键词。好在对于此类模糊查询的需求，也用不着像搞搜索引擎，自然语言处理那么精细的语义解析。只要参考`pg_trgm`的思路把中文也给手动一锅烩了就行。除此之外，通过自定义的分词逻辑，还可以实现很多有趣的功能。比如使用**拼音模糊查询，使用拼音首字母缩写模糊查询**。

让我们从最简单的分词开始。

### 快速开始

首先来定义一个非常简单粗暴的分词函数，它只是把输入拆分成2字词语的组合。

```plsql
-- 创建分词函数，将字符串拆为单字，双字组成的词素数组
CREATE OR REPLACE FUNCTION tokens12(text) returns text[] AS $$
DECLARE
    res TEXT[];
BEGIN
    SELECT regexp_split_to_array($1, '') INTO res;
    FOR i in 1..length($1) - 1 LOOP
            res := array_append(res, substring($1, i, 2));
    END LOOP;
    RETURN res;
END;
$$ LANGUAGE plpgsql STRICT PARALLEL SAFE IMMUTABLE;
```

使用这个分词函数，可以将一个应用名称肢解为一系列的语素

```
SELECT tokens2('艾米莉的埃及历险记');
-- {艾米,米莉,莉的,的埃,埃及,及历,历险,险记}
```

现在假设用户搜索关键词“艾米利”，这个关键词被拆分为：

```
SELECT tokens2('艾米莉');
-- {艾米,米莉}
```

然后，我们可以通过以下查询非常迅速地，找到所有包含这两个关键词素的记录：

```sql
SELECT * FROM app WHERE tokens2(name) @> tokens2('艾米莉');
 美味餐厅 - 艾米莉的圣诞颂歌
 美味餐厅 - 艾米莉的瓶中信笺
 小清新艾米莉
 艾米莉的埃及历险记
 艾米莉的极地大冒险
 艾米莉的万圣节历险记
 6rows / 0.38ms
```

这里通过关键词数组的倒排索引，可以快速实现前后模糊的效果。

这里的条件比较严格，应用需要完整的包含两个关键词才会匹配。

如果我们改用更宽松的条件来执行**模糊查询**，例如，只要包含任意一个语素：

```sql
SELECT * FROM app WHERE tokens2(name) && tokens2('艾米莉');

 AR艾米互动故事-智慧妈妈必备
 Amy and train 艾米和小火车
 米莉·马洛塔的涂色探索
 给利伴_艾米罗公司旗下专业购物返利网
 艾米团购
 记忆游戏 - 米莉和泰迪
 (56 row ) / 0.4 ms
```

那么可供近一步筛选的应用候选集就更宽泛了。同时执行时间也并没有发生巨大的变化。

更近一步，我们并不需要在查询中使用完全一致的分词逻辑，完全可以手工进行精密的查询控制。

我们完全可以通过数组的布尔运算，控制哪些关键词是我们想要的，哪些是不想要的，哪些可选，哪些必须。

```sql
-- 包含关键词 微信、红包，但不包含 ‘支付’ (1ms | 11 rows)
SELECT * FROM app WHERE tokens2(name) @> ARRAY['微信','红包'] 
AND NOT tokens2(name) @> ARRAY['支付'];
```

当然，也可以对返回的结果进行相似度排序。一种常用的字符串似度衡量是L式编辑距离，即一个字符串最少需要多少次单字编辑才能变为另一个字符串。这个距离函数`levenshtein` 在PG的官方扩展包`fuzzystrmatch`中提供。

```sql
-- 包含关键词 微信 的应用，按照L式编辑距离排序 ( 1.1 ms | 10 rows)
-- create extension fuzzystrmatch;
SELECT name, levenshtein(name, '微信') AS d 
FROM app WHERE tokens12(name) @> ARRAY['微信'] 
ORDER BY 2 LIMIT 10;

 微信           | 0
 微信读书       | 2
 微信趣图       | 2
 微信加密       | 2
 企业微信       | 2
 微信通助手     | 3
 微信彩色消息   | 4
 艺术微信平台网 | 5
 涂鸦画板- 微信 | 6
 手写板for微信  | 6
```

### 改进全文检索方式

接下来，我们可以对分词的方式进行一些改进：

* 缩小关键词范围：将标点符号从关键词中移除，将语气助词（的得地，啊唔之乎者也）之类排除掉。（可选）
* 扩大关键词列表：将已有关键词的汉语拼音，首字母缩写一并加入关键词列表。
* 优化关键词大小：针对单字，3字短语，4字成语进行提取与优化。中文不同于英文，英文拆分为3字符的小串效果很好，中文信息密度更大，单字或双字就有很大的区分度了。
* 去除重复关键词：例如前后重复出现，或者通假字，同义词之类的。
* 跨语言分词处理，例如中西夹杂的名称，我们可以分别对中英文进行处理，中日韩字符采用中式分词处理逻辑，英文字母使用常规的`pg_trgm`处理逻辑。

实际上也不一定用得着这些逻辑，而这些逻辑也不一定非要在数据库里用存储过程实现。比较好的方式当然是在外部读取数据库然后使用专用的分词库和自定义业务逻辑来进行分词，分完之后再回写到数据表的另一列上。

当然这里出于演示目的，我们就直接用存储过程直接上了，实现一个比较简单的改进版分词逻辑。

```sql
CREATE OR REPLACE FUNCTION cjk_to_tsvector(_src text) RETURNS tsvector AS $$
DECLARE
    res TEXT[]:= show_trgm(_src);
    cjk TEXT; -- 中日韩连续文本段
BEGIN
    FOR cjk IN SELECT unnest(i) FROM regexp_matches(_src,'[\u4E00-\u9FCC\u3400-\u4DBF\u20000-\u2A6D6\u2A700-\u2B81F\u2E80-\u2FDF\uF900-\uFA6D\u2F800-\u2FA1B]+','g') regex(i) LOOP
            FOR i in 1..length(cjk) - 1 LOOP
                    res := array_append(res, substring(cjk, i, 2));
                END LOOP; -- 将每个中日韩连续文本段两字词语加入列表
        END LOOP;
    return array_to_tsvector(res);
end
$$ LANGUAGE PlPgSQL PARALLEL SAFE COST 100 STRICT IMMUTABLE;


-- 如果需要使用标签数组的方式，可以使用此函数。
CREATE OR REPLACE FUNCTION cjk_to_array(_src text) RETURNS TEXT[] AS $$
BEGIN
    RETURN tsvector_to_array(cjk_to_tsvector(_src));
END
$$ LANGUAGE PlPgSQL PARALLEL SAFE COST 100 STRICT IMMUTABLE;

-- 创建分词专用函数索引
CREATE INDEX ON app USING GIN(cjk_to_array(name));
```

### 基于 tsvector

除了基于数组的运算之外，PostgreSQL还提供了`tsvector`与`tsquery`类型，用于全文检索。

我们可以使用这两种类型的运算取代数组之间的运算，写出更灵活的查询来：

```sql
CREATE OR REPLACE FUNCTION to_tsvector123(src text) RETURNS tsvector AS $$
DECLARE
    res TEXT[];
    n INTEGER:= length(src);
begin
    SELECT regexp_split_to_array(src, '') INTO res;
    FOR i in 1..n - 2 LOOP res := array_append(res, substring(src, i, 2));res := array_append(res, substring(src, i, 3)); END LOOP;
    res := array_append(res, substring(src, n-1, 2));
    SELECT array_agg(distinct i) INTO res FROM (SELECT i FROM unnest(res) r(i) EXCEPT SELECT * FROM (VALUES(' '),('，'),('的'),('。'),('-'),('.')) c ) d; -- optional (normalize)
    RETURN array_to_tsvector(res);
end
$$ LANGUAGE PlPgSQL PARALLEL SAFE COST 100 STRICT IMMUTABLE;

-- 使用自定义分词函数，创建函数表达式索引
CREATE INDEX ON app USING GIN(to_tsvector123(name));
```

使用tsvector进行查询的方式也相当直观

```sql
-- 包含 '学英语' 和 '雅思'
SELECT * from app where to_tsvector123(name) @@ '学英语 & 雅思'::tsquery;

-- 所有关于 'BTC' 但不含'钱包' '交易'字样的应用
SELECT * from app where to_tsvector123(name) @@ 'BTC &! 钱包 & ! 交易 '::tsquery;
```



## 参考文章：

PostgreSQL 模糊查询最佳实践 - (含单字、双字、多字模糊查询方法)

https://developer.aliyun.com/article/672293



