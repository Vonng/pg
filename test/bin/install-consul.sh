#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   install-consul.sh
# Mtime     :   2019-03-02
# Desc      :   Install consul
# Path      :   bin/install-consul.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   check /opt/conf/consul.json
# Note      :   check /opt/conf/services/consul.service
#==============================================================#


# module info
__MODULE_INSTALL_CONSUL="install-consul"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


#--------------------------------------------------------------#
# Name: download_consul
# Desc: Guarantee a usable consul in ${target_location}
# Arg1: target consul location      (/usr/local/bin/consul)
# Arg2: cache consul location       (/opt/pkg/consul)
# Arg3: consul version to download  (1.6.1)
# Note: Run this as root
#--------------------------------------------------------------#
function download_consul() {
    local target_location=${1-'/usr/local/bin/consul'}
    local cache_location=${2-'/opt/pkg/consul'}
    local consul_version=${3-'1.6.1'}

    # if exact same version already in target location, skip
    if [[ -x ${target_location} ]]; then
        echo "warn: found consul ${consul_version} on ${target_location}, skip"
        return 0
    fi

    # if consul in /opt/pkg, use it regardless version
    if [[ -x ${cache_location} ]]; then
        echo "warn: found consul in cache, cp ${cache_location} ${target_location}, skip"
        cp -f ${cache_location} ${target_location}
        return 0
    fi

    # download from Internet
    local consul_filename="consul_${consul_version}_linux_amd64.zip"
    local consul_url="https://releases.hashicorp.com/consul/${consul_version}/${consul_filename}"
    echo "info: download consul from ${consul_url}"

    cd /tmp
    rm -rf ${consul_filename}
    if ! curl --silent --remote-name ${consul_url} 2> /dev/null; then
        echo 'error: download consul failed'
        return 2
    fi
    if ! unzip ${consul_filename} 2> /dev/null; then
        echo 'error: unzip consul failed'
        return 3
    fi
    mv -f consul ${target_location}
    cd - > /dev/null

    return 0
}


#--------------------------------------------------------------#
# Name: install_consul
# Desc: install consul service to systemctl
# Note: Assume viable consul binary in /usr/local/bin/consul
# Note: Run this as root
#       consul conf dir: /etc/consul.d
#       consul data dir: /var/lib/consul
#       consul binary  : /usr/local/bin/consul
#--------------------------------------------------------------#
function install_consul() {
    if [[ ! -x /usr/local/bin/consul ]]; then
        echo "warn: /usr/local/bin/consul not found, download"
        download_consul
        if [[ $? != 0 ]]; then
            echo "error: download consul failed"
            return $?
        fi
    fi

    # completion
    /usr/local/bin/consul -autocomplete-install 2> /dev/null
    complete -C /usr/local/bin/consul consul 2> /dev/null

    # create consul user if not exists
    if ( ! grep -q consul /etc/passwd ); then
        echo "info: add user consul"
        useradd --system --home /etc/consul.d --shell /bin/false consul
        if [[ $? != 0 ]]; then
            echo "error: create user consul failed"
            return 4
        fi
    fi

    # user & dir & privilege
    mkdir -p /etc/consul.d /var/lib/consul
    chown -R consul:consul /etc/consul.d /var/lib/consul
    chmod 640 /etc/consul.d/* 2> /dev/null

    # init consul config file
    if [[ -f /opt/conf/consul.json ]]; then
        echo "info: found consul.json in /opt/conf, cp consul.json /etc/consul.d/"
        rm -rf /etc/consul.d/consul.json
        cp -f /opt/conf/consul.json /etc/consul.d/consul.json
    else
        local local_ip=$(ip addr | grep -Eo 'inet ([0-9]*\.){3}[0-9]*' | grep -Eo '10\.10\.10\.[0-9]*' 2>/dev/null)
        if [[ $? != 0 || -z ${local_ip} ]]; then
            echo "error: local ip not found"
            return 5
        fi
        echo "info: overwrite /etc/consul.d/consul.json"
		cat > /etc/consul.d/consul.json <<- EOF
		{
		  "datacenter": "dc",
		  "node_name": "${HOSTNAME}",
		  "bind_addr": "${local_ip}",
		  "data_dir": "/var/lib/consul",
		  "retry_join": ["primary.test.pg","standby.test.pg","offline.test.pg","monitor"],
		  "log_level": "INFO",
		  "server": true,
		  "ui": true,
		  "bootstrap_expect": 3,
		  "services": []
		}
		EOF
    fi

    # init consul services
    if [[ -f /opt/conf/services/consul.service ]]; then
        echo "info: found consul.services in /opt/conf, cp consul.service to /etc/systemd/system/"
        rm -rf /etc/systemd/system/consul.service
        cp -f /opt/conf/services/consul.service /etc/systemd/system/consul.service
    else
        echo "info: overwrite /etc/systemd/system/consul.service"
		cat > /etc/systemd/system/consul.service <<- EOF
		[Unit]
		Description="Consul"
		Documentation=https://www.consul.io/
		Requires=network-online.target
		After=network-online.target
		ConditionFileNotEmpty=/etc/consul.d/consul.json

		[Service]
		User=consul
		Group=consul
		ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d
		ExecReload=/usr/local/bin/consul reload
		KillMode=process
		Restart=on-failure
		LimitNOFILE=65536

		[Install]
		WantedBy=multi-user.target
		EOF
    fi

    chown -R consul:consul /etc/consul.d /var/lib/consul /etc/systemd/system/consul.service
    chmod 640 /etc/consul.d/* 2> /dev/null

    systemctl daemon-reload
    return 0
}



#--------------------------------------------------------------#
# Name: launch_consul
# Desc: launch consul service
# Note: Assume consul.service installed
#--------------------------------------------------------------#
function launch_consul(){
    if ! systemctl | grep consul.service; then
        echo "warn: consul.service not found, install"
        install_consul
    fi

    systemctl stop    consul > /dev/null 2>&1
    systemctl enable  consul > /dev/null 2>&1
    systemctl start   consul > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        systemctl status consul
        return 6
    fi

    # Double check
    if systemctl status consul > /dev/null 2>&1; then
        echo "info: start consul.service"
    else
        echo "error: fail to start consul.service"
    fi
    return 0
}


#==============================================================#
#                              Main                            #
#==============================================================#
function main(){
    if [[ $(whoami) != "root" ]]; then
        echo "error: install consul require root"
        return 1
    fi

    local action=${1-''}
    case ${action} in
        download ) shift; download_consul  $@ ;;
        install  ) shift; install_consul   $@ ;;
        launch   ) shift; launch_consul    $@ ;;
        *        )        launch_consul    $@ ;;
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
#   2   download consul failed
#   3   decompress consul failed
#   4   create user consul failed
#   5   get local IP failed
#   6   launch consul.service failed
#==============================================================#
main $@