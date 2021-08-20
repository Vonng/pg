# 数据库故障

- [故障检查清单](checklist.md)



## 硬件故障

* [PostgreSQL数据页面损坏导致的故障](page-corruption.md)

* [内存错误导致DROP缓存](drop-cache.md)

* 同步复制导致的故障



## 软件故障

- [XID回卷](xid-wrap-around.md)

- [`template0`老化](vacuum-template0.md)

- [AutoVacuum导致的尖峰](auto-vacuum.md)

* 执行计划错误导致的故障



## 设计缺陷

* [移走负载导致的性能恶化](download-failure.md)

* [序列号溢出导致的故障](sequence-overflow.md)

* [条件索引膨胀一例](bloat-conditional-index.md)



## 人为故障

* [人为操作导致从库被Promote](manual-promote.md)
* [pg_dump导致的血案](search_path.md)

* [批量授权导致的线上短暂故障](batch-grant.md)

* [删除索引导致的故障](drop-index.md)