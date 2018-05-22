#!/bin/bash

# import remote schema
/pg/bin/catalog.sh meta 'postgres://postgres:postgres@primary.test.pg:5432/test?id=test001m01'
/pg/bin/catalog.sh meta 'postgres://postgres:postgres@standby.test.pg:5432/test?id=test001s01'
/pg/bin/catalog.sh meta 'postgres://postgres:postgres@offline.test.pg:5432/test?id=test001o01'