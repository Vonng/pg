#!/bin/bash

#==============================================================#
# File      :   install-pgbouncer.sh
# Mtime     :   2019-03-06
# Desc      :   Install Pgbouncer
# Path      :   bin/install-pgbouncer.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   CentOS7
# Note      :   Require postgresql
#==============================================================#


# module info
__MODULE_INSTALL_PGBOUNCER="install-pgbouncer"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


#--------------------------------------------------------------#
# Name: install_pgbouncer
# Desc: init pgbouncer
# Note: assume /bin/pgbouncer exists
#--------------------------------------------------------------#
function install_pgbouncer(){
    # download pgbouncer
    if [[ ! -x /bin/pgbouncer ]]; then
        echo "info: /bin/pgbouncer not found, download from yum"
        yum install -q -y pgbouncer 2> /dev/null
        if [[ $? != 0 ]]; then
            echo "error: yum install pgbouncer failed"
            return 2
        fi
    fi

    # init pgbouncer.ini
    if [[ -f /opt/conf/pgbouncer.ini ]]; then
        echo "info: found pgbouncer.ini in /opt/conf, copy pgbouncer.ini /etc/pgbouncer/"
        rm -rf /etc/pgbouncer/pgbouncer.ini
        cp -f /opt/conf/pgbouncer.ini /etc/pgbouncer/pgbouncer.ini
    else
        echo "info: overwrite /etc/pgbouncer/pgbouncer.ini"
		cat > /etc/pgbouncer/pgbouncer.ini <<- EOF
		[databases]
		postgres =

		[pgbouncer]
		logfile = /var/log/pgbouncer/pgbouncer.log
		pidfile = /var/run/pgbouncer/pgbouncer.pid
		listen_addr = *
		listen_port = 6432
		auth_type = trust
		auth_file = /etc/pgbouncer/userlist.txt
		unix_socket_dir = /var/run/postgresql
		admin_users = postgres
		stats_users = stats, postgres
		pool_mode = session
		server_reset_query =
		max_client_conn = 50000
		default_pool_size = 25
		reserve_pool_size = 5
		reserve_pool_timeout = 5
		log_connections = 0
		log_disconnections = 0
		application_name_add_host = 1
		ignore_startup_parameters = extra_float_digits
		EOF
    fi


    # init pgbouncer userlist
    if [[ -f /opt/conf/userlist.txt ]]; then
        echo "info: found userlist.txt in /opt/conf, copy userlist.txt /etc/pgbouncer/"
        rm -rf /etc/pgbouncer/userlist.txt
        cp -f /opt/conf/userlist.txt /etc/pgbouncer/userlist.txt
    else
        echo "info: overwrite /etc/pgbouncer/userlist.txt"
		cat > /etc/pgbouncer/userlist.txt <<- EOF
		"postgres": "postgres"
		"test"    : "test"
		EOF
    fi


    # pgbouncer limit
    echo "info: increase pgbouncer file limit"
	cat > /etc/security/limits.d/pgbouncer.conf <<- EOF
	pgbouncer    soft    nproc       655360
	pgbouncer    hard    nofile      655360
	pgbouncer    soft    nofile      655360
	pgbouncer    soft    stack       unlimited
	pgbouncer    hard    stack       unlimited
	pgbouncer    soft    core        unlimited
	pgbouncer    hard    core        unlimited
	pgbouncer    soft    memlock     250000000
	pgbouncer    hard    memlock     250000000
	EOF

    # init pgbouncer services
    if [[ -f /opt/conf/services/pgbouncer.service ]]; then
        echo "info: found pgbouncer.services in /opt/conf, copy pgbouncer.service to /etc/systemd/system/"
        rm -rf /etc/systemd/system/pgbouncer.service
        cp -f /opt/conf/services/pgbouncer.service /etc/systemd/system/pgbouncer.service
    else
        echo "info: overwrite /etc/systemd/system/pgbouncer.service"
		cat > /etc/systemd/system/pgbouncer.service <<- 'EOF'
		[Unit]
		Description=pgbouncer connection pooling for PostgreSQL
		Documentation=https://pgbouncer.github.io
		Wants=postgresql.service
		ConditionFileNotEmpty=/etc/pgbouncer/pgbouncer.ini

		[Service]
		User=postgres
		Group=postgres
		Type=forking
		PermissionsStartOnly=true
		ExecStartPre=-/usr/bin/mkdir -p /var/run/pgbouncer /var/log/pgbouncer
		ExecStartPre=-/usr/bin/chown -R postgres:postgres /var/run/pgbouncer /var/log/pgbouncer /etc/pgbouncer

		ExecStart=/bin/pgbouncer -d /etc/pgbouncer/pgbouncer.ini
		ExecReload=/bin/kill -SIGHUP $MAINPID
		PIDFile=/var/run/pgbouncer/pgbouncer.pid

		[Install]
		WantedBy=multi-user.target
		EOF
    fi

    chown -R postgres:postgres /var/run/pgbouncer /var/log/pgbouncer /etc/pgbouncer /etc/systemd/system/pgbouncer.service
    systemctl daemon-reload
    return 0
}



#--------------------------------------------------------------#
# Name: launch_pgbouncer
# Desc: launch pgbouncer service
# Note: Assume pgbouncer.service installed
#--------------------------------------------------------------#
function launch_pgbouncer(){
    if ! systemctl | grep pgbouncer.service; then
        echo "info: pgbouncer.service not found, install pgbouncer"
        install_pgbouncer
    fi

    systemctl stop    pgbouncer  > /dev/null 2>&1
    systemctl enable  pgbouncer  > /dev/null 2>&1
    systemctl start   pgbouncer  > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        systemctl status pgbouncer
        return 3
    fi

    # Double check
    if systemctl status pgbouncer > /dev/null 2>&1; then
        echo "info: start pgbouncer.service"
    else
        echo "error: fail to start pgbouncer.service"
    fi
    return 0
}



#==============================================================#
#                              Main                            #
#==============================================================#
function main(){
    if [[ $(whoami) != "root" ]]; then
        echo "error: install pgbouncer require root"
        return 1
    fi

    local action=${1-''}
    case ${action} in
        install  ) shift; install_pgbouncer   $@ ;;
        launch   ) shift; launch_pgbouncer    $@ ;;
        *        )        launch_pgbouncer    $@ ;;
    esac

    return $?
}



#==============================================================#
#                             Main                             #
#==============================================================#
# Code:
#   0   ok
#   1   insufficient privilege
#   2   download pgbouncer failed
#   3   start pgbouncer failed
#==============================================================#
main $@
