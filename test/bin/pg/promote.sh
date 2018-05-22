#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   promote.sh
# Mtime     :   2018-05-18
# Desc      :   Promote postgres slave
# Path      :   /pg/bin/promote.sh
# Author    :   Vonng(fengruohang@outlook.com)
#==============================================================#

# module info
__MODULE_PROMOTE="promote"

PROGRAM_DIR="$(cd $(dirname $0) && pwd)"
PROGRAM_NAME="$(basename $0)"

touch /pg/promote; pg_ctl -D /pg/data promote