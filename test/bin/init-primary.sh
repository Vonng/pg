#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   init-primary.sh
# Mtime     :   2019-03-07
# Desc      :   Init PostgreSQL primary
# Path      :   bin/init-primary.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   This scripts is idempotent
#==============================================================#


# module info
__MODULE_INIT_PRIMARY="init-primary"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


#--------------------------------------------------------------#
# Name: init_pgdata
# Desc: create a new database cluster on given path
# Arg1: pgdata  data directory (/pg/data)
# Arg2: force   force remove old data (true)
# Note: this function is idempotent
#--------------------------------------------------------------#
function init_pgdata(){
    local pgdata=${1-'/pg/data'}
    local force=${2-'true'}

    # cleanup
    if systemctl status postgresql > /dev/null 2>&1 ; then
        echo "warn: shutdown postgresql.service"
        sudo systemctl stop postgresql > /dev/null 2>&1
    fi
    if [[ -f ${pgdata}/postmaster.pid ]] ; then
        echo "warn: shutdown postgresql on ${pgdata}"
        pg_ctl -D ${pgdata} stop -m immediate > /dev/null 2>&1
    fi

    # make sure dir is empty with postgres 0700 access
    # if force is not true, prompt choice
    [[ ! -d ${pgdata} ]] && mkdir -p ${pgdata}
    if [[ "$(ls ${pgdata} | wc -l )" != "0" ]]; then
        if [[ ${force} == 'true' ]]; then
            echo "warn: ${pgdata} not empty: force remove ${pgdata}"
            rm -rf ${pgdata}
        else
            echo "WARNING: ${pgdata} is not empty, remove all stuff?"
            local choice=""
            read -p "Continue (y/n)?>" choice
            case "$choice" in
                y|Y )
                    if ! rm -rf ${pgdata}; then   
                        echo "error: ${pgdata} remove failed"
                        return 11
                    fi
                    echo "warn: ${pgdata} removed"
                ;;
                * )
                    echo "error: user choose to abort"
                    return 12
                ;;
            esac
        fi
    fi
    [[ ! -d ${pgdata} ]] && mkdir -p ${pgdata}
    chmod 0700 ${pgdata}

    # create new database cluster
    echo "info: initdb --pgdata=${pgdata} --encoding UTF8 --locale=C --data-checksums"
    initdb --pgdata=${pgdata} --encoding UTF8 --locale=C --data-checksums > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        echo "error: init database cluster failed"
        return 13
    fi
    echo "info: database cluster ${pgdata} initialized"
    return 0
}



#--------------------------------------------------------------#
# Name: init_postgresql_conf
# Desc: Use user provided conf in /opt/conf or make default change
# Arg1: conf_path   database conf path  (/pg/data/postgresql.conf)
# Arg2: check_path  user provided conf  (/opt/conf/postgresql.conf)
# Note: this function is idempotent
#--------------------------------------------------------------#
function init_postgresql_conf(){
    local conf_path=${1-'/pg/data/postgresql.conf'}
    local check_path=${2-'/opt/conf/postgresql.conf'}
    local backup_path="$(dirname ${conf_path})/postgresql.conf.backup"
    
    # if found user provided conf, use it instead
    if [[ -f ${check_path} ]]; then
        echo "info: found ${check_path}, overwrite to ${conf_path}"
        [[ -f ${conf_path} ]] && mv -f ${conf_path} $(dirname ${conf_path})/postgresql.conf.old
        cp -f ${check_path} ${conf_path}
        return 0
    fi
    
    # check whether it is writable
    touch ${conf_path} > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        echo "error: permission denied for ${conf_path}"
        return 21
    fi

    # skip if already have edit mark
    if ( grep -q "PGTEST CONFIGURATION DONE" ${conf_path} 2>/dev/null); then
        echo "info: ${conf_path} been edited, skip"
        return 0
    fi

    echo "info: make default changes to ${conf_path}"
    sed -ie "s/#listen_addresses = 'localhost'/listen_addresses = '*'/"         ${conf_path}
    sed -ie "s/#log_destination/log_destination/"                               ${conf_path}
    sed -ie "s/log_destination = 'stderr'/log_destination = 'csvlog'/"          ${conf_path}
    sed -ie "s/shared_buffers = 128MB/shared_buffers = 256MB/"                  ${conf_path}
    sed -ie "s/#log_checkpoints = off/log_checkpoints = on/"                    ${conf_path}
    sed -ie "s/#logging_collector = off/logging_collector = on/"                ${conf_path}
    sed -ie "s/#log_truncate_on_rotation = off/log_truncate_on_rotation = on/"  ${conf_path}
    sed -ie "s/#track_commit_timestamp = off/track_commit_timestamp = on/"      ${conf_path}
    sed -ie "s/#wal_keep_segments = 0/wal_keep_segments = 100/"                 ${conf_path}
    sed -ie "s/#track_io_timing = off/track_io_timing = on/"                    ${conf_path}
    sed -ie "s/#track_functions = none/track_functions = all/"                  ${conf_path}
    sed -ie "s/#shared_preload_libraries = ''/shared_preload_libraries = 'pg_stat_statements, auto_explain'/" ${conf_path}
    cat >> ${conf_path} <<- 'EOF'

	auto_explain.log_min_duration = 1min
	auto_explain.log_analyze = true
	auto_explain.log_verbose = true
	auto_explain.log_timing = true
	auto_explain.log_nested_statements = true

	pg_stat_statements.max = 10000
	pg_stat_statements.track = all

	# PGTEST CONFIGURATION DONE
	EOF

    return 0
}


#--------------------------------------------------------------#
# Name: init_pg_hba_conf
# Desc: Use user provided hba conf in /opt/conf or make default change
# Arg1: conf_path   database conf path  (/pg/data/pg_hba.conf)
# Arg2: check_path  user provided conf  (/opt/conf/pg_hba.conf)
# Note: this function is idempotent
#--------------------------------------------------------------#
function init_pg_hba_conf(){
    local conf_path=${1-'/pg/data/pg_hba.conf'}
    local check_path=${2-'/opt/conf/pg_hba.conf'}

    # if found user provided version, use it instead
    if [[ -f ${check_path} ]]; then
        echo "info: found ${check_path}, overwrite to ${conf_path}"
        [[ -f ${conf_path} ]] && mv -f ${conf_path} $(dirname ${conf_path})/pg_hba.conf.old
        cp -f ${check_path} ${conf_path}
        return 0
    fi

    # otherwise, overwrite default HBA file
    echo "info: write default hba config to ${conf_path}"
	cat > ${conf_path} <<- EOF
	# TYPE  DATABASE        USER            ADDRESS                 METHOD

	# local user can login
	local   all             all                                     ident

	# reject remote su access (maybe)
	host    all             postgres        127.0.0.1/32            ident
	host    all             postgres        0.0.0.0/0               reject
	host    all             postgres        ::1/128                 reject

	# replication from local is allowed, remote require password
	local   replication     postgres                                ident
	host    replication     postgres        127.0.0.1/32            ident
	host    replication     postgres        ::1/128                 ident
	host    replication     all             0.0.0.0/0               md5
	host    replication     all             ::1/128                 md5

	# application
	host    all             all             ::1/128                 md5
	host    all             all             0.0.0.0/0               md5

	# olap access

	# read only access

	# read write access

	EOF
    return 0
}


#--------------------------------------------------------------#
# Name: init_recovery_conf
# Desc: Use user provided recovery conf in /opt/conf or make default change
# Arg1: conf_path   database conf path  (/pg/data/recovery.done)
# Arg2: check_path  user provided conf  (/opt/conf/recovery.conf)
# Arg3: primary_conninfo    used when primary rewind to standby
#   default to 'host=standby.test.pg port=5432 user=replicator passfile=/pg/.pgass application_name=standby sslmode=disable sslcompression=0'
# Note: this function is idempotent
#--------------------------------------------------------------#
function init_recovery_conf(){
    local conf_path=${1-'/pg/data/recovery.done'}
    local check_path=${2-'/opt/conf/recovery.conf'}
    local primary_conninfo=${3-''}

    # if found user provided version, use it instead (note this is primary)
    if [[ -f ${check_path} ]]; then
        echo "info: found ${check_path}, overwrite to ${conf_path}"
        rm -rf ${conf_path}
        cp -f ${check_path} ${conf_path}
        return 0
    fi

    # otherwise, write to recovery.conf
    echo "info: write failover config to ${conf_path}"
	cat > ${conf_path} <<- EOF
	# This file is used after emergency failover
	# to attach old primary to new primary run:
	# mv /pg/data/recovery.done /pg/data/recovery.conf
	
	standby_mode = 'on'
	primary_conninfo = '${primary_conninfo}'
	recovery_target_timeline = 'latest'
	trigger_file = '/pg/promote'
	#restore_command ='gzcat /pg/arcwal/%f 1> %p 2> /pg/log/restore.log'
	#archive_cleanup_command = '/usr/pgsql/bin/pg_archivecleanup -x .gz /pg/arcwal %r'
	#recovery_min_apply_delay = '0'
	#recovery_end_command = ''
	#recovery_target = 'immediate'
	#recovery_target_name = ''    # e.g. 'daily backup 2011-01-26'
	#recovery_target_time = ''    # e.g. '2004-07-14 22:39:00 EST'
	#recovery_target_xid  = ''    # e.g. '1234567'
	#recovery_target_lsn  = ''    # e.g. '0/70006B8'
	#recovery_target_inclusive = true
	#recovery_target_action = 'shutdown'
	#reovery_target_action = 'pause'
	EOF
    return 0
}



#--------------------------------------------------------------#
# Name: launch_postgresql
# Desc: start postgresql services
# Note: require proper sudo privileges
# Note: this function is idempotent
#--------------------------------------------------------------#
function launch_postgresql(){
    sudo systemctl enable postgresql  > /dev/null 2>&1

    if systemctl status postgresql > /dev/null 2>&1; then
        echo "warn: postgresql.service already running, restart anyway"
        if ! sudo systemctl stop postgresql ; then
            echo "error: fail to stop postgresql.service"
            return 51
        fi
    fi

    if ! sudo systemctl restart postgresql > /dev/null 2>&1; then
        echo "error: start postgresql.service on primary failed"
        systemctl status postgresql
        return 52
    fi

    if ! systemctl status postgresql > /dev/null 2>&1; then
        echo "error: postgresql.service status failed"
        systemctl status postgresql
        return 53
    fi
    touch ${pgdata}/log/postgresql-{Mon,Tue,Wed,Thu,Fri,Sat,Sun}.csv 2> /dev/null
    return 0
}



#--------------------------------------------------------------#
# Name: init_user
# Desc: init database replication user and reset su password
# Arg1: repl_user   replication username
# Arg2: repl_pass   replication password
# Arg3: su_password password for postgres
# Note: this function is idempotent
#--------------------------------------------------------------#
function init_user(){
    local repl_user=${1-'replicator'}
    local repl_pass=${2-'replicating'}
    local su_password=${3-'postgres'}

    local res=$(psql postgres -wqAtc "SELECT rolname FROM pg_catalog.pg_roles WHERE rolname = '${repl_user}';" 2>/dev/null)
    if [[ $? != 0 ]]; then
        echo "error: postgresql unreachable"
        return 61
    fi

    if [[ -z "${res}" ]]; then
        echo "info: create replication user ${repl_user}"
		psql postgres -wqAt >/dev/null 2>&1  <<- SQL
		CREATE USER "${repl_user}" REPLICATION PASSWORD '${repl_pass}';
		SQL
        
        if [[ $? != 0 ]]; then
            echo "error: create replication user ${repl_user} failed"
            return 62
        fi
    else
        echo "info: reset replication user ${repl_user} password"
		psql postgres -wqAt >/dev/null 2>&1 <<- SQL
		ALTER USER "${repl_user}" REPLICATION PASSWORD '${repl_pass}';
		SQL

        if [[ $? != 0 ]]; then
            echo "error: reset replication user ${repl_user} failed"
            return 63
        fi    
    fi

    # reset su postgres password to it's name
	psql postgres -wqAt >/dev/null 2>&1 <<- SQL
	ALTER USER "postgres" PASSWORD '${su_password}';
	SQL
    
    if [[ $? != 0 ]]; then
        echo "error: reset password for postgres failed"
        return 64
    fi
    return 0
}



#--------------------------------------------------------------#
# Name: init_pgpass
# Desc: init .pgpass with replicator user credential
# Arg1: repl_user  replication username (replicator)
# Arg2: repl_pass  replication password (replicating)
# Note: this function is idempotent
#--------------------------------------------------------------#
function init_pgpass(){
    local repl_user=${1-'replicator'}
    local repl_pass=${2-'replicating'}

    local pgpass_file="${HOME}/.pgpass"
    local credential='*:*:*:'"${repl_user}:${repl_pass}"

    # if found /opt/conf/pgass, use it anyway
    if [[ -f /opt/conf/pgpass ]]; then
        echo "info: found /opt/conf/pgass , overwrite to ${pgpass}"
        rm -rf ${pgpass_file}
        cp -f /opt/conf/pgpass ${pgpass_file}
        return 0
    fi

    # create pgpass
    [[ ! -f ${pgpass_file} ]]
    touch ${pgpass_file} 2>/dev/null
    if [[ $? != 0 ]]; then
        echo "error: failed to touch ${pgpass_file}"    # permission denied
        return 71
    fi

    # write credential if not exists
    if ! (grep ${credential} ${pgpass_file} >/dev/null 2>&1); then
        echo "info: write ${repl_user} credential to ${pgpass_file}"
        echo ${credential} >> ${pgpass_file}
    fi
    chmod 0600 ${pgpass_file}
    return 0
}


#--------------------------------------------------------------#
# Name: init_default_database
# Desc: init a database and user with given name
# Arg1: datname     default database/user name
# Note: this function is idempotent
#--------------------------------------------------------------#
function init_default_database(){
    local datname=${1-'postgres'}
    [[ ${datname} == "postgres" ]] && return 0

    local res=$(psql postgres -wqAtc "SELECT rolname FROM pg_catalog.pg_roles WHERE rolname = '${datname}';" 2>/dev/null)
    if [[ $? != 0 ]]; then
        echo "error: postgresql unreachable"
        return 81
    fi
    # create user if not exists
    if [[ ! -z "${res}" ]]; then
        echo "error: user ${datname} already exists"
        return 82
    fi

    echo "info: create default db user ${datname}"
	psql postgres -wqAt >/dev/null 2>&1  <<- SQL
	CREATE USER "${datname}" PASSWORD '${datname}';
	CREATE DATABASE "${datname}" OWNER "${datname}";
	SQL
    if [[ $? != 0 ]]; then
        echo "error: create default database ${datname} failed"
        return 83
    fi

    # init.sql hook: skip user defined scripts error
    if [[ -f /opt/conf/init.sql ]]; then
        echo "info: running user defined init.sql"
        psql ${datname} -wqAt >/dev/null 2>&1 -f /opt/conf/init.sql
        if [[ $? != 0 ]]; then
            echo "warn: user defined init.sql error, skip"
        fi
    fi
    return 0
}

#--------------------------------------------------------------#
# Name: retarget_pgbouncer
# Desc: make pgbouncer route to new default database instead of postgres
# Arg1: datname     default database/user name
# Note: this function is idempotent
# Note: make sure postgres owns /etc/pgbouncer.ini and have sudo systemctl * pgbouncer
# Note: this assume pgbouncer is already installed
#--------------------------------------------------------------#
function retarget_pgbouncer(){
    local datname=${1-'postgres'}
    # pgbouncer conf not found
    if [[ ! -f /etc/pgbouncer/pgbouncer.ini ]]; then
        echo "error: /etc/pgbouncer/pgbouncer.ini not exist"
        return 91
    fi

    # you'd better keep pgbouncer.ini format intact to make this work
    # usually it is not a problem using default settings, but be cautious
    # when use your own pgbouncer.ini

    # delete the line right after '[databases]'
    sed -ie '/\[databases\]/{n;d}' /etc/pgbouncer/pgbouncer.ini

    # append the new line right after '[databases]'
    sed -ie "/\[databases\]/a ${datname} =" /etc/pgbouncer/pgbouncer.ini
    if [[ $? != 0 ]]; then
        echo "error: fail to edit /etc/pgbouncer/pgbouncer.ini"
        return 92
    fi

    echo "info: restart pgbouncer.service"
    if ! sudo systemctl restart pgbouncer > /dev/null 2>&1; then
        echo "error: restart pgbouncer failed"
        systemctl status pgbouncer
        return 93
    fi
    sudo systemctl enable pgbouncer 2> /dev/null
    return 0
}



#--------------------------------------------------------------#
# Name: retarget_postgres_exporter
# Desc: make postgres exporter route to new default database instead of postgres
# Arg1: datname     default database/user name
# Note: this function is idempotent
# Note: make sure postgres owns /etc/postgres_exporter/env and have proper sudo privileges
# Note: this assume postgres_exporter is already installed
#--------------------------------------------------------------#
function retarget_postgres_exporter(){
    local datname=${1-'postgres'}
    # pgbouncer conf not found
    if [[ ! -f /etc/postgres_exporter/env ]]; then
        echo "error: /etc/postgres_exporter/env not exist"
        return 101
    fi

    # replace old dbname=.... to new database
    sed -ie 's/dbname=[0-9a-zA-Z_-]*'"/dbname=${datname}/" /etc/postgres_exporter/env 2> /dev/null
    if [[ $? != 0 ]]; then
        echo "error: fail to edit /etc/postgres_exporter/env"
        return 102
    fi

    echo "info: restart postgres_exporter.service"
    if ! sudo systemctl restart postgres_exporter > /dev/null 2>&1; then
        echo "error: restart postgres_exporter failed"
        systemctl status postgres_exporter
        return 103
    fi

    return 0
}


#==============================================================#
#                             Main                             #
#==============================================================#
function main(){
    # check privilege
    if [[ "$(whoami)" != "postgres" ]]; then
        echo "error: run this as postgres"
        return 1
    fi

    # parse pg url style argument
    local pgurl=${1-'postgres:///postgres'}
    local proto="$(echo ${pgurl} | grep :// | sed -e's,^\(.*://\).*,\1,g')"
    local urlbody="$(echo ${pgurl/${proto}/})"
    proto=${proto%%"://"}
    local user="$(echo ${urlbody} | grep @ | cut -d@ -f1)"
    local host="$(echo ${urlbody/${user}@/} | cut -d/ -f1)"
    local pass=$(echo ${user} | grep : | cut -d: -f2)
    [[ -n "${pass}" ]] && user=$(echo ${user} | grep : | cut -d: -f1)
    local port="$(echo ${host} | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"
    host=${host%%":${port}"}
    local urlpath="$(echo ${urlbody} | grep / | cut -d/ -f2-)"
    local queries="$(echo ${urlpath} | grep '?' | cut -d'?' -f2)"
    [[ -n "${queries}" ]] && urlpath="$(echo ${urlpath} | grep '?' | cut -d'?' -f1)"

    local pgdata=$(echo ${queries} | grep -Eo 'pgdata=([^&]*)')
    pgdata=${pgdata##'pgdata='}
    local application_name=$(echo ${queries} | grep -Eo 'application_name=([^&]*)')
    application_name=${application_name##'application_name='}

    # parameters
    [[ -z "${user}"   ]] && user='replicator'
    [[ -z "${pass}"   ]] && pass='replicating'
    [[ -z "${host}"   ]] && host='url.primary.pg'
    [[ -z "${port}"   ]] && port='5432'
    [[ -z "${pgdata}" ]] && pgdata='/pg/data'
    [[ -z "${application_name}" ]] && application_name='standby'
    local dbname=${urlpath-'postgres'}
    local primary_url="postgres://${user}:${pass}@${host}:${port}/${dbname}"
    local primary_conninfo=$(cat <<- CONN
	host=${host} port=${port} user=${user} passfile=/pg/.pgass application_name=${application_name} sslmode=disable sslcompression=0
	CONN
    )

    # check url protocol start with postgres
    if [[ ${proto} != postgres* ]]; then
        echo "error: invalid protocol"
        return 2
    fi
    echo "info: init primary instance on ${HOSTNAME}:${pgdata} : ${primary_url}"

    # init primary instance
    #--------------------------------------------#
    echo "info: init-primary (1/10) init_pgdata"
    init_pgdata ${pgdata}
    [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-primary (2/10) init_postgresql_conf"
    init_postgresql_conf ${pgdata}/postgresql.conf
    [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-primary (3/10) init_pg_hba_conf"
    init_pg_hba_conf ${pgdata}/pg_hba.conf
    [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-primary (4/10) init_recovery_conf"
    init_recovery_conf "${pgdata}/recovery.done" "/opt/conf/recovery.conf" "${primary_conninfo}"
    [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-primary (5/10) launch_postgresql"
    launch_postgresql
    [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-primary (6/10) init_user"
    init_user ${user} ${pass}
    [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-primary (7/10) init_pgpass"
    init_pgpass ${user} ${pass}
    [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-primary (8/10) init_default_database"
    init_default_database ${dbname}
    [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-primary (9/10) retarget_pgbouncer"
    retarget_pgbouncer ${dbname}
    # [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-primary (10/10) retarget_postgres_exporter"
    retarget_postgres_exporter ${dbname}
    # [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    # init hook (skip error)
    echo "info: running user defined init.sh"
    [[ -f /opt/conf/init.sh ]] && bash /opt/conf/init.sh

    return 0
}

#==============================================================#
#                             Main                             #
#==============================================================#
# Args:
#   $1  connection string , example:
#   pg://replicator:replicating@standby.test.pg:5432/test?pgdata=/pg/data
#                repl_user   repl_pass   standby-host-port   dbname    data_dir
#
# If you want to use default settings with default dbname=test
#   just use postgres:///test
#
# Code:
#   0   ok
#   1   insufficient privilege
#   2   invalid url protocol
#   11  fail to remove old data dir
#   12  user abort due to non-empty data dir
#   13  fail to init database cluster
#   21  postgresql.conf permission denied
#   51  fail to stop postgresql.service
#   52  fail to start postgresql.service
#   53  postgresql.service status abnormal
#   61  fail to create replication user
#   62  fail to reset existing replication user
#   63  fail to reset replication user
#   64  fail to reset password for su
#   71  fail to create .pgpass file
#   81  fail to reach local postgresql
#   82  target database/user already exists
#   83  fail to create default database
#   91  /etc/pgbouncer/pgbouncer.ini not found
#   92  fail to edit /etc/pgbouncer/pgbouncer.ini
#   93  fail to start pgbouncer.service
#   101 /etc/postgres_exporter/env not found
#   102 fail to edit /etc/postgres_exporter/env
#   103 fail to start postgres_exporter
#==============================================================#
main $@


