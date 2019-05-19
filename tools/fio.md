# 使用FIO测试IO性能

```bash
fio --filename=/tmp/fio.data \
    -direct=1 \
    -iodepth=32 \
    -rw=randrw \
    --rwmixread=80 \
    -bs=4k \
    -size=1G \
    -numjobs=16 \
    -runtime=60 \
    -group_reporting \
    -name=randrw \
    --output=/tmp/fio_randomrw.txt \
    && unlink /tmp/fio.data
```



```sql
--8k  随机写
fio -name=8krandw  -runtime=120  -filename=/data/rand.txt -ioengine=libaio -direct=1  -bs=8K  -size=10g  -iodepth=128  -numjobs=1  -rw=randwrite -group_reporting -time_based
  
--8K  随机读
fio -name=8krandr  -runtime=120  -filename=/data/rand.txt -ioengine=libaio -direct=1  -bs=8K  -size=10g  -iodepth=128  -numjobs=1  -rw=randread -group_reporting -time_based
  
--8k  混合读写
fio -name=8krandrw  -runtime=120  -filename=/data/rand.txt -ioengine=libaio -direct=1  -bs=8k  -size=10g  -iodepth=128  -numjobs=1  -rw=randrw -rwmixwrite=30  -group_reporting -time_based
   
--1Mb  顺序写
fio -name=1mseqw  -runtime=120  -filename=/data/seq.txt -ioengine=libaio -direct=1  -bs=1024k  -size=20g  -iodepth=128  -numjobs=1  -rw=write -group_reporting -time_based
  
--1Mb  顺序读
fio -name=1mseqr  -runtime=120  -filename=/data/seq.txt -ioengine=libaio -direct=1  -bs=1024k  -size=20g  -iodepth=128  -numjobs=1  -rw=read -group_reporting -time_based
  
--1Mb  顺序读写
fio -name=1mseqrw  -runtime=120  -filename=/data/seq.txt -ioengine=libaio -direct=1  -bs=1024k  -size=20g  -iodepth=128  -numjobs=1  -rw=rw -rwmixwrite=30  -group_reporting -time_based
```



测试PostgreSQL相关的IO性能表现时，可以考虑以下参数组合。

3 Demension：RW Ratio, Block Size, N Jobs

* RW Ratio:  Pure Read, Pure Write, rwmixwrite=80, rwmixwrite=20

* Block Size = 4KB (OS granular), 8KB (DB granular)
* N jobs: 1 , 4 , 8 , 16 ,32

主要以8KB随机IO为主