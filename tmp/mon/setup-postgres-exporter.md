# PostgresExporter

## 安装

### 安装脚本

```bash
#!/bin/bash

#==============================================================#
# File      :   install-postgres-exporter.sh
# Mtime     :   2018-12-06
# Desc      :   Install Postgres Exporter
# Path      :   bin/install-postgres-exporter.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Depend    :   CentOS7
# Note      :   check /opt/conf/services/postgres_exporter.service
#==============================================================#


# module info
__MODULE_INSTALL_POSTGRES_EXPORTER="install-postgres-exporter"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


#--------------------------------------------------------------#
# Name: download_postgres_exporter
# Desc: Guarantee a usable postgres_exporter in ${target_location}
# Arg1: target postgres_exporter location      (/usr/local/bin/postgres_exporter)
# Arg2: cache  postgres_exporter location      (/opt/pkg/postgres_exporter)
# Arg3: postgres_exporter version to download  (0.4.7)
# Note: Run this as root
# Note: This will
#--------------------------------------------------------------#
function download_postgres_exporter() {
    local target_location=${1-'/usr/local/bin/postgres_exporter'}
    local cache_location=${2-'/opt/pkg/postgres_exporter'}
    local postgres_exporter_version=${3-'0.4.7'}

    # if exact same version already in target location, skip
    if [[ -x ${target_location} ]]; then
        echo "warn: found postgres_exporter ${postgres_exporter_version} on ${target_location}, skip"
        return 0
    fi

    # if postgres_exporter in /opt/pkg, use it regardless version
    if [[ -x ${cache_location} ]]; then
        echo "warn: found postgres_exporter in cache, cp ${cache_location} ${target_location}, skip"
        cp -f ${cache_location} ${target_location}
        return 0
    fi

    # download from Internet
    local postgres_exporter_filename="postgres_exporter_v${postgres_exporter_version}_linux-amd64.tar.gz"
    local postgres_exporter_url="https://github.com/wrouesnel/postgres_exporter/releases/download/v${postgres_exporter_version}/${postgres_exporter_filename}"
    echo "info: download postgres_exporter from ${postgres_exporter_url}"

    cd /tmp
    rm -rf ${postgres_exporter_filename}
    if ! wget ${postgres_exporter_url} 2> /dev/null; then
        echo 'error: download postgres_exporter failed'
        return 2
    fi
    if ! tar -xf ${postgres_exporter_filename} 2> /dev/null; then
        echo 'error: unzip postgres_exporter failed'
        return 3
    fi
    mv -f "postgres_exporter_v${postgres_exporter_version}_linux-amd64/postgres_exporter" ${target_location}
    cd - > /dev/null

    return 0
}


#--------------------------------------------------------------#
# Name: install_postgres_exporter
# Desc: install postgres_exporter service to systemctl
# Note: Assume viable postgres_exporter binary in /usr/local/bin/postgres_exporter
# Note: Run this as root
#       postgres_exporter conf dir: /etc/postgres_exporter.d
#       postgres_exporter data dir: /var/lib/postgres_exporter
#       postgres_exporter binary  : /usr/local/bin/postgres_exporter
#--------------------------------------------------------------#
function install_postgres_exporter() {
    if [[ ! -x /usr/local/bin/postgres_exporter ]]; then
        echo "warn: /usr/local/bin/postgres_exporter not found, download"
        download_postgres_exporter
        if [[ $? != 0 ]]; then
            echo "error: download postgres_exporter failed"
            return $?
        fi
    fi

    # init dir & conf
    mkdir -p /etc/postgres_exporter
    if [[ -f /opt/conf/postgres_exporter.yaml ]]; then
        echo "info: found /opt/conf/postgres_exporter.yaml , copy postgres_exporter.yaml to /etc/postgres_exporter/queries.yaml"
        rm -rf /etc/postgres_exporter/queries.yaml
        cp -f /opt/conf/postgres_exporter.yaml /etc/postgres_exporter/queries.yaml
    fi

    # services parameter
    if [[ -f /opt/conf/postgres_exporter.env ]]; then
        echo "info: found /opt/conf/postgres_exporter.env , copy postgres_exporter.env to /etc/postgres_exporter/env"
        rm -rf /etc/postgres_exporter/env
        cp /opt/conf/postgres_exporter.env /etc/postgres_exporter/env
    else
        if [[ -f /etc/postgres_exporter/queries.yaml ]]; then
			cat > /etc/postgres_exporter/env <<- EOF
			DATA_SOURCE_NAME='dbname=postgres user=postgres host=/tmp port=5432 sslmode=disable application_name=postgres_exporter'
			PG_EXPORTER_DISABLE_DEFAULT_METRICS=true
			PG_EXPORTER_EXTEND_QUERY_PATH=/etc/postgres_exporter/queries.yaml
			EOF
        else
            cat > /etc/postgres_exporter/env <<- EOF
			DATA_SOURCE_NAME='dbname=postgres user=postgres host=/tmp port=5432 sslmode=disable application_name=postgres_exporter'
			PG_EXPORTER_DISABLE_DEFAULT_METRICS=false
			EOF
        fi
    fi

    # init postgres_exporter services
    if [[ -f /opt/conf/services/postgres_exporter.service ]]; then
        echo "info: found postgres_exporter.services in /opt/conf, copy postgres_exporter.service to /etc/systemd/system/"
        rm -rf /etc/systemd/system/postgres_exporter.service
        cp -f /opt/conf/services/postgres_exporter.service /etc/systemd/system/postgres_exporter.service
    else
        echo "info: overwrite /etc/systemd/system/postgres_exporter.service"
	cat > /etc/systemd/system/postgres_exporter.service <<- EOF
		[Unit]
		Description=postgres_exporter for prometheus
		Wants=postgresql.service
		Wants=network-online.target
		After=network-online.target
		ConditionFileNotEmpty=/etc/postgres_exporter/env
		ConditionFileNotEmpty=/etc/postgres_exporter/queries.yaml

		[Service]
		User=postgres
		Group=postgres
		EnvironmentFile=/etc/postgres_exporter/env
		ExecStartPre=-/usr/bin/chown -R postgres:postgres /etc/systemd/system/postgres_exporter.service /etc/postgres_exporter

		ExecStart=/usr/local/bin/postgres_exporter
		KillMode=process
		Restart=on-failure

		[Install]
		WantedBy=default.target
		EOF
    fi

    chown -R postgres:postgres /etc/systemd/system/postgres_exporter.service /etc/postgres_exporter
    systemctl daemon-reload
    return 0
}



#--------------------------------------------------------------#
# Name: launch_postgres_exporter
# Desc: launch postgres_exporter service
# Note: Assume postgres_exporter.service installed
#--------------------------------------------------------------#
function launch_postgres_exporter(){
    if ! systemctl | grep postgres_exporter.service; then
        echo "info: postgres_exporter.service not found"
        install_postgres_exporter
    fi

    systemctl stop    postgres_exporter > /dev/null 2>&1
    systemctl enable  postgres_exporter > /dev/null 2>&1
    systemctl restart postgres_exporter > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        systemctl status postgres_exporter
        return 4
    fi

    # Double check
    if systemctl status postgres_exporter > /dev/null 2>&1; then
        echo "info: start postgres_exporter.service"
    else
        echo "error: fail to start postgres_exporter.service"
    fi
    return 0
}


#==============================================================#
#                              Main                            #
#==============================================================#
function main(){
    if [[ $(whoami) != "root" ]]; then
        echo "error: install postgres exporter require root"
        return 1
    fi

    local action=${1-''}
    case ${action} in
        download ) shift; download_postgres_exporter $@ ;;
        install  ) shift; install_postgres_exporter  $@ ;;
        launch   ) shift; launch_postgres_exporter   $@ ;;
        *        )        launch_postgres_exporter   $@ ;;
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
#   2   download postgres exporter failed
#   3   decompress postgres_exporter failed
#   4   launch postgres_exporter failed
#==============================================================#
main $@
```

### systemctl服务

```ini
[Unit]
Description=PostgreSQL metrics exporter for prometheus
Wants=postgresql.service
Wants=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/postgres_exporter/env
ConditionFileNotEmpty=/etc/postgres_exporter/queries.yaml

[Service]
User=postgres
Group=postgres
EnvironmentFile=/etc/postgres_exporter/env
ExecStartPre=-/usr/bin/chown -R postgres:postgres /etc/systemd/system/postgres_exporter.service /etc/postgres_exporter

ExecStart=/usr/local/bin/postgres_exporter
KillMode=process
Restart=on-failure

[Install]
WantedBy=default.target
```



## 自定义查询文件

postgres_exporter自带的指标太简单了，好在有自定义扩展机制。

比较操蛋的是`postgres_exporter`因为在启动时去连接数据库查询了一些配置，因此没法直接当成pgbouncer的exporter。



* [PostgreSQL 9.6 自定义配置文件](postgres_exporter/queries-96.yaml)
* [PostgreSQL 10 自定义配置文件](postgres_exporter/queries-10.yaml)
* [PostgreSQL 11 自定义配置文件](postgres_exporter/queries-11.yaml)





# PostgresExporter

Prometheus exporter for PostgreSQL server metrics. Supported Postgres versions: 9.1 and up.

## Quick Start

This package is available for Docker:

```
# Start an example database
docker run --net=host -it --rm -e POSTGRES_PASSWORD=password postgres
# Connect to it
docker run --net=host -e DATA_SOURCE_NAME="postgresql://postgres:password@localhost:5432/?sslmode=disable" wrouesnel/postgres_exporter
```

## Building and running

The build system is based on [Mage](https://magefile.org/)

The default make file behavior is to build the binary:

```
$ go get github.com/wrouesnel/postgres_exporter
$ cd ${GOPATH-$HOME/go}/src/github.com/wrouesnel/postgres_exporter
$ go run mage.go
$ export DATA_SOURCE_NAME="postgresql://login:password@hostname:port/dbname"
$ ./postgres_exporter <flags>
```

To build the dockerfile, run `go run mage.go docker`.

This will build the docker image as `wrouesnel/postgres_exporter:latest`. This is a minimal docker image containing *just*postgres_exporter. By default no SSL certificates are included, if you need to use SSL you should either bind-mount`/etc/ssl/certs/ca-certificates.crt` or derive a new image containing them.

### Vendoring

Package vendoring is handled with [`govendor`](https://github.com/kardianos/govendor)

### Flags

- `web.listen-address` Address to listen on for web interface and telemetry. Default is `:9187`.
- `web.telemetry-path` Path under which to expose metrics. Default is `/metrics`.
- `disable-default-metrics` Use only metrics supplied from `queries.yaml` via `--extend.query-path`
- `extend.query-path` Path to a YAML file containing custom queries to run. Check out [`queries.yaml`](https://github.com/wrouesnel/postgres_exporter/blob/master/queries.yaml) for examples of the format.
- `dumpmaps` Do not run - print the internal representation of the metric maps. Useful when debugging a custom queries file.
- `log.level` Set logging level: one of `debug`, `info`, `warn`, `error`, `fatal`
- `log.format` Set the log output target and format. e.g. `logger:syslog?appname=bob&local=7` or `logger:stdout?json=true` Defaults to `logger:stderr`.

### Environment Variables

The following environment variables configure the exporter:

- `DATA_SOURCE_NAME` the default legacy format. Accepts URI form and key=value form arguments. The URI may contain the username and password to connect with.
- `DATA_SOURCE_URI` an alternative to DATA_SOURCE_NAME which exclusively accepts the raw URI without a username and password component.
- `DATA_SOURCE_USER` When using `DATA_SOURCE_URI`, this environment variable is used to specify the username.
- `DATA_SOURCE_USER_FILE` The same, but reads the username from a file.
- `DATA_SOURCE_PASS` When using `DATA_SOURCE_URI`, this environment variable is used to specify the password to connect with.
- `DATA_SOURCE_PASS_FILE` The same as above but reads the password from a file.
- `PG_EXPORTER_WEB_LISTEN_ADDRESS` Address to listen on for web interface and telemetry. Default is `:9187`.
- `PG_EXPORTER_WEB_TELEMETRY_PATH` Path under which to expose metrics. Default is `/metrics`.
- `PG_EXPORTER_DISABLE_DEFAULT_METRICS` Use only metrics supplied from `queries.yaml`. Value can be `true` or `false`. Default is `false`.
- `PG_EXPORTER_EXTEND_QUERY_PATH` Path to a YAML file containing custom queries to run. Check out [`queries.yaml`](https://github.com/wrouesnel/postgres_exporter/blob/master/queries.yaml) for examples of the format.

Settings set by environment variables starting with `PG_` will be overwritten by the corresponding CLI flag if given.

### Setting the Postgres server's data source name

The PostgreSQL server's [data source name](http://en.wikipedia.org/wiki/Data_source_name) must be set via the `DATA_SOURCE_NAME` environment variable.

For running it locally on a default Debian/Ubuntu install, this will work (transpose to init script as appropriate):

```
sudo -u postgres DATA_SOURCE_NAME="user=postgres host=/var/run/postgresql/ sslmode=disable" postgres_exporter
```

See the [github.com/lib/pq](http://github.com/lib/pq) module for other ways to format the connection string.

### Adding new metrics

The exporter will attempt to dynamically export additional metrics if they are added in the future, but they will be marked as "untyped". Additional metric maps can be easily created from Postgres documentation by copying the tables and using the following Python snippet:

```
x = """tab separated raw text of a documentation table"""
for l in StringIO(x):
    column, ctype, description = l.split('\t')
    print """"{0}" : {{ prometheus.CounterValue, prometheus.NewDesc("pg_stat_database_{0}", "{2}", nil, nil) }}, """.format(column.strip(), ctype, description.strip())
```

Adjust the value of the resultant prometheus value type appropriately. This helps build rich self-documenting metrics for the exporter.

### Adding new metrics via a config file

The -extend.query-path command-line argument specifies a YAML file containing additional queries to run. Some examples are provided in [queries.yaml](https://github.com/wrouesnel/postgres_exporter/blob/master/queries.yaml).

### Disabling default metrics

To work with non-officially-supported postgres versions you can try disabling (e.g. 8.2.15) or a variant of postgres (e.g. Greenplum) you can disable the default metrics with the `--disable-default-metrics` flag. This removes all built-in metrics, and uses only metrics defined by queries in the `queries.yaml` file you supply (so you must supply one, otherwise the exporter will return nothing but internal statuses and not your database).

### Running as non-superuser

To be able to collect metrics from pg_stat_activity and pg_stat_replication as non-superuser you have to create views as a superuser, and assign permissions separately to those. In PostgreSQL, views run with the permissions of the user that created them so they can act as security barriers.

```sql
CREATE USER postgres_exporter PASSWORD 'password';
ALTER USER postgres_exporter SET SEARCH_PATH TO postgres_exporter,pg_catalog;

-- If deploying as non-superuser (for example in AWS RDS)
-- GRANT postgres_exporter TO :MASTER_USER;
CREATE SCHEMA postgres_exporter AUTHORIZATION postgres_exporter;

CREATE VIEW postgres_exporter.pg_stat_activity
AS
  SELECT * from pg_catalog.pg_stat_activity;

GRANT SELECT ON postgres_exporter.pg_stat_activity TO postgres_exporter;

CREATE VIEW postgres_exporter.pg_stat_replication AS
  SELECT * from pg_catalog.pg_stat_replication;

GRANT SELECT ON postgres_exporter.pg_stat_replication TO postgres_exporter;
```

> **NOTE** 
> Remember to use `postgres` database name in the connection string:
>
> ```
> DATA_SOURCE_NAME=postgresql://postgres_exporter:password@localhost:5432/postgres?sslmode=disable
> ```

# Hacking

- To build a copy for your current architecture run `go run mage.go binary` or just `go run mage.go` This will create a symlink to the just built binary in the root directory.
- To build release tar balls run `go run mage.go release`.
- Build system is a bit temperamental at the moment since the conversion to mage - I am working on getting it to be a perfect out of the box experience, but am time-constrained on it at the moment.