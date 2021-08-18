#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   install-alertmanager.sh
# Mtime     :   2019-03-02
# Desc      :   Install alertmanager
# Path      :   bin/install-alertmanager.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   check /opt/conf/alertmanager.yml
#               check /opt/conf/services/alertmanager.service
#==============================================================#


# module info
__MODULE_INSTALL_PROMETHEUS="install-alertmanager"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


#--------------------------------------------------------------#
# Name: download_alertmanager
# Desc: Guarantee a usable alertmanager in ${target_location}
# Arg1: target alertmanager location  (/usr/local/bin/alertmanager)
# Arg2: cache  alertmanager location  (/opt/pkg/alertmanager)
# Arg3: alertmanager version to download  (0.16.1)
#--------------------------------------------------------------#
function download_alertmanager() {
	local target_location=${1-'/usr/local/bin/alertmanager'}
	local cache_location=${2-'/opt/pkg/alertmanager'}
	local ver=${3-'0.19.0'}

	# if exact same version already in target location, skip
	if [[ -x ${target_location} ]]; then
		echo "warn: found alertmanager ${ver} on ${target_location}, skip"
		return 0
	fi

	# if alertmanager in /opt/pkg, use it regardless version
	if [[ -x ${cache_location} ]]; then
		echo "warn: found alertmanager in cache, cp ${cache_location} ${target_location}, skip"
		cp -f ${cache_location} ${target_location}
		return 0
	fi

    # download from Internet
    local filename="alertmanager-${ver}.linux-amd64"
    local pkg_name="alertmanager-${ver}.linux-amd64.tar.gz"
    local url="https://github.com/prometheus/alertmanager/releases/download/v${ver}/${pkg_name}"

    cd /tmp > /dev/null 2>&1
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
    mv -f ${filename}/alertmanager ${target_location}
    chmod a+x ${target_location}
    rm -rf ${filename} ${pkg_name}

    cd - > /dev/null 2>&1
    return 0
}



#--------------------------------------------------------------#
# Name: install_alertmanager
# Desc: install alertmanager service to systemctl
# Note: Assume viable alertmanager binary in /usr/local/bin/alertmanager
# Note: Run this as root
#       alertmanager conf dir: /etc/alertmanager
#       alertmanager data dir: /var/lib/alertmanager
#       alertmanager binary  : /usr/local/bin/alertmanager
#--------------------------------------------------------------#
function install_alertmanager() {
	if [[ ! -x /usr/local/bin/alertmanager ]]; then
		echo "warn: /usr/local/bin/alertmanager not found, download"
		download_alertmanager
		if [[ $? != 0 ]]; then
			echo "error: download alertmanager failed"
			return $?
		fi
	fi

	# create alertmanager user if not exists
	if ( ! grep -q alertmanager /etc/passwd ); then
		echo "info: add user alertmanager"
		useradd --system --home /etc/alertmanager --shell /bin/false alertmanager
		if [[ $? != 0 ]]; then
			echo "error: create user alertmanager failed"
			return 4
		fi
	fi

	# user & dir & privilege
	mkdir -p /etc/alertmanager /var/lib/alertmanager

	# init alertmanager config file
	if [[ -f /opt/conf/alertmanager.yml ]]; then
		echo "info: found alertmanager.yml in /opt/conf, copy alertmanager.yml /etc/alertmanager/"
		rm -rf /etc/alertmanager/alertmanager.yml
		cp -f /opt/conf/alertmanager.yml /etc/alertmanager/alertmanager.yml
	else
		echo "info: overwrite /etc/alertmanager/alertmanager.yml"
		cat > /etc/alertmanager.d/alertmanager.json <<- 'EOF'
		global:
		  scrape_interval:     15s
		  evaluation_interval: 15s

		alerting:
		  alertmanagers:
		  - static_configs:
		    - targets:

		rule_files:

		scrape_configs:
		- job_name: 'consul'
		  consul_sd_configs:
		    - server: 'localhost:8500'
		      tag: exporter

		  relabel_configs:
		    - source_labels: [ '__meta_consul_node' ]
		      action: replace
		      target_label: instance
		      regex: '(.*)'
		EOF
	fi

	# init alertmanager services
	if [[ -f /opt/conf/services/alertmanager.service ]]; then
		echo "info: found alertmanager.services in /opt/conf, copy alertmanager.service to /etc/systemd/system/"
		rm -rf /etc/systemd/system/alertmanager.service
		cp -f /opt/conf/services/alertmanager.service /etc/systemd/system/alertmanager.service
	else
		echo "info: overwrite /etc/systemd/system/alertmanager.service"
		cat > /etc/systemd/system/alertmanager.service <<- EOF
		[Unit]
		Description=Prometheus Server
		Documentation=https://alertmanager.io/docs/introduction/overview/
		After=network-online.target
		ConditionFileNotEmpty=/etc/alertmanager/alertmanager.yml

		[Service]
		User=alertmanager
		Restart=on-failure
		ExecStart=/usr/local/bin/alertmanager \
		  --config.file=/etc/alertmanager/alertmanager.yml \
		  --storage.tsdb.path=/var/lib/alertmanager

		[Install]
		WantedBy=multi-user.target
		EOF
	fi

	chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager /etc/systemd/system/alertmanager.service
	systemctl daemon-reload
	return 0
}



#--------------------------------------------------------------#
# Name: launch_alertmanager
# Desc: launch alertmanager service
# Note: Assume alertmanager.service installed
#--------------------------------------------------------------#
function launch_alertmanager(){
	if ! systemctl | grep alertmanager.service; then
		echo "warn: alertmanager.service not found, install"
		install_alertmanager
	fi

	systemctl stop    alertmanager  > /dev/null 2>&1
	systemctl enable  alertmanager  > /dev/null 2>&1
	systemctl start   alertmanager  > /dev/null 2>&1
	if [[ $? != 0 ]]; then
		systemctl status alertmanager
		return 5
	fi

	# Double check
	if systemctl status alertmanager > /dev/null 2>&1; then
		echo "info: start alertmanager.service"
	else
		echo "error: fail to start alertmanager.service"
	fi
	return 0
}


#==============================================================#
#                              Main                            #
#==============================================================#
function main(){
	if [[ $(whoami) != "root" ]]; then
		echo "error: install alertmanager require root"
		return 1
	fi

	local action=${1-''}
	case ${action} in
		download ) shift; download_alertmanager $@ ;;
		install  ) shift; install_alertmanager  $@ ;;
		launch   ) shift; launch_alertmanager   $@ ;;
		*        )        launch_alertmanager   $@ ;;
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
#   2   download alertmanager failed
#   3   decompress alertmanager failed
#   4   create user alertmanager failed
#   5   launch alertmanager.service failed
#==============================================================#
main $@