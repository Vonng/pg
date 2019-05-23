---
author: "Vonng"
description: "PostgreSQL安装方法"
categories: ["Dev"]
tags: ["PostgreSQL","Admin", "Install"]
type: "post"
---

# PostgreSQL Installation



## 脚本安装

以下脚本用于生产服务器，使用CentOS7系统，默认安装PostgreSQL11。

默认会创建`uid=256, gid=256`的`postgres`用户，二进制目录为`/usr/pgsql-<major>`，软链接目录为`/usr/pgsql`并创建相应的`path`项。默认数据目录与脚本目录为`/pg`。

[`pg/test/bin/install-postgres.sh`](https://github.com/Vonng/pg/blob/master/test/bin/install-postgres.sh)



## 手动二进制安装

#### MacOS 

```bash
brew install postgresql
brew install postgis
```

#### CentOS

```bash
short_version=11
yum install -q -y \
  postgresql"$short_version" \
  postgresql"$short_version"-libs \
  postgresql"$short_version"-server \
  postgresql"$short_version"-contrib \
  postgresql"$short_version"-devel \
  postgresql"$short_version"-debuginfo\
  pgbouncer \
  pg_top"$short_version" \
  pg_repack"$short_version"
  # pgpool-II-"$short_version" \
  # postgis2_"$short_version" \
  # postgis2_"$short_version"-client \
```

#### Ubuntu

```bash
apt install \
  postgresql-11 \
  postgresql-server-dev-11 \
  postgresql-client-11 \
  postgresql-client-11-dbgsym \
  postgresql-11-dbgsym \
  postgresql-11-repack \
  postgresql-11-repack-dbgsym \
  postgresql-11-wal2json \
  postgresql-11-wal2json-dbgsym \
  postgresql-11-postgis-2.5
```



## 源码编译

```bash
./configure
make
su
make install
adduser postgres
mkdir /usr/local/pgsql/data
chown postgres /usr/local/pgsql/data
su - postgres
/usr/local/pgsql/bin/initdb -D /usr/local/pgsql/data
/usr/local/pgsql/bin/postgres -D /usr/local/pgsql/data >logfile 2>&1 &
/usr/local/pgsql/bin/createdb test
/usr/local/pgsql/bin/psql test
```



## 安装LLVM JIT支持

因为不少平台上并未提供现成了LLVMJIT二进制安装包。安装LLVM JIT最简单的方法就是使用同版本PostgreSQL源码与LLVM链接编译出`llvmjit.so`，然后直接拷贝到PostgreSQL默认动态链接库目录即可。

### Ubuntu

```bash
# ubuntu
sudo apt install clang llvm-8 llvm-8-dev llvm-8-doc llvm-8-examples llvm-8-runtime llvm-8-tools zlib1g-dev zlib1g libreadline7 libreadline7-dbg libreadline-dev
cd postgresql-11.3 && ./configure --with-llvm LLVM_CONFIG=/usr/lib/llvm-8/bin/llvm-config
make & make install
cp /usr/local/pgsql/lib/llvmjit.so /usr/lib/postgresql/11/lib/llvmjit.so
cp /usr/local/pgsql/lib/llvmjit_types.bc /usr/lib/postgresql/11/lib/llvmjit_types.bc
```

###  mac

```bash
brew install llvm
cd postgresql-11.3 &&  ./configure --with-llvm LLVM_CONFIG=/usr/local/Cellar/llvm/8.0.0_1/bin/llvm-config

make & make install
cp /usr/local/pgsql/lib/llvmjit.so /usr/local/lib/postgresql/llvmjit.so
cp /usr/local/pgsql/lib/llvmjit_types.bc /usr/local/lib/postgresql/llvmjit_types.bc
```



## 安装PostGIS

PostGIS是一个相当复杂的扩展，依赖的最简单方式仍然是安装二进制包。编译安装可以参考这里：[PostGIS安装教程](../tools/postgis-install.md)。如果你的PostgreSQL本身是编译安装的，又不想手工编译PostGIS，最简单的办法就是将二进制包中的`postgis.so`以及其他一大堆动态链接库直接拷到你的动态链接库目录下。

