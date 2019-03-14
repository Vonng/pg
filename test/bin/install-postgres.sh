#!/bin/bash

#==============================================================#
# File      :   install-postgres.sh
# Mtime     :   2019-03-06
# Desc      :   Install PostgreSQL (and corresponding utils)
# Path      :   bin/install-postgres.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   CentOS7
# Note      :   Put conf file in /opt/conf
#==============================================================#


# module info
__MODULE_INSTALL_POSTGRES="install-postgres"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


#==============================================================#
#                             Usage                            #
#==============================================================#
function usage(){
	cat <<- 'EOF'
	NAME
		install-postgres.sh  -- install postgresql on local machine
	
	SYNOPSIS
		install-postgres.sh [db_version=11] [dbsu=postgres]
	
	DESCRIPTION
		optimize some os parameters
		create user postgres 256 within user group postgres 256
		create directory /pg/{bin,log,conf,data,backup,arcwal,change}
		install postgresql on /usr/pgsql-<ver>/ and a soft linke @ /usr/pgsql
		install postgresql extensions & utils
		register postgresql service (not launch)
		copy candidate scripts from /opt/bin/pg  to /pg/bin
		Use dbsu != postgres with cautious !
	EOF
}


#--------------------------------------------------------------#
# Name: init_postgres_user
# Desc: create postgres superuser
# Arg1: dbsu name, default is 'postgres' (do not change)
# Note: create group postgres (gid = 256)
#       create user  postgres (uid = 256)
#       create dir   /pg/{bin,log,conf,data,backup,arcwal,change}
#--------------------------------------------------------------#
function init_postgres_user(){
    local dbsu=${1-'postgres'}

    echo "info: mkdir /pg/{bin,log,conf,data,backup,arcwal}"
    mkdir -p /pg/{bin,log,conf,data,backup,arcwal,change}
    touch /pg/change/history

    # add user postgres with gid = 256
    if ( ! grep -q "$dbsu" /etc/group ); then
        echo "info: add group ${dbsu} with gid=256"
        groupadd -r "$dbsu" --gid=256 2> /dev/null
        if [[ $? != 0 ]]; then
            echo "error: add group ${dbsu} failed"
            return 2
        fi
    fi
    if [[ $(id -g ${dbsu} 2> /dev/null) != 256 ]]; then
        echo "warn: force ${dbsu} gid=256"
        groupmod -g 256 ${dbsu}
        if [[ $? != 0 ]]; then
            echo "error: modify group ${dbsu} failed"
            return 3
        fi
    fi

    # add user postgres with uid = 256
    if ( ! grep -q "$dbsu" /etc/passwd ); then
        echo "info: add user ${dbsu} with uid=256"
        useradd -d /home/${dbsu} -g "$dbsu" --shell=/bin/bash --uid=256 "$dbsu" 2> /dev/null
        if [[ $? != 0 ]]; then
            echo "error: add user ${dbsu} failed"
            return 4
        fi
    fi
    if [[ $(id -u ${dbsu} 2> /dev/null) != 256 ]]; then
        echo "warn: force ${dbsu} uid=256"
        usermod -u 256 ${dbsu}
        if [[ $? != 0 ]]; then
            echo "error: modify user ${dbsu} failed"
            return 5
        fi
    fi

    # add ssh access
    echo "setup ssh to ${dbsu}@${HOSTNAME}:/home/${dbsu}/.ssh"
    mkdir -p /home/${dbsu}/.ssh
    if [[ -f /opt/bin/ssh/id_rsa ]]; then
        cp -rf /opt/bin/ssh/id_rsa /home/${dbsu}/.ssh/id_rsa
        chmod 600 /home/${dbsu}/.ssh/id_rsa
    fi
    if [[ -f /opt/bin/ssh/config ]]; then
        cp -rf /opt/bin/ssh/config /home/${dbsu}/.ssh/config
    else
        echo "StrictHostKeyChecking=no" >> /home/${dbsu}/.ssh/config
    fi
    chmod 600 /home/${dbsu}/.ssh/config
    if [[ -f /opt/bin/ssh/id_rsa.pub ]]; then
        cat /opt/bin/ssh/id_rsa.pub >> /home/${dbsu}/.ssh/authorized_keys
        chmod 644 /home/${dbsu}/.ssh/authorized_keys
    fi
    chown -R ${dbsu}:${dbsu} /home/${dbsu}/.ssh
    chmod 700 /home/${dbsu}/.ssh

    # add sudo entries
    echo "info: add sudo entries for ${dbsu}"
    if ( ! grep -q "${dbsu}" /etc/passwd ) && ( ! grep -q "${dbsu}" /etc/sudoers ); then
        chmod u+w /etc/sudoers
        echo "${dbsu}          ALL=(ALL)         NOPASSWD: ALL" >> /etc/sudoers
    fi

	cat > /etc/sudoers.d/${dbsu} <<- EOF
	%${dbsu} ALL= NOPASSWD: /bin/systemctl start   postgresql
	%${dbsu} ALL= NOPASSWD: /bin/systemctl stop    postgresql
	%${dbsu} ALL= NOPASSWD: /bin/systemctl restart postgresql
	%${dbsu} ALL= NOPASSWD: /bin/systemctl reload  postgresql
	%${dbsu} ALL= NOPASSWD: /bin/systemctl status  postgresql
	%${dbsu} ALL= NOPASSWD: /bin/systemctl enable  postgresql
	%${dbsu} ALL= NOPASSWD: /bin/systemctl disable postgresql

	%${dbsu} ALL= NOPASSWD: /bin/systemctl start   pgbouncer
	%${dbsu} ALL= NOPASSWD: /bin/systemctl stop    pgbouncer
	%${dbsu} ALL= NOPASSWD: /bin/systemctl restart pgbouncer
	%${dbsu} ALL= NOPASSWD: /bin/systemctl reload  pgbouncer
	%${dbsu} ALL= NOPASSWD: /bin/systemctl status  pgbouncer
	%${dbsu} ALL= NOPASSWD: /bin/systemctl enable  pgbouncer
	%${dbsu} ALL= NOPASSWD: /bin/systemctl disable pgbouncer

	%${dbsu} ALL= NOPASSWD: /bin/systemctl start   postgres_exporter
	%${dbsu} ALL= NOPASSWD: /bin/systemctl stop    postgres_exporter
	%${dbsu} ALL= NOPASSWD: /bin/systemctl restart postgres_exporter
	%${dbsu} ALL= NOPASSWD: /bin/systemctl reload  postgres_exporter
	%${dbsu} ALL= NOPASSWD: /bin/systemctl status  postgres_exporter
	%${dbsu} ALL= NOPASSWD: /bin/systemctl enable  postgres_exporter
	%${dbsu} ALL= NOPASSWD: /bin/systemctl disable postgres_exporter

	%${dbsu} ALL= NOPASSWD: /bin/systemctl start   pgbouncer_exporter
	%${dbsu} ALL= NOPASSWD: /bin/systemctl stop    pgbouncer_exporter
	%${dbsu} ALL= NOPASSWD: /bin/systemctl restart pgbouncer_exporter
	%${dbsu} ALL= NOPASSWD: /bin/systemctl reload  pgbouncer_exporter
	%${dbsu} ALL= NOPASSWD: /bin/systemctl status  pgbouncer_exporter
	%${dbsu} ALL= NOPASSWD: /bin/systemctl enable  pgbouncer_exporter
	%${dbsu} ALL= NOPASSWD: /bin/systemctl disable pgbouncer_exporter

	%${dbsu} ALL= NOPASSWD: /bin/systemctl start   walarchiver
	%${dbsu} ALL= NOPASSWD: /bin/systemctl stop    walarchiver
	%${dbsu} ALL= NOPASSWD: /bin/systemctl restart walarchiver
	%${dbsu} ALL= NOPASSWD: /bin/systemctl reload  walarchiver
	%${dbsu} ALL= NOPASSWD: /bin/systemctl status  walarchiver
	%${dbsu} ALL= NOPASSWD: /bin/systemctl enable  walarchiver
	%${dbsu} ALL= NOPASSWD: /bin/systemctl disable walarchiver

	%${dbsu} ALL= NOPASSWD: /bin/systemctl reload  consul
	%${dbsu} ALL= NOPASSWD: /bin/systemctl daemon-reload
	EOF


    if [[ -d /opt/bin/pg ]]; then
        echo "info: found /opt/bin/pg, copy to /pg/bin"
        cp -rf /opt/bin/pg/* /pg/bin/
    fi

    # copy bashrc to postgres
    [[ -f /root/.bashrc             ]] && cp -rf /root/.bashrc             /home/${dbsu}/.bashrc
    [[ -f /root/.bash_profile       ]] && cp -rf /root/.bash_profile       /home/${dbsu}/.bash_profile

    # write some alias to profile
	cat >> /home/${dbsu}/.bashrc <<- 'EOF'
	alias p=psql
	alias reload='pg_ctl -D /pg/data reload'
	alias b='cd /pg/bin'
	alias d='cd /pg/data'
	alias data='cd /pg/data'
	alias change='cd /pg/change'
	alias his='tail -n 10 /pg/change/history'
	alias l='cd /pg/data/log'
	alias w=walarchiver
	alias wal=walarchiver
	alias log='tail -f /pg/data/log/postgresql-$(date +%a).csv'
	alias vc='vi /pg/data/postgresql.conf'
	alias vconf='vi /pg/data/postgresql.conf'
	alias va='vi /pg/data/pg_hba.conf'
	alias ve='vi /pg/data/recovery.conf'
	alias sc='sudo systemctl'
	EOF

    # chown & chmod
    chown -R ${dbsu}:${dbsu} /pg
    chmod 0700 /pg/data

    return 0
}



#--------------------------------------------------------------#
# Name: optimize_system_parameters
# Desc: tune some os parameters
#--------------------------------------------------------------#
function optimize_system_parameters(){
    # these are tricky part may vary across different setup, omit here
    # sysctl
    # bond
    # grub
    # raid
    # swap
    # limit
    echo "info: increase postgresql file limit"
	cat > /etc/security/limits.d/postgresql.conf <<- EOF
	postgres    soft    nproc       655360
	postgres    hard    nproc       655360
	postgres    hard    nofile      655360
	postgres    soft    nofile      655360
	postgres    soft    stack       unlimited
	postgres    hard    stack       unlimited
	postgres    soft    core        unlimited
	postgres    hard    core        unlimited
	postgres    soft    memlock     250000000
	postgres    hard    memlock     250000000
	EOF

    # huge page
    echo "info: disable huge page"
    if ( ! grep -q 'Database optimisation' /etc/rc.local ); then
		cat >> /etc/rc.local <<- EOF
		# Database optimisation
		echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled
		echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag
		#blockdev --setra 16384 $(echo $(blkid | awk -F':' '$1!~"block"{print $1}'))
		EOF
        chmod +x /etc/rc.d/rc.local
    fi

    return 0
}


#--------------------------------------------------------------#
# Name: install_postgresql
# Desc: install pg on given major version (latest minor version)
# Arg1: major version: 9.6,10,11,  default is 11
# Arg1: pgdata database cluster dir default = /pg/data
# Note: CentOS6 / CentOS7 only
#--------------------------------------------------------------#
function install_postgresql(){
    local db_version=${1-'11'}
    local major_version="${db_version:0:3}" # e.g: 9.6 10 11
    local short_version="$(echo $db_version | awk -F'.' '{print $1$2}')" # e.g: 93 96 10 11

    local rpm_base="http://yum.postgresql.org/${major_version}/redhat/rhel-7Server-$(uname -m)"
    local pg_rpm="${rpm_base}/pgdg-centos${short_version}-${major_version}-2.noarch.rpm"

    echo "info: install rpm: ${pg_rpm}"
    local msg=$(yum install -q -y ${pg_rpm} 2>&1)
    if [[ $? != 0 ]]; then
        if (echo ${msg} | grep 'Error: Nothing to do');then
            echo "error: install postgresql rpm failed"
            return 6
        fi
    fi

    # echo "info: install dependencies"
    # yum clean all ; yum install -q -y epel-release
    # yum install -q -y uuid readline lz4 nc libxml2 libxslt lsof wget unzip

    echo "info: install postgresql"
    yum install -q -y \
        postgresql"$short_version" \
        postgresql"$short_version"-libs \
        postgresql"$short_version"-server \
        postgresql"$short_version"-contrib \
        postgresql"$short_version"-devel \
        postgresql"$short_version"-debuginfo\
        pgbouncer \
        pg_top"$short_version" \
        pg_repack"$short_version"
        # pgpool-II-"$short_version" \
        # postgis2_"$short_version" \
        # postgis2_"$short_version"-client \

    if [[ $? != 0 ]]; then
        echo "error: install postgresql packages failed $?"
        return 7
    fi

    echo "warn: force rm /usr/pgsql and ln -s /usr/pgsql-${major_version} /usr/pgsql"
    rm -rf /usr/pgsql
    ln -sf "/usr/pgsql-${major_version}" /usr/pgsql

    echo "info: add /pg/bin /usr/pgsql/bin to /etc/profile.d/pgsql.sh"
    echo 'export PATH=/pg/bin:/usr/pgsql/bin:$PATH' > /etc/profile.d/pgsql.sh
    . /etc/profile.d/pgsql.sh

    # init postgresql services
    if [[ -f /opt/conf/services/postgresql.service ]]; then
        echo "info: found postgresql.services in /opt/conf, copy postgresql.service to /etc/systemd/system/"
        rm -rf /etc/systemd/system/postgresql.service
        cp -f /opt/conf/services/postgresql.service /etc/systemd/system/postgresql.service
    else
        echo "info: overwrite /etc/systemd/system/postgresql.service"
		cat > /etc/systemd/system/postgresql.service <<- EOF
		[Unit]
		Description=PostgreSQL database server
		Documentation=https://www.postgresql.org
		After=network.target

		[Service]
		Type=forking
		User=postgres
		Group=postgres

		# Disable OOM kill on the postmaster
		OOMScoreAdjust=-1000
		Environment=PG_OOM_ADJUST_FILE=/proc/self/oom_score_adj
		Environment=PG_OOM_ADJUST_VALUE=0
		Environment=PGDATA=/pg/data

		ExecStart=/usr/pgsql/bin/pg_ctl  start  -D /pg/data -s -w -t 300
		ExecStop=/usr/pgsql/bin/pg_ctl   stop   -D /pg/data -s -m fast
		ExecReload=/usr/pgsql/bin/pg_ctl reload -D /pg/data -s
		TimeoutSec=300

		[Install]
		WantedBy=multi-user.target
		EOF
    fi

    chown -R postgres:postgres /etc/systemd/system/postgresql.service /pg
    systemctl daemon-reload

    echo "info: install postgresql on ${HOSTNAME} complete"
    return 0
}




#==============================================================#
#                            Main                              #
#==============================================================#
# Args:
#   -v  [db version]  default is 11
#   -u  [db user   ]  default is postgres
#
# Code:
#   0   ok
#   1   insufficient privilege
#   2   create user group failed
#   3   modify user group id failed
#   4   create user failed
#   5   insufficient privilege
#   6   install postgresql yum rpm failed
#   7   install postgresql failed
#==============================================================#
function main(){
    local pg_version='11'
    local pg_user='postgres'

    while (( $# > 0)); do
        case "$1" in
            -v|--version=*)
                [[ "$1" == "-v" ]]  && shift
                pg_version=${1##*=};shift ;;
            -u|--user=*)
                [[ "$1" == "-u" ]]  && shift
                pg_user=${1##*=};   shift ;;
            -h|--help|*) usage           ;;
        esac
    done

    # make sure running as root
    if [[ "$(whoami)" != "root" ]]; then
        echo "error: run this as root"
        return 1
    fi
    echo "info: install postgresql ${pg_version} with ${pg_user} on ${HOSTNAME}"

    # create user
    echo "info: init postgres user ${pg_user}"
    if ! init_postgres_user ${pg_user}; then
        echo "init postgres user failed"
        return $?
    fi

    # install binary
    echo "info: install postgresql ${pg_user}"
    if ! install_postgresql ${pg_version}; then
        echo "install postgresql binary failed"
        return $?
    fi

    # tuning parameter
    echo "info: optimize system parameters"
    optimize_system_parameters

    return 0
}

main $@