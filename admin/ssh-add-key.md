---
author: "Vonng"
description: "批量配置SSH免密登录"
categories: ["Ops"]
tags: ["PostgreSQL","Bash", "SSH"]
type: "post"
---





# 设置SSH

理想的情况是全部通过公私钥认证，从本地免密码直接连接所有数据库机器。

## 生成公私钥对

首先，使用`ssh-keygen`生成公私钥对

```bash
ssh-keygen -t rsa
```

### 注意权限

ssh内文件的权限应当设置为`0600`，`.ssh`目录的权限应当设置为`0700`，设置失当会导致免密登录无法使用。



## 配置ssh config穿透跳板机

把`User`换成自己的名字。放入`.ssh/config`，这里给出了有跳板机环境下配置生产网数据库免密直连的方式：

```bash
# Vonng's ssh config

# SpringBoard IP
Host <BastionIP>
	Hostname <your_ip_address>
	IdentityFile ~/.ssh/id_rsa

# Target Machine Wildcard (Proxy via Bastion)
Host 10.xxx.xxx.*
	ProxyCommand ssh <BastionIP> exec nc %h %p 2>/dev/null
	IdentityFile ~/.ssh/id_rsa

# Common Settings
Host *
	User xxxxxxxxxxxxxx
	PreferredAuthentications publickey,password
	Compression yes
	ServerAliveInterval 30
	ControlMaster auto
	ControlPath ~/.ssh/ssh-%r@%h:%p
	ControlPersist yes
	StrictHostKeyChecking no
```



## 将公钥拷贝到目标机器上

然后将公钥拷贝到跳板机，DBA工作机，所有数据库机器上。

```bash
ssh-copy-id <target_ip>
```

每次执行此命令都会要求输入密码，非常繁琐无聊，可以通过expect 脚本进行自动化



## 使用expect自动化

将下列脚本中的`<your password>`替换为你自己的密码。如果服务器IP列表有变化，修改列表即可。

```bash
#!/usr/bin/expect
foreach id { 
     10.xxx.xxx.xxx
     10.xxx.xxx.xxx
     10.xxx.xxx.xxx
} {
    spawn ssh-copy-id $id
    expect {
    	"*(yes/no)?*"
    	{
            send "yes\n"
            expect "*assword:" { send "<your password>\n"}
    	}
     	"*assword*" { send "<your password>\n"}
    }
}

exit
```

