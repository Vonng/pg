#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   monitor.sh
# Mtime     :   2018-07-01
# Desc      :   Setup PostgreSQL Monitoring Views
# Path      :   /pg/bin/monitor.sh
# Author    :   Vonng(fengruohang@outlook.com)
#==============================================================#

# module info
__MODULE_MONITOR="monitor"

PROGRAM_DIR="$(cd $(dirname $0) && pwd)"
PROGRAM_NAME="$(basename $0)"

# TODO