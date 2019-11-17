#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   install-prometheus.sh
# Mtime     :   2019-03-02
# Desc      :   Install prometheus
# Path      :   bin/install-prometheus.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   check /opt/conf/prometheus.yml
#               check /opt/conf/services/prometheus.service
#==============================================================#


# module info
__MODULE_INSTALL_PROMETHEUS="install-prometheus"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


#--------------------------------------------------------------#
# Name: download_prometheus
# Desc: Guarantee a usable prometheus in ${target_location}
# Arg1: target prometheus location  (/usr/local/bin/prometheus)
# Arg2: cache  prometheus location  (/opt/pkg/prometheus)
# Arg3: prometheus version to download  (2.14.0)
#--------------------------------------------------------------#
function download_prometheus() {
	local target_location=${1-'/usr/local/bin/prometheus'}
	local cache_location=${2-'/opt/pkg/prometheus'}
	local prometheus_version=${3-'2.14.0'}

	# if exact same version already in target location, skip
	if [[ -x ${target_location} ]]; then
		echo "warn: found prometheus ${prometheus_version} on ${target_location}, skip"
		return 0
	fi

	# if prometheus in /opt/pkg, use it regardless version
	if [[ -x ${cache_location} ]]; then
		echo "warn: found prometheus in cache, cp ${cache_location} ${target_location}, skip"
		cp -f ${cache_location} ${target_location}
		return 0
	fi

	# download from Internet
	local prometheus_filename="prometheus-${prometheus_version}.linux-amd64.tar.gz"
	local prometheus_url="https://github.com/prometheus/prometheus/releases/download/v${prometheus_version}/${prometheus_filename}"
	echo "info: download prometheus from ${prometheus_url}"
	cd /tmp
	rm -rf ${prometheus_filename}
	if ! wget ${prometheus_url} 2> /dev/null; then
		echo 'error: download prometheus failed'
		return 2
	fi
	if ! tar -xf ${prometheus_filename} 2> /dev/null; then
		echo 'error: decompress prometheus failed'
		return 3
	fi
	mv -f "prometheus-${prometheus_version}.linux-amd64"/prometheus /usr/local/bin/prometheus
	mv -f "prometheus-${prometheus_version}.linux-amd64"/promtool   /usr/local/bin/promtool
	rm -rf "prometheus-${prometheus_version}.linux-amd64"
	cd - > /dev/null

	return 0
}


#--------------------------------------------------------------#
# Name: install_prometheus
# Desc: install prometheus service to systemctl
# Note: Assume viable prometheus binary in /usr/local/bin/prometheus
# Note: Run this as root
#       prometheus conf dir: /etc/prometheus
#       prometheus data dir: /var/lib/prometheus
#       prometheus binary  : /usr/local/bin/prometheus
#--------------------------------------------------------------#
function install_prometheus() {
	if [[ ! -x /usr/local/bin/prometheus ]]; then
		echo "warn: /usr/local/bin/prometheus not found, download"
		download_prometheus
		if [[ $? != 0 ]]; then
			echo "error: download prometheus failed"
			return $?
		fi
	fi

	# create prometheus user if not exists
	if ( ! grep -q prometheus /etc/passwd ); then
		echo "info: add user prometheus"
		useradd --system --home /etc/prometheus --shell /bin/false prometheus
		if [[ $? != 0 ]]; then
			echo "error: create user prometheus failed"
			return 4
		fi
	fi

	# user & dir & privilege
	mkdir -p /etc/prometheus /var/lib/prometheus

	# init prometheus config file
	if [[ -f /opt/conf/prometheus.yml ]]; then
		echo "info: found prometheus.yml in /opt/conf, copy prometheus.yml /etc/prometheus/"
		rm -rf /etc/prometheus/prometheus.yml
		cp -f /opt/conf/prometheus.yml /etc/prometheus/prometheus.yml
	else
		echo "info: overwrite /etc/prometheus/prometheus.yml"
		cat > /etc/prometheus/prometheus <<- 'EOF'
		global:
		  scrape_interval:     15s
		  evaluation_interval: 15s

		alerting:
		  alertmanagers:
		  - static_configs:
		    - targets:

		rule_files:
		  - "alert.rules"

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

	# copy alert.rules to /etc/prometheus
	if [[ -f /opt/conf/alert.rules ]]; then
		echo "info: found alert.yml in /opt/conf, copy alert.yml /etc/prometheus/"
		rm -rf /etc/prometheus/alert.rules
		cp -f /opt/conf/alert.rules /etc/prometheus/alert.rules
	else
		touch /etc/prometheus/alert.rules
	fi
	chown prometheus:prometheus /etc/prometheus/alert.rules

	# init prometheus services
	if [[ -f /opt/conf/services/prometheus.service ]]; then
		echo "info: found prometheus.services in /opt/conf, copy prometheus.service to /etc/systemd/system/"
		rm -rf /etc/systemd/system/prometheus.service
		cp -f /opt/conf/services/prometheus.service /etc/systemd/system/prometheus.service
	else
		echo "info: overwrite /etc/systemd/system/prometheus.service"
		cat > /etc/systemd/system/prometheus.service <<- EOF
		[Unit]
		Description=Prometheus Server
		Documentation=https://prometheus.io/docs/introduction/overview/
		After=network-online.target
		ConditionFileNotEmpty=/etc/prometheus/prometheus.yml

		[Service]
		User=prometheus
		Restart=on-failure
		ExecStart=/usr/local/bin/prometheus \
		  --config.file=/etc/prometheus/prometheus.yml \
		  --storage.tsdb.path=/var/lib/prometheus

		[Install]
		WantedBy=multi-user.target
		EOF
	fi

	chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus /etc/systemd/system/prometheus.service
	systemctl daemon-reload
	return 0
}



#--------------------------------------------------------------#
# Name: launch_prometheus
# Desc: launch prometheus service
# Note: Assume prometheus.service installed
#--------------------------------------------------------------#
function launch_prometheus(){
	if ! systemctl | grep prometheus.service; then
		echo "warn: prometheus.service not found, install"
		install_prometheus
	fi

	systemctl stop    prometheus  > /dev/null 2>&1
	systemctl enable  prometheus  > /dev/null 2>&1
	systemctl start   prometheus  > /dev/null 2>&1
	if [[ $? != 0 ]]; then
		systemctl status prometheus
		return 5
	fi

	# Double check
	if systemctl status prometheus > /dev/null 2>&1; then
		echo "info: start prometheus.service"
	else
		echo "error: fail to start prometheus.service"
	fi
	return 0
}


#==============================================================#
#                              Main                            #
#==============================================================#
function main(){
	if [[ $(whoami) != "root" ]]; then
		echo "error: install prometheus require root"
		return 1
	fi

	local action=${1-''}
	case ${action} in
		download ) shift; download_prometheus $@ ;;
		install  ) shift; install_prometheus  $@ ;;
		launch   ) shift; launch_prometheus   $@ ;;
		*        )        launch_prometheus   $@ ;;
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
#   2   download prometheus failed
#   3   decompress prometheus failed
#   4   create user prometheus failed
#   5   launch prometheus.service failed
#==============================================================#
main $@