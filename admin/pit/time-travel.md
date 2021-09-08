---
title: "故障档案:时间回溯导致的Patroni故障"
linkTitle: "故障:时间回溯"
date: 2021-02-22
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  机器因为故障重启，NTP服务在PG启动后修复了PG的时间，导致Patroni无法启动。
---



【草稿】

机器因为故障重启，NTP服务在PG启动后修复了PG的时间，导致Patroni无法启动。

Patroni中的故障信息如下所示。

patroni 进程启动时间和pid时间不一致。就会认为：postgres is not running。

两个时间相差超过30秒。patroni就尿了。



还发现了Patroni里的一个BUG：https://github.com/zalando/patroni/issues/811

错误信息里两个时间戳打反了。

