# 第三卷：原理

### 架构篇

25. 庖丁解牛：PostgreSQL解剖学： [《PG Internal》 Ch1 Ch2](https://pg-internal.vonng.com/#/ch1)
26. 来龙去脉：一条SQL的旅途：[《PG Internal》 Ch3 查询处理](https://pg-internal.vonng.com/#/ch3)
27. 层次分明：一条元组的前世今生： [《PG Internal》 内存/磁盘/增删改/HOT](https://pg-internal.vonng.com/#/ch3)
28. 刻骨铭心：大象从不忘记 [《PG Internal 》](https://pg-internal.vonng.com/#/ch9) Ch9 WAL

### 活性篇

29. 一目十行： 快速检索你的数据 [索引扫描原理]()
30. 除旧布新：我的表为什么越用越大？ [关系膨胀原理与处理]()
31. 快照隔离：为什么PgSQL读写互不阻塞？ [PgSQL MVCC实现原理]()
32. 踩踏惊群：小小查询如何导致雪崩？[PostgreSQL中的锁]()

### 安全篇

33. 坚若磐石：PgSQL如何保证数据不丢？ [故障恢复/同步复制]()
34. 狡兔三窟：物理复制原理  [《PG Internal》 Ch9 流复制]()
35. 改头换面：如何订阅PgSQL重的变更，[逻辑复制]()、[逻辑解码]()、[CDC]()
36. 隔墙有耳：PGSQL数据协议/SSL

