#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   pgbouncer.sh
# Mtime     :   2018-05-18
# Desc      :   Pgbouncer utils
# Path      :   /pg/bin/pgbouncer.sh
# Author    :   Vonng(fengruohang@outlook.com)
#==============================================================#

# module info
__MODULE_PGBOUNCER="pgbouncer"

PROGRAM_DIR="$(cd $(dirname $0) && pwd)"
PROGRAM_NAME="$(basename $0)"

# TODO