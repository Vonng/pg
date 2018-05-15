



注意，`pg_lsn`是WAL日志坐标，实质上是一个int64，在9.3及以前的版本中，类型为TEXT，9.4以后为专门的类型`pg_lsn`，为了统一，建议转成一致的BIGINT。



```sql

-- PostgreSQL before 9.4 (not include)
create or replace function monitor.lsn2int(text)
returns bigint as $$
select ('x'||lpad( 'ff000000', 16, '0'))::bit(64)::bigint
* ('x'||lpad( split_part( $1 ,'/',1), 16, '0'))::bit(64)::bigint
+ ('x'||lpad( split_part( $1 ,'/',2), 16, '0'))::bit(64)::bigint ;
$$ language sql;


-- PostgreSQL after 9.4
create or replace function monitor.lsn2int(pg_lsn) 
returns bigint as $$
select ('x'||lpad( 'ff000000', 16, '0'))::bit(64)::bigint
* ('x'||lpad( split_part( $1::text ,'/',1), 16, '0'))::bit(64)::bigint
+ ('x'||lpad( split_part( $1::text ,'/',2), 16, '0'))::bit(64)::bigint ;
$$ language sql;
```

