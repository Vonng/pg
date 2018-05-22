#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   bench.sh
# Mtime     :   2018-12-16
# Desc      :   PostgreSQL Bench Load Generator
# Path      :   /pg/bin/bench.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   psql, pgbench
#==============================================================#

# module info
__MODULE_BENCH="bench"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"

# psql & pg_basebackup PATH
export PATH=/usr/pgsql/bin:${PATH}

# TODO