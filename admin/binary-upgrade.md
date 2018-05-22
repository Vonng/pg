# Payment迁移方案

### 0. 准备工作

配置好新的数据库机器三台。

| 编号     | IP             | 角色域名               | 机器域名                   |
| -------- | -------------- | ---------------------- | -------------------------- |
| py002m01 | `10.189.11.21` | 1.master.paymentdb2.tt | 53.db-r730.bjs.p1staff.com |
| py002s01 | `10.189.11.22` | 1.slave.paymentdb2.tt  | 50.db-r730.bjs.p1staff.com |
| py002s02 | `10.189.11.26` | 2.slave.paymentdb2.tt  | 49.db-r730.bjs.p1staff.com |

```bash
老主库：10.191.161.35

10.189.11.21
10.189.11.22
10.189.11.26
```

* 保证在迁移时，新主库`10.189.11.21`与原主库处于同步流复制状态。制作从库的方法：
* 在`10.189.11.21上执行 `/tmp/upgrade/setup-slave.sh`

```bash
# postgres@10.189.11.21
# /tmp/upgrade/setup-slave.sh

if [[ "$(whoami)" != "postgres" ]]; then
    echo "execute this with postgres user"
    exit -1
fi

# clean up
/usr/pgsql-9.6/bin/pg_ctl stop -D /export/postgresql/paymentdb_96/data
/usr/pgsql-10/bin/pg_ctl stop -D /export/postgresql/paymentdb_10/data
rm -rf "/export/postgresql/paymentdb_96/data" "/export/postgresql/paymentdb_10/data"

# make basebackup & start as new slave
/usr/pgsql-9.6/bin/pg_basebackup \
    -h 10.191.161.35 \
    -U replication \
    -c fast -Xs -Pv -R \
    -D "/export/postgresql/paymentdb_96/data"

# change synchronous_standby_names to ''
sed -ie 's/synchronous_standby_names/#synchronous_standby_names/' /export/postgresql/paymentdb_96/data/postgresql.conf

echo "base backup done, now start as old master's slave"
/usr/pgsql-9.6/bin/pg_ctl start -D /export/postgresql/paymentdb_96/data


# check availability
echo "ping postgres"
psql putong-payment -h/tmp -qAXtc "SELECT pg_is_in_recovery(), version();"

echo "show slave"
psql putong-payment -h/tmp -qXxc  "TABLE pg_stat_wal_receiver;"

log_info "show pgbouncer"
psql -qXAxt postgres://stats@tmp:6432/pgbouncer?host=/tmp -c "SHOW STATS;"
```



### 1. 停服务

- [ ] 业务方确认服务停止：（Start @ 02:02  Done @ ）

- [ ] 停止老主库的连接池，确认没有查询流量。

    ```bash
    # root@10.191.161.35
    
    # stop pgbouncer
    kill $(cat /var/run/pgbouncer/pgbouncer.pid) && ps aux | grep pgbouncer
    
    # check activity
    su - postgres
    psql putong-payment -c "select * from pg_stat_activity where state = 'active';"
    
    # execute checkpoint
    psql putong-payment -c 'checkpoint;'
    psql putong-payment -c 'checkpoint;'
    ```

- [ ] 检查新老库之间的LSN位置是否同步，如有关停老主库，以便强制达成一致。

    ```bash
    # /tmp/upgrade/replay.sh
    
    # check old master: run @ 10.191.161.35
    psql -c 'SELECT pg_current_xlog_location()';
    pg_controldata -D /export/postgresql/payment_96/data | grep -E 'checkpoint'
      
      
    # check new master: run @ 10.189.11.21
    psql -c 'SELECT pg_last_xlog_replay_location()';
    /usr/pgsql-9.6/bin/pg_controldata -D /export/postgresql/paymentdb_96/data | grep -E 'checkpoint'
     
    
    # shutdown old master WARNNING !!!!!!!!!!!!!!!!!!
    psql putong-payment -c 'checkpoint;'
    /usr/pgsql/bin/pg_ctl -D /export/postgresql/payment_96/data stop
     
    # ROLLBACK:
    # /usr/pgsql/bin/pg_ctl -D /export/postgresql/payment_96/data start
    ```


### 2. 原地升级

- [ ] Promote新主库，关闭数据库，执行原地升级，拷贝配置文件并启动。
  - [ ] 执行`/tmp/upgrade/clean-96.sh`，提升新主库。
  - [ ] 执行 `/tmp/upgrade/start-10.sh` 升级为10 并启动新主库。

```bash
# postgres@10.189.11.21
cd /tmp/upgrade

/tmp/upgrade/clean-96.sh
/tmp/upgrade/start-10.sh
```

第一步，首先将新主库从老主库上摘除，提升，修改同步提交的配置项，重启，删除问题视图

```bash
# /tmp/upgrade/clean-96.sh
# run as postgres @ NEW MASTER 10.189.11.21 !!!!

if [[ "$(whoami)" != "postgres" ]]; then
    echo "execute this with postgres user"
    exit -1
fi

# promote new master
/usr/pgsql-9.6/bin/pg_ctl promote -D /export/postgresql/paymentdb_96/data

# change synchronous_standby_names to ''
sed -ie 's/synchronous_standby_names/#synchronous_standby_names/' /export/postgresql/paymentdb_96/data/postgresql.conf


/usr/pgsql-9.6/bin/pg_ctl restart -D /export/postgresql/paymentdb_96/data


# drop promblematic views & shutdown
sleep 2
/usr/pgsql-9.6/bin/psql -h /tmp putong-payment -c "select pg_is_in_recovery();"
/usr/pgsql-9.6/bin/psql -h /tmp putong-payment -c "DROP VIEW monitor.v_streaming_timedelay;"
/usr/pgsql-9.6/bin/psql -h /tmp putong-payment -c "DROP VIEW monitor.v_repl_stats;"
/usr/pgsql-9.6/bin/pg_ctl stop -D /export/postgresql/paymentdb_96/data
```

第二步，原地升级

```bash
# /tmp/upgrade/start-10.sh

# create new cluster with version 10
rm -rf /export/postgresql/paymentdb_10/data
/usr/pgsql-10/bin/pg_ctl -D /export/postgresql/paymentdb_10/data init

# perform upgrade
/usr/pgsql-10/bin/pg_upgrade \
	-b /usr/pgsql-9.6/bin/ \
	-B /usr/pgsql-10/bin/ \
	-d /export/postgresql/paymentdb_96/data \
	-D /export/postgresql/paymentdb_10/data \
	-j 24 -k 

# tear down
./delete_old_cluster.sh
./analyze_new_cluster.sh

# copy conf file
cp -f /tmp/upgrade/pg_hba.conf /export/postgresql/paymentdb_10/data/pg_hba.conf
cp -f /tmp/upgrade/postgresql.conf /export/postgresql/paymentdb_10/data/postgresql.conf

# start new master
/usr/pgsql-10/bin/pg_ctl -D /export/postgresql/paymentdb_10/data start
psql putong-payment -c "SELECT 'OK' as ok;"
```

进行清理与ANALYZE，验证无误后切换域名，将读写流量导入新主库，并验证。

```bash
psql putong-payment -qAXtc "SELECT pg_is_in_recovery();"

psql putong-payment -qXxc "TABLE pg_stat_wal_receiver;"

psql putong-payment -qXxc "TABLE pg_stat_replication;"

psql -qXAxt postgres://stats@tmp:6432/pgbouncer?host=/tmp -c "SHOW STATS;"
```

可选操作，将老主库与从库上的pgbouncer指向新主库。

```bash
10.191.161.35
10.191.161.36
10.191.160.208

sudo su -
mv /etc/pgbouncer/pgbouncer.ini /etc/pgbouncer/pgbouncer.ini.old
cp -f /etc/pgbouncer/pgbouncer.ini.new /etc/pgbouncer/pgbouncer.ini

# notify pgbouncer
kill -1 $(cat /var/run/pgbouncer/pgbouncer.pid)
# kill -9 $(cat /var/run/pgbouncer/pgbouncer.pid)

# restart 
/usr/bin/pgbouncer -q -R -d /etc/pgbouncer/pgbouncer.ini

# check
sleep 1
tail -n3 /var/log/pgbouncer/pgbouncer.log
```



### 3. 做新从库

在从库上执行，安装新的从库。（制作从库约需要5分钟）

```ini
10.189.11.22
10.189.11.26
```

```bash
/tmp/upgrade/setup-slave.sh
```

验证完成后从库承接新流量



#### 4. 回滚方案

任何情况下失败，重启老库`10.191.161.35`。

```bash
ssh "10.191.161.35"

# start postgres
su - postgres
ps aux | grep postgres
pg_ctl -D /var/lib/pgsql/data start
ps aux | grep postgres

# start pgbouncer
exit
su - pgbouncer
/usr/bin/pgbouncer -d -R /etc/pgbouncer/pgbouncer.ini
ps aux | grep pgbouncer
```

并切换回原来的域名重启即可。