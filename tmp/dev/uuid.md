---
title: "UUID性质原理与应用"
linkTitle: "UUID性质原理与应用"
date: 2016-11-06
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  UUID性质原理与应用，以及如何利用PostgreSQL的存储过程操作UUID。
---



最近一个项目需要生成业务流水号，需求如下：

* ID必须是分布式生成的，不能依赖中心节点分配并保证全局唯一。
* ID必须包含时间戳并尽量依时序递增。（方便阅读，提高索引效率）
* ID尽量散列。（分片，与HBase日志存储需要）

在造轮子之前，首先要看一下有没有现成的解决方案。



### Serial
传统实践上业务流水号经常通过数据库自增序列或者发码服务来实现。
`MySQL`的`Auto Increment`,`Postgres`的`Serial`,或者`Redis+lua`写个小发码服务都是方便快捷的解决方案。这种方案可以保证全局唯一，但会出现中心节点依赖：每个节点需要访问一次数据库才能拿到序列号。这就产生了可用性问题：如果能在本地生成流水号并直接返回响应，那为什么非要用一次网络访问拿ID呢？如果数据库挂了，节点也GG了。所以这并不是一个理想的方案。


### SnowflakeID

然后就是twitter的[SnowflakeID](http://www.lanindex.com/twitter-snowflake%EF%BC%8C64%E4%BD%8D%E8%87%AA%E5%A2%9Eid%E7%AE%97%E6%B3%95%E8%AF%A6%E8%A7%A3/)了，SnowflakeID是一个BIGINT，第一位不用，41bit的时间戳，10bit的节点ID，12bit的毫秒内序列号。时间戳，工作机器ID，序列号占用的位域长度是可以根据业务需求不同而变化的。

```
    0                   1                   2                   3
    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |x|                    41-bit timestamp                         |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |       timestamp   |10-bit machine node|    12-bit serial      |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

SnowflakeID可以说基本满足了这四个需求，首先，通过不同的时间戳(精确到毫秒)，节点ID(工作机器ID)，以及毫秒内的序列号，某种意义上确实可以做到唯一。一个比较讨喜的特性是所有ID是依时序递增的，所以索引起来或者拉取数据会非常方便，长整形的索引和存储效率也很高，生成效率也没得说。

但我认为SnowflakeId存在两个致命问题：

* 虽然ID生成不需要中心节点分配，但工作机器ID还是需要手工分配或者提供中心节点协调的，本质上是改善而不是解决问题。
* 无法解决时间回溯的问题，一旦服务器时间发生调整，几乎一定会生成出重复ID。



### UUID  (Universally Unique IDentifier)

其实这种问题早就有经典的解决方案了，譬如：[UUID by RFC 4122](https://tools.ietf.org/html/rfc4122)  。著名的IDFA就是一种UUID

UUID是一种格式，共有5个版本，最后我选择了v1作为最终方案。下面详细简单介绍一下UUID v1的性质。

* 可以分布式本地生成。
* 保证全局唯一，且可以应对时间回溯或网卡变化导致ID重复生成的问题。
* 时间戳(60bit)，精确至0.1微秒(1e-7 s)。蕴含在ID中。
* 在一个连续的时间片段(2^32/1e7 s约7min)内，ID单调递增。
* 连续生成的ID会被均匀散列，（所以分片起来不要太方便，放在HBase里也可以直接当Rowkey）
* 有现成的标准，不需要任何事先配置与参数输入，各个语言均有实现，开箱即用。
* 可以直接通过UUID字面值得知大概的业务时间戳。
* PostgreSQL直接内建UUID支持(ver>9.0)。

综合考虑，这确实是我能找到的最完美的解决方案了。

### UUID概览

```bash
# Shell中生成一个随机UUID的简单方式
$ python -c 'import uuid;print(uuid.uuid4())'
8d6d1986-5ab8-41eb-8e9f-3ae007836a71
```

我们通常见到的UUID如上所示，通常用`'-'`分隔的五组十六进制数字表示。但这个字符串只不过是UUID的字符串表示，即所谓的`UUID Literal`。实际上UUID是一个128bit的整数。也就是16个字节，两个长整形的宽度。

因为每个字节用2个`hex`字符表示，所以UUID通常可以表示为32个十六进制数字，按照`8-4-4-4-12`的形式进行分组。为什么采用这种分组形式？因为最原始版本的UUID v1采用了这种位域划分方式，后面其他版本的UUID虽然可能位域划分跟这个结构已经不同了，依然采用此种字面值表示方法。UUID1是最经典的UUID，所以我着重介绍UUID1。

下面是UUID版本1的位域划分：

```c
    0                   1                   2                   3
    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                          time_low                             |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |       time_mid                |         time_hi_and_version   |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |clk_seq_hi_res |  clk_seq_low  |         node (0-1)            |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                         node (2-5)                            |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   
 typedef struct {
    unsigned32  time_low;
    unsigned16  time_mid;
    unsigned16  time_hi_and_version;
    unsigned8   clock_seq_hi_and_reserved;
    unsigned8   clock_seq_low;
    byte        node[6];
} uuid_t;
```

但位域划分是按照C结构体的表示方便来划分的，从逻辑上UUID1包括五个部分：

* 时间戳 :`time_low(32)`,` time_mid(16)`,`time_high(12)`，共60bit。
* UUID版本:`version(4)`
* UUID类型: `variant(2)`
* 时钟序列:`clock_seq(14)`
* 节点: `node(48)`，UUID1中为MAC地址。

这五个部分实际占用的位域如下图所示：

```
    0                   1                   2                   3
    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                          time_low                             |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |       time_mid                |  ver  |      time_high        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |var|       clock_seq           |         node (0-1)            |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                         node (2-5)                            |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

在UUID中：

* `version`固定等于`0b0001`,即版本号固定为`1`。

  	反应在字面值上就是：一个合法的UUID v1第三个分组的第一个`hex`一定是`1`:

  * *6b54058a-a413-***1***1e6-b501-a0999b048337*

  当然，如果这个值是`2,3,4,5`，也代表着这就是一个版本`2,3,4,5`的UUID。

* `varient`是用来和其他类型UUID(如GUID)进行区分的字段，指明了UUID的位域解释方法。这里固定为`0b10`。

  	反应在字面值上，一个合法的UUID v1第四个分组的第一个`hex`一定是`8,9,A,B`之一：

  * *6b54058a-a413-11e6-***b***501-a0999b048337*

* `timestamp`由系统时钟获得，形式为60bit的整数，内容是：*Coordinated Universal Time (UTC) as a count of 100-   nanosecond intervals since 00:00:00.00, 15 October 1582 (the date of   Gregorian reform to the Christian calendar).*

  即从1582/10/15 00:00:00至今经过的百纳秒数（100 ns= 1e-7 s）。这么蛋疼的设计是为了让产生良好的散列，让输出ID分布的熵最大化。

  将`unix timestamp`换算为所需时间戳的公式为:`ts * 10000000 + 122192928000000000`

  `time_low = (long long)timestamp [32:64)` ，将时间戳的最低位的`32bit`按照同样的顺序填入UUID前32bit

  `time_mid = (long long)timestamp [16:32)` ，将时间戳中间的`16bit`按照同样的顺序填入UUID的`time_mid`

  `time_high = (long long)timestamp [4:16)` ，将时间戳的最高的`12bit`按照同样的顺序生成`time_hi`。

  不过`time_hi`和`version`是共享一个`short int`的，所以其生成方法为：

  `time_hi_and_version = (long long)timestamp[0:16) & 0x0111 | 0x1000`

  

* `clock_seq`是为了防止网卡变更与时间回溯导致的ID重复问题，当系统时间回溯或网卡状态变更时，`clock_seq`会自动重置，从而避免ID重复问题。其形式为14个bit，换算成整数即`0`~`16383`，一般的UUID库都会自动处理，不在乎的话也可以随机生成或者设为固定值提高性能。

* `node`字段在UUID1中的涵义等同于机器网卡MAC。48bit正好与MAC地址等长。一般UUID库会自动获取，但因为MAC地址泄露出去可能会有一些安全隐患，所以也有一些库是按照IP地址生成的，或者因为拿不到MAC就用一些系统指纹来生成，总之也不用操心。

所以，其实UUIDv1的所有字段都可以自动获取，压根不用人操心。其实是很方便的。



阅读UUID v1时也有一些经验和技巧。

UUID的第一个分组位域宽度为32bit，以百纳秒表示时间的话，也就是`(2 ^ 32 / 1e7 s = 429.5 s = 7.1 min)`。即每7分钟，第一个分组经历一次重置循环。所以对于随机到达的请求，生成的ID哈希分布应该是很均匀的。

UUID的第二个分组位域宽度为16bit，也就是`2^48 / 1e7 s = 326 Day`，也就是说，第二个分组基本上每年循环一次。可以近似的看做年内的业务日期。

当然，最靠谱的方法还是用程序直接从UUID v1中提取出时间戳来。这也是非常方便的。



## 一些问题

前几天需要合并老的业务日志，老的系统里面日志压根没有流水号这个概念，这就让人蛋疼了。新老日志合并需要为老日志补充生成业务流水ID。

UUID v1生成起来是非常方便的，但要手工构造一个UUID去补数据就比较蛋疼了。我在中英文互联网,`StackOverflow`找了很久都没发现现成的`python`,`Node`,`Go`,`pl/pgsql`库或者函数能完成这个功能，这些包大抵就是提供一个`uuid.v1()`给外面用，压根没想到还会有回溯生成ID这种功能吧……

所以我自己写了一个`pl/pgsql`的存储过程，可以根据业务时间戳和当初工作机器的MAC重新生成UUID1。编写这个函数让我对UUID的实现细节与原理有了更深的了解，还是不错的。

根据时间戳，时钟序列(非必须)，MAC生成UUID的存储过程，其他语言同理：

```sql
-- Build UUIDv1 via RFC 4122. 
-- clock_seq is a random 14bit unsigned int with range [0,16384)
CREATE OR REPLACE FUNCTION form_uuid_v1(ts TIMESTAMPTZ, clock_seq INTEGER, mac MACADDR)
  RETURNS UUID AS $$
DECLARE
  t       BIT(60) := (extract(EPOCH FROM ts) * 10000000 + 122192928000000000) :: BIGINT :: BIT(60);
  uuid_hi BIT(64) := substring(t FROM 29 FOR 32) || substring(t FROM 13 FOR 16) || b'0001' ||
                     substring(t FROM 1 FOR 12);
BEGIN
  RETURN lpad(to_hex(uuid_hi :: BIGINT) :: TEXT, 16, '0') ||
         (to_hex((b'10' || clock_seq :: BIT(14)) :: BIT(16) :: INTEGER)) :: TEXT ||
         replace(mac :: TEXT, ':', '');
END
$$ LANGUAGE plpgsql;

-- Usage: SELECT form_uuid_v1(time, 666, '44:88:99:36:57:32');
```

从UUID1中提取时间戳的存储过程

```sql
CREATE OR REPLACE FUNCTION uuid_v1_timestamp(_uuid UUID)
  RETURNS TIMESTAMP WITH TIME ZONE AS $$
SELECT to_timestamp(
    (
      ('x' || lpad(h, 16, '0')) :: BIT(64) :: BIGINT :: DOUBLE PRECISION -
      122192928000000000
    ) / 10000000
)
FROM (
       SELECT substring(u FROM 16 FOR 3) ||
              substring(u FROM 10 FOR 4) ||
              substring(u FROM 1 FOR 8) AS h
       FROM (VALUES (_uuid :: TEXT)) s (u)
     ) s;
$$ LANGUAGE SQL IMMUTABLE;
```