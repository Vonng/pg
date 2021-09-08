# UNIX命令TOP

显示Linux任务

## 交互式操作

- 按下空格或回车强制刷新
- 使用`h`打开帮助
- 使用`l,t,m`收起摘要部分。
- 使用`d`修改刷新周期
- 使用`z`开启颜色高亮
- 使用`u`列出指定用户的进程
- 使用`<>`来改变排序列
- 使用`P`按CPU使用率排序
- 使用`M`按驻留内存大小排序
- 使用`T`按累计时间排序



## 1. 批处理模式

`-b`参数可以用于批处理模式，配合`-n`参数指定批次数目。同时`-d`参数可以指定批次的间隔时间

例如获取机器当前的负载使用情况，以0.1秒为间隔获取三次，获取最后一次的CPU摘要。

```bash
$ top -bn3 -d0.1 | grep Cpu | tail -n1
Cpu(s):  4.1%us,  1.0%sy,  0.0%ni, 94.8%id,  0.0%wa,  0.0%hi,  0.1%si,  0.0%st
```



## 2. 输出格式

`top`的输出分为两部分，上面几行是系统摘要，下面是进程列表，两者通过一个空行分割。下面是`top`命令的输出样例：

```
top - 12:11:01 up 401 days, 19:17,  2 users,  load average: 1.12, 1.26, 1.40
Tasks: 1178 total,   3 running, 1175 sleeping,   0 stopped,   0 zombie
Cpu(s):  5.4%us,  1.7%sy,  0.0%ni, 92.5%id,  0.1%wa,  0.0%hi,  0.4%si,  0.0%st
Mem:  396791756k total, 389547376k used,  7244380k free,   263828k buffers
Swap: 67108860k total,        0k used, 67108860k free, 366252364k cached

   PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND
  5094 postgres  20   0 37.2g 829m 795m S 14.2  0.2   0:04.11 postmaster
  5093 postgres  20   0 37.2g 926m 891m S 13.2  0.2   0:04.96 postmaster
165359 postgres  20   0 37.2g 4.0g 4.0g S 12.6  1.1   0:44.93 postmaster
 93426 postgres  20   0 37.2g 6.8g 6.7g S 12.2  1.8   1:32.94 postmaster
  5092 postgres  20   0 37.2g 856m 818m R 11.2  0.2   0:04.21 postmaster
 67634 root      20   0  569m 520m  328 S 11.2  0.1 140720:15 haproxy
 93429 postgres  20   0 37.2g 8.7g 8.7g S 11.2  2.3   2:12.23 postmaster
129653 postgres  20   0 37.2g 6.8g 6.7g S 11.2  1.8   1:27.92 postmaster
```

### 2.1摘要部分

摘要默认由三个部分，共计五行组成：

* 系统运行时间，平均负载，共计一行（`l`切换内容）

* 任务、CPU状态，各一行（`t`切换内容）
* 内存使用，Swap使用，各一行（`m`切换内容）

#### 2.1.1 系统运行时间和平均负载

```
top - 12:11:01 up 401 days, 19:17,  2 users,  load average: 1.12, 1.26, 1.40
```

  - 当前时间：`12:11:01`
  - 系统已运行的时间：`up 401 days`
  - 当前登录用户的数量：`2 users`
  - 相应最近5、10和15分钟内的平均负载：`load average: 1.12, 1.26, 1.40`。

> #### Load
>
> Load表示操作系统的负载，即，当前运行的任务数目。而load average表示一段时间内平均的load，也就是过去一段时间内平均有多少个任务在运行。注意Load与CPU利用率并不是一回事。

#### 2.1.2 任务

```
Tasks: 1178 total,   3 running, 1175 sleeping,   0 stopped,   0 zombie
```

第二行显示的是任务或者进程的总结。进程可以处于不同的状态。这里显示了全部进程的数量。除此之外，还有正在运行、睡眠、停止、僵尸进程的数量（僵尸是一种进程的状态）。

#### 2.1.3 CPU状态

```bash
Cpu(s):  5.4%us,  1.7%sy,  0.0%ni, 92.5%id,  0.1%wa,  0.0%hi,  0.4%si,  0.0%st
```

下一行显示的是CPU状态。 这里显示了不同模式下的所占CPU时间的百分比。这些不同的CPU时间表示:

- us, user： 运行(未调整优先级的) 用户进程的CPU时间
- sy，system: 运行内核进程的CPU时间
- ni，niced：运行已调整优先级的用户进程的CPU时间
- id，idle：空闲CPU时间
- wa，IO wait: 用于等待IO完成的CPU时间
- hi：处理硬件中断的CPU时间
- si: 处理软件中断的CPU时间
- st：虚拟机被hypervisor偷去的CPU时间（如果当前处于一个虚拟机内，宿主机消耗的CPU处理时间）。

#### 2.1.4 内存使用

```
Mem:  396791756k total, 389547376k used,  7244380k free,   263828k buffers
Swap: 67108860k total,        0k used, 67108860k free, 366252364k cached
```

* 内存部分：全部可用内存、已使用内存、空闲内存、缓冲内存。
* SWAP部分：全部、已使用、空闲和缓冲交换空间。



### 2.2 进程部分

进程部分默认会显示一些关键信息

```
   PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND
  5094 postgres  20   0 37.2g 829m 795m S 14.2  0.2   0:04.11 postmaster
  5093 postgres  20   0 37.2g 926m 891m S 13.2  0.2   0:04.96 postmaster
165359 postgres  20   0 37.2g 4.0g 4.0g S 12.6  1.1   0:44.93 postmaster
 93426 postgres  20   0 37.2g 6.8g 6.7g S 12.2  1.8   1:32.94 postmaster
  5092 postgres  20   0 37.2g 856m 818m R 11.2  0.2   0:04.21 postmaster
 67634 root      20   0  569m 520m  328 S 11.2  0.1 140720:15 haproxy
 93429 postgres  20   0 37.2g 8.7g 8.7g S 11.2  2.3   2:12.23 postmaster
129653 postgres  20   0 37.2g 6.8g 6.7g S 11.2  1.8   1:27.92 postmaster
```

**PID**：进程ID，进程的唯一标识符

**USER**：进程所有者的实际用户名。

**PR**：进程的调度优先级。这个字段的一些值是'rt'。这意味这这些进程运行在实时态。

**NI**：进程的nice值（优先级）。越小的值意味着越高的优先级。

**VIRT**：进程使用的虚拟内存。

**RES**：驻留内存大小。驻留内存是任务使用的非交换物理内存大小。

**SHR**：SHR是进程使用的共享内存。

**S**这个是进程的状态。它有以下不同的值:

- D - 不可中断的睡眠态。
- R – 运行态
- S – 睡眠态
- T – Trace或Stop
- Z – 僵尸态

**%CPU**：自从上一次更新时到现在任务所使用的CPU时间百分比。

**%MEM**：进程使用的可用物理内存百分比。

**TIME+**：任务启动后到现在所使用的全部CPU时间，单位为百分之一秒。

**COMMAND**：运行进程所使用的命令。

> ###  Linux进程的状态
>
> ```c
> static const char * const task_state_array[] = {
>   "R (running)", /* 0 */
>   "S (sleeping)", /* 1 */
>   "D (disk sleep)", /* 2 */
>   "T (stopped)", /* 4 */
>   "t (tracing stop)", /* 8 */
>   "X (dead)", /* 16 */
>   "Z (zombie)", /* 32 */
> };
> ```
>
> `R (TASK_RUNNING)`，可执行状态。实际运行与`Ready`在Linux都算做Running状态
>
> `S(TASK_INTERRUPTIBLE)`，可中断的睡眠态，进程等待事件，位于等待队列中。
>
> `D (TASK_UNINTERRUPTIBLE)`，不可中断的睡眠态，无法响应异步信号，例如硬件操作，内核线程
>
> `T (TASK_STOPPED | TASK_TRACED)`，暂停状态或跟踪状态，由SIGSTOP或断点触发
>
> `Z (TASK_DEAD)`，子进程退出后，父进程还没有来收尸，留下`task_structure`的进程就处于这种状态。