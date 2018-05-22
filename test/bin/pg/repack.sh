#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   repack.sh
# Mtime     :   2018-05-18
# Desc      :   Maintain tasks, vacuum
# Path      :   /pg/bin/repack.sh
# Cron      :   "00 03 * * * sh /pg/bin/vacuum.sh"
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   psql, pg_repack
#==============================================================#

# module info
__MODULE_REPACK="repack"

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


# TODO
