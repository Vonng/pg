#!/bin/bash

#==============================================================#
# File      :   install-postgres-exporter.sh
# Mtime     :   2019-03-06
# Desc      :   Install Postgres Exporter
# Path      :   bin/install-postgres-exporter.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   CentOS7
# Note      :   check /opt/conf/services/walarchiver.service
#==============================================================#


# module info
__MODULE_INSTALL_WALARCHIVER="install-walarchiver"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


#--------------------------------------------------------------#
# Name: download_walarchiver
# Desc: Guarantee a usable walarchiver in ${target_location}
# Arg1: download walarchiver url         (my github link)
# Arg2: target walarchiver location      (/usr/local/bin/walarchiver)
# Arg3: cache  walarchiver location      (/opt/pkg/walarchiver)
# Arg3: walarchiver version to download  (0.4.7)
# Note: Run this as root
# Note: walarchiver is already in cache dir
#--------------------------------------------------------------#
function download_walarchiver() {
    local download_location=${1-'https://raw.githubusercontent.com/Vonng/pg/master/test/pkg/walarchiver'}
    local target_location=${2-'/usr/local/bin/walarchiver'}
    local cache_location=${3-'/opt/pkg/walarchiver'}

    # if exact same version already in target location, skip
    if [[ -x ${target_location} ]]; then
        echo "warn: found walarchiver ${walarchiver_version} on ${target_location}, skip"
        return 0
    fi

    # if walarchiver in /opt/pkg, use it regardless version
    if [[ -x ${cache_location} ]]; then
        echo "warn: found walarchiver in cache, cp ${cache_location} ${target_location}, skip"
        cp -f ${cache_location} ${target_location}
        return 0
    else
        echo "walarchiver not found, did you remove it from /bin/cache ?"
        return 2
    fi

    cd /tmp

    # otherwise, download from github
    if ! wget ${download_location} 2> /dev/null; then
        echo 'error: download walarchiver failed'
        return 3
    fi

    if [[ ! -f walarchiver ]]; then
        echo "walarchiver still not found"
        return 4
    fi

    chmod a+x walarchiver
    mv -f walarchiver /usr/local/bin/walarchiver
    cd -
    return 0
}


#--------------------------------------------------------------#
# Name: install_walarchiver
# Desc: install walarchiver service to systemctl
# Note: Assume viable walarchiver binary in /usr/local/bin/walarchiver
# Note: Run this as root
#  walarchiver conf file   : /etc/walarchiver/env
#  walarchiver binary      : /usr/local/bin/walarchiver
#  walarchiver service     : /etc/systemd/system/walarchiver.service
#--------------------------------------------------------------#
function install_walarchiver() {
    if [[ ! -x /usr/local/bin/walarchiver ]]; then
        echo "warn: /usr/local/bin/walarchiver not found, download"
        download_walarchiver
        if [[ $? != 0 ]]; then
            echo "error: download walarchiver failed"
            return $?
        fi
    fi

    echo "warn: install walarchiver will clean up /pg/arcwal"
    rm -rf /pg/arcwal/*

    mkdir /etc/walarchiver
    # services parameter
    if [[ -f /opt/conf/walarchiver.env ]]; then
        echo "info: found /opt/conf/walarchiver.env , copy walarchiver.env to /etc/walarchiver/env"
        rm -rf /etc/walarchiver/env
        cp /opt/conf/walarchiver.env /etc/walarchiver/env
    else
		cat > /etc/walarchiver/env <<- EOF
		DBNAME='postgres://replicator@primary.test.pg/postgres'
		WALDIR=/pg/arcwal
		SLOT_NAME=walarchiver
		COMPRESS=4
		EOF
    fi

    # init walarchiver services
    if [[ -f /opt/conf/services/walarchiver.service ]]; then
        echo "info: found walarchiver.services in /opt/conf, copy walarchiver.service to /etc/systemd/system/"
        rm -rf /etc/systemd/system/walarchiver.service
        cp -f /opt/conf/services/walarchiver.service /etc/systemd/system/walarchiver.service
    else
        echo "info: overwrite /etc/systemd/system/walarchiver.service"
		cat > /etc/systemd/system/walarchiver.service <<- EOF
		[Unit]
		Description=PostgreSQL WAL Archiver
		Wants=network-online.target
		After=network-online.target

		[Service]
		Type=forking
		User=postgres
		Group=postgres
		EnvironmentFile=/etc/walarchiver/env

		ExecStartPre=-"/bin/mkdir -p ${WALDIR}"
		ExecStartPre=-"/bin/chown -R postgres:postgres ${WALDIR}"

		ExecStart=/usr/local/bin/walarchiver start -d ${DBNAME} -D ${WALDIR} -S ${SLOT_NAME} -Z ${COMPRESS}
		ExecStop=/usr/local/bin/walarchiver  stop
		Restart=on-failure

		[Install]
		WantedBy=multi-user.target
		EOF
    fi

    chown -R postgres:postgres /etc/systemd/system/walarchiver.service /etc/walarchiver
    systemctl daemon-reload
    return 0
}



#--------------------------------------------------------------#
# Name: launch_walarchiver
# Desc: launch walarchiver service
# Note: Assume walarchiver.service installed
#--------------------------------------------------------------#
function launch_walarchiver(){
    if ! systemctl | grep walarchiver.service; then
        echo "info: walarchiver.service not found"
        install_walarchiver
    fi

    systemctl stop    walarchiver > /dev/null 2>&1
    systemctl enable  walarchiver > /dev/null 2>&1
    systemctl restart walarchiver > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        systemctl status walarchiver
        return 5
    fi

    # Double check
    if systemctl status walarchiver > /dev/null 2>&1; then
        echo "info: start walarchiver.service"
    else
        echo "error: fail to start walarchiver.service"
    fi
    return 0
}


#==============================================================#
#                              Main                            #
#==============================================================#
function main(){
    if [[ $(whoami) != "root" ]]; then
        echo "error: install walarchiver require root"
        return 1
    fi

    # by default, walarchiver will not launch until postgres
    # offline instance is proper inited. (which may change
    # the target url of walarchiver )
    local action=${1-''}
    case ${action} in
        download ) shift; download_walarchiver $@ ;;
        install  ) shift; install_walarchiver  $@ ;;
        launch   ) shift; launch_walarchiver   $@ ;;
        *        )        install_walarchiver  $@ ;;
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
#   2   walarchiver not found
#   3   download walarchiver failed
#   4   walarchiver not found
#   5   launch walarchiver failed
#==============================================================#
main $@