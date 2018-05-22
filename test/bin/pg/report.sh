#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   report.sh
# Mtime     :   2018-07-07
# Desc      :   Generate PostgreSQL Routine Report
# Path      :   /pg/bin/report.sh
# Cron      :   "00 00 * * * sh /pg/bin/report.sh"
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   psql
#==============================================================#

# module info
__MODULE_REPORT="report"

PROGRAM_DIR="$(cd $(dirname $0) && pwd)"
PROGRAM_NAME="$(basename $0)"

# psql PATH
export PATH=/usr/pgsql/bin:${PATH}

# TODO