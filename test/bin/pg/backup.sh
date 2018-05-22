#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   backup.sh
# Mtime     :   2018-12-06
# Desc      :   PostgreSQL backup script
# Path      :   /pg/bin/backup.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   lz4, ~/.pgpass for replication, openssl
#==============================================================#

# module info
__MODULE_BACKUP="backup"

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
        backup.sh   -- make base backup from PostgreSQL instance

    SYNOPSIS
        backup.sh -sdfeukr
        backup.sh --src postgres://localhost:5433/mydb --dst . --file mybackup.tar.lz4

    DESCRIPTION
        -s, --src, --url
            Backup source URL, optional, "postgres://replication@127.0.0.1/postgres" by default
            Note: if password is required, it should be provided in url or ~/.pgpass

        -d, --dst, --dir
            Where to put backup files, "/pg/backup" by default

        -f, --file
            Backup filename, "backup_${tag}_${date}.tar.lz4" by default

        -r, --remove
            .lz4 Files mtime before n minuts ago will be removed, default is 1200 (20hour)

        -t, --tag
            Backup file tag, if not set, local ip address will be used.
            Also used as part of default filename

        -k, --key
            Encryption key when --encrypt is specified, default key is ${tag}

        -u, --upload
            Upload backup files to ufile, filemgr & /etc/ufile/config.cfg is required

        -e, --encryption
            Encrypt with RC4 using OpenSSL, if not key is specified, "ttdba" by default

        -h, --help
            Print this message

    EXAMPLES
        routine backup for coredb:
            00 01 * * * /pg/bin/backup.sh --encrypt --upload --tag=coredb 2>> /pg/log/backup.log

        manual & one-time backup:
            backup.sh -s postgres://10.10.10.10:5432/mydb -d . -f once_backup.tar.lz4 -e -tag manual

        extract backup files:
            unlz4 -d -c ${BACKUP_FILE} | tar -xC ${DATA_DIR}
            openssl enc -rc4 -d -k ${PASSWORD} -in ${BACKUP_FILE} | unlz4 -d -c | tar -xC ${DATA_DIR}
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