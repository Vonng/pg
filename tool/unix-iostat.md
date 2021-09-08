# UNIX命令iostat

汇报IO相关统计信息

## 摘要

```bash
iostat [ -c ] [ -d ] [ -N ] [ -n ] [ -h ] [ -k | -m ] [ -t ] [ -V ] [ -x ] [ -y ] [ -z ] [ -j { ID | LABEL | PATH | UUID | ... } [ device [...] | ALL ] ] [ device [...] | ALL ] [ -p [ device [,...] | ALL ] ] [interval [ count ] ]
```

默认情况下iostat会打印cpu信息和磁盘io信息，使用`-d`参数只显示IO部分，使用`-x`打印更多信息。

样例输出：

```
avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           5.77    0.00    1.31    0.07    0.00   92.85

Device:            tps   Blk_read/s   Blk_wrtn/s   Blk_read   Blk_wrtn
sdb               0.00         0.00         0.00          0          0
sda               0.00         0.00         0.00          0          0
dfa            5020.00     15856.00     35632.00      15856      35632
dm-0              0.00         0.00         0.00          0          0
```

#### 常用选项

* 使用`-d`参数只显示IO部分的信息，而`-c`参数则只显示CPU部分的信息。

* 使用`-x`会打印更详细的扩展信息

* 使用`-k`会使用KB替代块数目作为部分数值的单位，`-m`则使用MB。

  

## 输出说明

不带`-x`选项默认会为每个设备打印5列：

* tps：该设备每秒的传输次数。（多个逻辑请求可能会合并为一个IO请求，传输量未知）
* kB_read/s：每秒从设备读取的数据量；kB_wrtn/s：每秒向设备写入的数据量；kB_read：读取的总数据量；kB_wrtn：写入的总数量数据量；这些单位都为Kilobytes，这是使用`-k`参数的情况。默认则以块数为单位。

带有`-x`选项后，会打印更多信息：

* rrqm/s：每秒这个设备相关的读取请求有多少被Merge了（当系统调用需要读取数据的时候，VFS将请求发到各个FS，如果FS发现不同的读取请求读取的是相同Block的数据，FS会将这个请求合并Merge）；
* wrqm/s：每秒这个设备相关的写入请求有多少被Merge了。
* r/s 与 w/s：（合并后）每秒读取/写入请求次数
* rsec/s 与 wsec/s：每秒读取/写入扇区的数目
* avgrq-sz：请求的平均大小（以扇区计）
* avgqu-sz：平均请求队列长度
* await：每一个IO请求的处理的平均时间（单位是毫秒）
* r_await/w_await：读/写的平均响应时间。
* %util：设备的带宽利用率，IO时间占比。在统计时间内所有处理IO时间。一般该参数是100%表示设备已经接近满负荷运行了。



## 常用方法

收集`/dev/dfa`的IO信息，按kB计算，每秒一次连续10次。

```bash
iostat -dxk /dev/dfa 1 10
```



## 数据来源

其实是从下面几个文件中提取信息的：

```
/proc/stat contains system statistics.

/proc/uptime contains system uptime.

/proc/partitions contains disk statistics (for pre 2.5 kernels that have been patched).

/proc/diskstats contains disks statistics (for post 2.5 kernels).

/sys contains statistics for block devices (post 2.5 kernels).

/proc/self/mountstats contains statistics for network filesystems.

/dev/disk contains persistent device names.
```



