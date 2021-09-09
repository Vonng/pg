---
title: "使用sysbench测试PostgreSQL性能"
linkTitle: "使用sysbench测试性能"
date: 2018-02-06
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  尽管PostgreSQL提供了pgbench，但有时候为了吊打一下MySQL，还是需要用到sysbench的。
---



sysbench首页：https://github.com/akopytov/sysbench


## 安装

二进制安装，在Mac上，使用brew安装sysbench。

```bash
brew install sysbench --with-postgresql
```

源代码编译（CentOS）：

```bash
yum -y install make automake libtool pkgconfig libaio-devel
# For MySQL support, replace with mysql-devel on RHEL/CentOS 5
yum -y install mariadb-devel openssl-devel
# For PostgreSQL support
yum -y install postgresql-devel
```

源代码编译

```bash
brew install automake libtool openssl pkg-config
# For MySQL support
brew install mysql
# For PostgreSQL support
brew install postgresql
# openssl is not linked by Homebrew, this is to avoid "ld: library not found for -lssl"
export LDFLAGS=-L/usr/local/opt/openssl/lib 
```

编译：

```bash
./autogen.sh

# --with-pgsql --with-pgsql-libs --with-pgsql-includes
# -- without-mysql
./configure 

make -j
make install
```





## 准备

创建一个压测用PostgreSQL数据库：`bench`



初始化测试用数据库：

```bash
sysbench /usr/local/share/sysbench/oltp_read_write.lua \
	--db-driver=pgsql \
	--pgsql-host=127.0.0.1 \
	--pgsql-port=5432 \
	--pgsql-user=vonng \
	--pgsql-db=bench \
	--table_size=100000 \
	--tables=3 \
	prepare
```

输出：

```
Creating table 'sbtest1'...
Inserting 100000 records into 'sbtest1'
Creating a secondary index on 'sbtest1'...
Creating table 'sbtest2'...
Inserting 100000 records into 'sbtest2'
Creating a secondary index on 'sbtest2'...
Creating table 'sbtest3'...
Inserting 100000 records into 'sbtest3'
Creating a secondary index on 'sbtest3'...
```



## 压测

```bash
sysbench /usr/local/share/sysbench/oltp_read_write.lua \
	--db-driver=pgsql \
	--pgsql-host=127.0.0.1 \
	--pgsql-port=5432 \
	--pgsql-user=vonng \
	--pgsql-db=bench \
	--table_size=100000 \
    --tables=3 \
    --threads=4 \
    --time=12 \
    run
```

输出

```
sysbench 1.1.0-e6e6a02 (using bundled LuaJIT 2.1.0-beta3)

Running the test with following options:
Number of threads: 4
Initializing random number generator from current time


Initializing worker threads...

Threads started!

SQL statistics:
    queries performed:
        read:                            127862
        write:                           36526
        other:                           18268
        total:                           182656
    transactions:                        9131   (760.56 per sec.)
    queries:                             182656 (15214.20 per sec.)
    ignored errors:                      2      (0.17 per sec.)
    reconnects:                          0      (0.00 per sec.)

Throughput:
    events/s (eps):                      760.5600
    time elapsed:                        12.0056s
    total number of events:              9131

Latency (ms):
         min:                                    4.30
         avg:                                    5.26
         max:                                   15.20
         95th percentile:                        5.99
         sum:                                47995.39

Threads fairness:
    events (avg/stddev):           2282.7500/4.02
    execution time (avg/stddev):   11.9988/0.00
```

