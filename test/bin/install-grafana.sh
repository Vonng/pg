#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   install-grafana.sh
# Mtime     :   2019-03-06
# Desc      :   Install grafana
# Path      :   bin/install-grafana.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   check /opt/conf/grafana.yml
#               check /opt/conf/services/grafana.service
#==============================================================#


# module info
__MODULE_INSTALL_GRAFANA="install-grafana"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


#--------------------------------------------------------------#
# Name: download_grafana
# Desc: Guarantee a usable grafana in ${target_location}
# Arg1: cache  grafana location  (/opt/pkg/grafana.rpm)
# Arg2: grafana version to download  (6.4.4-1)
# Note: Run this as root
#--------------------------------------------------------------#
function install_grafana() {
    local cache_location=${1-'/opt/pkg/grafana.rpm'}
    local grafana_version=${2-'6.4.4-1'}
    local grafana_filename="grafana-${grafana_version}.x86_64.rpm"
    local target_location="/tmp/${grafana_filename}"

    # if grafana in /opt/pkg, use it regardless version
    if [[ -f ${cache_location} ]]; then
        echo "warn: found grafana in cache, copy to ${target_location}"
        rm -rf ${target_location}
        cp -rf ${cache_location} ${target_location}
    else
        local grafana_url="https://dl.grafana.com/oss/release/${grafana_filename}"
        echo "info: download grafana from ${grafana_url}"
        cd /tmp
        rm -rf ${target_location}
        if ! wget ${grafana_url} 2> /dev/null; then
            echo 'error: download grafana failed'
            return 2
        fi
    fi


    # install from local rpm
    echo "info: install ${grafana_filename}"
    yum -q -y localinstall ${target_location} 2> /dev/null
    if [[ $? != 0 ]]; then
        echo "error: install grafana failed"
        return 3
    fi
    mkdir -p /var/lib/grafana /etc/grafana

    # replace grafana.ini if exists
    if [[ -f /opt/conf/grafana.ini ]]; then
        echo "info: found grafana.ini in /opt/conf, overwrite grafana.ini /etc/grafana/"
        rm -rf /etc/grafana/grafana.ini
        cp -f /opt/conf/grafana.ini /etc/grafana/grafana.ini
    fi

    # replace grafana.db if exists
    if [[ -f /opt/conf/grafana.db ]]; then
        echo "info: found grafana.db in /opt/conf, overwrite grafana.db /var/lib/grafana/"
        rm -rf /var/lib/grafana/grafana.db
        cp -f /opt/conf/grafana.db /var/lib/grafana/grafana.db
    fi

    chown -R grafana:grafana /var/lib/grafana /etc/grafana
    systemctl daemon-reload

    echo "info: install grafana plugins"
    grafana-cli plugins install grafana-piechart-panel      > /dev/null
    grafana-cli plugins install grafana-polystat-panel      > /dev/null
    grafana-cli plugins install grafana-clock-panel         > /dev/null
    grafana-cli plugins install mtanda-histogram-panel      > /dev/null
    grafana-cli plugins install savantly-heatmap-panel      > /dev/null
    grafana-cli plugins install digrich-bubblechart-panel   > /dev/null
    grafana-cli plugins install ryantxu-ajax-panel          > /dev/null

    return 0
}



#--------------------------------------------------------------#
# Name: launch_grafana
# Desc: launch grafana service
# Note: Assume grafana.service installed
#--------------------------------------------------------------#
function launch_grafana(){
    if ! systemctl | grep grafana.service; then
        echo "warn: grafana.service not found, install"
        install_grafana
    fi

    systemctl stop    grafana-server  > /dev/null 2>&1
    systemctl enable  grafana-server  > /dev/null 2>&1
    systemctl start   grafana-server  > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        systemctl status grafana-server
        return 4
    fi

    # Double check
    if systemctl status grafana-server > /dev/null 2>&1; then
        echo "info: start grafana-server.service"
    else
        echo "error: fail to start grafana-server.service"
    fi
    return 0
}


#==============================================================#
#                              Main                            #
#==============================================================#
function main(){
    if [[ $(whoami) != "root" ]]; then
        echo "error: install grafana require root"
        return 1
    fi

    local action=${1-''}
    case ${action} in
        install  ) shift; install_grafana  $@ ;;
        launch   ) shift; launch_grafana   $@ ;;
        *        )        launch_grafana   $@ ;;
    esac

    return $?
}

#==============================================================#
#                             Main                             #
#==============================================================#
# Args:
#   $1  action: install | launch (install by default)
#
# Code:
#   0   ok
#   1   insufficient privilege
#   2   download grafana failed
#   3   local install grafana failed
#   4   start grafana.service failed
#==============================================================#
main $@