---
title: "Go数据库教程: database/sql"
date: "2017-08-24"
author: "Vonng"
description: "同JDBC类似，Go也有标准的数据库访问接口。本文详细介绍了database/sql的使用方法和注意事项。"
categories: ["Dev"]
featured: ""
featuredalt: ""
featuredpath: "/img/blog/golang.jpeg"
linktitle: ""
type: "post"
---

Go使用SQL与类SQL数据库的惯例是通过标准库[database/sql](http://golang.org/pkg/database/sql/)。这是一个对关系型数据库的通用抽象，它提供了标准的、轻量的、面向行的接口。不过`database/sql`的包文档只讲它做了什么，却对如何使用只字未提。快速指南远比堆砌事实有用，本文讲述了`database/sql`的使用方法及其注意事项。

<!--more-->

## 1. 顶层抽象

在Go中访问数据库需要用到`sql.DB`接口：它可以创建语句(statement)和事务(transaction)，执行查询，获取结果。

`sql.DB`并不是数据库连接，也并未在概念上映射到特定的数据库(Database)或模式(schema)。它只是一个抽象的接口，不同的具体驱动有着不同的实现方式。通常而言，`sql.DB`会处理一些重要而麻烦的事情，例如操作具体的驱动打开/关闭实际底层数据库的连接，按需管理连接池。

`sql.DB`这一抽象让用户不必考虑如何管理并发访问底层数据库的问题。当一个连接在执行任务时会被标记为正在使用。用完之后会放回连接池中。不过用户如果用完连接后忘记释放，就会产生大量的连接，极可能导致资源耗尽（建立太多连接，打开太多文件，缺少可用网络端口）。



## 2. 导入驱动

使用数据库时，除了`database/sql`包本身，还需要引入想使用的特定数据库驱动。

尽管有时候一些数据库特有的功能必需通过驱动的Ad Hoc接口来实现，但通常只要有可能，还是应当尽量只用`database/sql`中定义的类型。这可以减小用户代码与驱动的耦合，使切换驱动时代码改动最小化，也尽可能地使用户遵循Go的惯用法。本文使用PostgreSQL为例，PostgreSQL的著名的驱动有：

* [`github.com/lib/pq`](https://github.com/lib/pq)
* [`github.com/go-pg/pg`](https://github.com/go-pg/pg)
* [`github.com/jackc/pgx`]([`https://github.com/jackc/pgx`])。

这里以`pgx`为例，它性能表现不俗，并对PostgreSQL诸多特性与类型有着良好的支持。既可使用Ad-Hoc API，也提供了标准数据库接口的实现：`github.com/jackc/pgx/stdlib`。

	import (
		"database/sql"
		_ "github.com/jackx/pgx/stdlib"
	)

使用`_`别名来匿名导入驱动，驱动的导出名字不会出现在当前作用域中。导入时，驱动的初始化函数会调用`sql.Register`将自己注册在`database/sql`包的全局变量`sql.drivers`中，以便以后通过`sql.Open`访问。



## 3. 访问数据

加载驱动包后，需要使用`sql.Open()`来创建`sql.DB`：

	func main() {
		db, err := sql.Open("pgx","postgres://localhost:5432/postgres")
		if err != nil {
			log.Fatal(err)
		}
		defer db.Close()
	}

`sql.Open`有两个参数：

* 第一个参数是驱动名称，字符串类型。为避免混淆，一般与包名相同，这里是`pgx`。
* 第二个参数也是字符串，内容依赖于特定驱动的语法。通常是URL的形式，例如`postgres://localhost:5432`。
* 绝大多数情况下都应当检查`database/sql`操作所返回的错误。
* 一般而言，程序需要在退出时通过`sql.DB`的`Close()`方法释放数据库连接资源。如果其生命周期不超过函数的范围，则应当使用`defer db.Close()`

执行`sql.Open()`并未实际建立起到数据库的连接，也不会验证驱动参数。第一个实际的连接会惰性求值，延迟到第一次需要时建立。用户应该通过`db.Ping()`来检查数据库是否实际可用。

```go
if err = db.Ping(); err != nil {
	// do something about db error
}
```

`sql.DB`对象是为了长连接而设计的，不要频繁`Open()`和`Close()`数据库。而应该为每个待访问的数据库创建**一个**`sql.DB`实例，并在用完前一直保留它。需要时可将其作为参数传递，或注册为全局对象。

如果没有按照`database/sql`设计的意图，不把`sql.DB`当成长期对象来用而频繁开关启停，就可能遭遇各式各样的错误：无法复用和共享连接，耗尽网络资源，由于TCP连接保持在`TIME_WAIT`状态而间断性的失败等……



## 4. 获取结果

有了`sql.DB`实例之后就可以开始执行查询语句了。

Go将数据库操作分为两类：`Query`与`Exec`。两者的区别在于前者会返回结果，而后者不会。

* `Query`表示查询，它会从数据库获取查询结果（一系列行，可能为空）。
* `Exec`表示执行语句，它不会返回行。

此外还有两种常见的数据库操作模式：

* `QueryRow`表示只返回一行的查询，作为`Query`的一个常见特例。
* `Prepare`表示准备一个需要多次使用的语句，供后续执行用。

### 4.1 获取数据

让我们看一个如何查询数据库并且处理结果的例子：利用数据库计算从1到10的自然数之和。

```go
func example() {
	var sum, n int32

	// invoke query
	rows, err := db.Query("SELECT generate_series(1,$1)", 10)
    // handle query error
	if err != nil {
		fmt.Println(err)
	}
    // defer close result set
	defer rows.Close()

	// Iter results
	for rows.Next() {
		if err = rows.Scan(&n); err != nil {
			fmt.Println(err)	// Handle scan error
		}
		sum += n				// Use result
	}

	// check iteration error
	if rows.Err() != nil {
		fmt.Println(err)
	}

	fmt.Println(sum)
}
```

* 整体工作流程如下：

	1. 使用`db.Query()`来发送查询到数据库，获取结果集`Rows`，并检查错误。
	2. 使用`rows.Next()`作为循环条件，迭代读取结果集。
	3. 使用`rows.Scan`从结果集中获取一行结果。
	4. 使用`rows.Err()`在退出迭代后检查错误。
	5. 使用`rows.Close()`关闭结果集，释放连接。

* 一些需要详细说明的地方：

	1. `db.Query`会返回结果集`*Rows`和错误。每个驱动返回的错误都不一样，用错误字符串来判断错误类型并不是明智的做法，更好的方法是对抽象的错误做`Type Assertion`，利用驱动提供的更具体的信息来处理错误。当然类型断言也可能产生错误，这也是需要处理的。

		```go
		if err.(pgx.PgError).Code == "0A000" {
		// Do something with that type or error
		}
		```

	2. `rows.Next()`会指明是否还有未读取的数据记录，通常用于迭代结果集。迭代中的错误会导致`rows.Next()`返回`false`。

	3. `rows.Scan()`用于在迭代中获取一行结果。数据库会使用wire protocal通过TCP/UnixSocket传输数据，对Pg而言，每一行实际上对应一条`DataRow`消息。`Scan`接受变量地址，解析`DataRow`消息并填入相应变量中。因为Go语言是强类型的，所以用户需要创建相应类型的变量并在`rows.Scan`中传入其指针，`Scan`函数会根据目标变量的类型执行相应转换。例如某查询返回一个单列`string`结果集，用户可以传入`[]byte`或`string`类型变量的地址，Go会将原始二进制数据或其字符串形式填入其中。但如果用户知道这一列始终存储着数字字面值，那么相比传入`string`地址后手动使用`strconv.ParseInt()`解析，更推荐的做法是直接传入一个整型变量的地址（如上面所示），Go会替用户完成解析工作。如果解析出错，`Scan`会返回相应的错误。

	4. `rows.Err()`用于在退出迭代后检查错误。正常情况下迭代退出是因为内部产生的EOF错误，使得下一次`rows.Next() == false`，从而终止循环；在迭代结束后要检查错误，以确保迭代是因为数据读取完毕，而非其他“真正”错误而结束的。遍历结果集的过程实际上是网络IO的过程，可能出现各种错误。健壮的程序应当考虑这些可能，而不能总是假设一切正常。

	5. `rows.Close()`用于关闭结果集。结果集引用了数据库连接，并会从中读取结果。读取完之后必须关闭它才能避免资源泄露。只要结果集仍然打开着，相应的底层连接就处于忙碌状态，不能被其他查询使用。

	6. 因错误(包括EOF)导致的迭代退出会自动调用`rows.Close()`关闭结果集（和释放底层连接）。但如果程序自行意外地退出了循环，例如中途`break & return`，结果集就不会被关闭，产生资源泄露。`rows.Close`方法是幂等的，重复调用不会产生副作用，因此建议使用 `defer rows.Close()`来关闭结果集。

以上就是在Go中使用数据库的标准方式。

### 4.2 单行查询

如果一个查询每次最多返回一行，那么可以用快捷的单行查询来替代冗长的标准查询，例如上例可改写为：

```go
var sum int
err := db.QueryRow("SELECT sum(n) FROM (SELECT generate_series(1,$1) as n) a;", 10).Scan(&sum)
if err != nil {
	fmt.Println(err)
}
fmt.Println(sum)
```

不同于`Query`，如果查询发生错误，错误会延迟到调用`Scan()`时统一返回，减少了一次错误处理判断。同时`QueryRow`也避免了手动操作结果集的麻烦。

需要注意的是，对于单行查询，Go将没有结果的情况视为错误。`sql`包中定义了一个特殊的错误常量`ErrNoRows`，当结果为空时，`QueryRow().Scan()`会返回它。

### 4.3 修改数据

什么时候用`Exec`，什么时候用`Query`，这是一个问题。通常`DDL`和增删改使用`Exec`，返回结果集的查询使用`Query`。但这不是绝对的，这完全取决于用户是否希望想要获取返回结果。例如在PostgreSQL中：`INSERT ... RETURNING *;`虽然是一条插入语句，但它也有返回结果集，故应当使用`Query`而不是`Exec`。

`Query`和`Exec`返回的结果不同，两者的签名分别是：

```go
func (s *Stmt) Query(args ...interface{}) (*Rows, error)
func (s *Stmt) Exec(args ...interface{}) (Result, error) 
```

`Exec`不需要返回数据集，返回的结果是`Result`，`Result`接口允许获取执行结果的元数据

```go
type Result interface {
	// 用于返回自增ID，并不是所有的关系型数据库都有这个功能。
	LastInsertId() (int64, error)
	// 返回受影响的行数。
	RowsAffected() (int64, error)
}
```

`Exec`的用法如下所示：

```go
db.Exec(`CREATE TABLE test_users(id INTEGER PRIMARY KEY ,name TEXT);`)
db.Exec(`TRUNCATE test_users;`)
stmt, err := db.Prepare(`INSERT INTO test_users(id,name) VALUES ($1,$2) RETURNING id`)
if err != nil {
	fmt.Println(err.Error())
}
res, err := stmt.Exec(1, "Alice")

if err != nil {
	fmt.Println(err)
} else {
	fmt.Println(res.RowsAffected())
	fmt.Println(res.LastInsertId())
}
```

相比之下`Query`则会返回结果集对象`*Rows`，使用方式见上节。其特例`QueryRow`使用方式如下：

```go
db.Exec(`CREATE TABLE test_users(id INTEGER PRIMARY KEY ,name TEXT);`)
db.Exec(`TRUNCATE test_users;`)
stmt, err := db.Prepare(`INSERT INTO test_users(id,name) VALUES ($1,$2) RETURNING id`)
if err != nil {
	fmt.Println(err.Error())
}
var returnID int
err = stmt.QueryRow(4, "Alice").Scan(&returnID)
if err != nil {
	fmt.Println(err)
} else {
	fmt.Println(returnID)
}
```

同样的语句使用`Exec`和`Query`执行有巨大的差别。如上文所述，`Query`会返回结果集`Rows`，而存在未读取数据的`Rows`其实会占用底层连接直到`rows.Close()`为止。因此，使用`Query`但不读取返回结果，会导致底层连接永远无法释放。`database/sql`期望用户能够用完就把连接还回来，所以这样的用法很快就会导致资源耗尽（连接过多）。所以，应该用`Exec`的语句绝不可用`Query`来执行。

### 4.4 准备查询

在上一节的两个例子中，没有直接使用数据库的`Query`和`Exec`方法，而是首先执行了`db.Prepare`获取准备好的语句(prepared statement)。准备好的语句`Stmt`和`sql.DB`一样，都可以执行`Query`、`Exec`等方法。

#### 4.4.1 准备语句的优势

在查询前进行准备是Go语言中的惯用法，多次使用的查询语句应当进行准备（`Prepare`）。准备查询的结果是一个准备好的语句（prepared statement），语句中可以包含执行时所需参数的占位符（即绑定值）。准备查询比拼字符串的方式好很多，它可以转义参数，避免SQL注入。同时，准备查询对于一些数据库也省去了解析和生成执行计划的开销，有利于性能。

#### 4.4.2 占位符

PostgreSQL使用`$N`作为占位符，`N`是一个从1开始递增的整数，代表参数的位置，方便参数的重复使用。MySQL使用`?`作为占位符，SQLite两种占位符都可以，而Oracle则使用`:param1`的形式。

```
MySQL               PostgreSQL            Oracle
=====               ==========            ======
WHERE col = ?       WHERE col = $1        WHERE col = :col
VALUES(?, ?, ?)     VALUES($1, $2, $3)    VALUES(:val1, :val2, :val3)
```

以`PostgreSQL`为例，在上面的例子中：`"SELECT generate_series(1,$1)"` 就用到了`$N`的占位符形式，并在后面提供了与占位符数目匹配的参数个数。

#### 4.4.3 底层内幕

准备语句有着各种优点：安全，高效，方便。但Go中实现它的方式可能和用户所设想的有轻微不同，尤其是关于和`database/sql`内部其他对象交互的部分。

在数据库层面，准备语句`Stmt`是与单个数据库连接绑定的。通常的流程是：客户端向服务器发送带有占位符的查询语句用于准备，服务器返回一个语句ID，客户端在实际执行时，只需要传输语句ID和相应的参数即可。因此准备语句无法在连接之间共享，当使用新的数据库连接时，必须重新准备。

`database/sql`并没有直接暴露出数据库连接。用户是在`DB`或`Tx`上执行`Prepare`，而不是`Conn`。因此`database/sql`提供了一些便利处理，例如自动重试。这些机制隐藏在Driver中实现，而不会暴露在用户代码中。其工作原理是：当用户准备一条语句时，它在连接池中的一个连接上进行准备。`Stmt`对象会引用它实际使用的连接。当执行`Stmt`时，它会尝试会用引用的连接。如果那个连接忙碌或已经被关闭，它会获取一个新的连接，并在连接上重新准备，然后再执行。

因为当原有连接忙时，`Stmt`会在其他连接上重新准备。因此当高并发地访问数据库时，大量的连接处于忙碌状态，这会导致`Stmt`不断获取新的连接并执行准备，最终导致资源泄露，甚至超出服务端允许的语句数目上限。所以通常应尽量采用扇入的方式减小数据库访问并发数。

#### 4.4.4 查询的微妙之处

数据库连接其实是实现了`Begin,Close,Prepare`方法的接口。

```go
type Conn interface {
        Prepare(query string) (Stmt, error)
        Close() error
        Begin() (Tx, error)
}
```

所以连接接口上实际并没有`Exec`，`Query`方法，这些方法其实定义在`Prepare`返回的`Stmt`上。对于Go而言，这意味着`db.Query()`实际上执行了三个操作：首先对查询语句做了准备，然后执行查询语句，最后关闭准备好的语句。这对数据库而言，其实是3个来回。设计粗糙的程序与简陋实现驱动可能会让应用与数据库交互的次数增至3倍。好在绝大多数数据库驱动对于这种情况有优化，如果驱动实现`sql.Queryer`接口：

```go
type Queryer interface {
        Query(query string, args []Value) (Rows, error)
}
```

那么`database/sql`就不会再进行`Prepare-Execute-Close`的查询模式，而是直接使用驱动实现的`Query`方法向数据库发送查询。对于查询都是即拼即用，也不担心安全问题的情况下，直接`Query`可以有效减少性能开销。



## 5. 使用事务

事物是关系型数据库的核心特性。Go中事务（Tx）是一个持有数据库连接的对象，它允许用户在**同一个连接**上执行上面提到的各类操作。

### 5.1 事务基本操作

通过`db.Begin()`来开启一个事务，`Begin`方法会返回一个事务对象`Tx`。在结果变量`Tx`上调用`Commit()`或者`Rollback()`方法会提交或回滚变更，并关闭事务。在底层，`Tx`会从连接池中获得一个连接并在事务过程中保持对它的独占。事务对象`Tx`上的方法与数据库对象`sql.DB`的方法一一对应，例如`Query,Exec`等。事务对象也可以准备(prepare)查询，由事务创建的准备语句会显式绑定到创建它的事务。

### 5.2 事务注意事项

使用事务对象时，不应再执行事务相关的SQL语句，例如`BEGIN,COMMIT`等。这可能产生一些副作用：

* `Tx`对象一直保持打开状态，从而占用了连接。
* 数据库状态不再与Go中相关变量的状态保持同步。
* 事务提前终止会导致一些本应属于事务内的查询语句不再属于事务的一部分，这些被排除的语句有可能会由别的数据库连接而非原有的事务专属连接执行。

当处于事务内部时，应当使用`Tx`对象的方法而非`DB`的方法，`DB`对象并不是事务的一部分，直接调用数据库对象的方法时，所执行的查询并不属于事务的一部分，有可能由其他连接执行。

### 5.3 Tx的其他应用场景

如果需要修改连接的状态，也需要用到`Tx`对象，即使用户并不需要事务。例如：

* 创建仅连接可见的临时表
* 设置变量，例如`SET @var := somevalue`
* 修改连接选项，例如字符集，超时设置。

在`Tx`上执行的方法都保证同一个底层连接执行，这使得对连接状态的修改对后续操作起效。这是Go中实现这种功能的标准方式。

### 5.4 在事务中准备语句

调用`Tx.Prepare`会创建一个与事务绑定的准备语句。在事务中使用准备语句，有一个特殊问题需要关注：一定要在事务结束前关闭准备语句。

在事务中使用`defer stmt.Close()`是相当危险的。因为当事务结束后，它会释放自己持有的数据库连接，但事务创建的未关闭`Stmt`仍然保留着对事务连接的引用。在事务结束后执行`stmt.Close()`，如果原来释放的连接已经被其他查询获取并使用，就会产生竞争，极有可能破坏连接的状态。



## 6. 处理空值

可空列（Nullable Column）非常的恼人，容易导致代码变得丑陋。如果可以，在设计时就应当尽量避免。因为：

* Go语言的每一个变量都有着默认零值，当数据的零值没有意义时，可以用零值来表示空值。但很多情况下，数据的零值和空值实际上有着不同的语义。单独的原子类型无法表示这种情况。


* 标准库只提供了有限的四种`Nullable type`：：`NullInt64, NullFloat64, NullString, NullBool`。并没有诸如`NullUint64`，`NullYourFavoriteType`，用户需要自己实现。
* 空值有很多麻烦的地方。例如用户认为某一列不会出现空值而采用基本类型接收时却遇到了空值，程序就会崩溃。这种错误非常稀少，难以捕捉、侦测、处理，甚至意识到。


### 6.1 使用额外的标记字段

`database\sql`提供了四种基本可空数据类型：使用基本类型和一个布尔标记的复合结构体表示可空值。例如：

```go
type NullInt64 struct {
        Int64 int64
        Valid bool // Valid is true if Int64 is not NULL
}
```

可空类型的使用方法与基本类型一致：

```go
for rows.Next() {
	var s sql.NullString
	err := rows.Scan(&s)
	// check err
	if s.Valid {
	   // use s.String
	} else {
	   // handle NULL case
	}
}
```

#### 6.2 使用指针

在Java中通过装箱（boxing）处理可空类型，即把基本类型包装成一个类，并通过指针引用。于是，空值语义可以通过指针为空来表示。Go当然也可以采用这种办法，不过标准库中并没有提供这种实现方式。`pgx`提供了这种形式的可空类型支持。

#### 6.3 使用零值表示空值

如果数据本身从语义上就不会出现零值，或者根本不区分零值和空值，那么最简便的方法就是使用零值来表示空值。驱动`go-pg`提供了这种形式的支持。

#### 6.4 自定义处理逻辑

任何实现了`Scanner`接口的类型，都可以作为`Scan`传入的地址参数类型。这就允许用户自己定制复杂的解析逻辑，实现更丰富的类型支持。

```go
type Scanner interface {
  		// Scan 从数据库驱动中扫描出一个值，当不能无损地转换时，应当返回错误
  		// src可能是int64, float64, bool, []byte, string, time.Time，也可能是nil，表示空值。
        Scan(src interface{}) error
}
```

#### 6.5 在数据库层面解决

通过对列添加`NOT NULL`约束，可以确保任何结果都不会为空。或者，通过在`SQL`中使用`COALESCE`来为NULL设定默认值。



## 7. 处理动态列

`Scan()`函数要求传递给它的目标变量的数目，与结果集中的列数正好匹配，否则就会出错。

但总有一些情况，用户事先并不知道返回的结果到底有多少列，例如调用一个返回表的存储过程时。

在这种情况下，使用`rows.Columns()`来获取列名列表。在不知道列类型情况下，应当使用`sql.RawBytes`作为接受变量的类型。获取结果后自行解析。

```
cols, err := rows.Columns()
if err != nil {
	// handle this....
}

// 目标列是一个动态生成的数组
dest := []interface{}{
	new(string),
	new(uint32),
	new(sql.RawBytes),
}

// 将数组作为可变参数传入Scan中。
err = rows.Scan(dest...)
// ...

```



## 8. 连接池

`database/sql`包里实现了一个通用的连接池，它只提供了非常简单的接口，除了限制连接数、设置生命周期基本没有什么定制选项。但了解它的一些特性也是很有帮助的。

- 连接池意味着：同一个数据库上的连续两条查询可能会打开两个连接，在各自的连接上执行。这可能导致一些让人困惑的错误，例如程序员希望锁表插入时连续执行了两条命令：`LOCK TABLE`和`INSERT`，结果却会阻塞。因为执行插入时，连接池创建了一个新的连接，而这条连接并没有持有表锁。

- 在需要时，而且连接池中没有可用的连接时，连接才被创建。

- 默认情况下连接数量没有限制，想创建多少就有多少。但服务器允许的连接数往往是有限的。

- 用`db.SetMaxIdleConns(N)`来限制连接池中空闲连接的数量，但是这并不会限制连接池的大小。连接回收(recycle)的很快，通过设置一个较大的N，可以在连接池中保留一些空闲连接，供快速复用(reuse)。但保持连接空闲时间过久可能会引发其他问题，比如超时。设置`N=0`则可以避免连接空闲太久。

- 用`db.SetMaxOpenConns(N)`来限制连接池中**打开**的连接数量。

- 用`db.SetConnMaxLifetime(d time.Duration)`来限制连接的生命周期。连接超时后，会在需要时惰性回收复用。

  ​


## 9. 微妙行为

`database/sql`并不复杂，但某些情况下它的微妙表现仍然会出人意料。

### 9.1 资源耗尽

不谨慎地使用`database/sql`会给自己挖许多坑，最常见的问题就是资源枯竭（resource exhaustion）：

- 打开和关闭数据库（`sql.DB`）可能会导致资源枯竭；
- 结果集没有读取完毕，或者调用`rows.Close()`失败，结果集会一直占用池里的连接；
- 使用`Query()`执行一些不返回结果集的语句，返回的未读取结果集会一直占用池里的连接；
- 不了解准备语句（Prepared Statement）的工作原理会产生许多额外的数据库访问。


### 9.2 Uint64

Go底层使用`int64`来表示整型，使用`uint64`时应当极其小心。使用超出`int64`表示范围的整数作为参数，会产生一个溢出错误：

```go
// Error: constant 18446744073709551615 overflows int
_, err := db.Exec("INSERT INTO users(id) VALUES", math.MaxUint64) 
```

这种类型的错误非常不容易发现，它可能一开始表现的很正常，但是溢出之后问题就来了。

### 9.3 不合预期的连接状态

连接的状态，例如是否处于事务中，所连接的数据库，设置的变量等，应该通过Go的相关类型来处理，而不是通过SQL语句。用户不应当对自己的查询在哪条连接上执行作任何假设，如果需要在同一条连接上执行，需要使用`Tx`。

举个例子，通过`USE DATABASE`改变连接的数据库对于不少人是习以为常的操作，执行这条语句，只影响当前连接的状态，其他连接仍然访问的是原来的数据库。如果没有使用事务`Tx`，后续的查询并不能保证仍然由当前的连接执行，所以这些查询很可能并不像用户预期的那样工作。

更糟糕的是，如果用户改变了连接的状态，用完之后它成为空连接又回到了连接池，这会污染其他代码的状态。尤其是直接在SQL中执行诸如`BEGIN`或`COMMIT`这样的语句。

### 9.4 驱动的特殊语法

尽管`database/sql`是一个通用的抽象，但不同的数据库，不同的驱动仍然会有不同的语法和行为。参数占位符就是一个例子。

### 9.5 批量操作

出乎意料的是，标准库没有提供对批量操作的支持。即`INSERT INTO xxx VALUES (1),(2),...;`这种一条语句插入多条数据的形式。目前实现这个功能还需要自己手动拼SQL。

### 9.6 执行多条语句

`database/sql`并没有对在一次查询中执行多条SQL语句的显式支持，具体的行为以驱动的实现为准。所以对于

```go
_, err := db.Exec("DELETE FROM tbl1; DELETE FROM tbl2") // Error/unpredictable result
```

这样的查询，怎样执行完全由驱动说了算，用户并无法确定驱动到底执行了什么，又返回了什么。

### 9.7 事务中的多条语句

因为事务保证在它上面执行的查询都由同一个连接来执行，因此事务中的语句必需按顺序一条一条执行。对于返回结果集的查询，结果集必须`Close()`之后才能进行下一次查询。用户如果尝试在前一条语句的结果还没读完前就执行新的查询，连接就会失去同步。这意味着事务中返回结果集的语句都会占用一次单独的网络往返。



## 10. 其他

本文主体基于[[Go database/sql tutorial]]([Go database/sql tutorial])，由我翻译并进行一些增删改，修正过时错误的内容。转载保留出处。