# PostgreSQL 12 声明式分区表


测试，创建一个分区表
```sql
CREATE TABLE users
(
    id       serial NOT NULL,
    username text   NOT NULL,
    password text
)
    PARTITION BY RANGE ( id );


CREATE TABLE users_0 partition OF users (
    id, PRIMARY KEY (id),
    UNIQUE (username)
    )
    FOR VALUES FROM (MINVALUE) TO (10);

CREATE TABLE users_1 PARTITION OF users (
    id, PRIMARY KEY (id),
    UNIQUE (username)
    )
    FOR VALUES FROM (10) TO (20);

INSERT INTO users (username)
SELECT 'user #' || i
FROM generate_series(1, 15) i;

SELECT tableoid, * FROM users;


```