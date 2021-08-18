#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   download.sh.sh
# Mtime     :   2019-03-13
# Desc      :   Download package to accelerate vm creation
# Path      :   pkg/download.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   wget, curl
#==============================================================#


# module info
__MODULE_INSTALL_UTILS="install-utils"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"



function download_alertmanager() {
    local ver=${1-'0.19.0'}

    # if exact same version already in target location, skip
    if [[ -x alertmanager ]]; then
        echo "warn: found alertmanager in same dir, skip"
        return 0
    fi

    # download from Internet
    local filename="alertmanager-${ver}.linux-amd64"
    local pkg_name="alertmanager-${ver}.linux-amd64.tar.gz"
    local url="https://github.com/prometheus/alertmanager/releases/download/v${ver}/${pkg_name}"

    rm -rf ${filename} ${pkg_name}
    echo "info: download alertmanager from ${url}"
    if ! wget ${url} 2> /dev/null; then
        echo 'error: download alertmanager failed'
        return 2
    fi
    if ! tar -xf ${pkg_name} 2> /dev/null; then
        echo 'error: decompress alertmanager failed'
        return 3
    fi
    mv -f ${filename}/alertmanager alertmanager
    chmod a+x alertmanager

    rm -rf ${filename} ${pkg_name}
    return 0
}


function download_prometheus() {
    local ver=${1-'2.14.0'}

    # if exact same version already in target location, skip
    if [[ -x prometheus ]]; then
        echo "warn: found prometheus in same dir, skip"
        return 0
    fi

    # download from Internet
    local filename="prometheus-${ver}.linux-amd64"
    local pkg_name="prometheus-${ver}.linux-amd64.tar.gz"

    local url="https://github.com/prometheus/prometheus/releases/download/v${ver}/${pkg_name}"

    rm -rf ${filename} ${pkg_name}
    echo "info: download prometheus from ${url}"
    if ! wget ${url} 2> /dev/null; then
        echo 'error: download prometheus failed'
        return 2
    fi
    if ! tar -xf ${pkg_name} 2> /dev/null; then
        echo 'error: decompress prometheus failed'
        return 3
    fi
    mv -f ${filename}/prometheus prometheus
    chmod a+x prometheus

    rm -rf ${filename} ${pkg_name}
    return 0
}


function download_grafana(){
    local ver=${1-'6.4.4-1'}
    local filename="grafana-${ver}.x86_64.rpm"
    local url="https://dl.grafana.com/oss/release/${filename}"

    if [[ -f grafana.rpm ]]; then
        echo "warn: found grafana.rpm in same dir, skip"
        return 0
    fi

    rm -rf ${filename}
    echo "info: download grafana from ${url}"
    if ! wget ${url} 2> /dev/null; then
        echo 'error: download grafana failed'
        return 2
    fi

    mv ${filename} grafana.rpm
    return 0
}


function download_pgbouncer_exporter() {
    local ver=${3-'0.0.3'}

    # if exact same version already in target location, skip
    if [[ -x pgbouncer_exporter ]]; then
        echo "warn: found pgbouncer_exporter in same dir, skip"
        return 0
    fi

    # download from Internet
    local filename="pgbouncer_exporter-${ver}.linux-amd64"
    local pkg_name="pgbouncer_exporter-${ver}.linux-amd64.tar.gz"
    local url="https://github.com/larseen/pgbouncer_exporter/releases/download/${ver}/${pkg_name}"

    rm -rf ${filename} ${pkg_name}
    echo "info: download pgbouncer_exporter from ${url}"
    if ! wget ${url} 2> /dev/null; then
        echo 'error: download pgbouncer_exporter failed'
        return 2
    fi
    if ! tar -xf ${pkg_name} 2> /dev/null; then
        echo 'error: unzip pgbouncer_exporter failed'
        return 3
    fi
    mv -f ${filename}/pgbouncer_exporter pgbouncer_exporter
    chmod a+x pgbouncer_exporter
    rm -rf ${filename} ${pkg_name}

    return 0
}


function download_walarchiver() {
    local download_location=${1-'https://raw.githubusercontent.com/Vonng/pg/master/test/pkg/walarchiver'}

    # if exact same version already in target location, skip
    if [[ -x walarchiver ]]; then
        echo "warn: found walarchiver in same dir, skip"
        return 0
    fi

    # otherwise, download from github
    if ! wget ${download_location} 2> /dev/null; then
        echo 'error: download walarchiver failed'
        return 2
    fi

    if [[ ! -f walarchiver ]]; then
        echo "walarchiver still not found"
        return 3
    fi

    chmod a+x walarchiver
    return 0
}


function download_postgres_exporter() {
    local ver=${1-'0.7.0'}

    # if exact same version already in target location, skip
    if [[ -x postgres_exporter ]]; then
        echo "warn: found postgres_exporter in same dir, skip"
        return 0
    fi

    # download from Internet
    local filename="postgres_exporter_v${ver}_linux-amd64"
    local pkg_name="postgres_exporter_v${ver}_linux-amd64.tar.gz"
    local url="https://github.com/wrouesnel/postgres_exporter/releases/download/v${ver}/${pkg_name}"

    rm -rf ${filename} ${pkg_name}
    echo "info: download postgres_exporter from ${url}"
    if ! wget ${url} 2> /dev/null; then
        echo 'error: download postgres_exporter failed'
        return 2
    fi
    if ! tar -xf ${pkg_name} > /dev/null 2>&1; then
        echo 'error: unzip postgres_exporter failed'
        return 3
    fi
    mv -f ${filename}/postgres_exporter postgres_exporter
    chmod a+x postgres_exporter
    rm -rf ${filename} ${pkg_name}
    return 0
}


function download_consul() {
    local ver=${1-'1.6.1'}

    # if exact same version already in target location, skip
    if [[ -x consul ]]; then
        echo "warn: found consul in same dir, skip"
        return 0
    fi

    # download from Internet
    local pkg_name="consul_${ver}_linux_amd64.zip"
    local url="https://releases.hashicorp.com/consul/${ver}/${pkg_name}"

    echo "info: download consul from ${url}"
    rm -rf ${pkg_name}
    if ! curl --silent --remote-name ${url} 2> /dev/null; then
        echo 'error: download consul failed'
        return 2
    fi
    if ! unzip ${pkg_name} > /dev/null 2>&1; then
        echo 'error: unzip consul failed'
        return 3
    fi

    chmod a+x consul
    rm -rf ${pkg_name}

    return 0
}


function download_node_exporter() {
    local ver=${3-'0.18.1'}

    # if exact same version already in target location, skip
    if [[ -x node_exporter ]]; then
        echo "warn: found node_exporter in same dir, skip"
        return 0
    fi

    # download from Internet
    local filename="node_exporter-${ver}.linux-amd64"
    local pkg_name="node_exporter-${ver}.linux-amd64.tar.gz"
    local url="https://github.com/prometheus/node_exporter/releases/download/v${ver}/${pkg_name}"
    echo "info: download node_exporter from ${url}"

    rm -rf ${filename} ${pkg_name}
    if ! wget ${url} 2> /dev/null; then
        echo 'error: download node_exporter failed'
        return 2
    fi
    if ! tar -xf ${pkg_name} > /dev/null 2>&1; then
        echo 'error: unzip node_exporter failed'
        return 3
    fi
    mv -f ${filename}/node_exporter node_exporter
    rm -rf ${filename} ${pkg_name}

    return 0
}


function main(){
    cd ${PROG_DIR} > /dev/null 2>&1
    download_walarchiver
    download_consul
    download_node_exporter
    download_postgres_exporter
    download_pgbouncer_exporter
    download_grafana
    download_prometheus
    download_alertmanager
    cd - > /dev/null 2>&1
}

main $@