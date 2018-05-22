# pg_repack用法

`pg_repack`是个很实用的工具，能够进行无锁的VACUUM FULL，CLUSTER等操作。



## 原理

### 对表Repack

1. 创建一张原始表的相应日志表。
2. 为原始表添加行触发器，在相应日志表中记录所有`INSERT`,`DELETE`,`UPDATE`操作。
3. 创建一张包含老表所有行的表。
4. 在新表上创建同样的索引
5. 将日志表中的增量变更应用到新表上
6. 使用系统目录切换表，相关索引，相关Toast表。

### 对索引单独Repack

1. 使用`CREATE INDEX CONCURRENTLY`在原表上创建新索引，保持与旧索引相同的定义。
2. 在数据目录中将新旧索引交换。
3. 删除旧索引。

注意，并发建立索引时，如果出现死锁或违背唯一约束，可能会失败，留下一个`INVALID`状态的索引。



## 安装

PostgreSQL官方yum源提供了pg_repack，直接通过yum安装即可：

```bash
yum install pg_repack10
```



## 使用

通常良好实践是：在业务低峰期估算表膨胀率，对膨胀比较厉害的表进行Repack。参阅膨胀监控一节。

典型用法包括

```bash
# 完全清理整个数据库，开5个并发任务，超时等待10秒
pg_repack -d <database> -j 5 -T 10

# 清理mydb中一张特定的表mytable，超时等待10秒
pg_repack mydb -t public.mytable -T 10

# 清理某个特定的索引 myschema.myindex，注意必须使用带模式的全名
pg_repack mydb -i myschema.myindex
```



## 部署

```bash
#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   repack.sh
# Mtime     :   2018-05-18
# Desc      :   Maintain tasks, Repack bloat tables and indexes
# Path      :   /pg/bin/repack.sh
# Cron      :   "00 03 * * * sh /pg/bin/repack.sh"
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   pg_repack, psql, monitor views
#==============================================================#

# module info
__MODULE_REPACK="repack.sh"

PROGRAM_DIR="$(cd $(dirname $0) && pwd)"
PROGRAM_NAME="$(basename $0)"


#==============================================================#
#                             Utils                            #
#==============================================================#
# logger functions
function log_debug() {
    [ -t 2 ] && printf "\033[0;34m[$(date "+%Y-%m-%d %H:%M:%S")][DEBUG] $*\033[0m\n" >&2 ||\
     printf "[$(date "+%Y-%m-%d %H:%M:%S")][DEBUG] $*\n" >&2
}
function log_info() {
    [ -t 2 ] && printf "\033[0;32m[$(date "+%Y-%m-%d %H:%M:%S")][INFO] $*\033[0m\n" >&2 ||\
     printf "[$(date "+%Y-%m-%d %H:%M:%S")][INFO] $*\n" >&2
}
function log_warn() {
    [ -t 2 ] && printf "\033[0;33m[$(date "+%Y-%m-%d %H:%M:%S")][WARN] $*\033[0m\n" >&2 ||\
     printf "[$(date "+%Y-%m-%d %H:%M:%S")][INFO] $*\n" >&2
}
function log_error() {
    [ -t 2 ] && printf "\033[0;31m[$(date "+%Y-%m-%d %H:%M:%S")][ERROR] $*\033[0m\n" >&2 ||\
     printf "[$(date "+%Y-%m-%d %H:%M:%S")][INFO] $*\n" >&2
}

# get primary IP address
function local_ip(){
    # ip range in 10.xxx.xxx.xx
    echo $(/sbin/ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '10\.([0-9]*\.){2}[0-9]*')
}


# send mail via mail service
function send_mail(){
    local subject=$1
    local content=$2
    local to=${3-"fengruohang@p1.com"}
    # TODO: Implement your own mail service
}

# slave returns 't', psql access required
function is_slave(){
    local db=$1
    echo $(psql ${db} -Atqc "SELECT pg_is_in_recovery();")
}

# kill vacuum queries to avoid contention, psql access required
function kill_queries(){
    local db=$1
    kill_count=$(psql ${db} -qAt <<-'EOF'
    SELECT count(pg_cancel_backend(pid))
    FROM pg_stat_activity
    WHERE state <> 'idle' AND pid <> pg_backend_pid()
          AND (query ~* 'vacuum' or query ~* 'analyze');
EOF
2>/dev/null)
    echo ${kill_count}
}

#==============================================================#
#                         Repack Tables                        #
#==============================================================#


#--------------------------------------------------------------#
# Name: repack_tables
# Desc: repack table via fullname
# Arg1: database_name
# Argv: list of table full name
# Deps: psql
#--------------------------------------------------------------#
# repack single table
function repack_tables(){
    local db=$1
    shift

    log_info "repack ${db} tables begin"
    log_info "repack table list: $@"

    for relname in $@
    do
        old_size=$(psql ${db} -Atqc "SELECT pg_size_pretty(pg_relation_size('${relname}'));")
        # kill_queries ${db}
        log_info "repack table ${relname} begin, old size: ${old_size}"
        pg_repack ${db} -T 10 -j 6 -t ${relname}
        new_size=$(psql ${db} -Atqc "SELECT pg_size_pretty(pg_relation_size('${relname}'));")
        log_info "repack table ${relname} done , new size: ${old_size} -> ${new_size}"
    done

    log_info "repack ${db} tables done"
}


#--------------------------------------------------------------#
# Name: get_bloat_tables
# Desc: find bloat tables in given database match some condition
# Arg1: database_name
# Echo: list of full table name
# Deps: psql, monitor.pg_bloat_tables
#--------------------------------------------------------------#
function get_bloat_tables(){
    echo $(psql ${1} -Atq <<-'EOF'
    WITH bloat_tables AS (
        SELECT
          nspname || '.' || relname as relname,
          actual_mb,
          bloat_pct
        FROM monitor.pg_bloat_tables
        WHERE nspname NOT IN ('dba', 'monitor', 'trash')
        ORDER BY 2 DESC,3 DESC
    )
    -- 64 small + 16 medium + 4 large
    (SELECT relname FROM bloat_tables WHERE actual_mb < 256 AND bloat_pct > 40 ORDER BY bloat_pct DESC LIMIT 64) UNION
    (SELECT relname FROM bloat_tables WHERE actual_mb BETWEEN 256 AND 1024  AND bloat_pct > 30 ORDER BY bloat_pct DESC LIMIT 16) UNION
    (SELECT relname FROM bloat_tables WHERE actual_mb BETWEEN 1024 AND 4096  AND bloat_pct > 20 ORDER BY bloat_pct DESC  LIMIT 4);
EOF
)
}

#==============================================================#
#                        Repack Indexes                        #
#==============================================================#


#--------------------------------------------------------------#
# Name: repack_indexes
# Desc: repack index via fullname
# Arg1: database_name
# Argv: list of index full name
# Deps: psql
#--------------------------------------------------------------#
# repack single table
function repack_indexes(){
    local db=$1
    shift

    log_info "repack ${db} indexes begin"
    log_info "repack index list: $@"

    for fullname in $@
    do
        local nspname=$(echo $2 | awk -F'.' '{print $1}')
        local idxname=$(echo $2 | awk -F'.' '{print $2}')

        old_size=$(psql ${db} -Atqc "SELECT pg_size_pretty(pg_relation_size('${fullname}'));")
        log_info "repack index ${nspname}.${idxname} begin, old size: ${old_size}"

        # drop possible repack remains & kill auto maintain tasks
        indexrelid=$(psql $db -Atqc "SELECT indexrelid FROM pg_stat_user_indexes WHERE schemaname='$nspname' AND indexrelname = '$idxname';")
        log_warn "remove possible repack legacy index ${nspname}.index_${indexrelid}"
        psql ${db} -qAtc "DROP INDEX CONCURRENTLY IF EXISTS ${nspname}.index_${indexrelid}" 1> /dev/null 2> /dev/null
        kill_count=$(kill_queries ${db})
        log_warn "kill ${kill_count} queries before repack index ${fullname}"

        pg_repack ${db} -T 10 -i ${fullname}
        new_size=$(psql ${db} -Atqc "SELECT pg_size_pretty(pg_relation_size('${fullname}'));")
        log_info "repack index ${fullname} done , new size: ${old_size} -> ${new_size}"
    done

    log_info "repack ${db} indexes done"
}




#--------------------------------------------------------------#
# Name: get_bloat_indexes
# Desc: find bloat index in given database match some condition
# Arg1: database_name
# Echo: list of full index name
# Deps: psql, monitor.pg_bloat_indexes
#--------------------------------------------------------------#
function get_bloat_indexes(){
    echo $(psql ${1} -Atq <<-'EOF'
   WITH indexes_bloat AS (
        SELECT
          nspname || '.' || idxname as idx_name,
          actual_mb,
          bloat_pct
        FROM monitor.pg_bloat_indexes
        WHERE nspname NOT IN ('dba', 'monitor', 'trash')
        ORDER BY 2 DESC,3 DESC
    )
    -- 64 small + 16 medium + 4 large + 1 top + custom
    (SELECT idx_name FROM indexes_bloat WHERE actual_mb < 128 AND bloat_pct > 40 ORDER BY bloat_pct DESC LIMIT 64) UNION
    (SELECT idx_name FROM indexes_bloat WHERE actual_mb BETWEEN 128 AND 512 AND bloat_pct > 35 ORDER BY bloat_pct DESC LIMIT 16) UNION
    (SELECT idx_name FROM indexes_bloat WHERE actual_mb BETWEEN 512 AND 2048 AND bloat_pct > 30 ORDER BY bloat_pct DESC LIMIT 4) UNION
    (SELECT idx_name FROM indexes_bloat WHERE actual_mb BETWEEN 2048 AND 4096 AND bloat_pct > 25 ORDER BY bloat_pct DESC LIMIT 1);                        -- 3  top
EOF
)
}


#--------------------------------------------------------------#
# Name: repack
# Desc: repack top table & index in given database
# Arg1: database_name
#--------------------------------------------------------------#
function repack_database(){
    local db=$1

    if [[ $(is_slave ${db}) == "t" ]]; then
        log_error "slave can't perform repack. do it on master"
        exit
    fi

    log_info "repack database ${db} begin"

    repack_tables ${db} $(get_bloat_tables ${db})
    repack_indexes ${db} $(get_bloat_indexes ${db})

    log_info "repack database ${db} done"
}


#--------------------------------------------------------------#
# Name: repack
# Desc: repack all database in local cluster
#--------------------------------------------------------------#
function repack(){
    local lock_path="/tmp/repack.lock"
    log_info "rountine repack begin, lock @ ${lock_path}"

    if [ -e ${lock_path} ] && kill -0 $(cat ${lock_path}); then
        log_error "repack already running: $(cat ${lock_path})"
        exit
    fi
    trap "rm -f ${lock_path}; exit" INT TERM EXIT
    echo $$ > ${lock_path}


    local databases=$(psql -Atqc "SELECT datname FROM pg_database WHERE datname NOT IN ('template0','template1','postgres');")
    log_info "repack all database in local cluster: ${databases}"
    for database in ${databases}
    do
        repack_database ${database}
    done

    # remove lock
    rm -f ${lock_path}
    log_info "routine repack done"
}


repack
```





## 注意事项

#### Repack之前

* Repack开始之前，最好取消掉所有正在进行了Vacuum任务。
* 对索引做Repack之前

#### 事故现场清理

临时表与临时索引建立在与原表/索引同一个schema内，

* 临时表的名称为：`${schema_name}.table_${table_oid}`
* 临时索引的名称为：`${schema_name}.index_${table_oid}}`

如果出现异常的情况，有可能留下未清理的垃圾，也许需要手工清理。





## 官方信息

- Homepage: <http://reorg.github.com/pg_repack>
- Download: <http://pgxn.org/dist/pg_repack/>
- Development: <https://github.com/reorg/pg_repack>
- Bug Report: <https://github.com/reorg/pg_repack/issues>
- Mailing List: <http://pgfoundry.org/mailman/listinfo/reorg-general>
