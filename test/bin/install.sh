#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   install.sh
# Mtime     :   2019-03-10
# Desc      :   Install All Common Components for PostgreSQL
# Path      :   bin/install.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Deps      #   Other installation scripts in same dir
#==============================================================#


# module info
__MODULE_INSTALL="install"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


if [[ $(whoami) != "root" ]]; then
	echo "error: install consul require root"
	return 1
fi

${PROG_DIR}/setup-dns.sh
${PROG_DIR}/install-utils.sh
${PROG_DIR}/install-consul.sh
${PROG_DIR}/install-node-exporter.sh
${PROG_DIR}/install-postgres.sh
${PROG_DIR}/install-postgres-exporter.sh
${PROG_DIR}/install-pgbouncer.sh
${PROG_DIR}/install-pgbouncer-exporter.sh
${PROG_DIR}/install-walarchiver.sh
