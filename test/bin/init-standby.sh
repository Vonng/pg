#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   init-standby.sh
# Mtime     :   2019-03-07
# Desc      :   Init PostgreSQL standby
# Path      :   bin/init-standby.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   This scripts is idempotent
#==============================================================#


# module info
__MODULE_INIT_STANDBY="init-standby"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


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
        return 11
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
# Name: init_pgdata
# Desc: create a new database cluster on given path
# Arg1: primary url (example: postgres://replicator@primary.test.pg/postgres)
# Arg2: pgdata  data directory (/pg/data)
# Arg3: force   force remove old data (true)
# Note: this function is idempotent
#--------------------------------------------------------------#
function init_pgdata(){
    local dbname=${1}
    local pgdata=${2-'/pg/data'}
    local force=${3-'true'}

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
                        return 21
                    fi
                    echo "warn: ${pgdata} removed"
                ;;
                * )
                    echo "error: user choose to abort"
                    return 22
                ;;
            esac
        fi
    fi
    [[ ! -d ${pgdata} ]] && mkdir -p ${pgdata}
    chmod 0700 ${pgdata}

    # init pgdata with pgbasebackup
    pg_basebackup \
        --dbname ${dbname} \
        --pgdata ${pgdata} \
        --checkpoint=fast  \
        --write-recovery-conf \
        --no-password

    if [[ $? != 0 ]]; then
        echo "error: make base backup failed"
        return 23
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

    # standby does not require configuration edit here
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

    # standby does not require configuration edit here
    return 0
}


#--------------------------------------------------------------#
# Name: init_recovery_conf
# Desc: Use user provided hba conf in /opt/conf or make default change
# Arg1: conf_path   database conf path  (/pg/data/recovery.done)
# Arg2: check_path  user provided conf  (/opt/conf/recovery.conf)
# Arg3: application_name                (standby)
# Note: this function is idempotent
#--------------------------------------------------------------#
function init_recovery_conf(){
    local conf_path=${1-'/pg/data/restore.conf'}
    local check_path=${2-'/opt/conf/restore.conf'}
    local application_name=${3-'standby'}

    # if found user provided version, use it instead (note this is standby)
    if [[ -f ${check_path} ]]; then
        echo "info: found ${check_path}, overwrite to ${conf_path}"
        rm -rf ${conf_path}
        cp -f ${check_path} ${conf_path}
        return 0
    fi
    # usually recovery.conf is not provided, pg_basebackup will write one
    # skip if already have edit mark
    if ( grep -q "ADDITIONAL RECOVERY CONF" ${conf_path} 2>/dev/null); then
        echo "info: ${conf_path} been edited, skip"
        return 0
    fi

    # otherwise, append to recovery.conf
    echo "info: append config to ${conf_path}"
	cat >> ${conf_path} <<- EOF

	# ADDITIONAL RECOVERY CONF
	recovery_target_timeline = 'latest'
	promote_trigger_file = '/pg/promote'
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

    # and append application_name to primary conn info
    sed -ie "s/user=/application_name=${application_name} user=/" ${conf_path}

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
            return 66
        fi
    fi

    if ! sudo systemctl restart postgresql > /dev/null 2>&1; then
        echo "error: start postgresql.service on standby failed"
        systemctl status postgresql
        return 67
    fi

    if ! systemctl status postgresql > /dev/null 2>&1; then
        echo "error: postgresql.service status failed"
        systemctl status postgresql
        return 68
    fi
    touch ${pgdata}/log/postgresql-{Mon,Tue,Wed,Thu,Fri,Sat,Sun}.csv 2> /dev/null
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
        return 71
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
        return 72
    fi

    echo "info: restart pgbouncer.service"
    if ! sudo systemctl restart pgbouncer > /dev/null 2>&1; then
        echo "error: restart pgbouncer failed"
        systemctl status pgbouncer
        return 73
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
        return 81
    fi

    # replace old dbname=.... to new database
    sed -ie 's/dbname=[0-9a-zA-Z_-]*'"/dbname=${datname}/" /etc/postgres_exporter/env 2> /dev/null
    if [[ $? != 0 ]]; then
        echo "error: fail to edit /etc/postgres_exporter/env"
        return 82
    fi

    echo "info: restart postgres_exporter.service"
    if ! sudo systemctl restart postgres_exporter > /dev/null 2>&1; then
        echo "error: restart postgres_exporter failed"
        systemctl status postgres_exporter
        return 83
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
    local pgurl=${1}
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

    # check url protocol start with postgres
    if [[ ${proto} != postgres* ]]; then
        echo "error: invalid protocol"
        return 2
    fi
    echo "info: init standby instance on ${HOSTNAME}:${pgdata} : ${primary_url}"


    # init standby instance
    #--------------------------------------------#
    echo "info: init-standby (1/8) init_pgpass"
    init_pgpass ${user} ${pass}
    [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-standby (2/8) init_pgdata"
    init_pgdata ${primary_url} ${pgdata}
    [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-standby (3/8) init_postgresql_conf"
    init_postgresql_conf ${pgdata}/postgresql.conf
    [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-standby (4/8) init_pg_hba_conf"
    init_pg_hba_conf ${pgdata}/pg_hba.conf
    [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-standby (5/8) init_recovery_conf"
    init_recovery_conf ${pgdata}/restore.conf /opt/conf/recovery.conf ${application_name}
    [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-standby (6/8) launch_postgresql"
    launch_postgresql
    [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-standby (7/8) retarget_pgbouncer"
    retarget_pgbouncer ${dbname}
     [[ $? != 0 ]] && return $?
    #--------------------------------------------#
    echo "info: init-standby (8/8) retarget_postgres_exporter"
    retarget_postgres_exporter ${dbname}
     [[ $? != 0 ]] && return $?
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
#   postgresql://replicator:replicating@primary.test.pg:5432/test?pgdata=/pg/data
#                repl_user   repl_pass   primary-host-port   dbname    data_dir
#
# If you want to use default settings with default dbname=test
#   just use postgres:///test
#
# Code:
#   0   ok
#   1   insufficient privilege
#   2   invalid url protocol
#   11  fail to create .pgpass file
#   21  fail to remove old data dir
#   22  user abort due to non-empty data dir
#   23  fail to init database cluster d
#   66  fail to stop postgresql.service
#   67  fail to start postgresql.service
#   68  postgresql.service status abnormal
#   71  /etc/pgbouncer/pgbouncer.ini not found
#   72  fail to edit /etc/pgbouncer/pgbouncer.ini
#   73  fail to start pgbouncer.service
#   81  /etc/postgres_exporter/env not found
#   82  fail to edit /etc/postgres_exporter/env
#   83  fail to start postgres_exporter
#==============================================================#
main $@


