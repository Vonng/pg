#!/bin/bash
set -uo pipefail
#==============================================================#
# File      :   install-postgres.sh
# Mtime     :   2019-03-06
# Desc      :   install postgres
# Path      :   install-postgres.sh
# Depend    :   CentOS 6/7
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   Run this as root
#==============================================================#
PROG_NAME="$(basename $0))"
PROG_DIR="$(cd $(dirname $0) && pwd)"

#==============================================================#
#                             Usage                            #
#==============================================================#
function usage() {
	cat <<-'EOF'
		NAME
			install-postgres.sh
		
		SYNOPSIS
			install postgres version -v with user -u
			create directory for cluster named -c
		
			install-postgres.sh [-c|--cluster=testdb]
			                    [-v|--version=12]
			                    [-u|--user=postgres]
			                    [--with-postgis]
			                    [--with-monitor]
			                    [--with-llvm]
		
		DESCRIPTION
			install postgres related tools
			create os group:user ${user} (256:256)
			create dir PG_ROOT=/exporter PG_BKUP=/var/backup
			setup sudo ulimit bashrc for $dbsu
			install pgdg repo
			install postgresql packages
			install postgresql systemd service (CentOS7)
			change dbsu other than postgres is not recommended!
	EOF
	exit 1
}

#--------------------------------------------------------------#
# Name: setup_os
# Desc: optimize operating system parameters & settings
# Note: disable transparent_hugepage, change sysctl.
# Note: idempotent
#--------------------------------------------------------------#
function setup_os() {
	# disable huge page
	if (! grep -q 'Database optimisation' /etc/rc.local); then
		cat >>/etc/rc.local <<-EOF
			# Database optimisation
			echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled
			echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag
			# setup pre-read for backup device
			# blockdev --setra 16384 $(echo $(blkid | awk -F':' '$1!~"block"{print $1}'))
		EOF
		chmod +x /etc/rc.d/rc.local
		printf "\033[0;32m[INFO] setup_os: disable huge page \033[0m\n" >&2
	fi

	# setup sysctl
	local cpucores=$(grep 'cpu cores' /proc/cpuinfo | wc -l)
	local mem="$(free | awk '/Mem:/{print $2}')"
	local swap="$(free | awk '/Swap:/{print $2}')"
	if [[ ${cpucores} -gt 31 ]]; then
		printf "\033[0;32m[INFO] setup_os: setup sysctl for prod env \033[0m\n" >&2
		cat >/etc/sysctl.conf <<-EOF
			# Database kernel optimisation
			fs.aio-max-nr = 1048576
			fs.file-max = 76724600
			kernel.sem = 4096 2147483647 2147483646 512000
			kernel.shmmax = $(($mem * 1024 / 2))
			kernel.shmall = $(($mem / 5))
			kernel.shmmni = 819200
			net.core.netdev_max_backlog = 10000
			net.core.rmem_default = 262144
			net.core.rmem_max = 4194304
			net.core.wmem_default = 262144
			net.core.wmem_max = 4194304
			net.core.somaxconn = 4096
			net.ipv4.tcp_max_syn_backlog = 4096
			net.ipv4.tcp_keepalive_intvl = 20
			net.ipv4.tcp_keepalive_probes = 3
			net.ipv4.tcp_keepalive_time = 60
			net.ipv4.tcp_mem = 8388608 12582912 16777216
			net.ipv4.tcp_fin_timeout = 5
			net.ipv4.tcp_synack_retries = 2
			net.ipv4.tcp_syncookies = 1
			net.ipv4.tcp_timestamps = 1
			net.ipv4.tcp_tw_recycle = 0
			net.ipv4.tcp_tw_reuse = 1
			net.ipv4.tcp_max_tw_buckets = 262144
			net.ipv4.tcp_rmem = 8192 87380 16777216
			net.ipv4.tcp_wmem = 8192 65536 16777216
			vm.dirty_background_bytes = 409600000
			net.ipv4.ip_local_port_range = 40000 65535
			vm.dirty_expire_centisecs = 6000
			vm.dirty_ratio = 80
			vm.dirty_writeback_centisecs = 50
			vm.extra_free_kbytes = 4096000
			vm.min_free_kbytes = 2097152
			vm.mmap_min_addr = 65536
			vm.swappiness = 0
			vm.overcommit_memory = 2
			vm.overcommit_ratio = $((($mem - $swap) * 100 / $mem))
			vm.zone_reclaim_mode = 0
		EOF
	elif [[ ${cpucores} -gt 15 ]]; then
		printf "\033[0;32m[INFO] setup_os: setup sysctl for pre env \033[0m\n" >&2
		cat >/etc/sysctl.conf <<-EOF
			# Database kernel optimisation
			fs.aio-max-nr = 1048576
			fs.file-max = 76724600
			kernel.sem = 4096 409600 4096 16384
			kernel.shmmax = $(($mem * 1024 / 2))
			kernel.shmall = $(($mem / 5))
			kernel.shmmni = 819200
			net.core.netdev_max_backlog = 10000
			net.core.rmem_default = 262144
			net.core.rmem_max = 4194304
			net.core.wmem_default = 262144
			net.core.wmem_max = 4194304
			net.core.somaxconn = 4096
			net.ipv4.tcp_max_syn_backlog = 4096
			net.ipv4.tcp_keepalive_intvl = 20
			net.ipv4.tcp_keepalive_probes = 3
			net.ipv4.tcp_keepalive_time = 60
			net.ipv4.tcp_mem = 8388608 12582912 16777216
			net.ipv4.tcp_fin_timeout = 5
			net.ipv4.tcp_synack_retries = 2
			net.ipv4.tcp_syncookies = 1
			net.ipv4.tcp_timestamps = 1
			net.ipv4.tcp_tw_recycle = 0
			net.ipv4.tcp_tw_reuse = 1
			net.ipv4.tcp_max_tw_buckets = 262144
			net.ipv4.tcp_rmem = 8192 87380 16777216
			net.ipv4.tcp_wmem = 8192 65536 16777216
			vm.dirty_background_bytes = 409600000
			net.ipv4.ip_local_port_range = 40000 65535
			vm.dirty_expire_centisecs = 6000
			vm.dirty_ratio = 80
			vm.dirty_writeback_centisecs = 50
			vm.extra_free_kbytes = 4096000
			vm.min_free_kbytes = 2097152
			vm.mmap_min_addr = 65536
			vm.swappiness = 0
			vm.overcommit_memory = 2
			vm.overcommit_ratio = $((($mem - $swap) * 100 / $mem))
			vm.zone_reclaim_mode = 0
		EOF
	else
		printf "\033[0;32m[INFO] setup_os: setup sysctl for dev env \033[0m\n" >&2
		cat >/etc/sysctl.conf <<-EOF
			# Database kernel optimisation
			fs.aio-max-nr = 1048576
			fs.file-max = 2000000
			net.ipv4.tcp_max_syn_backlog = 4096
			net.ipv4.tcp_keepalive_intvl = 20
			net.ipv4.tcp_keepalive_probes = 3
			net.ipv4.tcp_keepalive_time = 60
			net.ipv4.tcp_fin_timeout = 5
			net.ipv4.tcp_synack_retries = 2
			net.ipv4.tcp_syncookies = 1
			net.ipv4.tcp_timestamps = 1
			net.ipv4.tcp_tw_recycle = 0
			net.ipv4.tcp_tw_reuse = 1
			net.ipv4.ip_local_port_range = 40000 65535
			vm.dirty_ratio = 80
			vm.swappiness = 0
			vm.overcommit_memory = 2
			vm.zone_reclaim_mode = 0
		EOF
	fi
	sysctl -p &>/dev/null

	# bond
	# grub
	# raid
	# swap
	# limit
	return 0
}

#--------------------------------------------------------------#
# Name: setup_dbsu
# Desc: create a dbsu and generate ssh credential
# Arg1: dbsu name, default is 'postgres' (better not change)
# Note: create group postgres
#       create user  postgres
#       setup ssh on /home/$dbsu/.ssh/{id_rsa,id_rsa.pub,config}
#--------------------------------------------------------------#
function setup_dbsu() {
	local dbsu=${1-'postgres'}
	# create dbsu and corresponding group
	if getent passwd "${dbsu}" >/dev/null; then
		printf "\033[0;33m[WARN] setup_dbsu: dbsu ${dbsu} already exist, skip... \033[0m\n" >&2
	else
		getent group "${dbsu}" >/dev/null || groupadd --gid=256 --system "${dbsu}"
		getent passwd "${dbsu}" >/dev/null || useradd --uid=256 -g ${dbsu} --system --home-dir="/home/${dbsu}" --shell=/bin/bash --comment='Postgres Service' ${dbsu}
		mkdir "/home/${dbsu}"
		chown -R $dbsu:$dbsu "/home/${dbsu}"
		chmod 0700 "/home/${dbsu}"
		printf "\033[0;32m[INFO] setup_dbsu: dbsu $(getent passwd ${dbsu}) created: /home/${dbsu} \033[0m\n" >&2
	fi

	# setup ssh access if not exist
	local sshome="/home/${dbsu}/.ssh"
	if [[ -d ${sshome} ]] && [[ -f ${sshome}/id_rsa ]]; then
		printf "\033[0;33m[WARN] setup_dbsu: ssh credential already exist, skip... \033[0m\n" >&2
	else
		mkdir -p ${sshome}
		ssh-keygen -b 1024 -t rsa -q -N "" -f ${sshome}/id_rsa
		cat /home/${dbsu}/.ssh/id_rsa.pub >${sshome}/authorized_keys
		echo "StrictHostKeyChecking=no" >${sshome}/config
		chmod 600 ${sshome}/{id_rsa,id_rsa.pub,config}
		chmod 644 ${sshome}/authorized_keys
		chmod 700 ${sshome}
		printf "\033[0;32m[INFO] setup_dbsu: create dbsu credential on ${HOSTNAME}:${sshome}/id_rsa \033[0m\n" >&2
	fi
	chown -R ${dbsu}:${dbsu} /home/${dbsu}
	return 0
}

#--------------------------------------------------------------#
# Name: setup_dir
# Desc: create basic dir PG_ROOT PG_BKUP owned by dbsu
# Arg1: dbsu name, 'postgres' by default
# Note:
#	/export mounts the high performance SSD
#   /var/backups mounts the large volume cheap HDD
#
#   PGROOT = /export/postgresql/${cluster}_${version} <- /pg
#   PGBKUP = /var/backups
#--------------------------------------------------------------#
function setup_dir() {
	local cluster=${1-'testdb'}
	local version=${2-'12'}
	local dbsu=${3-'postgres'}

	printf "\033[0;32m[INFO] setup_dir: cluster=${cluster} version=${version} dbsu=${dbsu} \033[0m\n" >&2
	# e.g: PGROOT is the dir contains a series of stuff (data/conf/log/bin)
	# the name is deliberately choosen to label PG Instance with bizname
	# and pg version, which reduce the chance of stupid mistake
	local pgroot_name="${cluster}_${version}"
	local PGROOT="/export/postgresql/${pgroot_name}"
	local PGDATA="${PGROOT}/data"
	local PGBKUP="/var/backups"

	# make directories
	[[ ! -d ${PGROOT} ]] && mkdir -p ${PGROOT}
	[[ ! -d ${PGBKUP} ]] && mkdir -p ${PGBKUP}
	mkdir -p ${PGBKUP}/{arcwal,backup,remote}
	mkdir -p ${PGROOT}/{bin,conf,data,tmp,log}

	# remove soft links and make new one
	[[ -L /pg ]] && rm -rf /pg
	[[ -L /home/${dbsu}/pg ]] && rm -rf /home/${dbsu}/pg
	[[ -L ${PGROOT}/arcwal ]] && rm -rf ${PGROOT}/arcwal
	[[ -L ${PGROOT}/backup ]] && rm -rf ${PGROOT}/backup
	[[ -L ${PGROOT}/remote ]] && rm -rf ${PGROOT}/remote

	ln -s ${PGROOT} /pg              # /pg -> /export/postgresql/testdb_10
	ln -s ${PGROOT} /home/${dbsu}/pg # ~/pg -> /export/postgresql/testdb_10
	ln -s ${PGBKUP}/arcwal /pg/arcwal
	ln -s ${PGBKUP}/backup /pg/backup
	ln -s ${PGBKUP}/remote /pg/remote
	chown -R ${dbsu}:${dbsu} ${PGBKUP}/{arcwal,backup,remote} /export/postgresql

	printf "\033[0;32m[INFO] setup_dir: create symbolic link: /pg -> ${PGROOT} \033[0m\n" >&2
	return 0
}

#--------------------------------------------------------------#
# Name: setup_limit
# Desc: setup ulimit for dbsu
# Arg1: dbsu name, default is 'postgres'
#--------------------------------------------------------------#
function setup_limit() {
	local dbsu=${1-'postgres'}
	local cpucores=$(grep 'cpu cores' /proc/cpuinfo | wc -l)
	if [[ ${cpucores} -gt 8 ]]; then
		cat >/etc/security/limits.d/postgresql.conf <<-EOF
			${dbsu}    soft    nproc       655360
			${dbsu}    hard    nproc       655360
			${dbsu}    hard    nofile      655360
			${dbsu}    soft    nofile      655360
			${dbsu}    soft    stack       unlimited
			${dbsu}    hard    stack       unlimited
			${dbsu}    soft    core        unlimited
			${dbsu}    hard    core        unlimited
			${dbsu}    soft    memlock     250000000
			${dbsu}    hard    memlock     250000000
		EOF
		printf "\033[0;32m[INFO] setup_limit: prod ulimit entry /etc/security/limits.d/postgresql.conf created \033[0m\n" >&2
	else
		cat >/etc/security/limits.d/postgresql.conf <<-EOF
			${dbsu}    soft    nproc       65536
			${dbsu}    hard    nproc       65536
			${dbsu}    hard    nofile      65536
			${dbsu}    soft    nofile      65536
			${dbsu}    soft    stack       unlimited
			${dbsu}    hard    stack       unlimited
			${dbsu}    soft    core        unlimited
			${dbsu}    hard    core        unlimited
			${dbsu}    soft    memlock     2500000
			${dbsu}    hard    memlock     2500000
		EOF
		printf "\033[0;32m[INFO] setup_limit: dev ulimit entry /etc/security/limits.d/postgresql.conf created \033[0m\n" >&2
	fi
}

#--------------------------------------------------------------#
# Name: setup_sudo
# Desc: setup sudo privileges for postgres
# Arg1: dbsu name, 'postgres' by default
# Note: normal sudo with password, systemctl without password
#--------------------------------------------------------------#
function setup_sudo() {
	local dbsu=${1-'postgres'}
	# add dbsu to suders and create systemctl sudo entries
	if (! grep -q "${dbsu}" /etc/passwd) && (! grep -q "${dbsu}" /etc/sudoers); then
		chmod u+w /etc/sudoers
		echo "${dbsu}          ALL=(ALL)         NOPASSWD: ALL" >>/etc/sudoers
	fi
	if [[ ! -f /etc/sudoers.d/${dbsu} ]]; then
		cat >/etc/sudoers.d/${dbsu} <<-EOF
			%${dbsu} ALL= NOPASSWD: /bin/systemctl
		EOF
	fi
	printf "\033[0;32m[INFO] setup_sudo: sudo entry /etc/sudoers.d/${dbsu} created \033[0m\n" >&2
	return 0
}

#--------------------------------------------------------------#
# Name: setup_bashrc
# Desc: setup bashrc for dbsu
# Arg1: dbsu name, 'postgres' by default
#--------------------------------------------------------------#
function setup_bashrc() {
	local dbsu=${1-'postgres'}
	cat >/home/${dbsu}/.bashrc <<-'EOF'
		export EDITOR="vi"
		export PAGER="less"
		export LANG="en_US.UTF-8"
		export LC_ALL="en_US.UTF-8"
		#--------------------------------------------------------------#
		shopt -s nocaseglob;    # case-insensitive globbing
		shopt -s cdspell;       # auto-correct typos in cd
		set -o pipefail         # pipe fail when component fail
		shopt -s histappend;    # append to history rather than overwrite
		for option in autocd globstar; do
		    shopt -s "$option" 2> /dev/null;
		done;
		#--------------------------------------------------------------#
		export MANPAGER="less -X";
		export LESS_TERMCAP_md="$(tput setaf 136)";
		export HISTSIZE=65535;
		export HISTFILESIZE=$HISTSIZE;
		export HISTCONTROL=ignoredups;
		export HISTIGNORE="l:ls:cd:cd -:pwd:exit:date:* --help";
		export PS1="\[\033]0;\w\007\]\[\]\n\[\e[1;36m\][\D{%m-%d %T}] \[\e[1;31m\]\u\[\e[1;33m\]@\H\[\e[1;32m\]:\w \n\[\e[1;35m\]\$ \[\e[0m\]"
		#--------------------------------------------------------------#
		[ -d ${PGHOME:=/usr/pgsql/} ]  		&& export PGHOME || unset PGHOME
		[ -d ${PGDATA:=/pg/data} ]          && export PGDATA || unset PGDATA
		alias p=psql
		alias vcon="vi ${PGDATA}/postgresql.conf"
		alias vhba="vi ${PGDATA}/pg_hba.conf"
		alias vlog='tail -f /pg/data/log/postgresql-$(date +%a).csv'
		alias vrec='vi /pg/data/recovery.conf'
		alias cdd='cd /pg/data'
		alias cdlog='cd /pg/data/log'
		alias pgb='psql -p6432 -dpgbouncer'
		alias pgbstat='psql -p6432 -dpgbouncer -xc "SHOW STATS;"'
		alias pgbpool='psql -p6432 -dpgbouncer -xc "SHOW POOLS;"'
		alias pgstart='sudo systemctl start postgresql'
		alias pgstop='sudo systemctl stop postgresql'
		alias pgrestart='sudo systemctl restart postgresql'
		alias stoppg='pg_ctl -D /pg/data stop'
		alias startpg='pg_ctl -D /pg/data start'
		alias pgreload='sudo systemctl reload postgresql'
		alias pgst='sudo systemctl status postgresql'
		alias ptstart='sudo patroni start'
		alias ptsttop='sudo patroni stop'
		alias pgrepl='psql -Axc "TABLE pg_stat_replication;"'
		alias pt='patronictl -c /pg/bin/patroni.yml'
		alias plog='tail -f /pg/data/log/*.csv'
		alias pst='ps aux | grep postgres'
		alias ptst='sudo systemctl status patroni'
		alias metrics='curl localhost:9630/metrics | grep -v # | grep pg_'
		alias pg2md=" sed 's/+/|/g' | sed 's/^/|/' | sed 's/$/|/' |  grep -v rows | grep -v '||'"
		alias wal=walarchiver
		alias sc='sudo systemctl'
		#--------------------------------------------------------------#
		# ls corlor
		[ ls --color > /dev/null 2>&1 ] && colorflag="--color" || colorflag="-G"
		[ "${TERM}" != "dumb" ] && export LS_COLORS='no=00:fi=00:di=01;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:\ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:'
		alias sl=ls
		alias ll="ls -lh ${colorflag}"
		alias l="ls -lh ${colorflag}"
		alias la="ls -lha ${colorflag}"
		alias lsa="ls -a ${colorflag}"
		alias ls="command ls ${colorflag}"
		alias lsd="ls -lh ${colorflag} | grep --color=never '^d'"   # List only directories
		alias ~="cd ~"
		alias ..="cd .."
		alias cd..="cd .."
		alias ...="cd ../.."
		alias cd...="cd ../.."
		alias ....="cd ../../.."
		alias .....="cd ../../../.."
		alias grep="grep --color=auto"
		alias fgrep="fgrep --color=auto"
		alias egrep="egrep --color=auto"
		alias now='date +"DATE: %Y-%m-%d  TIME: %H:%M:%S  EPOCH: %s"'
		alias today='date +"%Y%m%d "'
		function v() {
			[ $# -eq 0 ] && vim . || vim $@
		}
		#--------------------------------------------------------------#
		# misc
		alias q='exit'
		alias j="jobs"
		alias h="history"
		alias hg="history | grep --color=auto "
		alias cl="clear"
		alias clc="clear"
		alias rf="rm -rf"
		alias ax="chmod a+x";
		alias suod='sudo '
		alias adm="sudo su admin";
		alias admin="sudo su admin";
		alias psa="ps aux | grep "
		alias map="xargs -n1"
		alias gst="git status"
		alias gci="git commit"
		alias gpu="git push origin master"
		function tz() {
			if [ -t 0 ]; then # argument
				tar -zcf "$1.tar.gz" "$@"
			else # pipe
				gzip
			fi;
		}
		function tx(){
			if [ -t 0 ]; then # argument
				tar -xf $@
			else # pipe
				tar -x -
			fi;
		}
		function log_debug() {
			[[ -t 2 ]] && printf "\033[0;34m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][DEBUG] $*\033[0m\n" >&2 ||
				printf "[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][DEBUG] $*\n" >&2
		}
		function log_info() {
			[[ -t 2 ]] && printf "\033[0;32m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][INFO] $*\033[0m\n" >&2 ||
				printf "[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][INFO] $*\n" >&2
		}
		function log_warn() {
			[[ -t 2 ]] && printf "\033[0;33m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][WARN] $*\033[0m\n" >&2 ||
				printf "[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][INFO] $*\n" >&2
		}
		function log_error() {
			[[ -t 2 ]] && printf "\033[0;31m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][ERROR] $*\033[0m\n" >&2 ||
				printf "[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][INFO] $*\n" >&2
		}
	EOF
	cat >/home/${dbsu}/.bash_profile <<-'EOF'
		if [ -f ~/.bashrc ]; then
			. ~/.bashrc
		fi
	EOF

	chmod 644 /home/${dbsu}/.bashrc
	chmod 644 /home/${dbsu}/.bash_profile
	chown -R $dbsu:$dbsu /home/${dbsu}
	printf "\033[0;32m[INFO] setup_bashrc: /home/${dbsu}/.bashrc created \033[0m\n" >&2
	return 0
}

#--------------------------------------------------------------#
# Name: setup_pgdg
# Desc: install official pg yum repo
# Arg1: version: major pg version, e.g: 96 10 11.  12 by default
# Note: https://yum.postgresql.org/12/redhat/rhel-6Server-x86_64/pgdg-redhat-repo-latest.noarch.rpm
# Note: https://yum.postgresql.org/12/redhat/rhel-7Server-x86_64/pgdg-redhat-repo-latest.noarch.rpm
#--------------------------------------------------------------#
function setup_pgdg() {
	local version=${1-'12'}
	if [[ -f /etc/yum.repos.d/pgdg-redhat-all.repo ]]; then
		printf "\033[0;32m[INFO] setup_pgdg: pgdg already installed, skip \033[0m\n" >&2
		return 0
	fi

	# if local yum detected, skip
	if [[ -f /etc/yum.repos.d/pigsty.repo ]]; then
		printf "\033[0;32m[INFO] setup_pgdg: local yum detected, skip \033[0m\n" >&2
		return 0
	fi

	local os_release=$(cat /etc/redhat-release)
	local pgdg_url=""
	if [[ ${os_release} == *CentOS*6.* ]]; then
		pgdg_url="https://yum.postgresql.org/${version}/redhat/rhel-6Server-$(uname -m)/pgdg-redhat-repo-latest.noarch.rpm"
	fi
	if [[ ${os_release} == "CentOS Linux release 7"* ]]; then
		pgdg_url="https://yum.postgresql.org/${version}/redhat/rhel-7Server-$(uname -m)/pgdg-redhat-repo-latest.noarch.rpm"
	fi

	if [[ -z "${pgdg_url}" ]]; then
		printf "\033[0;31m[ERROR] setup_pgdg: os release ${os_release} not supported \033[0m\n" >&2
		return 1
	fi

	printf "\033[0;32m[INFO] setup_pgdg: ${pgdg_url} \033[0m\n" >&2
	yum clean all && yum install -q -y epel-release "${pgdg_url}"
	return $?
}

#--------------------------------------------------------------#
# Name: install_pg_packages
# Desc: install postgresql related packages
# Arg1: version: major pg version, e.g: 96 10 11.  12 by default
#--------------------------------------------------------------#
function install_pg_packages() {
	local version=${1-'12'}
	local postgis_flag=""
	local llvmjit_flag=""
	# additional packages flags
	shift
	while (($# > 0)); do
		case "$1" in
		--with-postgis)
			postgis_flag="true"
			shift
			;;
		--with-llvm)
			llvmjit_flag="true"
			shift
			;;
		*)
			shift
			;;
		esac
	done

	printf "\033[0;32m[INFO] install_pg_packages: --version=${version} --postgis=${postgis_flag} --llvmjit=${llvmjit_flag} \033[0m\n" >&2
	yum install -q -y libxml2 libxslt uuid readline lz4 nc pv lz4 \
		"postgresql${version}" \
		"postgresql${version}-libs" \
		"postgresql${version}-docs" \
		"postgresql${version}-server" \
		"postgresql${version}-devel" \
		"postgresql${version}-contrib" \
		"postgresql${version}-debuginfo" \
		"postgresql${version}-test" \
		"pg_repack${version}" \
		pgbouncer

	# yum install -q -y postgis30_12 postgis30_12-client postgis30_12-devel postgis30_12-utils
	[[ ${postgis_flag} == "true" ]] && yum install -q -y \
		postgis30_${version} \
		postgis30_${version}-client \
		postgis30_${version}-devel \
		postgis30_${version}-utils

	[[ ${llvmjit_flag} == "true" ]] && yum install -q -y postgresql${version}-llvmjit

	# standard path
	printf "\033[0;32m[INFO] install_pg_packages: soft link /usr/pgsql -> /usr/pgsql-${version} \033[0m\n" >&2
	echo "[INFO] make soft link and add to PATH: /usr/pgsql -> /usr/pgsql-${version}"
	rm -rf /usr/pgsql
	ln -sf "/usr/pgsql-${version}" /usr/pgsql
	echo 'export PATH=/usr/pgsql/bin:/pg/bin:$PATH' >/etc/profile.d/pgsql.sh
	. /etc/profile.d/pgsql.sh

	return 0
}

#--------------------------------------------------------------#
# Name: install_pg_service
# Desc: install systemd service
# Arg1: dbsu, postgres by default
#--------------------------------------------------------------#
function install_pg_service() {
	local version=${1-'12'}
	local user=${2-'postgres'}

	if [[ ${os_release} == *CentOS*6.* ]]; then
		printf "\033[0;31m[ERROR] install_pg_service: systemd service not supoorted on CentOS 6, skip... \033[0m\n" >&2
		return 1
	fi

	# copy and change default service definition
	sed -e 's/PGDATA=.*/PGDATA=\/pg\/data/' /usr/lib/systemd/system/postgresql-${version}.service >/usr/lib/systemd/system/postgresql.service

	chown -R ${user}:${user} /etc/systemd/system/postgresql.service
	systemctl daemon-reload
	printf "\033[0;32m[INFO] install_pg_service: /etc/systemd/system/postgresql.service \033[0m\n" >&2
	return 0
}

#--------------------------------------------------------------#
# Name: check_installation
# Desc: check whehter postgres is installed properly
# Arg1: version, 12 by default
# Arg2: dbsu, postgres by default
#--------------------------------------------------------------#
function check_installation() {
	local version=${1-'12'}
	local user=${2-'postgres'}
	local errmsg=""

	[[ ! -z $(getent passwd ${user}) ]] || errmsg="dbsu user not exist"
	[[ ! -z $(getent group ${user}) ]] || errmsg="dbsu group not exist"
	[[ -d /export/postgresql && -d /var/backups ]] || errmsg="PGROOT & PGBACKUP not exist"
	# [[ -f /etc/yum.repos.d/pgdg-redhat-all.repo ]] || errmsg="pgdg repo not installed"

	[[ -f /etc/profile.d/pgsql.sh ]] || errmsg="path not set"
	[[ -f /etc/security/limits.d/postgresql.conf ]] || errmsg="ulimit not set"
	[[ -f /etc/sudoers.d/${user} ]] || errmsg="sudoers not set"
	[[ -d /usr/pgsql-${version} ]] || errmsg="package not installed"
	[[ -L /usr/pgsql ]] || errmsg="soft link not created"
	[[ -x /usr/pgsql/bin/psql ]] || errmsg="client not installed"
	[[ -x /usr/pgsql/bin/pg_ctl ]] || errmsg="server not installed"
	[[ $(pg_ctl --version) == "pg_ctl (PostgreSQL) ${version}"* ]] || errmsg="version not match"

	echo $errmsg
}

#==============================================================#
#                            Main                              #
#==============================================================#
# Args:
#   -v  [pg_version]  major pg version, default is 12
#   -u  [pg_user   ]  default is postgres
#==============================================================#
function log_debug() {
	[[ -t 2 ]] && printf "\033[0;34m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][DEBUG] $*\033[0m\n" >&2 ||
		printf "[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][DEBUG] $*\n" >&2
}
function log_info() {
	[[ -t 2 ]] && printf "\033[0;32m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][INFO] $*\033[0m\n" >&2 ||
		printf "[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][INFO] $*\n" >&2
}
function log_warn() {
	[[ -t 2 ]] && printf "\033[0;33m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][WARN] $*\033[0m\n" >&2 ||
		printf "[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][INFO] $*\n" >&2
}
function log_error() {
	[[ -t 2 ]] && printf "\033[0;31m[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][ERROR] $*\033[0m\n" >&2 ||
		printf "[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][INFO] $*\n" >&2
}

function main() {
	# parse opt
	local cluster='testdb'
	local version='12'
	local user='postgres'
	local postgis_flag=""
	local llvmjit_flag=""

	while (($# > 0)); do
		case "$1" in
		-c | --cluster=*)
			[ "$1" == "-c" ] && shift
			cluster=${1##*=}
			shift
			;;
		-v | --version=*)
			[ "$1" == "-v" ] && shift
			version=${1##*=}
			shift
			;;
		-u | --user=*)
			[ "$1" == "-u" ] && shift
			dbsu=${1##*=}
			shift
			;;
		-g | --with-postgis)
			postgis_flag="--with-postgis"
			shift
			;;
		-j | --with-llvm)
			llvmjit_flag="--with-llvm"
			shift
			;;
		-h | --help | *)
			usage
			exit 1
			;;
		esac
	done

	# precheck
	if [[ "$(whoami)" != "root" ]]; then
		echo "[ERROR] permission denied: run this as root"
		return 1
	fi
	local os_release=$(cat /etc/redhat-release)
	if [[ ${os_release} != *CentOS*6.* && ${os_release} != "CentOS Linux release 7"* ]]; then
		echo "[ERROR] unsupported linux version: ${os_release}"
		return 2
	fi

	# check opt
	local major_version="" # normalized pg majora version: 95, 96, 10, 11, 12
	if [[ ${version} == 9* ]]; then
		major_version=${version:0:3}                                # extract 9.x part
		major_version=$(echo ${version} | awk -F'.' '{print $1$2}') # get 95, 96, etc...
	else
		major_version=$(echo ${version} | awk -F'.' '{print $1}') # 10+
	fi
	version=${major_version}
	if [[ ${version} != "94" && ${version} != "95" && ${version} != "96" && ${version} != "10" && ${version} != "11" && ${version} != "12" ]]; then
		echo "[ERROR] invalid version ${version}, input: ${pg_version}"
		return 3
	fi

	# execute
	log_info "install postgresql ${version} with user ${user}, init cluster=${cluster}"

	log_info "setup operating system parameters & envs"
	setup_os

	log_info "setup dbsu ${user}"
	setup_dbsu ${user}

	log_info "create pg basic directories ${cluster} ${version} ${user}"
	setup_dir ${cluster} ${version} ${user}

	log_info "setup dbsu ulimit"
	setup_limit ${user}

	log_info "setup dbsu sudo privileges"
	setup_sudo ${user}

	log_info "setup dbsu bashrc"
	setup_bashrc ${user}

	log_info "install postgresql yum repo"
	setup_pgdg ${version}

	log_info "install postgresql yum packages"
	install_pg_packages ${version} ${postgis_flag} ${llvmjit_flag}

	log_info "install postgresql systemd configs"
	install_pg_service ${version} ${user}

	log_info "check postgresql installation"

	local errmsg=$(check_installation ${version} ${user})
	if [[ -z ${errmsg} ]]; then
		log_info "install postgres completed!"
		return 0
	else
		log_error "install postgres failed: $errmsg"
		return 1
	fi
}

main $@
