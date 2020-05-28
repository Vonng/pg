# 如何在LB后面获取客户端真实IP



使用TOA模块，Hook进内核函数，当获取ClientIP地址时，从TCP的Opt字段中获取而不是直接从报文中获取

```bash
yum install -y gcc
tar -zxvf linux_toa.tar.gz
cd linux_toa
make
mv toa.ko /lib/modules/`uname -r`/kernel/net/netfilter/ipvs/toa.ko
insmod /lib/modules/`uname -r`/kernel/net/netfilter/ipvs/toa.ko
lsmod | grep toa
```

