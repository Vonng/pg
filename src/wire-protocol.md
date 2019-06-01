# PostgreSQL前后端通信协议



## 启动阶段

### 基本流程

* 客户端发送一条`StartupMessage (F)`向服务端发起连接请求

  载荷包括`0x30000`的Int32版本号魔数，以及一系列kv结构的运行时参数（NULL0分割，必须参数为`user`），

* 客户端等待服务端响应，主要是等待服务端发送的`ReadyForQuery (Z)`事件，该事件代表服务端已经准备好接收请求。

上面是连接建立过程中最主要的两个事件，其他事件包括包括认证消息 `AuthenticationXXX (R)` ，后端密钥消息 `BackendKeyData (K)`，错误消息`ErrorResponse (E)`，一系列上下文无关消息（`NoticeResponse (N)`，`NotificationResponse (A)`，`ParameterStatus(S)`）



编写一个模拟这一过程

```go
package main

import (
	"fmt"
	"net"
	"time"

	"github.com/jackc/pgx/pgproto3"
)

func GetFrontend(address string) *pgproto3.Frontend {
	conn, _ := (&net.Dialer{KeepAlive: 5 * time.Minute}).Dial("tcp4", address)
	frontend, _ := pgproto3.NewFrontend(conn, conn)
	return frontend
}

func main() {
	frontend := GetFrontend("127.0.0.1:5432")

	// 建立连接
	startupMsg := &pgproto3.StartupMessage{
		ProtocolVersion: pgproto3.ProtocolVersionNumber,
		Parameters:      map[string]string{"user": "vonng"},
	}
	frontend.Send(startupMsg)

	// 启动过程，收到ReadyForQuery消息代表启动过程结束
	for {
		msg, _ := frontend.Receive()
		fmt.Printf("%T %v\n", msg, msg)
		if _, ok := msg.(*pgproto3.ReadyForQuery); ok {
			fmt.Println("[STARTUP] connection established")
			break
		}
	}

	// 简单查询协议
	simpleQueryMsg := &pgproto3.Query{String: `SELECT 1 as a;`}
	frontend.Send(simpleQueryMsg)
	// 收到CommandComplete消息代表查询结束
	for {
		msg, _ := frontend.Receive()
		fmt.Printf("%T %v\n", msg, msg)
		if _, ok := msg.(*pgproto3.CommandComplete); ok {
			fmt.Println("[QUERY] query complete")
			break
		}
	}
}

```

输出结果为：

```bash
*pgproto3.Authentication &{0 [0 0 0 0] [] []}
*pgproto3.ParameterStatus &{application_name }
*pgproto3.ParameterStatus &{client_encoding UTF8}
*pgproto3.ParameterStatus &{DateStyle ISO, MDY}
*pgproto3.ParameterStatus &{integer_datetimes on}
*pgproto3.ParameterStatus &{IntervalStyle postgres}
*pgproto3.ParameterStatus &{is_superuser on}
*pgproto3.ParameterStatus &{server_encoding UTF8}
*pgproto3.ParameterStatus &{server_version 11.3}
*pgproto3.ParameterStatus &{session_authorization vonng}
*pgproto3.ParameterStatus &{standard_conforming_strings on}
*pgproto3.ParameterStatus &{TimeZone PRC}
*pgproto3.BackendKeyData &{35703 345830596}
*pgproto3.ReadyForQuery &{73}
[STARTUP] connection established
*pgproto3.RowDescription &{[{a 0 0 23 4 -1 0}]}
*pgproto3.DataRow &{[[49]]}
*pgproto3.CommandComplete &{SELECT 1}
[QUERY] query complete
```



## 连接代理

 可以在`jackc/pgx/pgproto3`的基础上，很轻松地编写一些中间件。例如下面的代码就是一个非常简单的“连接代理”：

```sql
package main

import (
	"io"
	"net"
	"strings"
	"time"

	"github.com/jackc/pgx/pgproto3"
)

type ProxyServer struct {
	UpstreamAddr string
	ListenAddr   string
	Listener     net.Listener
	Dialer       net.Dialer
}

func NewProxyServer(listenAddr, upstreamAddr string) *ProxyServer {
	ln, _ := net.Listen(`tcp4`, listenAddr)
	return &ProxyServer{
		ListenAddr:   listenAddr,
		UpstreamAddr: upstreamAddr,
		Listener:     ln,
		Dialer:       net.Dialer{KeepAlive: 1 * time.Minute},
	}
}

func (ps *ProxyServer) Serve() error {
	for {
		conn, err := ps.Listener.Accept()
		if err != nil {
			panic(err)
		}
		go ps.ServeOne(conn)
	}
}

func (ps *ProxyServer) ServeOne(clientConn net.Conn) error {
	backend, _ := pgproto3.NewBackend(clientConn, clientConn)
	startupMsg, err := backend.ReceiveStartupMessage()
	if err != nil && strings.Contains(err.Error(), "ssl") {
		if _, err := clientConn.Write([]byte(`N`)); err != nil {
			panic(err)
		}
		// ssl is not welcome, now receive real startup msg
		startupMsg, err = backend.ReceiveStartupMessage()
		if err != nil {
			panic(err)
		}
	}

	serverConn, _ := ps.Dialer.Dial(`tcp4`, ps.UpstreamAddr)
	frontend, _ := pgproto3.NewFrontend(serverConn, serverConn)
	frontend.Send(startupMsg)

	errChan := make(chan error, 2)
	go func() {
		_, err := io.Copy(clientConn, serverConn)
		errChan <- err
	}()
	go func() {
		_, err := io.Copy(serverConn, clientConn)
		errChan <- err
	}()

	return <-errChan
}

func main() {
	proxy := NewProxyServer("127.0.0.1:5433", "127.0.0.1:5432")
	proxy.Serve()
}

```

这里代理监听5433端口，并将消息解析并转发至在5432端口的真实的数据库服务器。在另一个Session中执行以下命令：

```bash
$ psql postgres://127.0.0.1:5433/data?sslmode=disable -c 'SELECT * FROM pg_stat_activity LIMIT 1;'
```

可以观察到这一过程中的消息往来：

```
[B2F] *pgproto3.ParameterStatus &{application_name psql}
[B2F] *pgproto3.ParameterStatus &{client_encoding UTF8}
[B2F] *pgproto3.ParameterStatus &{DateStyle ISO, MDY}
[B2F] *pgproto3.ParameterStatus &{integer_datetimes on}
[B2F] *pgproto3.ParameterStatus &{IntervalStyle postgres}
[B2F] *pgproto3.ParameterStatus &{is_superuser on}
[B2F] *pgproto3.ParameterStatus &{server_encoding UTF8}
[B2F] *pgproto3.ParameterStatus &{server_version 11.3}
[B2F] *pgproto3.ParameterStatus &{session_authorization vonng}
[B2F] *pgproto3.ParameterStatus &{standard_conforming_strings on}
[B2F] *pgproto3.ParameterStatus &{TimeZone PRC}
[B2F] *pgproto3.BackendKeyData &{41588 1354047533}
[B2F] *pgproto3.ReadyForQuery &{73}
[F2B] *pgproto3.Query &{SELECT * FROM pg_stat_activity LIMIT 1;}
[B2F] *pgproto3.RowDescription &{[{datid 11750 1 26 4 -1 0} {datname 11750 2 19 64 -1 0} {pid 11750 3 23 4 -1 0} {usesysid 11750 4 26 4 -1 0} {usename 11750 5 19 64 -1 0} {application_name 11750 6 25 -1 -1 0} {client_addr 11750 7 869 -1 -1 0} {client_hostname 11750 8 25 -1 -1 0} {client_port 11750 9 23 4 -1 0} {backend_start 11750 10 1184 8 -1 0} {xact_start 11750 11 1184 8 -1 0} {query_start 11750 12 1184 8 -1 0} {state_change 11750 13 1184 8 -1 0} {wait_event_type 11750 14 25 -1 -1 0} {wait_event 11750 15 25 -1 -1 0} {state 11750 16 25 -1 -1 0} {backend_xid 11750 17 28 4 -1 0} {backend_xmin 11750 18 28 4 -1 0} {query 11750 19 25 -1 -1 0} {backend_type 11750 20 25 -1 -1 0}]}
[B2F] *pgproto3.DataRow &{[[] [] [52 56 55 52] [] [] [] [] [] [] [50 48 49 57 45 48 53 45 49 56 32 50 48 58 52 56 58 49 57 46 51 50 55 50 54 55 43 48 56] [] [] [] [65 99 116 105 118 105 116 121] [65 117 116 111 86 97 99 117 117 109 77 97 105 110] [] [] [] [] [97 117 116 111 118 97 99 117 117 109 32 108 97 117 110 99 104 101 114]]}
[B2F] *pgproto3.CommandComplete &{SELECT 1}
[B2F] *pgproto3.ReadyForQuery &{73}
[F2B] *pgproto3.Terminate &{}

```

