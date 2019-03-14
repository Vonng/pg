#!/bin/bash

# import remote schema

if psql 'postgres://postgres:postgres@primary.test.pg:5432/test' -1qAXtc 'SELECT 1;' > /dev/null; then
    /pg/bin/catalog.sh meta 'postgres://postgres:postgres@primary.test.pg:5432/test?id=test001m01'
fi

if psql 'postgres://postgres:postgres@standby.test.pg:5432/test' -1qAXtc 'SELECT 1;' > /dev/null; then
    /pg/bin/catalog.sh meta 'postgres://postgres:postgres@standby.test.pg:5432/test?id=test001s01'
fi

if psql 'postgres://postgres:postgres@offline.test.pg:5432/test' -1qAXtc 'SELECT 1;' > /dev/null; then
    /pg/bin/catalog.sh meta 'postgres://postgres:postgres@offline.test.pg:5432/test?id=test001o01'
fi