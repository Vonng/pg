#!/bin/bash

#==============================================================#
# File      :   install-node-exporter.sh
# Mtime     :   2019-03-06
# Desc      :   Install Node Exporter
# Path      :   bin/install-node-exporter.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   CentOS7
# Note      :   check /opt/conf/services/node_exporter.service
#==============================================================#


# module info
__MODULE_INSTALL_NODE_EXPORTER="install-node-exporter"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


#--------------------------------------------------------------#
# Name: download_node_exporter
# Desc: Guarantee a usable node_exporter in ${target_location}
# Arg1: target node_exporter location      (/usr/local/bin/node_exporter)
# Arg2: cache  node_exporter location      (/opt/pkg/node_exporter)
# Arg3: node_exporter version to download  (0.18.1)
# Note: Run this as root
#--------------------------------------------------------------#
function download_node_exporter() {
    local target_location=${1-'/usr/local/bin/node_exporter'}
    local cache_location=${2-'/opt/pkg/node_exporter'}
    local node_exporter_version=${3-'0.18.1'}

    # if exact same version already in target location, skip
    if [[ -x ${target_location} ]]; then
        echo "warn: found node_exporter ${node_exporter_version} on ${target_location}, skip"
        return 0
    fi

    # if node_exporter in /opt/pkg, use it regardless version
    if [[ -x ${cache_location} ]]; then
        echo "warn: found node_exporter in cache, cp ${cache_location} ${target_location}, skip"
        cp -f ${cache_location} ${target_location}
        return 0
    fi

    # download from Internet
    local node_exporter_filename="node_exporter-${node_exporter_version}.linux-amd64.tar.gz"
    local node_exporter_url="https://github.com/prometheus/node_exporter/releases/download/v${node_exporter_version}/${node_exporter_filename}"
    echo "info: download node_exporter from ${node_exporter_url}"

    cd /tmp
    rm -rf ${node_exporter_filename}
    if ! wget ${node_exporter_url} 2> /dev/null; then
        echo 'error: download node_exporter failed'
        return 2
    fi
    if ! tar -xf ${node_exporter_filename} 2> /dev/null; then
        echo 'error: unzip node_exporter failed'
        return 3
    fi
    mv -f "node_exporter-${node_exporter_version}.linux-amd64"/node_exporter ${target_location}
    cd - > /dev/null

    return 0
}


#--------------------------------------------------------------#
# Name: install_node_exporter
# Desc: install node_exporter service to systemctl
# Note: Assume viable node_exporter binary in /usr/local/bin/node_exporter
# Note: Run this as root
#       node_exporter conf dir: /etc/node_exporter.d
#       node_exporter data dir: /var/lib/node_exporter
#       node_exporter binary  : /usr/local/bin/node_exporter
#--------------------------------------------------------------#
function install_node_exporter() {
    if [[ ! -x /usr/local/bin/node_exporter ]]; then
        echo "warn: /usr/local/bin/node_exporter not found, download"
        download_node_exporter
        if [[ $? != 0 ]]; then
            echo "error: download node_exporter failed"
            return $?
        fi
    fi

    # init node_exporter services
    if [[ -f /opt/conf/services/node_exporter.service ]]; then
        echo "info: found node_exporter.services in /opt/conf, cp node_exporter.service to /etc/systemd/system/"
        rm -rf /etc/systemd/system/node_exporter.service
        cp -f /opt/conf/services/node_exporter.service /etc/systemd/system/node_exporter.service
    else
        echo "info: overwrite /etc/systemd/system/node_exporter.service"
		cat > /etc/systemd/system/node_exporter.service <<- EOF
		[Unit]
		Description=Node Exporter
		Documentation=https://github.com/prometheus/node_exporter
		Wants=network-online.target
		After=network-online.target

		[Service]
		User=root
		Restart=on-failure
		ExecStart=/usr/local/bin/node_exporter

		[Install]
		WantedBy=default.target
		EOF
    fi

    systemctl daemon-reload
    return 0
}



#--------------------------------------------------------------#
# Name: launch_node_exporter
# Desc: launch node_exporter service
# Note: Assume node_exporter.service installed
#--------------------------------------------------------------#
function launch_node_exporter(){
    if ! systemctl | grep node_exporter.service; then
        echo "info: node_exporter.service not found, install"
        install_node_exporter
    fi

    systemctl stop    node_exporter > /dev/null 2>&1
    systemctl enable  node_exporter > /dev/null 2>&1
    systemctl restart node_exporter > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        systemctl status node_exporter
        return 4
    fi

    # Double check
    if systemctl status node_exporter > /dev/null 2>&1; then
        echo "info: start node_exporter.service"
    else
        echo "error: fail to start node_exporter.service"
    fi
    return 0
}


#==============================================================#
#                              Main                            #
#==============================================================#
function main(){
    if [[ $(whoami) != "root" ]]; then
        echo "error: install node exporter require root"
        return 1
    fi

    local action=${1-''}
    case ${action} in
        download ) shift; download_node_exporter $@ ;;
        install  ) shift; install_node_exporter  $@ ;;
        launch   ) shift; launch_node_exporter   $@ ;;
        *        )        launch_node_exporter  $@ ;;
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
#   2   download node exporter failed
#   3   decompress node_exporter failed
#   4   launch node_exporter failed
#==============================================================#
main $@