package main

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/jackc/pgx"
)

type Subscriber struct {
	URL    string
	Slot   string
	Plugin string
	Conn   *pgx.ReplicationConn
	LSN    uint64
}

// Connect 会建立到服务器的复制连接，区别在于自动添加了replication=on|1|yes|dbname参数
func (s *Subscriber) Connect() {
	connConfig, _ := pgx.ParseURI(s.URL)
	s.Conn, _ = pgx.ReplicationConnect(connConfig)
}

// ReportProgress 会向主库汇报写盘，刷盘，应用的进度坐标（消费者偏移量）
func (s *Subscriber) ReportProgress() {
	status, _ := pgx.NewStandbyStatus(s.LSN)
	s.Conn.SendStandbyStatus(status)
}

// CreateReplicationSlot 会创建逻辑复制槽，并使用给定的解码插件
func (s *Subscriber) CreateReplicationSlot() {
	if consistPoint, snapshotName, err := s.Conn.CreateReplicationSlotEx(s.Slot, s.Plugin); err != nil {
		log.Fatalf("fail to create replication slot: %s", err.Error())
	} else {
		log.Printf("create replication slot %s with plugin %s : consist snapshot: %s, snapshot name: %s", s.Slot, s.Plugin, consistPoint, snapshotName)
		s.LSN, _ = pgx.ParseLSN(consistPoint)
	}
}

// StartReplication 会启动逻辑复制（服务器会开始发送事件消息）
func (s *Subscriber) StartReplication() {
	if err := s.Conn.StartReplication(s.Slot, 0, -1); err != nil {
		log.Fatalf("fail to start replication on slot %s : %s", s.Slot, err.Error())
	}
}

// DropReplicationSlot 会使用临时普通连接删除复制槽（如果存在）,注意如果复制连接正在使用这个槽是没法删的。
func (s *Subscriber) DropReplicationSlot() {
	connConfig, _ := pgx.ParseURI(s.URL)
	conn, _ := pgx.Connect(connConfig)
	var slotExists bool
	conn.QueryRow(`SELECT EXISTS(SELECT 1 FROM pg_replication_slots WHERE slot_name = $1)`, s.Slot).Scan(&slotExists)
	if slotExists {
		if s.Conn != nil {
			s.Conn.Close()
		}
		conn.Exec("SELECT pg_drop_replication_slot($1)", s.Slot)
	}
}

// Subscribe 开始订阅变更事件，主消息循环
func (s *Subscriber) Subscribe() {
	var message *pgx.ReplicationMessage
	for {
		// 等待一条消息, 消息有可能是真的消息，也可能只是心跳包
		message, _ = s.Conn.WaitForReplicationMessage(context.Background())
		if message.WalMessage != nil {
			// 如果是真的消息就消费它，可能是成功写入kafka，或者只是简单地打印出来。
			log.Printf("[LSN] %s [Message] %s", pgx.FormatLSN(message.WalMessage.WalStart), string(message.WalMessage.WalData))
			if message.WalMessage.WalStart > s.LSN { // 更新消费进度并向主库汇报
				s.LSN = message.WalMessage.WalStart + uint64(len(message.WalMessage.WalData))
				s.ReportProgress()
			}
		}
		if message.ServerHeartbeat != nil && message.ServerHeartbeat.ReplyRequested == 1 {
			s.ReportProgress() // 如果服务器心跳包要求回送进度，则汇报进度
		}
	}
}

func main() {
	dsn := "postgres://localhost:5432/postgres?application_name=cdc"
	plugin := "test_decoding"
	slot := "test_slot"
	if len(os.Args) > 1 {
		dsn = os.Args[1]
	}
	if len(os.Args) > 2 {
		plugin = os.Args[2]
	}
	if len(os.Args) > 3 {
		slot = os.Args[3]
	}

	subscriber := &Subscriber{
		URL:    dsn,
		Slot:   slot,
		Plugin: plugin,
	} // 创建新的CDC客户端
	subscriber.DropReplicationSlot() // 如果存在，清理掉遗留的Slot

	subscriber.Connect()                   // 建立复制连接
	defer subscriber.DropReplicationSlot() // 程序中止前清理掉复制槽
	subscriber.CreateReplicationSlot()     // 创建复制槽
	subscriber.StartReplication()          // 开始接收变更流
	go func() {
		for {
			time.Sleep(5 * time.Second)
			subscriber.ReportProgress()
		}
	}() // 协程2每5秒地向主库汇报进度
	subscriber.Subscribe() // 主消息循环
}

