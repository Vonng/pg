---
title: "PgSQL审计触发器"
date: 2017-06-09
author: |
  [冯若航](http://vonng.com)（[@Vonng](http://vonng.com/en/)）
description: >
  有时候，我们希望记录一些重要的元数据变更，以便事后审计之用。PostgreSQL的触发器就可以很方便地自动解决这一需求。
---

有时候，我们希望记录一些重要的元数据变更，以便事后审计之用。

PostgreSQL的触发器就可以很方便地自动解决这一需求。



```sql
-- 创建一个审计专用schema，并废除所有非superuser的权限。
DROP SCHEMA IF EXISTS audit CASCADE;
CREATE SCHEMA IF NOT EXISTS audit;
REVOKE CREATE ON SCHEMA audit FROM PUBLIC;

-- 审计表
CREATE TABLE audit.action_log (
  schema_name   TEXT                     NOT NULL,
  table_name    TEXT                     NOT NULL,
  user_name     TEXT,
  time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  action        TEXT                     NOT NULL CHECK (action IN ('I', 'D', 'U')),
  original_data TEXT,
  new_data      TEXT,
  query         TEXT
) WITH (FILLFACTOR = 100
);

-- 审计表权限
REVOKE ALL ON audit.action_log FROM PUBLIC;
GRANT SELECT ON audit.action_log TO PUBLIC;


-- 索引
CREATE INDEX logged_actions_schema_table_idx
  ON audit.action_log (((schema_name || '.' || table_name) :: TEXT));

CREATE INDEX logged_actions_time_idx
  ON audit.action_log (time);

CREATE INDEX logged_actions_action_idx
  ON audit.action_log (action);
---------------------------------------------------------------


---------------------------------------------------------------
-- 创建审计触发器函数
---------------------------------------------------------------
CREATE OR REPLACE FUNCTION audit.logger()
  RETURNS TRIGGER AS $body$
DECLARE
  v_old_data TEXT;
  v_new_data TEXT;
BEGIN
  IF (TG_OP = 'UPDATE')
  THEN
    v_old_data := ROW (OLD.*);
    v_new_data := ROW (NEW.*);
    INSERT INTO audit.action_log (schema_name, table_name, user_name, action, original_data, new_data, query)
    VALUES (TG_TABLE_SCHEMA :: TEXT, TG_TABLE_NAME :: TEXT, session_user :: TEXT, substring(TG_OP, 1, 1), v_old_data,
            v_new_data, current_query());
    RETURN NEW;
  ELSIF (TG_OP = 'DELETE')
    THEN
      v_old_data := ROW (OLD.*);
      INSERT INTO audit.action_log (schema_name, table_name, user_name, action, original_data, query)
      VALUES (TG_TABLE_SCHEMA :: TEXT, TG_TABLE_NAME :: TEXT, session_user :: TEXT, substring(TG_OP, 1, 1), v_old_data,
              current_query());
      RETURN OLD;
  ELSIF (TG_OP = 'INSERT')
    THEN
      v_new_data := ROW (NEW.*);
      INSERT INTO audit.action_log (schema_name, table_name, user_name, action, new_data, query)
      VALUES (TG_TABLE_SCHEMA :: TEXT, TG_TABLE_NAME :: TEXT, session_user :: TEXT, substring(TG_OP, 1, 1), v_new_data,
              current_query());
      RETURN NEW;
  ELSE
    RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - Other action occurred: %, at %', TG_OP, now();
    RETURN NULL;
  END IF;

  EXCEPTION
  WHEN data_exception
    THEN
      RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [DATA EXCEPTION] - SQLSTATE: %, SQLERRM: %', SQLSTATE, SQLERRM;
      RETURN NULL;
  WHEN unique_violation
    THEN
      RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [UNIQUE] - SQLSTATE: %, SQLERRM: %', SQLSTATE, SQLERRM;
      RETURN NULL;
  WHEN OTHERS
    THEN
      RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %', SQLSTATE, SQLERRM;
      RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, audit;

COMMENT ON FUNCTION audit.logger() IS '记录特定表上的插入、修改、删除行为';
---------------------------------------------------------------


---------------------------------------------------------------
-- 最后修改时间审计触发器函数
---------------------------------------------------------------
-- 当记录发生变更前，记录修改时间。
CREATE OR REPLACE FUNCTION audit.update_mtime()
  RETURNS TRIGGER AS $$
BEGIN
  NEW.mtime = now();
  RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

COMMENT ON FUNCTION audit.update_mtime() IS '更新记录mtime';
---------------------------------------------------------------


---------------------------------------------------------------
-- 元数据变动事件触发器函数
-- 向'change'信道发送数据变动的表名
---------------------------------------------------------------
CREATE OR REPLACE FUNCTION audit.notify_change()
  RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('change', TG_RELNAME);
  RETURN NULL;
END;
$$ LANGUAGE 'plpgsql';

COMMENT ON FUNCTION audit.notify_change() IS '数据变动事件触发器函数，向`change`信道发送数据变动的表名';
---------------------------------------------------------------
```

