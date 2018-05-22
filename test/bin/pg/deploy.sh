#!/bin/bash

set -uo pipefail

#==============================================================#
# File      :   deploy.sh
# Mtime     :   2019-03-12
# Desc      :   Deploy SQL/Bash changes
# Path      :   /pg/bin/deploy.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   psql, /pg/history
#==============================================================#

# module info
__MODULE_DEPLOY="deploy"

PROGRAM_DIR="$(cd $(dirname $0) && pwd)"
PROGRAM_NAME="$(basename $0)"

# psql PATH
export PATH=/usr/pgsql/bin:${PATH}

#==============================================================#
#                             Usage                            #
#==============================================================#
function usage() {
    cat <<- 'EOF'

	NAME
	    deploy.sh   -- deploy changes to database with history record

	SYNOPSIS
	    deploy  *.sql       [dbname]    deploy sql changes
	    deploy  *.sh        [args...]   deploy bash scripts
	    deploy  <src_path>  [dst_path]  deploy conf files

	DESCRIPTION

	EOF

    exit 1
}


#==============================================================#
#                             Utils                            #
#==============================================================#
# logger functions
function log_debug() {
    [[ -t 2 ]] && printf "\033[0;34m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][DEBUG] $*\033[0m\n" >&2 || \
 printf "[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][DEBUG] $*\n" >&2
}

function log_info() {
    [[ -t 2 ]] && printf "\033[0;32m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][INFO] $*\033[0m\n" >&2 || \
 printf "[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][INFO] $*\n" >&2
}

function log_warn() {
    [[ -t 2 ]] && printf "\033[0;33m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][WARN] $*\033[0m\n" >&2 || \
 printf "[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][INFO] $*\n" >&2
}

function log_error() {
    [[ -t 2 ]] && printf "\033[0;31m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][ERROR] $*\033[0m\n" >&2 || \
 printf "[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][INFO] $*\n" >&2
}


#--------------------------------------------------------------#
# Name: pg_get_dbname
# Desc: get nontrivial database name (not postgres|template*)
# Rets: dbname (0) , or 1 indicate failure
#--------------------------------------------------------------#
function pg_get_dbname() {
    local dbname=$(psql -1qAXtc "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres','template0','template1') LIMIT 1;")
    if [[ $? != 0 || -z "${dbname}" ]]; then
        return 1
    fi
    echo ${dbname}
    return 0
}



#==============================================================#
#                      BASH  DEPLOY                            #
#==============================================================#
# Name: deploy_bash
# Desc: run bash scripts with user postgres
#--------------------------------------------------------------#
function deploy_bash() {
    local src=$1;
    shift
    local src_filename=$(basename ${src})

    local change_timestamp="$(date '+%Y%m%d_%H%M%S')"
    local change_filename="${change_timestamp}_${src_filename}"
    local change_log="/pg/change/${change_filename}"
    local src_checksum=$(md5sum ${src} | awk '{print $1}')

    # check if any same deployment already recorded in change history
    if (grep -q ${src_checksum} /pg/change/histroy 2> /dev/null); then
        log_warn "found exact same bash scripts in history"
        grep ${src_checksum} /pg/change/histroy
    # return 10
    fi

    # for bash, just write exact copy into change_log
    # and record meta data in /pg/change/history
    cat ${src} > ${change_log}

    # deploy start
    log_info "deployment bash begin: bash ${src} $@"
    status="FAIL"
    bash ${src} $@
    if [[ $? == 0 ]]; then
        status="PASS"
        log_info "[PASS] deployment bash complete"
    else
        log_error "[FAIL] deployment bash failed, check ${change_log} for detail"
    fi

    # write change meta data to /pg/change/history
    local meta="$(date '+%Y-%m-%d %H:%M:%S') [${status}] ${src_checksum} ${change_log}"
    log_info "${meta}"
    echo "${meta}" >> /pg/change/history

    [[ ${status} == "PASS" ]] && return 0 || return 12
}



#==============================================================#
#                       SQL  DEPLOY                            #
#==============================================================#
# Name: deploy_sql
# Desc: deploy SQL changes to database
#--------------------------------------------------------------#
function deploy_sql() {
    local src=${1}
    local dbname=${2}
    local src_filename=$(basename ${src})

    local change_timestamp="$(date '+%Y%m%d_%H%M%S')"
    local change_filename="${change_timestamp}_${src_filename}"
    local change_log="/pg/change/${change_filename}"
    local src_checksum=$(md5sum ${src} | awk '{print $1}')

    # check if any same deployment already recorded in change history
    if (grep -q ${src_checksum} /pg/change/histroy 2> /dev/null); then
        log_warn "found exact same bash scripts in history"
        grep ${src_checksum} /pg/change/histroy
    # return 10
    fi

    local pg_is_primary=$(psql ${dbname} -1qAXtc 'SELECT pg_is_in_recovery();' 2> /dev/null)
    if [[ $? != 0 || ${pg_is_primary} == 't' ]]; then
        log_error "${dbname} unreachable or is in recovery"
        return 21
    fi

    # for sql, just write exact copy into change_log
    # and record meta data in /pg/change/history
    cat ${src} > ${change_log}

    # deploy start
    status="FAIL"
    log_info "deployment sql begin: psql ${dbname} -f ${src}"
    psql ${dbname} -v ON_ERROR_STOP=ON -Xf ${src}
    if [[ $? == 0 ]]; then
        status="PASS"
        log_info "[PASS] deployment sql complete"
    else
        log_error "[FAIL] deployment sql failed, check ${change_log} for detail"
    fi

    # write change meta data to /pg/change/history
    local meta="$(date '+%Y-%m-%d %H:%M:%S') [${status}] ${src_checksum} ${change_log}"
    log_info "${meta}"
    echo "${meta}" >> /pg/change/history

    [[ ${status} == "PASS" ]] && return 0 || return 22
}




#==============================================================#
#                       CONF DEPLOY                            #
#==============================================================#
# Name: deploy_conf
# Desc: deploy conf changes and record history
#--------------------------------------------------------------#

function deploy_conf() {
    local src=$1
    local dst=${2}

    local src_filename=$(basename ${src})
    local dst_filename=$(basename ${dst})

    local change_timestamp="$(date '+%Y%m%d_%H%M%S')"
    local change_filename="${change_timestamp}_${src_filename}"
    local change_log="/pg/change/${change_filename}"

    # if dst & src have exact same checksum, skip
    local src_checksum=$(md5sum ${src} | awk '{print $1}')
    if [[ -f ${dst} ]]; then
        local dst_checksum=$(md5sum ${dst} | awk '{print $1}')
        log_info "src checksum: ${src_checksum}"
        log_info "dst checksum: ${dst_checksum}"

        if [[ ${src_checksum} == ${dst_checksum} ]]; then
            log_warn "no change found between ${src} and ${dst}, skip"
            return 0
        fi
    fi

    # show diff
    diff ${src} ${dst}

    # overwrite dst_file
    cat ${src} >> ${change_log}
    if [[ -f ${dst} ]]; then
        # if dst file exist: write additional diff to it
        echo "#[DIFF]============================================================" >> ${change_log}
        diff ${src} ${dst} >> ${change_log}

        # and write original conf to change log
        echo "#[OLD]============================================================" >> ${change_log}
        cat ${dst} >> ${change_log}
    fi

    # write content to dst file
    local status="FAIL"
    cat ${src} > ${dst}
    if [[ $? == 0 ]]; then
        status="PASS"
        log_info "[PASS] deployment conf complete"
    else
        log_error "[FAIL] deployment conf failed, check ${change_log} for detail"
    fi

    # write change meta data to /pg/change/history
    local meta="$(date '+%Y-%m-%d %H:%M:%S') [${status}] ${src_checksum} ${change_log}"
    log_info "${meta}"
    echo "${meta}" >> /pg/change/history

    [[ ${status} == "PASS" ]] && return 0 || return 1
}




#==============================================================#
#                            Main                              #
#==============================================================#
# Args:
#   $1  file path to be deployed
#   $2  deploy target (by default is a non-trivial db in local)
#
# Desc:
#   There three modes: sql , bash , conf
#   sql deploy triggered by (*.sql) file: psql $2 -f $1
#   bash deploy triggered by (*.sh) file: bash $1 $@
#   conf deploy triggered by other files: cat $1 > $2
#
#==============================================================#


function main() {
    if [[ $(whoami) != "postgres" ]]; then
        log_error "deploy requires user postgres"
        return 1
    fi

    local src=${1};
    shift
    local dst=${1-''}

    if [[ -z ${src} ]]; then
        log_error "deploy require a file path"
        return 2
    fi

    # source file should exist
    if [[ ! -f ${src} ]]; then
        log_error "${src} not found, did you copy it to target machine?"
        return 3
    fi

    local src_filename=$(basename ${src})
    local deploy_type='conf'
    case ${src_filename} in
        *.sh)
            deploy_type='bash'
        ;;
        *.sql)
            deploy_type='sql'
            # if it is sql deploy without explict dbname, infer from local instance
            [[ -z ${dst} ]] && dst=$(pg_get_dbname)
            if [[ -z ${dst} ]]; then
                log_error "sql deployment require a local viable dbname"
                return 4
            fi
        ;;
    # Well known conf files
        "postgresql.conf")
            [[ -z "${dst}" ]] && dst='/pg/data/postgresql.conf' ;;
        "recovery.conf")
            [[ -z "${dst}" ]] && dst='/pg/data/recovery.conf' ;;
        "pg_hba.conf")
            [[ -z "${dst}" ]] && dst='/pg/data/pg_hba.conf' ;;
        "pgbouncer.ini")
            [[ -z "${dst}" ]] && dst='/etc/pgbouncer/pgbouncer.ini' ;;
        "walarchiver.env")
            [[ -z "${dst}" ]] && dst='/etc/walarchiver/env' ;;
        "postgres_exporter.env")
            [[ -z "${dst}" ]] && dst='/etc/postgres_exporter/env' ;;
        "postgres_exporter.yaml")
            [[ -z "${dst}" ]] && dst='/etc/postgres_exporter/queries.yaml' ;;
        *) # not a bash, not a sql, and not a well known conf
            if [[ -z ${dst} ]]; then
                log_error "you must specify dst path for not well known conf files"
                return 2
            fi
        ;;
    esac

    log_debug "DEPLOY TYPE: ${deploy_type} ${src} ${dst}"
    case ${deploy_type} in
        bash)
            deploy_bash ${src} $@ ;;
        sql)
            deploy_sql ${src} ${dst} ;;
        conf)
            deploy_conf ${src} ${dst} ;;
        *)
            log_error "invalid deploy type ${deploy_type}" ;;
    esac

    return $?
}


main $@