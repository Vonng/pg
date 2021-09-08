

# Pgbouncer的使用

Pgbouncer是一个轻量级的数据库连接池。

### 概要

```bash
pgbouncer [-d][-R][-v][-u user] <pgbouncer.ini>
pgbouncer -V|-h
```

### 描述

**pgbouncer** 是一个PostgreSQL连接池。 任何目标应用程序都可以连接到 **pgbouncer**， 就像它是PostgreSQL服务器一样，**pgbouncer** 将创建到实际服务器的连接， 或者它将重用其中一个现有的连接。

**pgbouncer** 的目的是为了降低打开PostgreSQL新连接时的性能影响。

为了不影响连接池的事务语义，**pgbouncer** 在切换连接时，支持多种类型的池化：

- **会话连接池（Session pooling）**

  最礼貌的方法。当客户端连接时，将在客户端保持连接的整个持续时间内分配一个服务器连接。 当客户端断开连接时，服务器连接将放回到连接池中。这是默认的方法。

- **事务连接池（Transaction pooling）**

  服务器连接只有在一个事务的期间内才指派给客户端。 当PgBouncer发觉事务结束的时候，服务器连接将会放回连接池中。

- **语句连接池（Statement pooling）**

  最激进的模式。在查询完成后，服务器连接将立即被放回连接池中。 该模式中不允许多语句事务，因为它们会中断。

**pgbouncer** 的管理界面由连接到特殊'虚拟'数据库 **pgbouncer** 时可用的一些新的 `SHOW` 命令组成。

### 上手

基本设置和用法如下。

1. 创建一个pgbouncer.ini文件。**pgbouncer(5)** 的详细信息。简单例子

   ```ini
   [databases]
   template1 = host=127.0.0.1 port=5432 dbname=template1
   
   [pgbouncer]
   listen_port = 6543
   listen_addr = 127.0.0.1
   auth_type = md5
   auth_file = users.txt
   logfile = pgbouncer.log
   pidfile = pgbouncer.pid
   admin_users = someuser
   ```

2. 创建包含许可用户的 `users.txt` 文件

   ```bash
   "someuser" "same_password_as_in_server"
   ```

3. 加载 **pgbouncer**

   ```bash
   $ pgbouncer -d pgbouncer.ini
   ```

4. 你的应用程序（或 **客户端psql**）已经连接到 **pgbouncer** ，而不是直接连接到PostgreSQL服务器了吗：

   ```bash
    psql -p 6543 -U someuser template1
   ```

5. 通过连接到特殊管理数据库 **pgbouncer** 来管理 **pgbouncer**， 发出 `show help;` 开始

   ```bash
   $ psql -p 6543 -U someuser pgbouncer
   pgbouncer=# show help;
   NOTICE:  Console usage
   DETAIL:
     SHOW [HELP|CONFIG|DATABASES|FDS|POOLS|CLIENTS|SERVERS|SOCKETS|LISTS|VERSION]
     SET key = arg
     RELOAD
     PAUSE
     SUSPEND
     RESUME
     SHUTDOWN
   ```

6. 如果你修改了pgbouncer.ini文件，可以用下列命令重新加载：

   ```bash
   pgbouncer=# RELOAD;
   ```

### 命令行开关

| -d             | 在后台运行。没有它，进程将在前台运行。 注意：在Windows上不起作用，**pgbouncer** 需要作为服务运行。 |
| -------------- | ------------------------------------------------------------ |
| -R             | 进行在线重启。这意味着连接到正在运行的进程，从中加载打开的套接字， 然后使用它们。如果没有活动进程，请正常启动。 注意：只有在操作系统支持Unix套接字且 `unix_socket_dir` 在配置中未被禁用时才可用。在Windows机器上不起作用。 不使用TLS连接，它们被删除了。 |
| -u user        | 启动时切换到给定的用户。                                     |
| -v             | 增加详细度。可多次使用。                                     |
| -q             | 安静 - 不要登出到stdout。请注意， 这不影响日志详细程度，只有该stdout不被使用。用于init.d脚本。 |
| -V             | 显示版本。                                                   |
| -h             | 显示简短的帮助。                                             |
| --regservice   | Win32：注册pgbouncer作为Windows服务运行。 **service_name** 配置参数值用作要注册的名称。 |
| --unregservice | Win32: 注销Windows服务。                                     |

### 管理控制台

通过正常连接到数据库 **pgbouncer** 可以使用控制台

```
$ psql -p 6543 pgbouncer
```

只有在配置参数 **admin_users** 或 **stats_users** 中列出的用户才允许登录到控制台。 （除了 auth_mode=any 时，任何用户都可以作为stats_user登录。）

另外，如果通过Unix套接字登录，并且客户端具有与运行进程相同的Unix用户uid， 允许用户名 **pgbouncer** 不使用密码登录。



### SHOW命令

#### `SHOW STATS;`

显示统计信息。

| 字段                | 说明                       |
| ------------------- | -------------------------- |
| `database`          | 统计信息按数据库组织       |
| `total_xact_count`  | SQL事务总数                |
| `total_query_count` | SQL查询总数                |
| `total_received`    | 收到的网络流量(字节)       |
| `total_sent`        | 发送的网络流量(字节)       |
| `total_xact_time`   | 在事务中的总时长           |
| `total_query_time`  | 在查询中的总时长           |
| `total_wait_time`   | 在等待中的总时长           |
| `avg_xact_count`    | （当前）平均事务数         |
| `avg_query_count`   | （当前）平均查询数         |
| `avg_recv`          | （当前）平均每秒收到字节数 |
| `avg_sent`          | （当前）平均每秒发送字节数 |
| `avg_xact_time`     | 平均事务时长（以毫秒计）   |
| `avg_query_time`    | 平均查询时长（以毫秒计）   |
| `avg_wait_time`     | 平均等待时长（以毫秒计）   |

两个变体：`SHOW STATS_TOTALS`与`SHOW STATS_AVERAGES`，分别显示整体与平均的统计。

TOTAL实际上是Counter，而AVG通常是Guage。监控时建议采集TOTAL，查看时建议查看AVG。



#### `SHOW SERVERS`

| 字段           | 说明                                                         |
| -------------- | ------------------------------------------------------------ |
| `type`         | Server的类型固定为S                                          |
| `user`         | Pgbouncer用于连接数据库的用户名                              |
| `state`        | pgbouncer服务器连接的状态，**active**、**used** 或 **idle** 之一。 |
| `addr`         | PostgreSQL server服务器的IP地址。                            |
| `port`         | PostgreSQL服务器的端口。                                     |
| `local_addr`   | 本机连接启动的地址。                                         |
| `local_port`   | 本机上的连接启动端口。                                       |
| `connect_time` | 建立连接的时间。                                             |
| `request_time` | 最后一个请求发出的时间。                                     |
| `ptr`          | 该连接内部对象的地址，用作唯一标识符                         |
| `link`         | 服务器配对的客户端连接地址。                                 |
| `remote_pid`   | 后端服务器进程的pid。如果通过unix套接字进行连接， 并且OS支持获取进程ID信息，则为OS pid。 否则它将从服务器发送的取消数据包中提取出来，如果服务器是Postgres， 则应该是PID，但是如果服务器是另一个PgBouncer，则它是一个随机数。 |



#### `SHOW CLIENTS`

| 字段           | 说明                                                         |
| -------------- | ------------------------------------------------------------ |
| `type`         | Client的类型固定为C                                          |
| `user`         | 客户端用于连接的用户                                         |
| `state`        | pgbouncer客户端连接的状态，**active**、**used** 、**waiting**或 **idle** 之一。 |
| `addr`         | 客户端的IP地址。                                             |
| `port`         | 客户端的端口                                                 |
| `local_addr`   | 本机地址                                                     |
| `local_port`   | 本机端口                                                     |
| `connect_time` | 建立连接的时间。                                             |
| `request_time` | 最后一个请求发出的时间。                                     |
| `ptr`          | 该连接内部对象的地址，用作唯一标识符                         |
| `link`         | 配对的服务器端连接地址。                                     |
| `remote_pid`   | 如果通过unix套接字进行连接， 并且OS支持获取进程ID信息，则为OS pid。 |





#### `SHOW CLIENTS`

| 字段           | 说明                                                         |
| -------------- | ------------------------------------------------------------ |
| `type`         | Client的类型固定为C                                          |
| `user`         | 客户端用于连接的用户                                         |
| `state`        | pgbouncer客户端连接的状态，**active**、**used** 、**waiting**或 **idle** 之一。 |
| `addr`         | 客户端的IP地址。                                             |
| `port`         | 客户端的端口                                                 |
| `local_addr`   | 本机地址                                                     |
| `local_port`   | 本机端口                                                     |
| `connect_time` | 建立连接的时间。                                             |
| `request_time` | 最后一个请求发出的时间。                                     |
| `ptr`          | 该连接内部对象的地址，用作唯一标识符                         |
| `link`         | 配对的服务器端连接地址。                                     |
| `remote_pid`   | 如果通过unix套接字进行连接， 并且OS支持获取进程ID信息，则为OS pid。 |





#### SHOW POOLS;

为每对(database, user)创建一个新的连接池选项。

- database

  数据库名称。

- user

  用户名。

- cl_active

  链接到服务器连接并可以处理查询的客户端连接。

- cl_waiting

  已发送查询但尚未获得服务器连接的客户端连接。

- sv_active

  链接到客户端的服务器连接。

- sv_idle

  未使用且可立即用于客户机查询的服务器连接。

- sv_used

  已经闲置超过 server_check_delay 时长的服务器连接， 所以在它可以使用之前，需要运行 server_check_query。

- sv_tested

  当前正在运行 server_reset_query 或 server_check_query 的服务器连接。

- sv_login

  当前正在登录过程中的服务器连接。

- maxwait

  队列中第一个（最老的）客户端已经等待了多长时间，以秒计。 如果它开始增加，那么服务器当前的连接池处理请求的速度不够快。 原因可能是服务器负载过重或 **pool_size** 设置过小。

- pool_mode

  正在使用的连接池模式。

#### SHOW LISTS;

在列（不是行）中显示以下内部信息：

- databases

  数据库计数。

- users

  用户计数。

- pools

  连接池计数。

- free_clients

  空闲客户端计数。

- used_clients

  使用了的客户端计数。

- login_clients

  在 **login** 状态中的客户端计数。

- free_servers

  空闲服务器计数。

- used_servers

  使用了的服务器计数。

#### SHOW USERS;

- name

  用户名

- pool_mode

  用户重写的pool_mode，如果使用默认值，则返回NULL。

#### SHOW DATABASES;

- name

  配置的数据库项的名称。

- host

  pgbouncer连接到的主机。

- port

  pgbouncer连接到的端口。

- database

  pgbouncer连接到的实际数据库名称。

- force_user

  当用户是连接字符串的一部分时，pgbouncer和PostgreSQL 之间的连接被强制给给定的用户，不管客户端用户是谁。

- pool_size

  服务器连接的最大数量。

- pool_mode

  数据库的重写pool_mode，如果使用默认值则返回NULL。

#### SHOW FDS;

内部命令 - 显示与附带的内部状态一起使用的fds列表。

当连接的用户使用用户名"pgbouncer"时， 通过Unix套接字连接并具有与运行过程相同的UID，实际的fds通过连接传递。 该机制用于进行在线重启。 注意：这不适用于Windows机器。

此命令还会阻止内部事件循环，因此在使用PgBouncer时不应该使用它。

- fd

  文件描述符数值。

- task

  **pooler**、**client** 或 **server** 之一。

- user

  使用该FD的连接的用户。

- database

  使用该FD的连接的数据库。

- addr

  使用FD的连接的IP地址，如果使用unix套接字则是 **unix**。

- port

  使用FD的连接的端口。

- cancel

  取消此连接的键。

- link

  对应服务器/客户端的fd。如果空闲则为NULL。

#### SHOW CONFIG;

显示当前的配置设置，一行一个，带有下列字段：

- key

  配置变量名

- value

  配置值

- changeable

  **yes** 或者 **no**，显示运行时变量是否可更改。 如果是 **no**，则该变量只能在启动时改变。

#### SHOW DNS_HOSTS;

显示DNS缓存中的主机名。

- hostname

  主机名。

- ttl

  直到下一次查找经过了多少秒。

- addrs

  地址的逗号分隔的列表。

#### SHOW DNS_ZONES

显示缓存中的DNS区域。

- zonename

  区域名称。

- serial

  当前序列号。

- count

  属于此区域的主机名。

### 过程控制命令

#### `PAUSE [db];`

PgBouncer尝试断开所有服务器的连接，首先等待所有查询完成。 所有查询完成之前，命令不会返回。在数据库重新启动时使用。如果提供了数据库名称，那么只有该数据库将被暂停。

#### `DISABLE db;`

拒绝给定数据库上的所有新客户端连接。

#### `ENABLE db;`

在上一个的 **DISABLE** 命令之后允许新的客户端连接。

#### `KILL db;`

立即删除给定数据库上的所有客户端和服务器连接。

#### `SUSPEND;`

所有套接字缓冲区被刷新，PgBouncer停止监听它们上的数据。 在所有缓冲区为空之前，命令不会返回。在PgBouncer在线重新启动时使用。

#### `RESUME [db];`

从之前的 **PAUSE** 或 **SUSPEND** 命令中恢复工作。

#### `SHUTDOWN;`

PgBouncer进程将会退出。

#### `RELOAD;`

PgBouncer进程将重新加载它的配置文件并更新可改变的设置。

### 信号

- SIGHUP

  重新加载配置。与在控制台上发出命令 **RELOAD;** 相同。

- SIGINT

  安全关闭。与在控制台上发出 **PAUSE;** 和 **SHUTDOWN;** 相同。

- SIGTERM

  立即关闭。与在控制台上发出 **SHUTDOWN;** 相同。

### Libevent设置

来自libevent的文档:

```
可以通过分别设置环境变量EVENT_NOEPOLL、EVENT_NOKQUEUE、
VENT_NODEVPOLL、EVENT_NOPOLL或EVENT_NOSELECT来禁用对
epoll、kqueue、devpoll、poll或select的支持。

通过设置环境变量EVENT_SHOW_METHOD，libevent显示它使用的内核通知方法。 
```

