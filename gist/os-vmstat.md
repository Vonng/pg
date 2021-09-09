# UNIX命令vmstat

汇报虚拟内存统计信息

## 摘要

```bash
vmstat [-a] [-n] [-t] [-S unit] [delay [ count]]
vmstat [-s] [-n] [-S unit]
vmstat [-m] [-n] [delay [ count]]
vmstat [-d] [-n] [delay [ count]]
vmstat [-p disk partition] [-n] [delay [ count]]
vmstat [-f]
vmstat [-V]
```

最常用的用法是：

```bash
vmstat <delay> <count>
```

例如`vmstat 1 10`就是以1秒为间隔，采样10次内存统计信息。



## 样例输出

```bash
$ vmstat 1 4 -S M
procs -----------memory---------- ---swap-- -----io---- --system-- -----cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 3  0      0   7288    170 344210    0    0   158   158    0    0  2  1 97  0  0
 5  0      0   7259    170 344228    0    0  7680 13292 38783 36814  6  1 93  0  0
 3  0      0   7247    170 344246    0    0  8720 21024 40584 39686  6  1 93  0  0
 1  0      0   7233    170 344255    0    0  6800 24404 39461 36984  6  1 93  0  0
```

```
Procs
    r: 等待运行的进程数目
    b: 处于不可中断睡眠状态的进程数(Block)
Memory
    swpd: 使用的交换区大小，大于0则说明内存过小
    free: 空闲内存
    buff: 缓冲区内存
    cache: 页面缓存
    inact: 不活跃内存 (-a 选项)
    active: 活跃内存 (-a 选项)
Swap
    si: 每秒从磁盘中换入的内存 (/s).
    so: 每秒从换出到磁盘的内存 (/s).
IO
    bi: 从块设备每秒收到的块数目 (blocks/s).
    bo: 向块设备每秒发送的快数目 (blocks/s).
System
    in: 每秒中断数，包括时钟中断
    cs: 每秒上下文切换数目
CPU
    总CPU时间的百分比
    us: 用户态时间 (包括nice的时间)
    sy: 内核态时间
    id: 空闲时间（在2.5.41前包括等待IO的时间）
    wa: 等待IO的时间（在2.5.41前包括在id里）
    st: 空闲时间（在2.6.11前没有）
```



## 数据来源

其实是从下面三个文件中提取信息的：

```
/proc/meminfo
/proc/stat
/proc/*/stat
```





## 输出

