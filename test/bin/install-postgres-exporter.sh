#!/bin/bash

#==============================================================#
# File      :   install-postgres-exporter.sh
# Mtime     :   2019-03-06
# Desc      :   Install Postgres Exporter
# Path      :   bin/install-postgres-exporter.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   CentOS7
# Note      :   check /opt/conf/services/postgres_exporter.service
#==============================================================#


# module info
__MODULE_INSTALL_POSTGRES_EXPORTER="install-postgres-exporter"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


#--------------------------------------------------------------#
# Name: download_postgres_exporter
# Desc: Guarantee a usable postgres_exporter in ${target_location}
# Arg1: target postgres_exporter location      (/usr/local/bin/postgres_exporter)
# Arg2: cache  postgres_exporter location      (/opt/pkg/postgres_exporter)
# Arg3: postgres_exporter version to download  (0.4.7)
# Note: Run this as root
# Note: This will
#--------------------------------------------------------------#
function download_postgres_exporter() {
    local target_location=${1-'/usr/local/bin/postgres_exporter'}
    local cache_location=${2-'/opt/pkg/postgres_exporter'}
    local postgres_exporter_version=${3-'0.4.7'}

    # if exact same version already in target location, skip
    if [[ -x ${target_location} ]]; then
        echo "warn: found postgres_exporter ${postgres_exporter_version} on ${target_location}, skip"
        return 0
    fi

    # if postgres_exporter in /opt/pkg, use it regardless version
    if [[ -x ${cache_location} ]]; then
        echo "warn: found postgres_exporter in cache, cp ${cache_location} ${target_location}, skip"
        cp -f ${cache_location} ${target_location}
        return 0
    fi

    # download from Internet
    local postgres_exporter_filename="postgres_exporter_v${postgres_exporter_version}_linux-amd64.tar.gz"
    local postgres_exporter_url="https://github.com/wrouesnel/postgres_exporter/releases/download/v${postgres_exporter_version}/${postgres_exporter_filename}"
    echo "info: download postgres_exporter from ${postgres_exporter_url}"

    cd /tmp
    rm -rf ${postgres_exporter_filename}
    if ! wget ${postgres_exporter_url} 2> /dev/null; then
        echo 'error: download postgres_exporter failed'
        return 2
    fi
    if ! tar -xf ${postgres_exporter_filename} 2> /dev/null; then
        echo 'error: unzip postgres_exporter failed'
        return 3
    fi
    mv -f "postgres_exporter_v${postgres_exporter_version}_linux-amd64/postgres_exporter" ${target_location}
    cd - > /dev/null

    return 0
}


#--------------------------------------------------------------#
# Name: install_postgres_exporter
# Desc: install postgres_exporter service to systemctl
# Note: Assume viable postgres_exporter binary in /usr/local/bin/postgres_exporter
# Note: Run this as root
#       postgres_exporter conf dir: /etc/postgres_exporter.d
#       postgres_exporter data dir: /var/lib/postgres_exporter
#       postgres_exporter binary  : /usr/local/bin/postgres_exporter
#--------------------------------------------------------------#
function install_postgres_exporter() {
    if [[ ! -x /usr/local/bin/postgres_exporter ]]; then
        echo "warn: /usr/local/bin/postgres_exporter not found, download"
        download_postgres_exporter
        if [[ $? != 0 ]]; then
            echo "error: download postgres_exporter failed"
            return $?
        fi
    fi

    # init dir & conf
    mkdir -p /etc/postgres_exporter
    if [[ -f /opt/conf/postgres_exporter.yaml ]]; then
        echo "info: found /opt/conf/postgres_exporter.yaml , copy postgres_exporter.yaml to /etc/postgres_exporter/queries.yaml"
        rm -rf /etc/postgres_exporter/queries.yaml
        cp -f /opt/conf/postgres_exporter.yaml /etc/postgres_exporter/queries.yaml
    fi

    # services parameter
    if [[ -f /opt/conf/postgres_exporter.env ]]; then
        echo "info: found /opt/conf/postgres_exporter.env , copy postgres_exporter.env to /etc/postgres_exporter/env"
        rm -rf /etc/postgres_exporter/env
        cp /opt/conf/postgres_exporter.env /etc/postgres_exporter/env
    else
        if [[ -f /etc/postgres_exporter/queries.yaml ]]; then
			cat > /etc/postgres_exporter/env <<- EOF
			DATA_SOURCE_NAME='dbname=postgres user=postgres host=/tmp port=5432 sslmode=disable application_name=postgres_exporter'
			PG_EXPORTER_DISABLE_DEFAULT_METRICS=true
			PG_EXPORTER_EXTEND_QUERY_PATH=/etc/postgres_exporter/queries.yaml
			EOF
        else
            cat > /etc/postgres_exporter/env <<- EOF
			DATA_SOURCE_NAME='dbname=postgres user=postgres host=/tmp port=5432 sslmode=disable application_name=postgres_exporter'
			PG_EXPORTER_DISABLE_DEFAULT_METRICS=false
			EOF
        fi
    fi

    # init postgres_exporter services
    if [[ -f /opt/conf/services/postgres_exporter.service ]]; then
        echo "info: found postgres_exporter.services in /opt/conf, copy postgres_exporter.service to /etc/systemd/system/"
        rm -rf /etc/systemd/system/postgres_exporter.service
        cp -f /opt/conf/services/postgres_exporter.service /etc/systemd/system/postgres_exporter.service
    else
        echo "info: overwrite /etc/systemd/system/postgres_exporter.service"
		cat > /etc/systemd/system/postgres_exporter.service <<- EOF
		[Unit]
		Description=postgres_exporter for prometheus
		Wants=postgresql.service
		Wants=network-online.target
		After=network-online.target
		ConditionFileNotEmpty=/etc/postgres_exporter/env
		ConditionFileNotEmpty=/etc/postgres_exporter/queries.yaml

		[Service]
		User=postgres
		Group=postgres
		EnvironmentFile=/etc/postgres_exporter/env
		ExecStartPre=-/usr/bin/chown -R postgres:postgres /etc/systemd/system/postgres_exporter.service /etc/postgres_exporter

		ExecStart=/usr/local/bin/postgres_exporter
		KillMode=process
		Restart=on-failure

		[Install]
		WantedBy=default.target
		EOF
    fi

    chown -R postgres:postgres /etc/systemd/system/postgres_exporter.service /etc/postgres_exporter
    systemctl daemon-reload
    return 0
}



#--------------------------------------------------------------#
# Name: launch_postgres_exporter
# Desc: launch postgres_exporter service
# Note: Assume postgres_exporter.service installed
#--------------------------------------------------------------#
function launch_postgres_exporter(){
    if ! systemctl | grep postgres_exporter.service; then
        echo "info: postgres_exporter.service not found"
        install_postgres_exporter
    fi

    systemctl stop    postgres_exporter > /dev/null 2>&1
    systemctl enable  postgres_exporter > /dev/null 2>&1
    systemctl restart postgres_exporter > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        systemctl status postgres_exporter
        return 4
    fi

    # Double check
    if systemctl status postgres_exporter > /dev/null 2>&1; then
        echo "info: start postgres_exporter.service"
    else
        echo "error: fail to start postgres_exporter.service"
    fi
    return 0
}


#==============================================================#
#                              Main                            #
#==============================================================#
function main(){
    if [[ $(whoami) != "root" ]]; then
        echo "error: install postgres exporter require root"
        return 1
    fi

    local action=${1-''}
    case ${action} in
        download ) shift; download_postgres_exporter $@ ;;
        install  ) shift; install_postgres_exporter  $@ ;;
        launch   ) shift; launch_postgres_exporter   $@ ;;
        *        )        launch_postgres_exporter   $@ ;;
    esac

    return $?
}

#==============================================================#
#                             Main                             #
#==============================================================#
# Args:
#   $1  action: download | install | launch (install by default)
#
# Code:
#   0   ok
#   1   insufficient privilege
#   2   download postgres exporter failed
#   3   decompress postgres_exporter failed
#   4   launch postgres_exporter failed
#==============================================================#
main $@