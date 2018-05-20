#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   backup.sh
# Mtime     :   2018-05-18
# Desc      :   Routine backup script (for local instance)
# Path      :   /pg/bin/backup.sh
# Cron      :   "00 01 * * * /pg/bin/backup.sh"
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   lz4, ~/.pgpass for replication, /pg/{backup,tmp}
#==============================================================#

# module info
__MODULE_BACKUP="backup"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


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

# get primary IP address
function local_ip(){
    # ip range in 10.xxx.xxx.xx
    echo $(/sbin/ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '10\.([0-9]*\.){2}[0-9]*')
}

# send mail via mail service
function send_mail(){
    local subject=$1
    local content=$2
    local to=${3-"fengruohang@p1.com"}
    # TODO: Implement your own mail service
}

# slave returns 't', psql access required
function is_slave(){
    echo $(psql -Atqc "SELECT pg_is_in_recovery();")
}


#==============================================================#
#                            Backup                            #
#==============================================================#


#--------------------------------------------------------------#
# Name: make_base_backup
# Desc: make a compress base backup to given path
# Arg1: backup target path
# Deps: lz4, replication .pgpass, pg_basebackup
# Note: e.g pgpass: '127.0.0.1:5432:*:replication:<password>'
#--------------------------------------------------------------#
function make_base_backup(){
    local backup_path=$1
    log_info "pg_basebackup start. target path: ${backup_path}"
    pg_basebackup -h 127.0.0.1 -Ureplication -Xf -Ft -c fast -v -D -  | lz4 -q -z > "${backup_path}"

    if [[ -f ${backup_path} ]]
    then
        backup_size=$(ls -lh ${backup_path} | awk '{print $5}')
        log_info "pg_basebackup complete. ${backup_size} ${backup_path}"
        return 0
    else
        log_error  "pg_basebackup failed! ${backup_path}"
        send_mail "Backup Failed: ${backup_path}" "$(local_ip) $(date +%Y%m%d)"
        return 1
    fi
}

#--------------------------------------------------------------#
# Name: kill_base_backup
# Desc: kill running backup process
#--------------------------------------------------------------#
function kill_base_backup(){
    local pids=$(ps aux | grep pg_basebackup | grep -e "-Xf")
    local -i npids=0
    log_warn "killing basebackup processes"

    for pid in ${pids}
    do
        log_warn "kill basebackup process: $pid"
        echo $pid | awk '{print $2}' | xargs -n1 kill
        log_info "kill basebackup process done"
    done

    log_warn "basebackup processes killed"
}


#--------------------------------------------------------------#
# Name: remove_old_backup
# Desc: remove old backup files in given backup dir
# Arg1: backup directory
# Note: cond: mtime +20h
#--------------------------------------------------------------#
function remove_old_backup(){
    # delete *.lz4 file mtime before 20h ago
    local backup_dir=$1
    log_warn "pg_rm_old_backup will remove these file: $(find ${backup_dir} -type f -mmin +1200 -name *.lz4)"

    find "${backup_dir}/" -type f -mmin +1200 -name *.lz4 -delete

    if (( $? == 0 ))
    then
        log_info "pg_rm_old_backup complete"
    else
        log_error "pg_rm_old_backups failed!"
    fi
}

#--------------------------------------------------------------#
# Name: add_backup_crontab
# Desc: add backup crontab entry
#--------------------------------------------------------------#
function add_backup_crontab(){
    sudo bash -c \"echo '00 03 * * * /pg/bin/backup.sh 2> /pg/tlog/backup.log' >> /var/spool/cron/postgres\"
}

#--------------------------------------------------------------#
# Name: backup
# Desc: make backup
#--------------------------------------------------------------#
function backup(){
    local backup_dir=${1}
    local lock_path="/tmp/backup.lock"

    local backup_file="backup_$(local_ip)_$(date +%Y%m%d).tar.lz4"
    local backup_path="${backup_dir}/${backup_file}"

    # concurrent control with lock
    log_info "rountine backup begin, lock @ ${lock_path}"
    if [ -e ${lock_path} ] && kill -0 $(cat ${lock_path}); then
        log_error "backup already running: $(cat ${lock_path})"
        exit
    fi
    trap "rm -f ${lock_path}; exit" INT TERM EXIT
    echo $$ > ${lock_path}


    # make backup & remove old backup
    make_base_backup ${backup_path}
    if (( $? == 0 )); then
        remove_old_backup ${backup_dir}
    else
        log_error echo "pg_make_base_backup failed!"
        send_mail "Remove old backups Failed" "${backup_file}"
    fi

    # remove lock
    rm -f ${lock_path}
    log_info "routine backup done"
}


#--------------------------------------------------------------#
# Main
#--------------------------------------------------------------#
backup ${1-"/pg/backup"}