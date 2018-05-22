#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   failover.sh
# Mtime     :   2018-05-18
# Desc      :   Failover to another PostgreSQL Instance
# Path      :   /pg/bin/fencing.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   pgbouncer, psql, pg_ctl
#==============================================================#

# module info
__MODULE_FAILOVER="failover"

PROGRAM_DIR="$(cd $(dirname $0) && pwd)"
PROGRAM_NAME="$(basename $0)"

# TODO