---
title: "Bash与psql小技巧"
date: 2018-04-07
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  一些PostgreSQL与Bash交互的技巧。
---



一些PostgreSQL与Bash交互的技巧。



## 使用严格模式编写Bash脚本

使用[Bash严格模式](http://redsymbol.net/articles/unofficial-bash-strict-mode/)，可以避免很多无谓的错误。在Bash脚本开始的地方放上这一行很有用：

```bash
set -euo pipefail
```

- `-e`：当程序返回非0状态码时报错退出
- `-u`：使用未初始化的变量时报错，而不是当成NULL
- `-o pipefail`：使用Pipe中出错命令的状态码（而不是最后一个）作为整个Pipe的状态码[^i]。

[^i]: 管道程序的退出状态放置在环境变量数组`PIPESTATUS`中



## 执行SQL脚本的Bash包装脚本

通过psql运行SQL脚本时，我们期望有这么两个功能：

1. 能向脚本中传入变量
2. 脚本出错后立刻中止（而不是默认行为的继续执行）

这里给出了一个实际例子，包含了上述两个特性。使用Bash脚本进行包装，传入两个参数。

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ $# != 2 ]; then
    echo "please enter a db host and a table suffix"
    exit 1
fi

export DBHOST=$1
export TSUFF=$2

psql \
    -X \
    -U user \
    -h $DBHOST \
    -f /path/to/sql/file.sql \
    --echo-all \
    --set AUTOCOMMIT=off \
    --set ON_ERROR_STOP=on \
    --set TSUFF=$TSUFF \
    --set QTSTUFF=\'$TSUFF\' \
    mydatabase

psql_exit_status = $?

if [ $psql_exit_status != 0 ]; then
    echo "psql failed while trying to run this sql script" 1>&2
    exit $psql_exit_status
fi

echo "sql script successful"
exit 0
```

一些要点：

- 参数`TSTUFF`会传入SQL脚本中，同时作为一个裸值和一个单引号包围的值，因此，裸值可以当成表名，模式名，引用值可以当成字符串值。
- 使用`-X`选项确保当前用户的`.psqlrc`文件不会被自动加载
- 将所有消息打印到控制台，这样可以知道脚本的执行情况。(失效的时候很管用)
- 使用`ON_ERROR_STOP`选项，当出问题时立即终止。
- 关闭`AUTOCOMMIT`，所以SQL脚本文件不会每一行都提交一次。取而代之的是SQL脚本中出现`COMMIT`时才提交。如果希望整个脚本作为一个事务提交，在sql脚本最后一行加上`COMMIT`（其它地方不要加），否则整个脚本就会成功运行却什么也没提交（自动回滚）。也可以使用`--single-transaction`标记来实现。

`/path/to/sql/file.sql`的内容如下:

```sql
begin;
drop index this_index_:TSUFF;
commit;

begin;
create table new_table_:TSUFF (
    greeting text not null default '');
commit;

begin;
insert into new_table_:TSUFF (greeting)
values ('Hello from table ' || :QTSUFF);
commit;
```



## 使用PG环境变量让脚本更简练

使用PG环境变量非常方便，例如用`PGUSER`替代`-U <user>`，用`PGHOST`替代`-h <host>`，用户可以通过修改环境变量来切换数据源。还可以通过Bash为这些环境变量提供默认值。

```bash
#!/bin/bash

set -euo pipefail

# Set these environmental variables to override them,
# but they have safe defaults.
export PGHOST=${PGHOST-localhost}
export PGPORT=${PGPORT-5432}
export PGDATABASE=${PGDATABASE-my_database}
export PGUSER=${PGUSER-my_user}
export PGPASSWORD=${PGPASSWORD-my_password}

RUN_PSQL="psql -X --set AUTOCOMMIT=off --set ON_ERROR_STOP=on "

${RUN_PSQL} <<SQL
select blah_column 
  from blahs 
 where blah_column = 'foo';
rollback;
SQL
```



## 在单个事务中执行一系列SQL命令

你有一个写满SQL的脚本，希望将整个脚本作为单个事务执行。一种经常出现的情况是在最后忘记加一行`COMMIT`。一种解决办法是使用`—single-transaction`标记：

```bash
psql \
    -X \
    -U myuser \
    -h myhost \
    -f /path/to/sql/file.sql \
    --echo-all \
    --single-transaction \
    --set AUTOCOMMIT=off \
    --set ON_ERROR_STOP=on \
    mydatabase
```

`file.sql`的内容变为：

```bash
insert into foo (bar) values ('baz');
insert into yikes (mycol) values ('hello');
```

两条插入都会被包裹在同一对`BEGIN/COMMIT`中。



## 让多行SQL语句更美观

```bash
#!/usr/bin/env bash
set -euo pipefail

RUN_ON_MYDB="psql -X -U myuser -h myhost --set ON_ERROR_STOP=on --set AUTOCOMMIT=off mydb"

$RUN_ON_MYDB <<SQL
drop schema if exists new_my_schema;
create table my_new_schema.my_new_table (like my_schema.my_table);
create table my_new_schema.my_new_table2 (like my_schema.my_table2);
commit;
SQL

# 使用'包围的界定符意味着HereDocument中的内容不会被Bash转义。
$RUN_ON_MYDB <<'SQL'
create index my_new_table_id_idx on my_new_schema.my_new_table(id);
create index my_new_table2_id_idx on my_new_schema.my_new_table2(id);
commit;
SQL
```

也可以使用Bash技巧，将多行语句赋值给变量，并稍后使用。

注意，Bash会自动清除多行输入中的换行符。实际上整个Here Document中的内容在传输时会重整为一行，你需要添加合适的分隔符，例如分号，来避免格式被搞乱。

```bash
CREATE_MY_TABLE_SQL=$(cat <<EOF
    create table foo (
        id bigint not null,
        name text not null
    );
EOF
)

$RUN_ON_MYDB <<SQL
$CREATE_MY_TABLE_SQL
commit;
SQL
```



## 如何将单个SELECT标量结果赋值给Bash变量

```bash
CURRENT_ID=$($PSQL -X -U $PROD_USER -h myhost -P t -P format=unaligned $PROD_DB -c "select max(id) from users")
let NEXT_ID=CURRENT_ID+1
echo "next user.id is $NEXT_ID"

echo "about to reset user id sequence on other database"
$PSQL -X -U $DEV_USER $DEV_DB -c "alter sequence user_ids restart with $NEXT_ID"
```



## 如何将单行结果赋给Bash变量

并且每个变量都以列名命名。

```bash
read username first_name last_name <<< $(psql \
    -X \
    -U myuser \
    -h myhost \
    -d mydb \
    --single-transaction \
    --set ON_ERROR_STOP=on \
    --no-align \
    -t \
    --field-separator ' ' \
    --quiet \
    -c "select username, first_name, last_name from users where id = 5489")

echo "username: $username, first_name: $first_name, last_name: $last_name"
```

也可以使用数组的方式

```bash
#!/usr/bin/env bash
set -euo pipefail

declare -a ROW=($(psql \
    -X \
    -h myhost \
    -U myuser \
    -c "select username, first_name, last_name from users where id = 5489" \
    --single-transaction \
    --set AUTOCOMMIT=off \
    --set ON_ERROR_STOP=on \
    --no-align \
    -t \
    --field-separator ' ' \
    --quiet \
    mydb))

username=${ROW[0]}
first_name=${ROW[1]}
last_name=${ROW[2]}

echo "username: $username, first_name: $first_name, last_name: $last_name"
```



## 如何在Bash脚本中迭代查询结果集

```bash
#!/usr/bin/env bash
set -euo pipefail
PSQL=/usr/bin/psql

DB_USER=myuser
DB_HOST=myhost
DB_NAME=mydb

$PSQL \
    -X \
    -h $DB_HOST \
    -U $DB_USER \
    -c "select username, password, first_name, last_name from users" \
    --single-transaction \
    --set AUTOCOMMIT=off \
    --set ON_ERROR_STOP=on \
    --no-align \
    -t \
    --field-separator ' ' \
    --quiet \
    -d $DB_NAME \
| while read username password first_name last_name ; do
    echo "USER: $username $password $first_name $last_name"
done
```

也可以读进数组里：

```bash
#!/usr/bin/env bash
set -euo pipefail

PSQL=/usr/bin/psql

DB_USER=myuser
DB_HOST=myhost
DB_NAME=mydb

$PSQL \
    -X \
    -h $DB_HOST \
    -U $DB_USER \
    -c "select username, password, first_name, last_name from users" \
    --single-transaction \
    --set AUTOCOMMIT=off \
    --set ON_ERROR_STOP=on \
    --no-align \
    -t \
    --field-separator ' ' \
    --quiet \
    $DB_NAME | while read -a Record ; do

    username=${Record[0]}
    password=${Record[1]}
    first_name=${Record[2]}
    last_name=${Record[3]}

    echo "USER: $username $password $first_name $last_name"
done
```



## 如何使用状态表来控制多个PG任务

假设你有一份如此之大的工作，以至于你一次只想做一件事。 您决定一次可以完成一项任务，而这对数据库来说更容易，而不是执行一个长时间运行的查询。 您创建一个名为my_schema.items_to_process的表，其中包含要处理的每个项目的item_id，并且您将一列添加到名为done的items_to_process表中，该表默认为false。 然后，您可以使用脚本从items_to_process中获取每个未完成项目，对其进行处理，然后在items_to_process中将该项目更新为done = true。 一个bash脚本可以这样做：

```bash
#!/usr/bin/env bash
set -euo pipefail

PSQL="/u99/pgsql-9.1/bin/psql"
DNL_TABLE="items_to_process"
#DNL_TABLE="test"
FETCH_QUERY="select item_id from my_schema.${DNL_TABLE} where done is false limit 1"

process_item() {
    local item_id=$1
    local dt=$(date)
    echo "[${dt}] processing item_id $item_id"
    $PSQL -X -U myuser -h myhost -c "insert into my_schema.thingies select thingie_id, salutation, name, ddr from thingies where item_id = $item_id and salutation like 'Mr.%'" mydb
}

item_id=$($PSQL -X -U myuser -h myhost -P t -P format=unaligned -c "${FETCH_QUERY}" mydb)
dt=$(date)
while [ -n "$item_id" ]; do
    process_item $item_id
    echo "[${dt}] marking item_id $item_id as done..."
    $PSQL -X -U myuser -h myhost -c "update my_schema.${DNL_TABLE} set done = true where item_id = $item_id" mydb
    item_id=$($PSQL -X -U myuser -h myhost -P t -P format=unaligned -c "${FETCH_QUERY}" mydb)
    dt=$(date)
done
```



## 跨数据库拷贝表

有很多方式可以实现这一点，利用`psql`的`\copy`命令可能是最简单的方式。假设你有两个数据库`olddb`与`newdb`，有一张`users`表需要从老库同步到新库。如何用一条命令实现：

```bash
psql \
    -X \
    -U user \
    -h oldhost \
    -d olddb \
    -c "\\copy users to stdout" \
| \
psql \
    -X \
    -U user \
    -h newhost \
    -d newdb \
    -c "\\copy users from stdin"

```

一个更困难的例子：假如你的表在老数据库中有三列：`first_name`, `middle_name`, `last_name`。

但在新数据库中只有两列，`first_name`，`last_name`，则可以使用：

```bash
psql \
    -X \
    -U user \
    -h oldhost \
    -d olddb \
    -c "\\copy (select first_name, last_name from users) to stdout" \
| \
psql \
    -X \
    -U user \
    -h newhost \
    -d newdb \
    -c "\\copy users from stdin"

```



## 获取表定义的方式

```bash
pg_dump \
    -U db_user \
    -h db_host \
    -p 55432 \
    --table my_table \
    --schema-only my_db
```



## 将bytea列中的二进制数据导出到文件

注意`bytea`列，在PostgreSQL 9.0 以上是使用十六进制表示的，带有一个恼人的前缀`\x`，可以用`substring`去除。

```bash
#!/usr/bin/env bash
set -euo pipefail

psql \
    -P t \
    -P format=unaligned \
    -X \
    -U myuser \
    -h myhost \
    -c "select substring(my_bytea_col::text from 3) from my_table where id = 12" \
    mydb \
| xxd -r -p > dump.txt

```

## 将文件内容作为一个列的值插入

有两种思路完成这件事，第一种是在外部拼SQL，第二种是在脚本中作为变量。

```sql
CREATE TABLE sample(
	filename	INTEGER,
    value		JSON
);
```

```bash
psql <<SQL
\set content `cat ${filename}`
INSERT INTO sample VALUES(\'${filename}\',:'content')
SQL
```



## 显示特定数据库中特定表的统计信息

```bash
#!/usr/bin/env bash
set -euo pipefail
if [ -z "$1" ]; then
    echo "Usage: $0 table [db]"
    exit 1
fi

SCMTBL="$1"
SCHEMANAME="${SCMTBL%%.*}"  # everything before the dot (or SCMTBL if there is no dot)
TABLENAME="${SCMTBL#*.}"  # everything after the dot (or SCMTBL if there is no dot)

if [ "${SCHEMANAME}" = "${TABLENAME}" ]; then
    SCHEMANAME="public"
fi

if [ -n "$2" ]; then
    DB="$2"
else
    DB="my_default_db"
fi

PSQL="psql -U my_default_user -h my_default_host -d $DB -x -c "

$PSQL "
select '-----------' as \"-------------\", 
       schemaname,
       tablename,
       attname,
       null_frac,
       avg_width,
       n_distinct,
       correlation,
       most_common_vals,
       most_common_freqs,
       histogram_bounds
  from pg_stats
 where schemaname='$SCHEMANAME'
   and tablename='$TABLENAME';
" | grep -v "\-\[ RECORD "

```

使用方式

```bash
./table-stats.sh myschema.mytable
```

对于public模式中的表

```bash
./table-stats.sh mytable
```

连接其他数据库

```bash
./table-stats.sh mytable myotherdb
```



## 将psql的默认输出转换为Markdown表格

```bash
alias pg2md=' sed '\''s/+/|/g'\'' | sed '\''s/^/|/'\'' | sed '\''s/$/|/'\'' |  grep -v rows | grep -v '\''||'\'''

# Usage
psql -c 'SELECT * FROM pg_database' | pg2md
```

输出的结果贴到Markdown编辑器即可。