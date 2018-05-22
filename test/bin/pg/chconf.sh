#!/bin/bash
set -uo pipefail

##=============================================================#
# File      :   chconf.sh
# Mtime     :   2018-12-06
# Desc      :   Change Config File (and record change history)
# Path      :   /pg/bin/chconf.sh
# Author    :   Vonng(fengruohang@outlook.com)
##=============================================================#

# module info
__MODULE_CHCONF="chconf"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


function chconf() {
    local src_file=$1
    local dst_file=${2-''}

    if [[ ! -f ${src_file} ]]; then
		echo "error: ${src_file} not found"
		return 1
    fi

    local src_filename=$(basename ${src_file})
    case ${src_filename} in
		"postgresql.conf" ) [[ -z "${dst_file}" ]] && dst_file='/pg/data/postgresql.conf'                   ;;
		"recovery.conf" ) [[ -z "${dst_file}" ]] && dst_file='/pg/data/recovery.conf'                       ;;
		"pg_hba.conf" ) [[ -z "${dst_file}" ]] && dst_file='/pg/data/pg_hba.conf'                           ;;
		"pgbouncer.ini" ) [[ -z "${dst_file}" ]] && dst_file='/etc/pgbouncer/pgbouncer.ini'                 ;;
		"walarchiver.env" ) [[ -z "${dst_file}" ]] && dst_file='/etc/walarchiver/env'                       ;;
		"postgres_exporter.env" ) [[ -z "${dst_file}" ]] && dst_file='/etc/postgres_exporter/env'           ;;
		"postgres_exporter.yaml" ) [[ -z "${dst_file}" ]] && dst_file='/etc/postgres_exporter/queries.yaml' ;;
		"consul.json" ) [[ -z "${dst_file}" ]] && dst_file='/etc/consul.d/consul.json'                      ;;
		* )
			if [[ -z ${dst_file} ]]; then
				echo "error: you must specify dst_path for not well known conf files"
				return 2
			fi
		;;
    esac
    local dst_filename=$(basename ${dst_file})
    local change_timestamp="$(date +%Y%m%d_%H%M%S)"
    local change_filename="${change_timestamp}_change_${dst_filename}"
    local change_log="/pg/change/${change_filename}"

    local src_checksum=$(md5sum ${src_file})
    local dst_checksum="<destination file do not exists>  ${dst_file}"
    if [[ -f ${dst_file} ]]; then
        dst_checksum=$(md5sum ${dst_file})

        echo "info: src_checksum $(echo ${src_checksum} | awk '{print $1}')"
	    echo "info: dst_checksum $(echo ${dst_checksum} | awk '{print $1}')"

        if [[ $(echo ${src_checksum} | awk '{print $1}') == $(echo ${dst_checksum} | awk '{print $1}') ]]; then
            echo "info: src and dst are exactly the same, skip"
            return 0
        fi
    fi

	cat > ${change_log} <<- EOF
	#========================================================
	# Change Record
	# Type: Conf Change
	# Time: ${change_timestamp}
	# Src : ${src_checksum}
	# Dst : ${dst_checksum}
	#========================================================
	EOF

    if [[ -f ${dst_file} ]]; then
		# dst file exist: replace and record change
		echo "info: ${dst_file} exists, write diff to change log"

        # write difference between and new
		cat >> ${change_log} <<- EOF
		#========================================================
		# DIFF ${src_file} ${dst_file}
		#========================================================
		EOF
		diff ${src_file} ${dst_file} >> ${change_log}

        # Write old conf file content
		cat >> ${change_log} <<- EOF
		#========================================================
		# OLD ${dst_file}
		#========================================================
		EOF
		cat ${dst_file} >> ${change_log}
    fi

    # write content to dst file
    local status="FAIL"
    cat ${src_file} > ${dst_file}
    if [[ $? == 0 ]]; then
		status="PASS"
    fi

	cat >> ${change_log} <<- EOF
	#========================================================
	# CHANGE [${status}] ${HOSTNAME} $(date '+%Y-%m-%d %H:%M:%S')
	#========================================================
	EOF
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${status}] $(md5sum ${change_log})" >> /pg/change/history

    head -n15 ${change_log}
    [[ ${status} == "PASS" ]] && return 0 || return 1
}

chconf $@