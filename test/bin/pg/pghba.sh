#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   pghba.sh
# Mtime     :   2018-11-01
# Desc      :   PostgreSQL Config Management
# Path      :   /pg/bin/pghba.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   psql, pg_ctl
#==============================================================#

# module info
__MODULE_PGHBA="pghba"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"

# psql & pg_basebackup PATH
export PATH=/usr/pgsql/bin:${PATH}


#==============================================================#
#                             Usage                            #
#==============================================================#
function usage(){
    cat <<- 'EOF'

    NAME
        pghba.sh   -- PostgreSQL HBA Configuration Management

    SYNOPSIS


    DESCRIPTION

EOF
}


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


# TODO