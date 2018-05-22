#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   vacuum.sh
# Mtime     :   2018-05-18
# Desc      :   Maintain tasks, vacuum
# Path      :   /pg/bin/vacuum.sh
# Cron      :   "00 05 * * * sh /pg/bin/vacuum.sh"
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   psql
#==============================================================#

# module info
__MODULE_VACUUM="vacuum"

PROGRAM_DIR="$(cd $(dirname $0) && pwd)"
PROGRAM_NAME="$(basename $0)"

# psql PATH
export PATH=/usr/pgsql/bin:${PATH}

#==============================================================#
#                             Utils                            #
#==============================================================#
# logger functions
function log_debug() {
    [ -t 2 ] && printf "\033[0;34m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][DEBUG] $*\033[0m\n" >&2 ||\
     printf "[$(date "+%Y-%m-%d %H:%M:%S")][DEBUG] $*\n" >&2
}
function log_info() {
    [ -t 2 ] && printf "\033[0;32m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][INFO] $*\033[0m\n" >&2 ||\
     printf "[$(date "+%Y-%m-%d %H:%M:%S")][INFO] $*\n" >&2
}
function log_warn() {
    [ -t 2 ] && printf "\033[0;33m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][WARN] $*\033[0m\n" >&2 ||\
     printf "[$(date "+%Y-%m-%d %H:%M:%S")][INFO] $*\n" >&2
}
function log_error() {
    [ -t 2 ] && printf "\033[0;31m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][ERROR] $*\033[0m\n" >&2 ||\
     printf "[$(date "+%Y-%m-%d %H:%M:%S")][INFO] $*\n" >&2
}


# kill queries to avoid contention, psql su access required
function kill_backend(){
    local db=$1
    kill_count=$(psql ${db} -qwAt <<-'EOF'
		SELECT count(pg_cancel_backend(pid))
		FROM pg_stat_activity
		WHERE state <> 'idle' AND pid <> pg_backend_pid()
		      AND (query ~* 'vacuum' or query ~* 'analyze');
		EOF
    2>/dev/null)
    echo ${kill_count}
}

# return tables age by fullname
function table_age(){
    local db=$1
    local fullname=$2
    echo $(psql ${db} -wqAtc "SELECT age(relfrozenxid) FROM pg_class WHERE oid = '${fullname}'::RegClass::oid;")
}

# get database's age
function database_age(){
    local db=$1
    echo $(psql ${db} -wqAtc "SELECT age(datfrozenxid) FROM pg_database WHERE datname = '${db}';")
}


# TODO
