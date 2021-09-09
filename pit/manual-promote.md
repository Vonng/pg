# 从删库到跑路

​	维持系统正常运转，需要从技术与管理两方面着手。设计并构建了软件系统的工程师是人类，维持系统运行的运维也是人类。而人类是不可靠的，即使他们的动机并非是恶意的。

​	故障大多出于不可抗力的因素。今天碰上了一起人为故障。

​	前任DBA（ somehow保留了生产机的登录权限，在做压测时误把生产机当成测试机压测……不仅如此，还直接promote了从库……。这就尴尬了……

​	信息安全的老生常谈：三分靠技术，七分靠管理。

![](../img/failure-manual-promote.png)



```bash
018-06-01 11:57:50.464 CST,"putong","putong",165588,"::1:53796",5b10c43e.286d4,1,"",2018-06-01 11:57:50 CST,13/1770801413,0,FATAL,28P01,"password authentication failed for user ""putong""","Connection matched pg_hba.conf line 12: ""host  all all ::1/128 md5""",,,,,,,,""
2018-06-01 11:57:53.910 CST,,,163512,,5952aff8.27eb8,7,,2017-06-28 03:20:24 CST,1/0,0,LOG,00000,"received promote request",,,,,,,,,""
2018-06-01 11:57:53.910 CST,,,166859,,5952b193.28bcb,2,,2017-06-28 03:27:15 CST,,0,FATAL,57P01,"terminating walreceiver process due to administrator command",,,,,,,,,""
2018-06-01 11:57:53.932 CST,,,163512,,5952aff8.27eb8,8,,2017-06-28 03:20:24 CST,1/0,0,LOG,00000,"unexpected pageaddr 358F7/3A146000 in log segment 0000000700035936000000AA, offset 1335296",,,,,,,,,""
2018-06-01 11:57:53.934 CST,,,163512,,5952aff8.27eb8,9,,2017-06-28 03:20:24 CST,1/0,0,LOG,00000,"redo done at 35936/AA145EC8",,,,,,,,,""
2018-06-01 11:57:53.934 CST,,,163512,,5952aff8.27eb8,10,,2017-06-28 03:20:24 CST,1/0,0,LOG,00000,"last completed transaction was at log time 2018-06-01 11:57:53.907694+08",,,,,,,,,""
2018-06-01 11:57:53.975 CST,,,163512,,5952aff8.27eb8,11,,2017-06-28 03:20:24 CST,1/0,0,LOG,00000,"selected new timeline ID: 8",,,,,,,,,""
2018-06-01 11:57:54.075 CST,,,163512,,5952aff8.27eb8,12,,2017-06-28 03:20:24 CST,1/0,0,LOG,00000,"archive recovery complete",,,,,,,,,""
```

