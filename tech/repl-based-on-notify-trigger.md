---
title: "PostgreSQL基于触发器与通知的逻辑复制"
date: "2017-08-03"
author: "Vonng"
description: "巧妙运用Pg的Notify功能，可以方便地通知应用元数据变更，实现基于触发器的逻辑复制。"
categories: ["Dev"]
featured: ""
featuredalt: ""
featuredpath: "/img/blog/go-pg.png"
linktitle: ""
type: "post"
---



# PostgreSQL基于触发器与通知的逻辑复制

​	Parallel与Hierarchy是架构设计的两大法宝，**缓存**是Hierarchy在IO领域的体现。单线程场景下缓存机制的实现可以简单到不可思议，但很难想象成熟的应用会只有一个实例。在使用缓存的同时引入并发，就不得不考虑一个问题：如何保证每个实例的缓存与底层数据副本的数据一致性（和实时性）。

​	PostgreSQL在版本9引入了流式复制，在版本10引入了逻辑复制，但这些都是针对PostgreSQL数据库而言的。如果希望PostgreSQL中某张表的部分数据与应用内存中的状态保持一致，我们还是需要自己实现一种逻辑复制的机制。对于关键的少量元数据而言，使用触发器与Notify-Listen就是一个不错的选择。

​	

## 传统方法

​	最简单粗暴的办法就是定时重新拉取，例如每个整点，所有应用一起去数据库拉取一次最新版本的数据。很多应用都是这么做的。当然问题也很多：拉的间隔长了，变更不能及时应用，用户体验差；拉的频繁了，IO压力大。而且实例数目和数据大小一旦膨胀起来，对于宝贵的IO资源是很大的浪费。

​	异步通知是一种更好的办法，尤其是在读请求远多于写请求的情况下。接受到写请求的实例，通过发送广播的方式通知其他实例。`Redis`的`PubSub`就可以很好地实现这个功能。如果原本下层存储就是`Redis`自然是再方便不过，但如果下层存储是关系型数据库的话，为这样一个功能引入一个新的组件似乎有些得不偿失。况且考虑到后台管理程序或者其他应用如果在修改了数据库后也要去redis发布通知，实在太麻烦了。一种可行的办法是通过数据库中间件来监听`RDS`变动并广播通知，淘宝不少东西就是这么做的。但如果DB本身就能搞定的事情，为什么需要额外的组件呢？通过PostgreSQL的Notfiy-Listen机制，可以方便地实现这种功能。

## 目标

无论从任何渠道产生的数据库记录变更（增删改）都能被所有相关应用实时感知，用于维护自身缓存与数据库内容的一致性。



## 原理

PostgreSQL行级触发器 + Notify机制 + 自定义协议 + Smart Client

* 行级触发器：通过为我们感兴趣的表建立一个行级别的写触发器，对数据表中的每一行记录的Update,Delete,Insert都会出发自定义函数的执行。
* Notify：通过PostgreSQL内建的异步通知机制向指定的Channel发送通知
* 自定义协议：协商消息格式，传递操作的类型与变更记录的标识
* Smart Client：客户端监听消息变更，根据消息对缓存执行相应的操作。

实际上这样一套东西就是一个超简易的WAL（Write *After* Log）实现，从而使应用内部的缓存状态能与数据库保持*实时*一致（compare to poll）。



## 实现

### DDL

这里以一个最简单的表作为示例，一张以主键标识的`users`表。

```sql
-- 用户表
CREATE TABLE users (
  id   TEXT,
  name TEXT,
  PRIMARY KEY (id)
);
```

### 触发器

```sql
-- 通知触发器
CREATE OR REPLACE FUNCTION notify_change() RETURNS TRIGGER AS $$
BEGIN
  IF    (TG_OP = 'INSERT') THEN 
	PERFORM pg_notify(TG_RELNAME || '_chan', 'I' || NEW.id); RETURN NEW;
  ELSIF (TG_OP = 'UPDATE') THEN 
	PERFORM pg_notify(TG_RELNAME || '_chan', 'U' || NEW.id); RETURN NEW;
  ELSIF (TG_OP = 'DELETE') THEN 
	PERFORM pg_notify(TG_RELNAME || '_chan', 'D' || OLD.id); RETURN OLD;
  END IF;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;
```

这里创建了一个触发器函数，通过内置变量`TG_OP`获取操作的名称，`TG_RELNAME`获取表名。每当触发器执行时，它会向名为`<table_name>_chan`的通道发送指定格式的消息：`[I|U|D]<id>`

题外话：通过行级触发器，还可以实现一些很实用的功能，例如In-DB Audit，自动更新字段值，统计信息，自定义备份策略与回滚逻辑等。

```sql
-- 为用户表创建行级触发器，监听INSERT UPDATE DELETE 操作。
CREATE TRIGGER t_user_notify AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH ROW EXECUTE PROCEDURE notify_change();
```

创建触发器也很简单，表级触发器对每次表变更执行一次，而行级触发器对每条记录都会执行一次。这样，数据库的里的工作就算全部完成了。

### 消息格式

通知需要传达出两个信息：变更的操作类型，变更的实体标记。

* 变更的操作类型就是增删改：INSERT,DELETE,UPDATE。通过一个打头的字符'[I|U|D]'就可以标识。
* 变更的对象可以通过实体主键来标识。如果不是字符串类型，还需要确定一种无歧义的序列化方式。

这里为了省事直接使用字符串类型作为ID，那么插入一条`id=1`的记录，对应的消息就是`I1`，更新一条`id=5`的记录消息就是`U5`，删除`id=3`的记录消息就是`D3`。

完全可以通过更复杂的消息协议实现更强大的功能。

### SmartClient

数据库的机制需要客户端的配合才能生效，客户端需要监听数据库的变更通知，才能将变更实时应用到自己的缓存副本中。对于插入和更新，客户端需要根据ID重新拉取相应实体，对于删除，客户端需要删除自己缓存副本的相应实体。以Go语言为例，编写了一个简单的客户端模块。

本例中使用一个以`User.ID`作为键，`User`对象作为值的并发安全字典`Users sync.Map`作为缓存。

作为演示，启动了另一个goroutine对数据库写入了一些变更。

```go
package main

import "sync"
import "strings"
import "github.com/go-pg/pg"
import . "github.com/Vonng/gopher/db/pg"
import log "github.com/Sirupsen/logrus"

type User struct {
	ID   string `sql:",pk"`
	Name string
}

var Users sync.Map // Users 内部数据缓存

func LoadAllUser() {
	var users []User
	Pg.Query(&users, `SELECT ID,name FROM users;`)
	for _, user := range users {
		Users.Store(user.ID, user)
	}
}

func LoadUser(id string) {
	user := User{ID: id}
	Pg.Select(&user)
	Users.Store(user.ID, user)
}

func PrintUsers() string {
	var buf []string
	Users.Range(func(key, value interface{}) bool {
		buf = append(buf, key.(string));
		return true
	})
	return strings.Join(buf, ",")
}

// ListenUserChange 会监听PostgreSQL users数据表中的变动通知
func ListenUserChange() {
	go func(c <-chan *pg.Notification) {
		for notify := range c {
			action, id := notify.Payload[0], notify.Payload[1:]
			switch action {
			case 'I':
				fallthrough
			case 'U':
				LoadUser(id);
			case 'D':
				Users.Delete(id)
			}
			log.Infof("[NOTIFY] Action:%c ID:%s Users: %s", action, id, PrintUsers())
		}
	}(Pg.Listen("users_chan").Channel())
}

// MakeSomeChange 会向数据库写入一些变更
func MakeSomeChange() {
	go func() {
		Pg.Insert(&User{"001", "张三"})
		Pg.Insert(&User{"002", "李四"})
		Pg.Insert(&User{"003", "王五"})  // 插入
		Pg.Update(&User{"003", "王麻子"}) // 改名
		Pg.Delete(&User{ID: "002"})    // 删除
	}()
}

func main() {
	Pg = NewPg("postgres://localhost:5432/postgres")
	Pg.Exec(`TRUNCATE TABLE users;`)
	LoadAllUser()
	ListenUserChange()
	MakeSomeChange()
	<-make(chan struct{})
}
```

运行结果如下：

```
[NOTIFY] Action:I ID:001 Users: 001          
[NOTIFY] Action:I ID:002 Users: 001,002      
[NOTIFY] Action:I ID:003 Users: 002,003,001  
[NOTIFY] Action:U ID:003 Users: 001,002,003  
[NOTIFY] Action:D ID:002 Users: 001,003      
```

可以看出，缓存确是与数据库保持了同样的状态。



## 应用场景

小数据量下这种做法是相当可靠的，大数据量下尚未进行充分的测试。

其实，对于上例中缓存同步的场景，完全不需要自定义消息格式，只要发送发生变更的记录ID，由应用直接拉取，然后覆盖或删除缓存中的记录即可。