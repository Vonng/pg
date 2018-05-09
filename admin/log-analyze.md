---
author: "Vonng"
description: "PostgreSQL日志分析"
categories: ["DBA"]
tags: ["PostgreSQL","Log"]
type: "post"
---



# PostgreSQL日志数据分析



建议配置PostgreSQL的日志格式为CSV，方便分析，而且可以直接导入PostgreSQL数据表中。



## 使用PostgreSQL存储PostgreSQL日志

很有趣的想法，将CSV日志弄成PostgreSQL表，对于分析而言非常方便。

原始的csv日志格式定义如下：

```sql
日志表的结构定义
create table postgresql_log
(
  log_time               timestamp,
  user_name              text,
  database_name          text,
  process_id             integer,
  connection_from        text,
  session_id             text   not null,
  session_line_num       bigint not null,
  command_tag            text,
  session_start_time     timestamp with time zone,
  virtual_transaction_id text,
  transaction_id         bigint,
  error_severity         text,
  sql_state_code         text,
  message                text,
  detail                 text,
  hint                   text,
  internal_query         text,
  internal_query_pos     integer,
  context                text,
  query                  text,
  query_pos              integer,
  location               text,
  application_name       text,
  PRIMARY KEY (session_id, session_line_num)
);
```



## 导入日志

日志是结构良好的CSV，（CSV允许跨行记录），直接使用COPY命令导入即可。

```sql
COPY postgresql_log FROM '/var/lib/pgsql/data/pg_log/postgresql.log' CSV DELIMITER ',';
```





## 加工日志

可以使用以下存储过程从日志消息中进一步提取语句的执行时间

```sql
CREATE OR REPLACE FUNCTION extract_duration(statement TEXT)
  RETURNS FLOAT AS $$
DECLARE
  found_duration BOOLEAN;
BEGIN
  SELECT position('duration' in statement) > 0
  into found_duration;
  IF found_duration
  THEN
    RETURN (SELECT regexp_matches [1] :: FLOAT
            FROM regexp_matches(statement, 'duration: (.*) ms')
            LIMIT 1);
  ELSE
    RETURN NULL;
  END IF;
END
$$
LANGUAGE plpgsql
IMMUTABLE;


CREATE OR REPLACE FUNCTION extract_statement(statement TEXT)
  RETURNS TEXT AS $$
DECLARE
  found_statement BOOLEAN;
BEGIN
  SELECT position('statement' in statement) > 0
  into found_statement;
  IF found_statement
  THEN
    RETURN (SELECT regexp_matches [1]
            FROM regexp_matches(statement, 'statement: (.*)')
            LIMIT 1);
  ELSE
    RETURN NULL;
  END IF;
END
$$
LANGUAGE plpgsql
IMMUTABLE;


CREATE OR REPLACE FUNCTION extract_ip(app_name TEXT)
  RETURNS TEXT AS $$
DECLARE
  ip TEXT;
BEGIN
  SELECT regexp_matches [1]
  into ip
  FROM regexp_matches(app_name, '(\d+\.\d+\.\d+\.\d+)')
  LIMIT 1;
  RETURN ip;
END
$$
LANGUAGE plpgsql
IMMUTABLE;
```

