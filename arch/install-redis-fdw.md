# Redis FDW 安装

先安装hiredis

```bash
git clone https://github.com/redis/hiredis
cd hiredis
make -j8
sudo make install

```

再安装`redis_fdw`即可

```bash
git clone https://github.com/pg-redis-fdw/redis_fdw
cd redis_fdw
PGSQL_BIN="/usr/local/pgsql/bin/"
git checkout REL9_5_STABLE
PATH="$PGSQL_BIN:$PATH" make USE_PGXS=1
sudo PATH="$PGSQL_BIN:$PATH" make USE_PGXS=1 install
```

