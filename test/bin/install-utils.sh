#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   install-utils.sh
# Mtime     :   2019-03-02
# Desc      :   Install some system utils
# Path      :   bin/install-utils.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   Run this as root
# Depend    :   CentOS, yum required
#==============================================================#


# module info
__MODULE_INSTALL_UTILS="install-utils"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"



#--------------------------------------------------------------#
# Name: download_yum_package
# Desc: Install all rpm package listed in cache
# Note: This only for one-time use purpose
#       It will download all yum package into /opt/pkg/yum
#       Then you can copy to other machine to speedup installation
#--------------------------------------------------------------#
function download_utils(){
    local db_version=${1-'11'}
    local major_version="${db_version:0:3}" # e.g: 9.6 10 11
    local short_version="$(echo $db_version | awk -F'.' '{print $1$2}')" # e.g: 93 96 10 11

    
    # latest yum for CentOS7: https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    local pg_rpm="https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-$(uname -m)/pgdg-redhat-repo-latest.noarch.rpm"

    echo "info: install rpm: ${pg_rpm}"
    yum install -q -y ${pg_rpm}

    mkdir -p /opt/pkg/yum
    echo "info: download packages to /opt/pkg/yum"
    yumdownloader --destdir=/opt/pkg/yum --assumeyes --resolve --archlist=$(uname -m) \
        ntp uuid zlib zlib-devel readline readline-devel lz4 nc libxml2 libxslt lsof wget perl \
        unzip git htop tmux telnet sysstat ioping iperf fio \
        postgresql"$short_version" \
        postgresql"$short_version"-libs \
        postgresql"$short_version"-server \
        postgresql"$short_version"-contrib \
        postgresql"$short_version"-devel \
        postgresql"$short_version"-debuginfo \
        pgbouncer \
        pg_top"$short_version" \
        pg_repack"$short_version"

    # PostGIS is quiet big (you can uncomment to download that)
    # pgpool-II-"$short_version" \
    # postgis2_"$short_version" \
    # postgis2_"$short_version"-client
}



#--------------------------------------------------------------#
# Name: install_utils
# Desc: Install some common tools via yum
# Args: Additional packages to be installed
# Note: Run this as root
#--------------------------------------------------------------#
function install_utils() {
    # install package in /opt/pkg/yum to speed up installation
    if [[ ! -d /opt/pkg/yum ]]; then
        echo "info: yum cache in /opt/pkg/yum not found, skip"
        return 0
    else
        if [[ $(ls /opt/pkg/yum | grep -q x86_64 | grep rpm | wc -l 2> /dev/null) != 0 ]]; then
            echo "info: install rpm cache package from /opt/pkg/yum"
            rpm -ivhU /opt/pkg/yum/*.rpm
        fi
    fi

    echo "info: install epel release"
    yum -q clean all
    yum install -q -y epel-release > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        echo "error: install epel-release failed"
        return 2
    fi

    echo "info: install utils"
    yum install -q -y \
        ntp \
        uuid \
        readline \
        lz4 \
        nc \
        libxml2 \
        libxslt \
        lsof \
        wget \
        unzip $@ >/dev/null 2>&1

    if [[ $? != 0 ]]; then
        echo 'error: install utils failed'
        return 3
    fi

    systemctl enable ntpd > /dev/null 2>&1
    systemctl start  ntpd > /dev/null 2>&1

    echo "info: write /etc/profile.d/path.sh"
    echo 'export PATH=/usr/local/bin:$PATH' > /etc/profile.d/path.sh

    return 0
}


#==============================================================#
#                             Main                             #
#==============================================================#
# Args:
#   $@  additional packages list to be installed
#
# Code:
#
#   0   ok
#   1   insufficient privilege
#   2   install epel-release failed
#   3   install package failed
#==============================================================#
function main(){
    if [[ $(whoami) != "root" ]]; then
        echo "error: install consul require root"
        return 1
    fi

    local action=${1-''}
    case ${action} in
        download ) shift; download_utils   $@ ;;
        install  ) shift; install_utils    $@ ;;
        *        )        install_utils    $@ ;;
    esac

    return $?
}

main $@