# Pgbouncer使用说明



## 安装

```bash
# 快速安装
sudo yum install pgbouncer
sudo apt-get install pgbouncer
brew install pgbouncer

# CentOS下安装特定版本
# 检查所有以pg打头的包：
sudo yum list pg*

# 显示所有版本的pgbouncer
yum --showduplicates list pgbouncer

# 移除旧版本的pgbouncer
sudo yum remove pgbouncer

# 选择需要安装的版本
sudo yum install pgbouncer-1.8.1

# 检查版本
pgbouncer --version
```

样例配置文件

[database]节由一系列[k=v]的记录组成，其中左边的k是连接池中数据库的名称，右边是数据库的实际连接串。

[pgbouncer]节包括一些重要的配置。

```ini
[databases]
vonng = host=127.0.0.1

[pgbouncer]
logfile = /var/log/pgbouncer/pgbouncer.log
pidfile = /var/run/pgbouncer/pgbouncer.pid
listen_addr = *
listen_port = 6432
auth_type = trust
auth_file = /etc/pgbouncer/userlist.txt
admin_users = vonng
stats_users = vonng
pool_mode = transaction
server_reset_query =
max_client_conn = 50000
default_pool_size = 100
reserve_pool_size = 1
reserve_pool_timeout = 5
log_connections = 0
log_disconnections = 0
application_name_add_host = 1
```





# pgbouncer.ini

### 描述

配置文件采用"ini"格式。章节名称介于"["和"]"之间。以";"或"#" 开头的行是注释并且忽略。字符";"和"#"在注释行中稍后出现时不被识别。

### 通用设置

#### `logfile`

指定日志文件。日志文件是保持打开的，所以重启 `kill -HUP` 之后 或控制台上 `RELOAD;` 应该完成。 注意：在Windows机器上，服务必须停止并启动。

默认：没有设置。

#### `pidfile`

指定pid文件。没有pidfile，不允许守护进程。

默认：没有设置。

#### `listen_addr`

指定地址列表，表明在哪里监听TCP连接。 你还可以使用 `*` 表示“监听所有地址”。没有设置时， 只允许Unix套接字连接。

可以用数字(IPv4/IPv6)或名称指定地址。

默认：没有设置。

#### listen_port

监听哪个端口。应用到TCP和Unix套接字。

默认: 6432

#### unix_socket_dir

指定Unix套接字的位置。应用到监听套接字和服务器配置。 如果设置为一个空的字符串，则禁用Unix套接字。 需要在线重新启动(-R)才能工作。 注意：Windows机器不支持。

默认: /tmp

#### unix_socket_mode

unix套接字的文件系统模式。

默认: 0777

#### unix_socket_group

用于unix套接字的组名。

默认：没有设置

#### user

如果设置了，则指定启动后要切换到的Unix用户。只有在 PgBouncer以root身份启动，或者已经以给定的用户身份运行时才能工作。

注意：Windows机器不支持。

默认：没有设置

#### auth_file

从中加载用户名和密码的文件名。文件格式和PostgreSQL 8.x pg_auth/pg_pwd 文件相同。自版本9.0以来，PostgreSQL不再使用这种文本文件，所以它必须手动生成。 详见下面的 [认证文件格式](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#id12) 章节。

默认：没有设置。

#### auth_hba_file

当 [auth_type](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#auth-type) 是 `hba` 时要使用的HBA配置文件。 从版本1.7开始支持。

默认：没有设置。

#### auth_type

如何验证用户

| 方式  | 说明                                                         |
| ----- | ------------------------------------------------------------ |
| hba   | 实际验证类型是从 [auth_hba_file](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#auth-hba-file) 文件中加载的。这允许不同的验证方式、 不同的访问路径。例如：unix套接字上的连接使用 `peer` 认证类型， TCP上的连接必须使用TLS。从版本1.7开始支持。 |
| cert  | 客户端必须通过TLS连接与有效的客户端证书进行连接。 然后，用户名从证书中的CommonName字段中取出。 |
| md5   | 使用基于MD5的密码检查。 [auth_file](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#auth-file) 可能同时包含MD5加密 或纯文本密码。这是默认的身份验证方法。 |
| plain | 明文密码通过线路发送。已过时。                               |
| trust | 不执行认证。用户名必须仍然存在于 [auth_file](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#auth-file) 中。 |
| any   | 类似于 `trust` 方式，但是不需要用户名。 要求将所有数据库配置为以特定用户身份登陆。另外， 控制台数据库允许任意用户以管理员身份登陆。 |
|       |                                                              |
|       |                                                              |
|       |                                                              |



#### auth_query

查询从数据库加载用户密码。

直接访问pg_shadow需要管理员权限。最好使用非管理员用户调用SECURITY DEFINER功能。

默认: `SELECT usename, passwd FROM pg_shadow WHERE usename=$1`

#### pool_mode

指定服务器连接何时可被其他客户端重用。

- session

  在客户端断开的时候，服务器连接会放回到连接池中。默认。

- transaction

  事务结束后，服务器将会放回连接池中。

- statement

  查询结束后，服务器将会放回连接池中。在这个模式中， 不允许多个语句的长事务。

#### max_client_conn

允许的最大客户端连接数量。当增加时，文件描述符限制也应该增加。 注意实际使用的文件描述符数量是超过max_client_conn的。 理论上使用的最大值是：

> max_client_conn + (max_pool_size * total_databases * total_users)

如果每个用户以自己的用户名连接到服务器。如果在连接字符串中指定了数据库用户 （所有用户在同一用户名下连接），理论上的最大值为：

> max_client_conn + (max_pool_size * total_databases)

理论上的最大值应该永远不会达到，除非有人故意制造出特殊的负荷。 不过，这意味着您应该将文件描述符的数量设置为安全的数字。

在你最喜欢的shell手册页中搜索 `ulimit` 。 注意： `ulimit` 不适用于Windows环境。

默认: 100

#### default_pool_size

每个用户/数据库对允许多少个服务器连接。可以在每个数据库配置中被覆盖。

默认: 20

#### min_pool_size

如果低于此数字，请添加更多服务器连接到池。 改进常规负载在完全不活动的时间段之后突然恢复时的行为。

默认: 0 (禁用)

#### reserve_pool_size

池允许有多少额外的连接。0 不允许。

默认: 0 (禁用)

#### reserve_pool_timeout

如果客户端在这么多秒钟内没有得到维护，pgbouncer就可以使用备用池中的其他连接。0禁用。

默认: 5.0

#### max_db_connections

不允许每个数据库超过这么多个连接（不管池，即用户）。应该注意的是， 当您达到限制时，关闭客户端到一个池的连接将不会立即允许为另一个池建立服务器连接， 因为第一个池的服务器连接仍然是打开的。一旦服务器连接关闭（由于空闲超时）， 将立即为等待的池打开新的服务器连接。

默认: 无限制

#### max_user_connections

不允许每个用户超过这么多个连接（不管池，即用户）。应该注意的是， 当您达到限制时，关闭客户端到一个池的连接将不会立即允许为另一个池建立服务器连接， 因为第一个池的服务器连接仍然是打开的。一旦服务器连接关闭（由于空闲超时）， 将立即为等待的池打开新的服务器连接。

#### server_round_robin

默认情况下，pgbouncer以LIFO（后进先出）方式重新使用服务器连接， 因此几乎没有连接得到最大的负载。如果您有一台服务器提供数据库， 这将提供最佳性能。但是如果在数据库IP之后有TCP循环， 那么如果pgbouncer也以这种方式使用连接，那么更好，从而实现均匀的负载。

默认: 0

#### ignore_startup_parameters

默认情况下，pgbouncer只允许在启动数据包中可以跟踪的参数—— `client_encoding`、`datestyle`、`timezone` 和 `standard_conforming_strings` 。

所有其他参数会引发错误。为了允许其他参数，可以在这里指定它们， 以便pgbouncer知道它们由管理员处理，并且可以忽略它们。

默认: 空

#### disable_pqexec

禁用简单查询协议（PQexec）。与扩展查询协议不同，简单查询允许一个数据包中的多个查询， 这允许一些类型的SQL注入攻击。禁用它可以提高安全性。 显然这意味着只有使用扩展查询协议的客户端才能保持工作。

默认: 0

#### application_name_add_host

将客户端主机地址和端口添加到连接启动上设置的应用程序名称设置。 这有助于识别错误查询的来源等。此逻辑仅适用于连接开始， 如果以后用SET更改application_name，pgbouncer不会再次更改。

默认: 0

#### conffile

显示当前配置文件的位置。改变它将使PgBouncer为下一个 `RELOAD` / `SIGHUP` 使用另一个配置文件。

默认: 来自命令行的文件。

#### service_name

用于win32服务注册。

默认: pgbouncer

#### job_name

[service_name](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#service-name) 的别名。



### 日志设置

#### syslog

切换syslog on/off 对于windows环境，使用eventlog。

默认: 0

#### syslog_ident

以什么名称将日志发送到syslog。

默认: pgbouncer (程序名)

#### syslog_facility

在什么工具上发送日志到syslog。 可能性: `auth`、`authpriv`、`daemon`、`user`、`local0-7`。

默认: daemon

#### log_connections

日志成功登陆。

默认: 1

#### log_disconnections

日志断开与原因。

默认: 1

#### log_pooler_errors

日志错误消息池发送给客户端。

默认: 1

#### stats_period

将聚合统计信息写入日志的时间段。

默认: 60

#### verbose

增加冗长度。"-v"打开命令行。 在命令行上使用"-v -v"等同于在配置中设置 verbose=2 。

默认: 0



### 控制台访问控制

#### admin_users

允许逗号分隔的数据库用户列表在控制台上连接并运行所有命令。 当 [auth_type](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#auth-type) 是 `any` 时忽略，这种情况下允许任何用户作为管理员登陆。

默认: 空

#### stats_users

允许逗号分隔的数据库用户列表在控制台上连接并运行只读查询。 这表示所有除SHOW FDS之外的SHOW命令。

默认: 空



## 连接健全检查，超时

#### server_reset_query

在向其他客户端提供查询之前，发送到服务器的连接发布。在那一刻， 没有任何事务正在进行中，因此它不应该包含 `ABORT` 或 `ROLLBACK` 。

该查询应该清除对数据库会话所做的任何更改， 以便下一个客户端以良好定义的状态获取连接。默认是 `DISCARD ALL` ， 它清除所有内容，但这会使下一个客户端没有预缓存状态。 如果应用程序在一些状态被保留时不会中断，它可以做得更轻， 例如 `DEALLOCATE ALL` 只是删除准备好的语句。

当使用事务池时，不使用 [server_reset_query](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#server-reset-query) ， 因为客户端必须不能使用任何基于会话的功能，因为每个事务都以不同的连接结束， 并且因此获得不同的会话状态。

默认: DISCARD ALL

#### server_reset_query_always

[server_reset_query](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#server-reset-query) 是否应该在所有池模式中运行。当此设置为off（默认）， [server_reset_query](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#server-reset-query) 将只能在会话池模式中运行。事务池模式中的连接不需要重置查询。

这是破坏在事务池pgbouncer上使用会话功能运行应用程序设置的解决办法。 将非确定性破坏变为确定性破坏 - 每次事务之后，客户端总是丢失自己的状态。

默认: 0

#### server_check_delay

保持释放的连接可以立即重新使用的时间，而无需对其进行健全检查查询。 如果0，则总是运行查询。

默认: 30.0

#### server_check_query

简单的什么也不做的查询检查服务器连接是否存在。

如果是空字符串，那么合理检查被禁用。

默认: SELECT 1;

#### server_lifetime

池将尝试关闭连接时间超过此设置的服务器连接。将它设置为0意味着连接只能使用一次， 然后关闭。[seconds]

默认: 3600.0

#### server_idle_timeout

如果一个服务器连接已经闲置超过这么多秒，那么它将被删除。 如果是0，那么禁用超时。 [seconds]

默认: 600.0

#### server_connect_timeout

如果连接和登陆不能在这些时间内完成，那么连接将被关闭。 [seconds]

默认: 15.0

#### server_login_retry

如果登陆失败，因为来自connect()或验证的错误， 池会在重新尝试连接之前等待这么长时间。[seconds]

默认: 15.0

#### client_login_timeout

如果客户端连接但没有在这些时间之内登录，则会断开连接。 主要需要避免死连接阻塞SUSPEND，从而在线重新启动。 [seconds]

默认: 60.0

#### autodb_idle_timeout

如果自动创建的（通过"*"）数据库池已经有这么多秒没有被使用， 就会被释放。负面影响是它们的统计状态也会被忘记。 [seconds]

默认: 3600.0

#### dns_max_ttl

DNS查找可以缓存多长时间。如果一个DNS查询返回几个答案， pgbouncer会在这段时间之间进行robin。实际DNS TTL被忽略。[seconds]

默认: 15.0

#### dns_nxdomain_ttl

错误和NXDOMAIN DNS查找可以缓存多长时间。 [seconds]

默认: 15.0

#### dns_zone_check_period

检查区域序列是否已更改的期间。

PgBouncer可以从主机名（第一个点之后的任何地方）收集dns区域， 然后定期检查区域串行更改。如果注意到更改， 则该区域下的所有主机名将再次被查找。如果任何主机ip更改，则它的连接无效。

仅适用于UDNS后端 (`--with-udns` 来配置)。

默认: 0.0 (禁用)



### TLS 设置

#### client_tls_sslmode

用于从客户端连接的TLS模式。默认是禁用TLS连接的。当启用时， 还必须配置 [client_tls_key_file](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#client-tls-key-file) 和 [client_tls_cert_file](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#client-tls-cert-file) ， 以配置PgBouncer用于接受客户端连接的密钥和证书。

- disable

  纯TCP。如果客户端请求TLS，则会被忽略。默认。

- allow

  如果客户端请求TLS，则使用它。如果没有，则使用纯TCP。 如果客户端使用了客户端证书，则不会验证。

- prefer

  和 `allow` 相同。

- require

  客户端必须使用TLS。如果不使用，则拒绝客户端连接。 如果客户端使用了客户端证书，则不会验证。

- verify-ca

  客户必须使用带有有效客户端证书的TLS。

- verify-full

  和 `verify-ca` 相同。

#### client_tls_key_file

PgBouncer接受客户端连接的私钥。

默认: 没有设置。

#### client_tls_cert_file

私钥证书。客户端可以验证它。

默认: 没有设置。

#### client_tls_ca_file

验证客户端证书的根证书文件。

默认: 未设置。

#### client_tls_protocols

允许哪个TLS协议版本。允许的值：`tlsv1.0`、`tlsv1.1`、`tlsv1.2`。 缩写: `all` (tlsv1.0,tlsv1.1,tlsv1.2)、`secure`(tlsv1.2)、`legacy` (所有)。

默认: `all`

#### client_tls_ciphers

默认: `fast`

#### client_tls_ecdhcurve

用于ECDH密钥交换的椭圆曲线名称。

允许的值: `none` (禁用DH)、`auto` (256位 ECDH)、曲线名称。

默认: `auto`

#### client_tls_dheparams

DHE密钥交换类型。

允许的值: `none` (禁用DH)、`auto` (2048位 DH)、`legacy` (1024位 DH).

默认: `auto`

#### server_tls_sslmode

用于连接到PostgreSQL服务器的TLS模式。 默认禁用TLS连接。

- disable

  纯TCP。TCP不是从服务器请求的结果。默认。

- allow

  FIXME: 如果服务器拒绝，尝试TLS?

- prefer

  始终从PostgreSQL首先请求TLS连接，拒绝时连接将通过普通TCP建立。 不验证服务器证书。

- require

  连接必须通过TLS。如果服务器拒绝，则不会尝试使用纯TCP。 不验证服务器证书。

- verify-ca

  连接必须通过TLS，并且服务器证书必须根据 [server_tls_ca_file](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#server-tls-ca-file) 有效。 不根据证书检查服务器主机名。

- verify-full

  连接必须通过TLS，并且服务器证书必须根据 [server_tls_ca_file](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#server-tls-ca-file) 有效。 服务器主机名必须匹配证书信息。

#### server_tls_ca_file

验证PostgreSQL服务器证书的根证书文件。

默认: 未设置。

#### server_tls_key_file

PgBouncer用于对PostgreSQL服务器进行身份验证的私钥。

默认: 没有设置。

#### server_tls_cert_file

私钥证书。PostgreSQL服务器可以验证它。

默认: 没有设置。

#### server_tls_protocols

允许哪个TLS协议版本。允许的值: `tlsv1.0`、`tlsv1.1`、`tlsv1.2`。 缩写: `all` (tlsv1.0、tlsv1.1、tlsv1.2)、`secure`(tlsv1.2)、`legacy` (所有)。

默认: `all`

#### server_tls_ciphers

默认: `fast`



### 危险的超时

设置以下超时会导致意外错误。

#### query_timeout

运行时间比这长的查询将被取消。只应该用于较小的服务器端statement_timeout， 才能应用于网络问题。 [seconds]

默认: 0.0 (禁用)

#### query_wait_timeout

允许查询等待执行花费的最大时间。如果在此期间查询未分配给服务器， 客户端将断开连接。这用于防止无响应的服务器抓取连接。 [seconds]

当服务器关闭或由于任何原因数据库拒绝连接时它也有帮助。 如果它被禁用，客户端将无限排队。

默认: 120

#### client_idle_timeout

闲置超过这么长时间的客户端连接被关闭。这应该大于客户端连接生命周期设置， 并且仅用于网络问题。 [seconds]

默认: 0.0 (禁用)

#### idle_transaction_timeout

如果客户端在"idle in transaction"状态的时间超长， 将断开连接。 [seconds]

默认: 0.0 (禁用)



### 低层级网络设置

#### pkt_buf

数据包的内部缓冲区大小。影响发送的TCP数据包的大小和一般内存使用情况。 实际的libpq数据包可以大于这个，所以不需要将它设置的很大。

默认: 4096

#### max_packet_size

PgBouncer允许的Postgres数据包的最大大小。 一个数据包是一个查询或一个结果集行。全部结果集可以更大。

默认: 2147483647

#### listen_backlog

listen(2)的Backlog参数。确定队列中保留了多少新的未应答的连接尝试。 当队列已满时，将会删除更新的连接。

默认: 128

#### sbuf_loopcnt

在继续进行之前，需要处理多少次一个连接上的数据。没有这个限制， 一个大的结果集的连接可能会使PgBouncer长时间停止。 一个循环处理一个 [pkt_buf](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#pkt-buf) 数据量。0表示没有限制。

默认: 5

#### suspend_timeout

在SUSPEND或重新启动（-R）期间等待缓冲区刷新的秒数。 如果刷新不成功，连接将被丢弃。

默认: 10

#### tcp_defer_accept

有关此项和其他tcp选项的详细信息，请参阅 `man 7 tcp`。

默认: Linux上是45，其他是 0

#### tcp_socket_buffer

默认: 没有设置

#### tcp_keepalive

使用操作系统默认值打开基本的keepalive。

在Linux上，系统默认是 **tcp_keepidle=7200**、**tcp_keepintvl=75**、 **tcp_keepcnt=9**。其他系统上大概类似。

默认: 1

#### tcp_keepcnt

默认: 没有设置

#### tcp_keepidle

默认: 没有设置

#### tcp_keepintvl

默认: 没有设置



### Section [databases]

包含key=value对，其中key将被看做数据库名， value被看做key=value对的libpq连接字符串风格列表。 实际上没有使用libpq，所以并不是libpq的所有特性都可以使用(service=, .pgpass)。

数据库名可以包含字符 `_0-9A-Za-z` 而不必引用。 包含其他字符的名称需要使用标准SQL识别引号引用：双引号""被看做单引号。

"*"用作备用数据库：如果准确的名称不存在，那么它的值被看做是所请求数据库的连接字符串。 如果这种自动创建的数据库项保持空闲状态的时间超过 [autodb_idle_timeout](https://github.com/postgres-cn/pgbouncer-cn/blob/master/doc/config.rst#autodb-idle-timeout) 参数指定的时间，则会被清理。

### dbname

目标数据库名称。

默认：和客户端数据库名称相同。

### host

要连接的主机名或IP地址。主机名在连接时解析， 结果按照 `dns_max_ttl` 参数缓存。 如果DNS返回多个结果，则以循环方式使用。

默认：没有设置，意味着使用Unix套接字。

### port

默认: 5432

### user, password

如果已经设置了 `user=`，则目标数据库的所有连接将使用指定的用户完成， 意味着这个数据库将只有一个池。

否则PgBouncer尝试使用客户端用户名登录到目标数据库，意味着每个用户有一个池。

### auth_user

如果已经设置 `auth_user`，没有在auth_file中指出的任何用户将使用 `auth_user` 从数据库中的pg_shadow中查询。Auth_user的密码将从 `auth_file` 中获取。

直接访问pg_shadow要求管理员权限。最好是使用非管理员用户调用SECURITY DEFINER功能。

### pool_size

设置该数据库池的最大尺寸。如果没有设置，默认使用default_pool_size。

### connect_query

在建立连接之后但在允许任何客户端使用连接之前执行的查询。 如果查询引发错误，则会被记录，否则会被忽略。

### pool_mode

设置特定于该数据库的池模式。如果没有设置，则使用默认的pool_mode。

### max_db_connections

配置一个数据库范围的最大值（也就是，数据库中的所有池将不会拥有超过此数量的服务器连接）。

### client_encoding

从服务器询问具体的 `client_encoding`。

### datestyle

从服务器询问具体的 `datestyle`。

### timezone

从服务器询问具体的 **timezone**。



### Section [users]

包含key=value对，其中key将被看做用户名， value被看做key=value对的libpq连接字符串风格列表。 实际上没有使用libpq，所以并不是libpq的所有特性都可以使用。

### pool_mode

将池模式设置为用于该用户的所有连接。如果没有设置， 则使用数据库或默认的pool_mode。



### include指令

PgBouncer配置文件可以包含include指令，它们指定另一个配置文件进行读取和处理。 这允许将配置文件分割成物理上分开的部分。include指令如下所示：

> %include filename

如果文件名不是绝对路径，则将其视为与当前工作目录相对。



### 认证文件格式

PgBouncer需要自己的用户数据库。用户从以下格式的文本文件中加载:

```
"username1" "password" ...
"username2" "md5abcdef012342345" ...
```

应至少有2个字段，由双引号括起来。第一个字段是用户名， 第二个字段是纯文本或MD5隐藏密码。PgBouncer忽略行的剩余部分。

此文件格式相当于PostgreSQL 8.x用于验证信息的文本文件， 从而允许PgBouncer直接在数据目录中的PostgreSQL身份验证文件上工作。

自PostgreSQL 9.0以来，不再使用文本文件了。因此，需要生成验证文件。 请参阅 ./etc/mkauth.py 来获取样本脚本，来从 pg_shadow 表生成auth文件。

PostgreSQL MD5隐藏密码格式:

```
"md5" + md5(password + username)
```

所以用户 admin、密码 1234 将有MD5隐藏密码 md545f2603610af569b6155c45067268c6b。



### HBA文件格式

它遵循PostgreSQL pg_hba.conf文件的格式- <http://www.postgresql.org/docs/9.4/static/auth-pg-hba-conf.html>

有以下差异：

- 支持的记录类型: local、host、hostssl、hostnossl。
- 数据库字段: 支持 all、sameuser、@file、多个名字。不支持: replication、samerole、samegroup。
- 用户名字段: 支持 all、@file、多个名字。不支持: +groupname。
- 地址字段: 支持IPv4、IPv6。不支持: DNS 名称、域前缀。
- 认证方法字段: 支持的方法: trust、reject、md5、password、peer、cert。 不支持: gss、sspi、ident、ldap、radius、pam。 用户名映射(map=)参数也不支持。

### 示例

最小配置

```
[databases]
template1 = host=127.0.0.1 dbname=template1 auth_user=someuser

[pgbouncer]
pool_mode = session
listen_port = 6543
listen_addr = 127.0.0.1
auth_type = md5
auth_file = users.txt
logfile = pgbouncer.log
pidfile = pgbouncer.pid
admin_users = someuser
stats_users = stat_collector
```

数据库默认

```ini
[databases]

; unix套接字上的foodb
foodb =

; 重定向bardb到本地主机上的bazdb
bardb = host=127.0.0.1 dbname=bazdb

; 使用单个用户访问目标数据库
forcedb = host=127.0.0.1 port=300 user=baz password=foo client_encoding=UNICODE datestyle=ISO
```

auth_query的安全功能示例

```sql
CREATE OR REPLACE FUNCTION pgbouncer.user_lookup(in i_username text, out uname text, out phash text)
RETURNS record AS $$
BEGIN
    SELECT usename, passwd FROM pg_catalog.pg_shadow
    WHERE usename = i_username INTO uname, phash;
    RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON FUNCTION pgbouncer.user_lookup(text) FROM public, pgbouncer;
GRANT EXECUTE ON FUNCTION pgbouncer.user_lookup(text) TO pgbouncer;
```





## FAQ

### How to use prepared statements with session pooling?

In session pooling mode, the reset query must clean old prepared statements. This can be achieved by `server_reset_query = DISCARD ALL;` or at least to `DEALLOCATE ALL;`

### How to use prepared statements with transaction pooling?

To make prepared statements work in this mode would need PgBouncer to keep track of them internally, which it does not do. So only way to keep using PgBouncer in this mode is to disable prepared statements in the client.

 