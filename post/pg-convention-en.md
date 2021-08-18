

# PostgreSQL Convention

This is a PostgreSQL convention I wrote for previous company. Could be a useful reference when dealing with database. For now it's just an index. detailed information will be traslated when got time.

## **0x00 Background**

> Nothing can be accomplished without norms or standards. 

PostgreSQL is a powerful database. But to make it powerful all the time, it is a team work of Dev, Ops & DBA.

## **0x01 Naming Convention**

> Naming is beginning of everthing.

[REQUIRED] Common naming rule

[REQUIRED] Database naming rule

[REQUIRED] Role naming rule

[REQUIRED] Schema naming rule

[OPTIONAL] Table naming rule

[OPTIONAL] Index naming rule

[OPTIONAL] Function naming rule

[OPTIONAL] Column naming rule

[OPTIONAL] Variable and Parameter naming rule

## **0x02 Designing Convention**

> Suum cuique

[REQUIRED] Character Encoding must be UTF-8

[REQUIRED] Capacity Planning

[REQUIRED] Do not abuse stroed procedure

[REQUIRED] Separation of storage and calculation

[REQUIRED] Primary key and IDENTITY

[REQUIRED] Beware of foreign key

[REQUIRED] Beware of trigger

[REQUIRED] Avoid wide tables

[REQUIRED] Add default value to column

[REQUIRED] Handle nullable with caution

[REQUIRED] Unique constraint should be forced by database

[REQUIRED] Beware of integer overflow

[REQUIRED] Use Timestamp without timezone, force timezone to UTC

[REQUIRED] DROP obsolete function in time

[OPTIONAL] Data Type of primary key

[OPTIONAL] Use proper data types

[OPTIONAL] Use ENUM for stable and small valuespace fields

[OPTIONAL] Choose right text types.

[OPTIONAL] Choose right numeric types

[OPTIONAL] Function format

[OPTIONAL] Design for evolvability

[OPTIONAL] Choose right norm level

[OPTIONAL] Embrace new database version

[OPTIONAL] Use radical feature with caution

[OPTIONAL] Choose right norm level

## **0x03 Indexing Convention**

> Wer Ordnung hält, ist nur zu faul zum Suchen. 

[REQUIRED] OLTP queries must have corresponding index

[REQUIRED] Never build index on wide field

[REQUIRED] Explicit with null ordering

[REQUIRED] Handle KNN problem with GiST index

[OPTIONAL] Make use of function index

[OPTIONAL] Make use of partial index

[OPTIONAL] Make use of BRIN index

[OPTIONAL] Beware of selectivity

## **0x04 Querying Convention**

> The limits of my language mean the limits of my world.

[REQUIRED] Separation of read and write

[REQUIRED] Separation of fast and slow

[REQUIRED] Set timeout for queries

[REQUIRED] Beware of replication lag

[REQUIRED] Use connection pooling

[REQUIRED] Changing connection state is forbidden

[REQUIRED] Have retry mechanism for aborted transaction

[REQUIRED] Have reconnecting mechanism

[REQUIRED] Execute DDL in production application code is forbidden 

[REQUIRED] Using explicit schema names

[REQUIRED] Using explicit table names when involve join

[REQUIRED] Have reconnecting mechanism

[REQUIRED] Full table scan is forbidden in OLTP systems

[REQUIRED] Idle in Transaction for a long time is forbidden

[REQUIRED] Close cursors

[REQUIRED] Beware of NULL

[REQUIRED] Beware of null input on aggragation

[REQUIRED] Beware of hole in serial space

[OPTIONAL] Use prepared statement for repeat queries

[OPTIONAL] Use right isolation levels

[OPTIONAL] Do not tell existance by count

[OPTIONAL] Use returning clause

[OPTIONAL] Use upsert

[OPTIONAL] Use advisory locks to avoid contention

[OPTIONAL] Optimize IN operator

[OPTIONAL] Do not use left fuzzy search

[OPTIONAL] Use array instead of temporary table

## **0x05 Deploying Convention**

[REQUIRED] Follow the deploy procdure

[REQUIRED] Deploy request format

[REQUIRED] Deployment review rules

[REQUIRED] Deployment time window

## **0x06 Operation Convention**

[REQUIRED] Take care of backups

[REQUIRED] Take care of ages

[REQUIRED] Take care of bloats

[REQUIRED] Take care of replication lags

[REQUIRED] Take care of resource consumption

[REQUIRED] Minimal privilege princple

[REQUIRED] CREATE INDEX CONCURRENTLY

[REQUIRED] Warmming before taking real traffic

[REQUIRED] Doing schema migration with caution

[OPTIONAL] Split batch operation

[OPTIONAL] Speed up bulk load