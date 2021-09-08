---
title: "PgSQL在线修改列类型"
linkTitle: "PG在线修改列类型"
date: 2021-01-15
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  如何在线修改表中列的类型，例如从INT升级为BIGINT？
---



# 如何在线升级INT至Bigint？

假设在PG中有一个表，在设计的时候拍脑袋使用了 INT 整型主键，现在业务蓬勃发展发现序列号不够用了，想升级到BIGINT类型。这时候该怎么做呢？

拍脑袋的方法当然是直接使用DDL修改类型：

```
ALTER TABLE pgbench_accounts
```

## 太长；不看

以Pgbench为例

```sql
-- 操作目标：升级 pgbench_accounts 表普通列 abalance 类型：INT -> BIGINT

-- 添加新列：abalance_tmp BIGINT
ALTER TABLE pgbench_accounts ADD COLUMN abalance_tmp BIGINT;

-- 创建触发器函数：保持新列数据与旧列同步
CREATE OR REPLACE FUNCTION public.sync_pgbench_accounts_abalance() RETURNS TRIGGER AS $$
BEGIN NEW.abalance_tmp = NEW.abalance; RETURN NEW;END;
$$ LANGUAGE 'plpgsql';

-- 完成整表更新，分批更新的方式见下
UPDATE pgbench_accounts SET abalance_tmp = abalance; -- 不要在大表上运行这个

-- 创建触发器
CREATE TRIGGER tg_sync_pgbench_accounts_abalance BEFORE INSERT OR UPDATE ON pgbench_accounts
    FOR EACH ROW EXECUTE FUNCTION sync_pgbench_accounts_abalance();

-- 完成列的新旧切换，这时候数据同步方向变化 旧列数据与新列保持同步
BEGIN;
LOCK TABLE pgbench_accounts IN EXCLUSIVE MODE;
ALTER TABLE pgbench_accounts DISABLE TRIGGER tg_sync_pgbench_accounts_abalance;
ALTER TABLE pgbench_accounts RENAME COLUMN abalance TO abalance_old;
ALTER TABLE pgbench_accounts RENAME COLUMN abalance_tmp TO abalance;
ALTER TABLE pgbench_accounts RENAME COLUMN abalance_old TO abalance_tmp;
ALTER TABLE pgbench_accounts ENABLE TRIGGER tg_sync_pgbench_accounts_abalance;
COMMIT;

-- 确认数据完整性
SELECT count(*) FROM pgbench_accounts WHERE abalance_new != abalance;

-- 清理触发器与函数
DROP FUNCTION IF EXISTS sync_pgbench_accounts_abalance();
DROP TRIGGER tg_sync_pgbench_accounts_abalance ON pgbench_accounts;
```



## 外键

```sql
alter table my_table add column new_id bigint;

begin; update my_table set new_id = id where id between 0 and 100000; commit;
begin; update my_table set new_id = id where id between 100001 and 200000; commit;
begin; update my_table set new_id = id where id between 200001 and 300000; commit;
begin; update my_table set new_id = id where id between 300001 and 400000; commit;
...

create unique index my_table_pk_idx on my_table(new_id);

begin;
alter table my_table drop constraint my_table_pk;
alter table my_table alter column new_id set default nextval('my_table_id_seq'::regclass);
update my_table set new_id = id where new_id is null;
alter table my_table add constraint my_table_pk primary key using index my_table_pk_idx;
alter table my_table drop column id;
alter table my_table rename column new_id to id;
commit;
```





## 以pgbench为例

```sql
vonng=# \d pgbench_accounts
              Table "public.pgbench_accounts"
  Column  |     Type      | Collation | Nullable | Default
----------+---------------+-----------+----------+---------
 aid      | integer       |           | not null |
 bid      | integer       |           |          |
 abalance | integer       |           |          |
 filler   | character(84) |           |          |
Indexes:
    "pgbench_accounts_pkey" PRIMARY KEY, btree (aid)
```

升级`abalance`列为BIGINT

会锁表，在表大小非常小，访问量非常小的的情况下可用。

```sql
ALTER TABLE pgbench_accounts ALTER COLUMN abalance SET DATA TYPE bigint;
```





### 在线升级流程

1. 添加新列
2. 更新数据
3. 在新列上创建相关索引（如果没有也可以单列创建，加快第四步的速度）
4. 执行切换**事务**
   1. 排他锁表
   2. UPDATE更新空列（也可以使用触发器）
   3. 删旧列
   4. 重命名新列



```sql
-- Step 1 : 创建新列
ALTER TABLE pgbench_accounts ADD COLUMN abalance_new BIGINT;

-- Step 2 : 更新数据，可以分批更新，分批更新方法详见下面
UPDATE pgbench_accounts SET abalance_new = abalance;

-- Step 3 : 可选（在新列上创建索引）
CREATE INDEX CONCURRENTLY ON public.pgbench_accounts (abalance_new);
UPDATE pgbench_accounts SET abalance_new = abalance WHERE ;

-- Step 3 :

-- Step 4 :
```



```sql
-- 同步更新对应列
CREATE OR REPLACE FUNCTION public.sync_abalance() RETURNS TRIGGER AS $$
BEGIN NEW.abalance_new = OLD.abalance; RETURN NEW;END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER pgbench_accounts_sync_abalance BEFORE INSERT OR UPDATE ON pgbench_accounts EXECUTE FUNCTION sync_abalance();
```









```sql
alter table my_table add column new_id bigint;

begin; update my_table set new_id = id where id between 0 and 100000; commit;
begin; update my_table set new_id = id where id between 100001 and 200000; commit;
begin; update my_table set new_id = id where id between 200001 and 300000; commit;
begin; update my_table set new_id = id where id between 300001 and 400000; commit;
...

create unique index my_table_pk_idx on my_table(new_id);

begin;
alter table my_table drop constraint my_table_pk;
alter table my_table alter column new_id set default nextval('my_table_id_seq'::regclass);
update my_table set new_id = id where new_id is null;
alter table my_table add constraint my_table_pk primary key using index my_table_pk_idx;
alter table my_table drop column id;
alter table my_table rename column new_id to id;
commit;
```









## 批量更新逻辑

有时候需要为大表添加一个非空的，带有默认值的列。因此需要对整表进行一次更新，可以使用下面的办法，将一次巨大的更新拆分为100次或者更多的小更新。

从统计信息中获取主键的分桶信息：

```sql
SELECT unnest(histogram_bounds::TEXT::BIGINT[]) FROM pg_stats WHERE tablename = 'signup_users' and attname = 'id';
```

直接从统计分桶信息中生成需要执行的SQL，在这里把SQL改成需要更新的语

```bash
SELECT 'UPDATE signup_users SET app_type = '''' WHERE id BETWEEN ' || lo::TEXT || ' AND ' || hi::TEXT || ';'
FROM (
         SELECT lo, lead(lo) OVER (ORDER BY lo) as hi
         FROM (
                  SELECT unnest(histogram_bounds::TEXT::BIGINT[]) lo
                  FROM pg_stats
                  WHERE tablename = 'signup_users'
                    and attname = 'id'
                  ORDER BY 1
              ) t1
     ) t2;
```

直接使用SHELL脚本打印出更新语句

```bash
DATNAME=""
RELNAME="pgbench_accounts"
IDENTITY="aid"
UPDATE_CLAUSE="abalance_new = abalance"

SQL=$(cat <<-EOF
SELECT 'UPDATE ${RELNAME} SET ${UPDATE_CLAUSE} WHERE ${IDENTITY} BETWEEN ' || lo::TEXT || ' AND ' || hi::TEXT || ';'
FROM (
		SELECT lo, lead(lo) OVER (ORDER BY lo) as hi
		FROM (
				SELECT unnest(histogram_bounds::TEXT::BIGINT[]) lo
				FROM pg_stats
				WHERE tablename = '${RELNAME}'
					and attname = '${IDENTITY}'
				ORDER BY 1
			) t1
	) t2;
EOF
)

# echo $SQL

psql ${DATNAME} -qAXwtc "ANALYZE ${RELNAME};"
psql ${DATNAME} -qAXwtc "${SQL}"

```

处理边界情况。

```bash
 UPDATE signup_users SET app_type = '' WHERE app_type != '';
```



也可以加工一下，添加事务语句和休眠间隔

```sql
DATNAME="test"
RELNAME="pgbench_accounts"
COLNAME="aid"
UPDATE_CLAUSE="abalance_tmp = abalance"
SLEEP_INTERVAL=0.1

SQL=$(cat <<-EOF
SELECT 'BEGIN;UPDATE ${RELNAME} SET ${UPDATE_CLAUSE} WHERE ${COLNAME} BETWEEN ' || lo::TEXT || ' AND ' || hi::TEXT || ';COMMIT;SELECT pg_sleep(${SLEEP_INTERVAL});VACUUM ${RELNAME};'
FROM (
		SELECT lo, lead(lo) OVER (ORDER BY lo) as hi
		FROM (
				SELECT unnest(histogram_bounds::TEXT::BIGINT[]) lo
				FROM pg_stats
				WHERE tablename = '${RELNAME}'
					and attname = '${COLNAME}'
				ORDER BY 1
			) t1
	) t2;
EOF
)
# echo $SQL
psql ${DATNAME} -qAXwtc "ANALYZE ${RELNAME};"
psql ${DATNAME} -qAXwtc "${SQL}"
```



```sql
BEGIN;UPDATE pgbench_accounts SET abalance_new = abalance WHERE aid BETWEEN 397 AND 103196;COMMIT;SELECT pg_sleep(0.5);VACUUM pgbench_accounts;
BEGIN;UPDATE pgbench_accounts SET abalance_new = abalance WHERE aid BETWEEN 103196 AND 213490;COMMIT;SELECT pg_sleep(0.5);VACUUM pgbench_accounts;
BEGIN;UPDATE pgbench_accounts SET abalance_new = abalance WHERE aid BETWEEN 213490 AND 301811;COMMIT;SELECT pg_sleep(0.5);VACUUM pgbench_accounts;
BEGIN;UPDATE pgbench_accounts SET abalance_new = abalance WHERE aid BETWEEN 301811 AND 400003;COMMIT;SELECT pg_sleep(0.5);VACUUM pgbench_accounts;
BEGIN;UPDATE pgbench_accounts SET abalance_new = abalance WHERE aid BETWEEN 400003 AND 511931;COMMIT;SELECT pg_sleep(0.5);VACUUM pgbench_accounts;
BEGIN;UPDATE pgbench_accounts SET abalance_new = abalance WHERE aid BETWEEN 511931 AND 613890;COMMIT;SELECT pg_sleep(0.5);VACUUM pgbench_accounts;
```






