# Unix命令Free

显示系统的内存使用情况

```bash
free -b | -k | -m | -g | -h -s delay  -a -l
```

* 其中`-b | -k | -m | -g | -h `可用于控制显示大小时的单位（字节，KB,MB,GB，自动适配）
* `-s`可以指定轮询周期，`-c`指定轮询次数。



## 输出样例

```bash
$ free -m
             total       used       free     shared    buffers     cached
Mem:        387491     379383       8107      37762        182     348862
-/+ buffers/cache:      30338     357153
Swap:        65535          0      65535
```

* 这里，总内存有378GB，使用370GB，空闲8GB。三者存在`total=used+free`的关系。共享内存占36GB。

* buffers与cache由操作系统分配管理，用于提高I/O性能，其中Buffer是写入缓冲，而Cache是读取缓存。这一行表示，应用程序**已使用**的`buffers/cached`，以及理论上**可使用**的`buffers/cache`。

    ```bash
    -/+ buffers/cache:      30338     357153
    ```

* 最后一行显示了SWAP信息，总的SWAP空间，实际使用的SWAP空间，以及可用的SWAP空间。只要没有用到SWAP（used = 0），就说明内存空间仍然够用。

    

## `/proc/meminfo`

free实际上是通过`cat /proc/meminfo`获取信息的。

详细信息：https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/deployment_guide/s2-proc-meminfo

```bash
$ cat /proc/meminfo
MemTotal:       396791752 kB	# 总可用RAM, 物理内存减去内核二进制与保留位
MemFree:         7447460 kB		# 系统可用物理内存
Buffers:          186540 kB		# 磁盘快的临时存储大小
Cached:         357066928 kB	# 缓存
SwapCached:            0 kB		# 曾移入SWAP又移回内存的大小
Active:         260698732 kB	# 最近使用过，如非强制不会回收的内存。
Inactive:       112228764 kB	# 最近没怎么用过的内存，可能会回收
Active(anon):   53811184 kB		# 活跃的匿名内存(不与具体文件关联)
Inactive(anon):   532504 kB		# 不活跃的匿名内存
Active(file):   206887548 kB	# 活跃的文件缓存
Inactive(file): 111696260 kB	# 不活跃的文件缓存
Unevictable:           0 kB		# 不可淘汰的内存
Mlocked:               0 kB		# 被钉在内存中
SwapTotal:      67108860 kB		# 总SWAP
SwapFree:       67108860 kB		# 可用SWAP
Dirty:            115852 kB		# 被写脏的内存
Writeback:             0 kB		# 回写磁盘的内存
AnonPages:      15676608 kB		# 匿名页面
Mapped:         38698484 kB		# 用于mmap的内存，例如共享库
Shmem:          38668836 kB		# 共享内存
Slab:            6072524 kB		# 内核数据结构使用内存
SReclaimable:    5900704 kB		# 可回收的slab
SUnreclaim:       171820 kB		# 不可回收的slab
KernelStack:       25840 kB		# 内核栈使用的内存
PageTables:      2480532 kB		# 页表大小
NFS_Unstable:          0 kB		# 发送但尚未提交的NFS页面
Bounce:                0 kB		# bounce buffers
WritebackTmp:          0 kB
CommitLimit:    396446012 kB
Committed_AS:   57195364 kB
VmallocTotal:   34359738367 kB
VmallocUsed:     6214036 kB
VmallocChunk:   34353427992 kB
HardwareCorrupted:     0 kB
AnonHugePages:         0 kB
HugePages_Total:       0
HugePages_Free:        0
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:       2048 kB
DirectMap4k:        5120 kB
DirectMap2M:     2021376 kB
DirectMap1G:    400556032 kB
```



其中，free与`/proc/meminfo`中指标的对应关系为：

```
total	= (MemTotal + SwapTotal)

used	= (total - free - buffers - cache)

free	= (MemFree + SwapFree)

shared	= Shmem

buffers	= Buffers

cache	= Cached

buffer/cached = Buffers + Cached
```



## 清理缓存

可以通过以下命令强制清理缓存：

```bash
$ sync # flush fs buffers
$ echo 1 > /proc/sys/vm/drop_caches	# drop page cache
$ echo 2 > /proc/sys/vm/drop_caches	# drop dentries & inode
$ echo 3 > /proc/sys/vm/drop_caches	# drop all
```