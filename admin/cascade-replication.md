# 级联复制

配置级联复制时需要注意在从库上配置：`recovery_target_timeline = 'latest'`，否则当级联从库Promote的时候，下面挂着的从库会无法恢复。

```
[postgres@10-9-97-214 data]$ tail -f log/postgresql-Sun.csv
2018-08-19 22:54:12.255 CST,,,31781,,5b7968d5.7c25,2,,2018-08-19 20:55:49 CST,,0,FATAL,57P01,"terminating walreceiver process due to administrator command",,,,,,,,,""
2018-08-19 22:54:12.256 CST,"postgres","postgres",31809,"[local]",5b796d6b.7c41,1,"idle",2018-08-19 21:15:23 CST,2/0,0,FATAL,57P01,"terminating connection due to administrator command",,,,,,,,,"psql"
2018-08-19 22:54:12.258 CST,,,26280,,5b73a087.66a8,1,,2018-08-15 11:39:51 CST,,0,LOG,00000,"shutting down",,,,,,,,,""
2018-08-19 22:54:12.265 CST,,,26277,,5b73a087.66a5,6,,2018-08-15 11:39:51 CST,,0,LOG,00000,"database system is shut down",,,,,,,,,""
2018-08-19 22:54:12.383 CST,,,31930,,5b798494.7cba,1,,2018-08-19 22:54:12 CST,,0,LOG,00000,"ending log output to stderr",,"Future log output will go to log destination ""csvlog"".",,,,,,,""
2018-08-19 22:54:12.386 CST,,,31932,,5b798494.7cbc,1,,2018-08-19 22:54:12 CST,,0,LOG,00000,"database system was shut down in recovery at 2018-08-19 22:54:12 CST",,,,,,,,,""
2018-08-19 22:54:12.386 CST,,,31932,,5b798494.7cbc,2,,2018-08-19 22:54:12 CST,,0,LOG,00000,"entering standby mode",,,,,,,,,""
2018-08-19 22:54:12.387 CST,,,31932,,5b798494.7cbc,3,,2018-08-19 22:54:12 CST,1/0,0,LOG,00000,"redo starts at 0/BE8F138",,,,,,,,,""
2018-08-19 22:54:12.388 CST,,,31932,,5b798494.7cbc,4,,2018-08-19 22:54:12 CST,1/0,0,LOG,00000,"consistent recovery state reached at 0/BE93200",,,,,,,,,""
2018-08-19 22:54:12.389 CST,,,31930,,5b798494.7cba,2,,2018-08-19 22:54:12 CST,,0,LOG,00000,"database system is ready to accept read only connections",,,,,,,,,""
^C
```

