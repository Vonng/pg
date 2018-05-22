#!/bin/bash

#==============================================================#
# File      :   install-pgbouncer-exporter.sh
# Mtime     :   2019-03-06
# Desc      :   Install Pgbouncer Exporter
# Path      :   bin/install-pgbouncer-exporter.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   CentOS7
# Note      :   check /opt/conf/services/pgbouncer_exporter.service
#==============================================================#


# module info
__MODULE_INSTALL_CONSUL="install-pgbouncer-exporter"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


#--------------------------------------------------------------#
# Name: download_pgbouncer_exporter
# Desc: Guarantee a usable pgbouncer_exporter in ${target_location}
# Arg1: target pgbouncer_exporter location      (/usr/local/bin/pgbouncer_exporter)
# Arg2: cache  pgbouncer_exporter location      (/opt/pkg/pgbouncer_exporter)
# Arg3: pgbouncer_exporter version to download  (0.0.3)
# Note: Run this as root
# Note: This will
#--------------------------------------------------------------#
function download_pgbouncer_exporter() {
    local target_location=${1-'/usr/local/bin/pgbouncer_exporter'}
    local cache_location=${2-'/opt/pkg/pgbouncer_exporter'}
    local pgbouncer_exporter_version=${3-'0.0.3'}

    # if exact same version already in target location, skip
    if [[ -x ${target_location} ]]; then
        echo "warn: found pgbouncer_exporter ${pgbouncer_exporter_version} on ${target_location}, skip"
        return 0
    fi

    # if pgbouncer_exporter in /opt/pkg, use it regardless version
    if [[ -x ${cache_location} ]]; then
        echo "warn: found pgbouncer_exporter in cache, cp ${cache_location} ${target_location}, skip"
        cp -f ${cache_location} ${target_location}
        return 0
    fi

    # download from Internet
    local pgbouncer_exporter_filename="pgbouncer_exporter-${pgbouncer_exporter_version}.linux-amd64.tar.gz"
    local pgbouncer_exporter_url="https://github.com/larseen/pgbouncer_exporter/releases/download/${pgbouncer_exporter_version}/${pgbouncer_exporter_filename}"
    echo "info: download pgbouncer_exporter from ${pgbouncer_exporter_url}"

    cd /tmp
    rm -rf ${pgbouncer_exporter_filename}
    if ! wget ${pgbouncer_exporter_url} 2> /dev/null; then
        echo 'error: download pgbouncer_exporter failed'
        return 2
    fi
    if ! tar -xf ${pgbouncer_exporter_filename} 2> /dev/null; then
        echo 'error: unzip pgbouncer_exporter failed'
        return 3
    fi
    mv -f "pgbouncer_exporter-${pgbouncer_exporter_version}.linux-amd64"/pgbouncer_exporter ${target_location}
    cd - > /dev/null

    return 0
}


#--------------------------------------------------------------#
# Name: install_pgbouncer_exporter
# Desc: install pgbouncer_exporter service to systemctl
# Note: Assume viable pgbouncer_exporter binary in /usr/local/bin/pgbouncer_exporter
# Note: Run this as root
#       pgbouncer_exporter conf dir: /etc/pgbouncer_exporter.d
#       pgbouncer_exporter data dir: /var/lib/pgbouncer_exporter
#       pgbouncer_exporter binary  : /usr/local/bin/pgbouncer_exporter
#--------------------------------------------------------------#
function install_pgbouncer_exporter() {
    if [[ ! -x /usr/local/bin/pgbouncer_exporter ]]; then
        echo "warn: /usr/local/bin/pgbouncer_exporter not found, download"
        download_pgbouncer_exporter
        if [[ $? != 0 ]]; then
            echo "error: download pgbouncer_exporter failed"
            return $?
        fi
    fi

    # init pgbouncer_exporter services
    if [[ -f /opt/conf/services/pgbouncer_exporter.service ]]; then
        echo "info: found pgbouncer_exporter.services in /opt/conf, copy pgbouncer_exporter.service to /etc/systemd/system/"
        rm -rf /etc/systemd/system/pgbouncer_exporter.service
        cp -f /opt/conf/services/pgbouncer_exporter.service /etc/systemd/system/pgbouncer_exporter.service
    else
        echo "info: overwrite /etc/systemd/system/pgbouncer_exporter.service"
		cat > /etc/systemd/system/pgbouncer_exporter.service <<- EOF
		[Unit]
		Description=pgbouncer_exporter for prometheus
		Documentation=https://github.com/larseen/pgbouncer_exporter
		Wants=pgbouncer.service
		Wants=network-online.target
		After=network-online.target

		[Service]
		User=postgres
		Group=postgres
		Environment=PGSSLMODE=disable
		Environment=PGPORT=6432
		Environment=PGHOST=/var/run/postgresql
		Environment=PGDATABASE=pgbouncer
		ExecStart=/usr/local/bin/pgbouncer_exporter -pgBouncer.connectionString=postgres://postgres@:6432/pgbouncer
		Restart=on-failure

		[Install]
		WantedBy=multi-user.target
		EOF
    fi

    chown -R postgres:postgres /etc/systemd/system/pgbouncer_exporter.service /usr/local/bin/pgbouncer_exporter
    systemctl daemon-reload
    return 0
}



#--------------------------------------------------------------#
# Name: launch_pgbouncer_exporter
# Desc: launch pgbouncer_exporter service
# Note: Assume pgbouncer_exporter.service installed
#--------------------------------------------------------------#
function launch_pgbouncer_exporter(){
    if ! systemctl | grep pgbouncer_exporter.service; then
        echo "info: pgbouncer_exporter.service not found"
        install_pgbouncer_exporter
    fi

    systemctl stop    pgbouncer_exporter > /dev/null 2>&1
    systemctl enable  pgbouncer_exporter > /dev/null 2>&1
    systemctl restart pgbouncer_exporter > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        systemctl status pgbouncer_exporter
        return 4
    fi

    # Double check
    if systemctl status consul > /dev/null 2>&1; then
        echo "info: start pgbouncer_exporter.service"
    else
        echo "error: fail to start pgbouncer_exporter.service"
    fi
    return 0
}


#==============================================================#
#                              Main                            #
#==============================================================#
function main(){
    if [[ $(whoami) != "root" ]]; then
        echo "error: install pgbouncer exporter require root"
        return 1
    fi

    local action=${1-''}
    case ${action} in
        download ) shift; download_pgbouncer_exporter $@ ;;
        install  ) shift; install_pgbouncer_exporter  $@ ;;
        launch   ) shift; launch_pgbouncer_exporter   $@ ;;
        *        )        launch_pgbouncer_exporter   $@ ;;
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
#   2   download pgbouncer exporter failed
#   3   decompress pgbouncer_exporter failed
#   4   launch pgbouncer_exporter failed
#==============================================================#
main $@