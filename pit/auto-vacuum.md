# `AutoVacuum`导致的尖峰



AutoVacuum是个好东西，但需要关注它被触发的时机。

比如这里，因为AutoVAcuum总是在晚高峰被触发。

![](../img/autovacuum-peak.png)



因为晚高峰对`users`表的增删改查特别频繁，因此会在晚高峰触发`AutoVacuum`。

