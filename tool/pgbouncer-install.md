# 安装Pgbouncer

### 安装脚本

```bash
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

```







## 安装

生产环境CentOS/RedHat使用yum进行二进制安装

```bash
# 检查所有以pg打头的包：
sudo yum list pg*

# 显示所有版本的pgbouncer
yum --showduplicates list pgbouncer

# 移除旧版本的pgbouncer
sudo yum -y remove pgbouncer

# 选择需要安装的版本
sudo yum -y install pgbouncer-1.9.0

# 检查版本
pgbouncer --version
```

Mac下直接使用brew安装：

```bash
brew install pgbouncer
```

编译Pgbouncer需要一些依赖：

- [GNU Make](https://www.gnu.org/software/make/) 3.81+
- [libevent](http://libevent.org/) 2.0
- [pkg-config](https://www.freedesktop.org/wiki/Software/pkg-config/)
- (optional) [OpenSSL](https://www.openssl.org/) 1.0.1 for TLS support.
- (optional) [c-ares](http://c-ares.haxx.se/) as alternative to libevent’s evdns.

源码下载地址：https://pgbouncer.github.io/downloads/

```bash
$ git clone https://github.com/pgbouncer/pgbouncer.git
$ cd pgbouncer
$ git submodule init
$ git submodule update
$ ./autogen.sh
$ ./configure ...
$ make
$ make install
```



## 配置

#### 设置目录

```bash
# run as root, setup directories

mkdir -p /var/log/pgbouncer /var/run/pgbouncer /etc/pgbouncer
chown -R pgbouncer:pgbouncer /var/log/pgbouncer /var/run/pgbouncer /etc/pgbouncer
```

#### 修改配置文件

```bash
cat > /etc/pgbouncer/pgbouncer.ini <<-EOF
[databases]
putong-payment = 
putong-payment-old = host=10.191.161.35 dbname=putong-payment

[pgbouncer]

logfile = /var/log/pgbouncer/pgbouncer.log
pidfile = /var/run/pgbouncer/pgbouncer.pid

listen_addr = *
listen_port = 6432

auth_type = trust
auth_file = /etc/pgbouncer/userlist.txt

admin_users = postgres
stats_users = stats, postgres

pool_mode = transaction
server_reset_query = 

application_name_add_host = 1
max_client_conn = 20000
default_pool_size = 50

reserve_pool_size = 10
reserve_pool_timeout = 5
max_db_connections = 80

log_connections = 0
log_disconnections = 0

ignore_startup_parameters = extra_float_digits

EOF

chown pgbouncer:pgbouncer /etc/pgbouncer/pgbouncer.ini
chmod 0600 /etc/pgbouncer/pgbouncer.ini
```

#### 用户列表文件

```bash
cat > /etc/pgbouncer/userlist.txt <<-EOF
"putong" "xxxxx"
"stats" "123456"
EOF

chown pgbouncer:pgbouncer /etc/pgbouncer/userlist.txt
chmod 0600 /etc/pgbouncer/userlist.txt
```



## 启动

以pgbouncer身份启动

```bash
sudo -iu pgbouncer /usr/bin/pgbouncer -d -R /etc/pgbouncer/pgbouncer.ini
```

这里`-d`选项代表以守护进程的模式启动，`-R`表示重启，如果已经有Pgbouncer实例，新的进程会接管老进程。

显示统计信息：

```bash
psql postgres://stats@tmp:6432/pgbouncer?host=/tmp -c "SHOW STATS;"
```

连接实际数据库：

```bash
psql postgres://putong@tmp:6432/putong-payment?host=/tmp
```

检查Pgbouncer的CPU使用：

```
top -d1 -bn10 -p `cat /var/run/pgbouncer/pgbouncer.pid` | grep pgbouncer
```





## 监控

监控pgbouncer可以使用prometheus，通过`pgbouncer_exporter`实现监控。



PostgreSQL的Exporter：https://github.com/wrouesnel/postgres_exporter/releases

Pgbouncer的Exporter：