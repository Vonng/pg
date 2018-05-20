# PostgreSQL目录设计

## 挂载点

* 每台机器挂载一块数据库用PCI-E SSD至`/export`，权限755
* 每台机器挂在一块备份用普通HDD至`/var/backups`，权限755
* 普通硬盘用于其他目录

```
Filesystem            Size  Used Avail Use% Mounted on
                      x.xT    xT  x.xT   x% /var/backups
/dev/dfa1             x.xT    xT  x.xT   x% /export
```

其中主数据库在备份盘上执行WAL归档，从库在备份盘上执行全量备份。

## 目录

* **数据库二进制安装目录**： `/usr/pgsql-<major-version>`

  * 软连接：`ln -s /usr/pgsql-10 /usr/pgsql`

* **数据库主目录**：`/export/postgresql/<rolename>`

  * 数据目录：`/export/postgresql/<rolename>/data`

* **备份目录**：`/var/backups/`：

  * 基础备份目录：`/var/backups/backup`
  * 远程备份目录：`/var/backups/remote` ：可能为NFS目录
  * 任务日志目录：`/var/backups/joblog`
  * WAL归档目录：`/var/backups/arcwal` 
  * 临时文件目录：`/var/backups/temp`

* **数据库Home**：`/var/lib/pgsql`

  * 目录：`meta` 元数据目录
  * 目录：`util` 实用脚本文件目录
  * 目录：`misc` 存放杂七杂八的东西
  * 软连接：`<dbversion>` ：数据库主目录
  * 软连接：`data` 指向数据目录
  * 软连接：`backup` 指向备份目录
  * 软连接：`remote`指向远程备份目录


  * 软连接：`arcwal` 指向归档目录
  * 软连接：`temp`指向临时目录
  * 软连接：`log`指向数据库日志目录
  * 软连接：`joblog`指向工具日志目录

* Pgbouncer相关目录：

  * 二进制：`/usr/bin/pgbouncer`
  * 日志目录：`/var/log/pgbouncer/`
  * PID目录：`/var/run/pgbouncer`
  * 配置目录：`/etc/pgbouncer/`



## 脚本

```bash
#!/bin/bash
# Run this as root

PG_MAJOR_VERSION="10"
MODULE_NAME="chatshard16"
ROLE_NAME="${MODULE_NAME}_${PG_MAJOR_VERSION}"

# Main directory
PG_REAL_DIR="/export/postgresql"
PG_MAIN_DIR="${PG_REAL_DIR}/${ROLE_NAME}"
PG_DATA_DIR="${PG_MAIN_DIR}/data"

mkdir -p ${PG_REAL_DIR} ${PG_MAIN_DIR} ${PG_DATA_DIR}
chown postgres:postgres ${PG_REAL_DIR} ${PG_MAIN_DIR} ${PG_DATA_DIR}
chmod 755 ${PG_REAL_DIR} ${PG_MAIN_DIR}
chmod 700 ${PG_DATA_DIR}

# Backup directory
PG_BACKUP_ROOT_DIR="/var/backups"
PG_BACKUP_DIR="${PG_BACKUP_ROOT_DIR}/backup"
PG_REMOTE_DIR="${PG_BACKUP_ROOT_DIR}/remote"
PG_JOBLOG_DIR="${PG_BACKUP_ROOT_DIR}/joblog"
PG_ARCHIVE_DIR="${PG_BACKUP_ROOT_DIR}/arcwal"
PG_TEMP_DIR="${PG_BACKUP_ROOT_DIR}/temp"

mkdir -p ${PG_BACKUP_ROOT_DIR} ${PG_BACKUP_DIR} ${PG_REMOTE_DIR} ${PG_JOBLOG_DIR} ${PG_ARCHIVE_DIR} ${PG_TEMP_DIR}
chown -R postgres:postgres ${PG_BACKUP_ROOT_DIR}
chmod 755 ${PG_BACKUP_ROOT_DIR} ${PG_JOBLOG_DIR}
chmod 700 ${PG_BACKUP_DIR} ${PG_REMOTE_DIR} ${PG_ARCHIVE_DIR}
chmod 777 ${PG_TEMP_DIR}

# Home Directory
PG_HOME_DIR="/var/lib/pgsql"
PG_UTIL_DIR="${PG_HOME_DIR}/util"
PG_META_DIR="${PG_HOME_DIR}/meta"

mkdir -p ${PG_HOME_DIR} ${PG_UTIL_DIR} ${PG_META_DIR}
chown postgres:postgres  ${PG_HOME_DIR} ${PG_UTIL_DIR} ${PG_META_DIR}
chmod 755 ${PG_HOME_DIR} ${PG_UTIL_DIR} ${PG_META_DIR}

[[ -h ${PG_HOME_DIR}/backup ]] && rm -rf ${PG_HOME_DIR}/backup
ln -s ${PG_MAIN_DIR}    "${PG_HOME_DIR}/${PG_MAJOR_VERSION}"
ln -s ${PG_DATA_DIR}    "${PG_HOME_DIR}/data"
ln -s ${PG_BACKUP_DIR}  "${PG_HOME_DIR}/backup"
ln -s ${PG_REMOTE_DIR}  "${PG_HOME_DIR}/remote"
ln -s ${PG_JOBLOG_DIR}  "${PG_HOME_DIR}/joblog"
ln -s ${PG_ARCHIVE_DIR} "${PG_HOME_DIR}/arcwal"
ln -s ${PG_TEMP_DIR}    "${PG_HOME_DIR}/temp"

if [[ ${PG_MAJOR_VERSION}=="10" ]]
then
    ln -s "${PG_HOME_DIR}/data/log" "${PG_HOME_DIR}/log"
else
    # before v10: pg_log
    ln -s "${PG_HOME_DIR}/data/pg_log" "${PG_HOME_DIR}/log"
fi

echo "all done!"
```





### Pgbouncer

- PgBouncer配置目录：`/etc/pgbouncer`

