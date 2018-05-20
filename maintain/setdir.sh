#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   setdir.sh
# Mtime     :   2018-05-18
# Desc      :   Setup directory
# Path      :   /pg/bin/setdir.sh
# Author    :   Vonng(fengruohang@outlook.com)
#==============================================================#


#==============================================================#
#                         Params                               #
#==============================================================#
# Module Name of Postgres (e.g chat, pay, shard42)
MODULE_NAME=${1}
if [[ ${MODULE_NAME} == "" ]]
then
    exit 1
fi

# Major PostgreSQL Version (default 10)
PG_MAJOR_VERSION=${2-"10"}

# Module Full Name
MODULE="${MODULE_NAME}_${PG_MAJOR_VERSION}"



#==============================================================#
#                  Color Message  Utils                        #
#==============================================================#
declare -r __NC='\033[0m' # No Color
declare -r __BLACK='\033[0;30m'
declare -r __RED='\033[0;31m'
declare -r __GREEN='\033[0;32m'
declare -r __YELLOW='\033[0;33m'
declare -r __BLUE='\033[0;34m'
declare -r __MAGENTA='\033[0;35m'
declare -r __CYAN='\033[0;36m'
declare -r __WHITE='\033[0;37m'

# colored message
function cm(){
    local color=$(echo $1 | tr '[:upper:]' '[:lower:]')
    local msg=$2
    case ${color} in
        0|k|black  ) color=$__BLACK   ;;
        1|r|red    ) color=$__RED     ;;
        2|g|green  ) color=$__GREEN   ;;
        3|y|yellow ) color=$__YELLOW  ;;
        4|b|blue   ) color=$__BLUE    ;;
        5|m|magenta) color=$__MAGENTA ;;
        6|c|cyan   ) color=$__CYAN    ;;
        7|w|white  ) color=$__WHITE   ;;
        8|n|none   ) color=$__NC      ;;
        *          ) color=""        ;;
    esac

    if [[ ${color} != "" ]]; then
        echo -n "${color}${msg}${__NC}"
        return 0
    else
        echo -n ${msg}
        return 0
    fi
}

# colored print
function print(){
    local color=$(echo $1 | tr '[:upper:]' '[:lower:]')
    local msg=$2
    case ${color} in
        0|k|black  ) color=$__BLACK   ;;
        1|r|red    ) color=$__RED     ;;
        2|g|green  ) color=$__GREEN   ;;
        3|y|yellow ) color=$__YELLOW  ;;
        4|b|blue   ) color=$__BLUE    ;;
        5|m|magenta) color=$__MAGENTA ;;
        6|c|cyan   ) color=$__CYAN    ;;
        7|w|white  ) color=$__WHITE   ;;
        8|n|none   ) color=$__NC      ;;
        *          ) color=""        ;;
    esac

    if [[ ${color} != "" ]]; then
        echo -e "${color}${msg}${__NC}"
        return 0
    else
        echo -e ${msg}
        return 0
    fi
}

#==============================================================#
#                        Mount Point                           #
#==============================================================#
PG_ROOT="/export/postgresql"
PG_BKUP="/var/backups"

print b "==========================================================="
print y "# Postgresql directory initialization..."
print b "==========================================================="
echo -e $(cm b PG_ROOT) $'\t'   $(cm y ${PG_ROOT})
echo -e $(cm b PG_BKUP) $'\t'   $(cm y ${PG_BKUP})
echo -e $(cm r MODULES) $'\t'   $(cm y ${MODULE})

# execute
mkdir -p ${PG_ROOT} ${PG_BKUP}
chown postgres:postgres ${PG_ROOT} ${PG_BKUP}
chmod 755 ${PG_ROOT} ${PG_BKUP}



#==============================================================#
#                       Backup Dirs                            #
#==============================================================#
PG_BACKUP_DIR="${PG_BKUP}/backup"
PG_REMOTE_DIR="${PG_BKUP}/remote"
PG_ARCWAL_DIR="${PG_BKUP}/arcwal"

print b "-----------------------------------------------------------"
print r "Directories in $(cm y ${PG_BKUP}):"
echo -e $(cm b PG_BACKUP_DIR  )  $'\t'   $(cm y ${PG_BACKUP_DIR})
echo -e $(cm b PG_REMOTE_DIR  )  $'\t'   $(cm y ${PG_REMOTE_DIR})
echo -e $(cm b PG_ARCWAL_DIR  )  $'\t'   $(cm y ${PG_ARCWAL_DIR})

# execute
mkdir -p ${PG_BACKUP_DIR} ${PG_REMOTE_DIR} ${PG_ARCWAL_DIR}
chown postgres:postgres ${PG_BACKUP_DIR} ${PG_REMOTE_DIR} ${PG_ARCWAL_DIR}
chmod 700 ${PG_BACKUP_DIR} ${PG_REMOTE_DIR} ${PG_ARCWAL_DIR}


#==============================================================#
#                        Main Dirs                             #
#==============================================================#
PG_MAIN_DIR="${PG_ROOT}/${MODULE}"

PG_BIN_DIR="${PG_MAIN_DIR}/bin"
PG_TMP_DIR="${PG_MAIN_DIR}/tmp"
PG_DATA_DIR="${PG_MAIN_DIR}/data"
PG_CONF_DIR="${PG_MAIN_DIR}/conf"
PG_TLOG_DIR="${PG_MAIN_DIR}/tlog"

print b "-----------------------------------------------------------"
print r "Directories in $(cm y ${PG_ROOT}):"
echo -e $(cm b PG_MAIN_DIR )  $'\t'   $(cm y ${PG_MAIN_DIR})
echo -e $(cm b PG_BIN_DIR  )  $'\t'   $(cm y ${PG_BIN_DIR})
echo -e $(cm b PG_TMP_DIR  )  $'\t'   $(cm y ${PG_TMP_DIR})
echo -e $(cm b PG_DATA_DIR )  $'\t'   $(cm y ${PG_DATA_DIR})
echo -e $(cm b PG_TLOG_DIR )  $'\t'   $(cm y ${PG_TLOG_DIR})
echo -e $(cm b PG_CONF_DIR )  $'\t'   $(cm y ${PG_CONF_DIR})

mkdir -p ${PG_MAIN_DIR} ${PG_BIN_DIR} ${PG_TMP_DIR} ${PG_DATA_DIR} ${PG_TLOG_DIR} ${PG_CONF_DIR}
chown postgres:postgres ${PG_MAIN_DIR} ${PG_BIN_DIR} ${PG_TMP_DIR} ${PG_DATA_DIR} ${PG_TLOG_DIR} ${PG_CONF_DIR}
chmod 755 ${PG_MAIN_DIR} ${PG_BIN_DIR} ${PG_TLOG_DIR} ${PG_TMP_DIR} ${PG_CONF_DIR}
chmod 700 ${PG_DATA_DIR}


#==============================================================#
#                      Soft Links                              #
#==============================================================#
PG_HOME_LINK="/var/lib/pgsql"
PG_FAST_LINK="/pg"
PG_LOG_LINK="${PG_MAIN_DIR}/log"
PG_BACKUP_LINK="${PG_MAIN_DIR}/backup"
PG_REMOTE_LINK="${PG_MAIN_DIR}/remote"
PG_ARCWAL_LINK="${PG_MAIN_DIR}/arcwal"
PG_LOG_DIR="${PG_DATA_DIR}/log"
if [[ ! ${PG_MAJOR_VERSION}=="10" ]]; then
    PG_LOG_DIR="${PG_DATA_DIR}/pg_log"
fi

print b "-----------------------------------------------------------"
print r "Soft Links:"
echo -e $(cm m ${PG_HOME_LINK} )   $'\t-> '   $(cm y ${PG_MAIN_DIR})
echo -e $(cm m ${PG_FAST_LINK} )   $'\t-> '   $(cm y ${PG_MAIN_DIR})
echo -e $(cm m ${PG_LOG_LINK} )    $'\t-> '   $(cm y ${PG_LOG_DIR})
echo -e $(cm m ${PG_BACKUP_LINK} ) $'\t-> '   $(cm y ${PG_BACKUP_DIR})
echo -e $(cm m ${PG_REMOTE_LINK} ) $'\t-> '   $(cm y ${PG_REMOTE_DIR})
echo -e $(cm m ${PG_ARCWAL_LINK} ) $'\t-> '   $(cm y ${PG_ARCWAL_DIR})

[[ -a ${PG_BACKUP_LINK} ]] && rm -rf ${PG_BACKUP_LINK}
[[ -a ${PG_REMOTE_LINK} ]] && rm -rf ${PG_REMOTE_LINK}
[[ -a ${PG_ARCWAL_LINK} ]] && rm -rf ${PG_ARCWAL_LINK}
[[ -a ${PG_LOG_LINK} ]] && rm -rf ${PG_LOG_LINK}
[[ -a ${PG_HOME_LINK} ]] && rm -rf ${PG_HOME_LINK}  # Warn!
[[ -a ${PG_FAST_LINK} ]] && rm -rf ${PG_FAST_LINK}

ln -s ${PG_MAIN_DIR} ${PG_HOME_LINK}
ln -s ${PG_MAIN_DIR} ${PG_FAST_LINK}

ln -s ${PG_LOG_DIR} ${PG_LOG_LINK}
ln -s ${PG_BACKUP_DIR} ${PG_BACKUP_LINK}
ln -s ${PG_REMOTE_DIR} ${PG_REMOTE_LINK}
ln -s ${PG_ARCWAL_DIR} ${PG_ARCWAL_LINK}
