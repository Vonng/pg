# [转]NFS的配置

**一、NFS服务简介**

　NFS 就是 **N**etwork **F**ile**S**ystem 的缩写，最早之前是由sun 这家公司所发展出来的。 它最大的功能就是可以透过网络，让不同的机器、不同的操作系统、可以彼此分享个别的档案 (share files)。所以，你也可以简单的将他看做是一个文件服务器 (file server) 呢！这个 NFS 服务器可以让你的 PC 来将网络远程的 NFS 服务器分享的目录，挂载到本地端的机器当中， 在本地端的机器看起来，那个远程主机的目录就好像是自己的一个磁盘分区槽一样 (partition)！使用上面相当的便利！

因为 NFS 支持的功能相当的多，而不同的功能都会使用不同的程序来启动， 每启动一个功能就会启用一些端口来传输数据，因此， NFS 的功能所对应的端口才没有固定住， 而是随机取用一些未被使用的小于 1024 的埠口来作为传输之用。但如此一来又造成客户端想要连上服务器时的困扰， 因为客户端得要知道服务器端的相关埠口才能够联机吧！

此时我们就得需要远程过程调用 (RPC) 的服务啦！RPC 最主要的功能就是在指定每个 NFS 功能所对应的 port number ，并且回报给客户端，让客户端可以连结到正确的埠口上去。 那 RPC 又是如何知道每个 NFS 的埠口呢？这是因为当服务器在启动 NFS 时会随机取用数个埠口，并主动的向 RPC 注册，因此 RPC 可以知道每个埠口对应的 NFS 功能，然后 RPC 又是固定使用 port 111 来监听客户端的需求并回报客户端正确的埠口， 所以当然可以让 NFS 的启动更为轻松愉快了！

所以你要注意，要启动 NFS 之前，RPC 就要先启动了，否则 NFS 会无法向 RPC 注册。 另外，RPC 若重新启动时，原本注册的数据会不见，因此 RPC 重新启动后，它管理的所有服务都需要重新启动来重新向 RPC 注册。

当客户端有 NFS 档案存取需求时，他会如何向服务器端要求数据呢？

1. 客户端会向服务器端的 RPC (port 111) 发出 NFS 档案存取功能的询问要求；
2. 服务器端找到对应的已注册的 NFS daemon 埠口后，会回报给客户端；
3. 客户端了解正确的埠口后，就可以直接与 NFS daemon 来联机。

由于 NFS 的各项功能都必须要向 RPC 来注册，如此一来 RPC 才能了解 NFS 这个服务的各项功能之 port number, PID, NFS 在服务器所监听的 IP 等等，而客户端才能够透过 RPC 的询问找到正确对应的埠口。 也就是说，NFS 必须要有 RPC 存在时才能成功的提供服务，因此我们称 NFS 为 RPC server 的一种。事实上，有很多这样的服务器都是向 RPC 注册的，举例来说，NIS (Network Information Service) 也是 RPC server 的一种呢

**二、所需要的软件及软件结构**

要设定好 NFS 服务器我们必须要有两个软件才行，分别是：

- - RPC 主程序：rpcbind
    就如同刚刚提的到，我们的 NFS 其实可以被视为一个 RPC 服务，而要启动任何一个 RPC 服务之前，我们都需要做好 port 的对应 (mapping) 的工作才行，这个工作其实就是『 rpcbind 』这个服务所负责的！也就是说， 在启动任何一个 RPC 服务之前，我们都需要启动 rpcbind 才行！ (在 CentOS 5.x 以前这个软件称为 portmap，在 CentOS 6.x 之后才称为 rpcbind 的！)
  - NFS 主程序：nfs-utils
    就是提供 rpc.nfsd 及 rpc.mountd 这两个 NFS daemons 与其他相关 documents 与说明文件、执行文件等的软件！这个就是 NFS 服务所需要的主要软件啦！一定要有喔！

 NFS 这个咚咚真的是很简单，上面我们提到的 NFS 软件中，配置文件只有一个，执行档也不多， 记录文件也三三两两而已吶！赶紧先来看一看吧！ ^_^

- 主要配置文件：/etc/exports
  这个档案就是 NFS 的主要配置文件了！不过，系统并没有默认值，所以这个档案『 不一定会存在』，你可能必须要使用 vim 主动的建立起这个档案喔！我们等一下要谈的设定也仅只是这个档案而已吶！
- NFS 文件系统维护指令：/usr/sbin/exportfs
  这个是维护 NFS 分享资源的指令，我们可以利用这个指令重新分享 /etc/exports 变更的目录资源、将 NFS Server 分享的目录卸除或重新分享等等，这个指令是 NFS 系统里面相当重要的一个喔！至于指令的用法我们在底下会介绍。
- 分享资源的登录档：/var/lib/nfs/*tab
  在 NFS 服务器的登录文件都放置到 /var/lib/nfs/ 目录里面，在该目录下有两个比较重要的登录档， 一个是 etab ，主要记录了 NFS 所分享出来的目录的完整权限设定值；另一个 xtab 则记录曾经链接到此 NFS 服务器的相关客户端数据。
- 客户端查询服务器分享资源的指令：/usr/sbin/showmount
  这是另一个重要的 NFS 指令。exportfs 是用在 NFS Server 端，而 showmount 则主要用在 Client 端。这个 showmount 可以用来察看 NFS 分享出来的目录资源喔！

就说不难吧！主要就是这几个啰！

 

**三、系统环境**

系统CentOS6.8

IP 192.168.2.203

**四、安装NFS服务**

1、查看系统是否已安装NFS

```bash
rpm -qa | grep nfs
rpm -qa | grep rpcbind
```

2、安装NFS

```bash
[root@bogon ~]# yum -y install nfs-utils rpcbind
已加载插件：fastestmirror
设置安装进程
Loading mirror speeds from cached hostfile
... ...
已安装:
  nfs-utils.x86_64 1:1.2.3-70.el6_8.2                           rpcbind.x86_64 0:0.2.0-12.el6                          

作为依赖被安装:
  keyutils.x86_64 0:1.4-5.el6         libevent.x86_64 0:1.4.13-4.el6         libgssglue.x86_64 0:0.1-11.el6           
  libtirpc.x86_64 0:0.2.1-11.el6_8    nfs-utils-lib.x86_64 0:1.1.5-11.el6    python-argparse.noarch 0:1.2.1-2.1.el6   

完毕！
```

**五、服务端配置**

 

在NFS服务端上创建共享目录/data/lys并设置权限

```
[root@bogon ~]# mkdir -p /data/lys
[root@bogon ~]# ll /data/
总用量 4
drwxr-xr-x. 2 root root 4096 10月 21 18:10 lys
[root@bogon ~]# chmod 666 /data/lys/
```

编辑export文件

```
[root@bogon ~]# vim /etc/exports 

/data/lys 192.168.2.0/24(rw,no_root_squash,no_all_squash,sync)
```

```
常见的参数则有：

参数值    内容说明
rw　　ro    该目录分享的权限是可擦写 (read-write) 或只读 (read-only)，但最终能不能读写，还是与文件系统的 rwx 及身份有关。

sync　　async    sync 代表数据会同步写入到内存与硬盘中，async 则代表数据会先暂存于内存当中，而非直接写入硬盘！

no_root_squash　　root_squash    客户端使用 NFS 文件系统的账号若为 root 时，系统该如何判断这个账号的身份？预设的情况下，客户端 root 的身份会由 root_squash 的设定压缩成 nfsnobody， 如此对服务器的系统会较有保障。但如果你想要开放客户端使用 root 身份来操作服务器的文件系统，那么这里就得要开 no_root_squash 才行！

all_squash    不论登入 NFS 的使用者身份为何， 他的身份都会被压缩成为匿名用户，通常也就是 nobody(nfsnobody) 啦！

anonuid　　anongid    anon 意指 anonymous (匿名者) 前面关于 *_squash 提到的匿名用户的 UID 设定值，通常为 nobody(nfsnobody)，但是你可以自行设定这个 UID 的值！当然，这个 UID 必需要存在于你的 /etc/passwd 当中！ anonuid 指的是 UID 而 anongid 则是群组的 GID 啰。
```

配置生效

```
[root@bogon lys]# exportfs -r
```

启动rpcbind、nfs服务

![复制代码](https://common.cnblogs.com/images/copycode.gif)

```
[root@bogon lys]# service rpcbind start
正在启动 rpcbind：                                         [确定]
[root@bogon lys]# service nfs start
启动 NFS 服务：                                            [确定]
启动 NFS mountd：                                          [确定]
启动 NFS 守护进程：                                        [确定]
正在启动 RPC idmapd：                                      [确定]
```

![复制代码](https://common.cnblogs.com/images/copycode.gif)

查看 RPC 服务的注册状况

![复制代码](https://common.cnblogs.com/images/copycode.gif)

```
[root@bogon lys]# rpcinfo -p localhost
   program vers proto   port  service
    100000    4   tcp    111  portmapper
    100000    3   tcp    111  portmapper
    100000    2   tcp    111  portmapper
    100000    4   udp    111  portmapper
    100000    3   udp    111  portmapper
    100000    2   udp    111  portmapper
    100005    1   udp  49979  mountd
    100005    1   tcp  58393  mountd
    100005    2   udp  45516  mountd
    100005    2   tcp  37792  mountd
    100005    3   udp  32997  mountd
    100005    3   tcp  39937  mountd
    100003    2   tcp   2049  nfs
    100003    3   tcp   2049  nfs
    100003    4   tcp   2049  nfs
    100227    2   tcp   2049  nfs_acl
    100227    3   tcp   2049  nfs_acl
    100003    2   udp   2049  nfs
    100003    3   udp   2049  nfs
    100003    4   udp   2049  nfs
    100227    2   udp   2049  nfs_acl
    100227    3   udp   2049  nfs_acl
    100021    1   udp  51112  nlockmgr
    100021    3   udp  51112  nlockmgr
    100021    4   udp  51112  nlockmgr
    100021    1   tcp  43271  nlockmgr
    100021    3   tcp  43271  nlockmgr
    100021    4   tcp  43271  nlockmgr
```

![复制代码](https://common.cnblogs.com/images/copycode.gif)

```
选项与参数：
-p ：针对某 IP (未写则预设为本机) 显示出所有的 port 与 porgram 的信息；
-t ：针对某主机的某支程序检查其 TCP 封包所在的软件版本；
-u ：针对某主机的某支程序检查其 UDP 封包所在的软件版本；
```

在你的 NFS 服务器设定妥当之后，我们可以在 server 端先自我测试一下是否可以联机喔！就是利用 showmount 这个指令来查阅！

```
[root@bogon lys]# showmount -e localhost
Export list for localhost:
/data/lys 192.168.2.0/24
选项与参数：
-a ：显示目前主机与客户端的 NFS 联机分享的状态；
-e ：显示某部主机的 /etc/exports 所分享的目录数据。
```

**六、客户端配置**

安装nfs-utils客户端

![复制代码](https://common.cnblogs.com/images/copycode.gif)

```
[root@bogon ~]# yum -y install nfs-utils
已安装:
  nfs-utils.x86_64 1:1.2.3-70.el6_8.2                                                                                  

作为依赖被安装:
  keyutils.x86_64 0:1.4-5.el6         libevent.x86_64 0:1.4.13-4.el6         libgssglue.x86_64 0:0.1-11.el6           
  libtirpc.x86_64 0:0.2.1-11.el6_8    nfs-utils-lib.x86_64 0:1.1.5-11.el6    python-argparse.noarch 0:1.2.1-2.1.el6   
  rpcbind.x86_64 0:0.2.0-12.el6      

完毕！
```

![复制代码](https://common.cnblogs.com/images/copycode.gif)

 

创建挂载目录

```
[root@bogon ~]# mkdir /lys
```

查看服务器抛出的共享目录信息

```
[root@bogon ~]# showmount -e 192.168.2.203
Export list for 192.168.2.203:
/data/lys 192.168.2.0/24
```

为了提高NFS的稳定性，使用TCP协议挂载，NFS默认用UDP协议

```
[root@bogon ~]# mount -t nfs 192.168.2.203:/data/lys /lys -o proto=tcp -o nolock
```

**七、测试结果**

查看挂载结果

![复制代码](https://common.cnblogs.com/images/copycode.gif)

```
[root@bogon ~]# df -h
Filesystem            Size  Used Avail Use% Mounted on
/dev/mapper/VolGroup-lv_root
                       18G  1.1G   16G   7% /
tmpfs                 112M     0  112M   0% /dev/shm
/dev/sda1             477M   54M  398M  12% /boot
192.168.2.203:/data/lys
                       18G  1.1G   16G   7% /lys
```

![复制代码](https://common.cnblogs.com/images/copycode.gif)

服务端

```
[root@bogon lys]# echo "test" > test.txt
```

客户端

```
[root@bogon ~]# cat /lys/test.txt 
test
[root@bogon ~]# echo "204" >> /lys/test.txt 
```

服务端

```
[root@bogon lys]# cat /data/lys/test.txt 
test
204
```

**卸载已挂在的NFS**

![复制代码](https://common.cnblogs.com/images/copycode.gif)

```
[root@bogon ~]# umount /lys/
[root@bogon ~]# df -h
Filesystem            Size  Used Avail Use% Mounted on
/dev/mapper/VolGroup-lv_root
                       18G  1.1G   16G   7% /
tmpfs                 112M     0  112M   0% /dev/shm
/dev/sda1             477M   54M  398M  12% /boot
```

![复制代码](https://common.cnblogs.com/images/copycode.gif)

 

到此结束

 

**补充部分：**

为了方便配置防火墙，需要固定nfs服务端口

[NFS](http://www.haiyun.me/tag/nfs)启动时会随机启动多个端口并向RPC注册，这样如果使用[iptables](http://www.haiyun.me/tag/iptables)对NFS端口进行限制就会有点麻烦，可以更改配置文件固定NFS服务相关端口。

![复制代码](https://common.cnblogs.com/images/copycode.gif)

```
[root@bogon lys]# rpcinfo -p localhost
   program vers proto   port  service
    100000    4   tcp    111  portmapper
    100000    3   tcp    111  portmapper
    100000    2   tcp    111  portmapper
    100000    4   udp    111  portmapper
    100000    3   udp    111  portmapper
    100000    2   udp    111  portmapper
    100005    1   udp  49979  mountd
    100005    1   tcp  58393  mountd
    100005    2   udp  45516  mountd
    100005    2   tcp  37792  mountd
    100005    3   udp  32997  mountd
    100005    3   tcp  39937  mountd
    100003    2   tcp   2049  nfs
    100003    3   tcp   2049  nfs
    100003    4   tcp   2049  nfs
    100227    2   tcp   2049  nfs_acl
    100227    3   tcp   2049  nfs_acl
    100003    2   udp   2049  nfs
    100003    3   udp   2049  nfs
    100003    4   udp   2049  nfs
    100227    2   udp   2049  nfs_acl
    100227    3   udp   2049  nfs_acl
    100021    1   udp  51112  nlockmgr
    100021    3   udp  51112  nlockmgr
    100021    4   udp  51112  nlockmgr
    100021    1   tcp  43271  nlockmgr
    100021    3   tcp  43271  nlockmgr
    100021    4   tcp  43271  nlockmgr
```



分配端口，编辑配置文件：

```
[root@bogon lys]# vim /etc/sysconfig/nfs
```

添加：

```
RQUOTAD_PORT=30001
LOCKD_TCPPORT=30002
LOCKD_UDPPORT=30002
MOUNTD_PORT=30003
STATD_PORT=30004                   
```

重启



```
[root@bogon lys]# service nfs restart
关闭 NFS 守护进程：                                        [确定]
关闭 NFS mountd：                                          [确定]
关闭 NFS 服务：                                            [确定]
Shutting down RPC idmapd:                                  [确定]
启动 NFS 服务：                                            [确定]
启动 NFS mountd：                                          [确定]
启动 NFS 守护进程：                                        [确定]
正在启动 RPC idmapd：                                      [确定]
```

查看结果



```
[root@bogon lys]# rpcinfo -p localhost
   program vers proto   port  service
    100000    4   tcp    111  portmapper
    100000    3   tcp    111  portmapper
    100000    2   tcp    111  portmapper
    100000    4   udp    111  portmapper
    100000    3   udp    111  portmapper
    100000    2   udp    111  portmapper
    100005    1   udp  30003  mountd
    100005    1   tcp  30003  mountd
    100005    2   udp  30003  mountd
    100005    2   tcp  30003  mountd
    100005    3   udp  30003  mountd
    100005    3   tcp  30003  mountd
    100003    2   tcp   2049  nfs
    100003    3   tcp   2049  nfs
    100003    4   tcp   2049  nfs
    100227    2   tcp   2049  nfs_acl
    100227    3   tcp   2049  nfs_acl
    100003    2   udp   2049  nfs
    100003    3   udp   2049  nfs
    100003    4   udp   2049  nfs
    100227    2   udp   2049  nfs_acl
    100227    3   udp   2049  nfs_acl
    100021    1   udp  30002  nlockmgr
    100021    3   udp  30002  nlockmgr
    100021    4   udp  30002  nlockmgr
    100021    1   tcp  30002  nlockmgr
    100021    3   tcp  30002  nlockmgr
    100021    4   tcp  30002  nlockmgr
```

![复制代码](https://common.cnblogs.com/images/copycode.gif)