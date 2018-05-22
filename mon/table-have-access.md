# 确认表已经没有访问



首先对`pg_stat_user_tables`取快照

```
DROP TABLE IF EXISTS dba.snapshot;
SELECT * INTO dba.snapshot FROM pg_stat_user_tables;
```



隔一段时间后，检查快照变化情况。新老快照按`relid`连接即可。

```sql
COPY(SELECT *
FROM
  (SELECT
     new.relid,
     new.relname,
     new.schemaname,
     new.seq_scan - old.seq_scan           as seq_scan,
     new.seq_tup_read - old.seq_tup_read   as seq_tup_read,
     new.idx_scan - old.idx_scan           as idx_scan,
     new.idx_tup_fetch - old.idx_tup_fetch as idx_tup_fetch,
     new.n_tup_ins - old.n_tup_ins         as n_tup_ins,
     new.n_tup_upd - old.n_tup_upd         as n_tup_upd,
     new.n_tup_del - old.n_tup_del         as n_tup_del,
     new.n_tup_hot_upd - old.n_tup_hot_upd as n_tup_hot_upd,
     new.n_live_tup - old.n_live_tup       as n_live_tup,
     new.n_dead_tup - old.n_dead_tup       as n_dead_tup
   FROM
     (SELECT *
      FROM pg_stat_user_tables) new
     JOIN dba.snapshot old
   ON old.relid = new.relid
  ) diff
WHERE
  seq_scan <> 0 or
  seq_tup_read <> 0 or
  idx_scan <> 0 or
  idx_tup_fetch <> 0 or
  n_tup_ins <> 0 or
  n_tup_upd <> 0 or
  n_tup_del <> 0 or
  n_tup_hot_upd <> 0 or
  n_live_tup <> 0 or
  n_dead_tup <> 0
order by 2, 3) TO STDOUT

```

