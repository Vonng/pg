#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   fencing.sh
# Mtime     :   2018-05-18
# Desc      :   Fencing PostgreSQL Master
# Path      :   /pg/bin/fencing.sh
# Author    :   Vonng(fengruohang@outlook.com)
#==============================================================#

# module info
__MODULE_FENCING="fencing"

PROGRAM_DIR="$(cd $(dirname $0) && pwd)"
PROGRAM_NAME="$(basename $0)"

# TODO