# Server Configuration


### 参数配置

* 查看配置的方法：
    * 查看数据库目录下配置文件
    * 系统视图：`SELECT name,setting FROM pg_settings where name ~ 'xxx'';`
    * 系统函数：`current_setting(setting_name [, missing_ok ])`
    * SQL语句：`SHOW <name> | ALL;`
* 修改配置的方法：
    * 系统级修改：修改配置文件、执行`ALTER SYSTEM xxx`、启动时`-c`参数。
    * 数据库级别： `ALTER DATABASE`
    * 会话级别：通过SET或`set_config(setting_name, new_value, false)`，更新pg_settings视图
    * 事务级别：通过SET或`set_config(setting_name, new_value, true)`

* 生效配置的方法：
    * 系统管理函数：`SELECT pg_reload_conf()`
    * `pg_ctl reload`，或发送`SIGHUP`
    * `/etc/init.d/postgresql-x.x reload`(el6)
    * `systemctl reload service.postgresql-9.x` (el7)



### 权限配置

* 在`postgresql.conf`中配置`listen_addresses`为`*`以允许外部连接。
* 在`pg_hba.conf`中配置访问权限。hba是`Host based authentication`
* `pg_hba`的配置项为`<type,database,user,address,method>`构成的五元组，指明了：
  * 什么样的连接方式：`local, host, hostssl, hostnossl`
  * 什么样的数据库：`all, sameuser, samerole, replication, <dbname>`
  * 什么样的用户：`all, <username>, +<groupname>`
  * 什么样的地址：IP地址，CIDR地址，`0.0.0.0/0`表示所有机器。
  * 什么样的行为：`trust, reject, md5, password, ident, peer...`


