Here is the detail of why that query have O(N^2) inside GIN implementation.

## Details

Inspect the index `example_keys_idx`

```bash
postgres=# select oid,* from pg_class where relname = 'example_keys_idx';
-[ RECORD 1 ]-------+-----------------
oid                 | 20699
relname             | example_keys_idx
relnamespace        | 20692
reltype             | 0
reloftype           | 0
relowner            | 10
relam               | 2742
relfilenode         | 20699
reltablespace       | 0
relpages            | 2051
reltuples           | 300000
relallvisible       | 0
reltoastrelid       | 0
relhasindex         | f
relisshared         | f
relpersistence      | p
relkind             | i
relnatts            | 1
relchecks           | 0
relhasoids          | f
relhasrules         | f
relhastriggers      | f
relhassubclass      | f
relrowsecurity      | f
relforcerowsecurity | f
relispopulated      | t
relreplident        | n
relispartition      | f
relrewrite          | 0
relfrozenxid        | 0
relminmxid          | 0
relacl              |
reloptions          | {fastupdate=off}
relpartbound        |
```

Find index information via index's oid

```bash
postgres=# select * from pg_index where indexrelid = 20699;
-[ RECORD 1 ]--+------
indexrelid     | 20699
indrelid       | 20693
indnatts       | 1
indnkeyatts    | 1
indisunique    | f
indisprimary   | f
indisexclusion | f
indimmediate   | t
indisclustered | f
indisvalid     | t
indcheckxmin   | f
indisready     | t
indislive      | t
indisreplident | f
indkey         | 2
indcollation   | 0
indclass       | 10075
indoption      | 0
indexprs       |
indpred        |
```

Find corresponding operator class for that index via `indclass`

```bash
postgres=# select * from pg_opclass where oid = 10075;
-[ RECORD 1 ]+----------
opcmethod    | 2742
opcname      | array_ops
opcnamespace | 11
opcowner     | 10
opcfamily    | 2745
opcintype    | 2277
opcdefault   | t
opckeytype   | 2283
```

Find four operator corresponding to operator faimily `array_ops`

```
postgres=# select * from pg_amop where amopfamily =2745;
-[ RECORD 1 ]--+-----
amopfamily     | 2745
amoplefttype   | 2277
amoprighttype  | 2277
amopstrategy   | 1
amoppurpose    | s
amopopr        | 2750
amopmethod     | 2742
amopsortfamily | 0
-[ RECORD 2 ]--+-----
amopfamily     | 2745
amoplefttype   | 2277
amoprighttype  | 2277
amopstrategy   | 2
amoppurpose    | s
amopopr        | 2751
amopmethod     | 2742
amopsortfamily | 0
-[ RECORD 3 ]--+-----
amopfamily     | 2745
amoplefttype   | 2277
amoprighttype  | 2277
amopstrategy   | 3
amoppurpose    | s
amopopr        | 2752
amopmethod     | 2742
amopsortfamily | 0
-[ RECORD 4 ]--+-----
amopfamily     | 2745
amoplefttype   | 2277
amoprighttype  | 2277
amopstrategy   | 4
amoppurpose    | s
amopopr        | 1070
amopmethod     | 2742
amopsortfamily | 0
```

https://www.postgresql.org/docs/10/xindex.html

**Table 37.6. GIN Array Strategies**

| Operation       | Strategy Number |
| --------------- | --------------- |
| overlap         | 1               |
| contains        | 2               |
| is contained by | 3               |
| equal           | 4               |

When we access that index with `&&` operator, we are using stragety 1 `overlap`, which corresponding operator oid is `2750`.

```bash
postgres=# select * from pg_operator where oid = 2750;
-[ RECORD 1 ]+-----------------
oprname      | &&
oprnamespace | 11
oprowner     | 10
oprkind      | b
oprcanmerge  | f
oprcanhash   | f
oprleft      | 2277
oprright     | 2277
oprresult    | 16
oprcom       | 2750
oprnegate    | 0
oprcode      | arrayoverlap
oprrest      | arraycontsel
oprjoin      | arraycontjoinsel
```

The underlying C function to judge arrayoverlap is `arrayoverlap` in [here](https://github.com/postgres/postgres/blob/master/src/backend/utils/adt/arrayfuncs.c) 

```c
Datum
arrayoverlap(PG_FUNCTION_ARGS)
{
	AnyArrayType *array1 = PG_GETARG_ANY_ARRAY_P(0);
	AnyArrayType *array2 = PG_GETARG_ANY_ARRAY_P(1);
	Oid			collation = PG_GET_COLLATION();
	bool		result;

	result = array_contain_compare(array1, array2, collation, false,
								   &fcinfo->flinfo->fn_extra);

	/* Avoid leaking memory when handed toasted input. */
	AARR_FREE_IF_COPY(array1, 0);
	AARR_FREE_IF_COPY(array2, 1);

	PG_RETURN_BOOL(result);
}
```

It actually use `array_contain_compare` to test whether two array are overlap

```c
static bool
array_contain_compare(AnyArrayType *array1, AnyArrayType *array2, Oid collation,
					  bool matchall, void **fn_extra)
```

Line 4177, we see a nested loop to iterate two array, which makes it O(N^2)

```c
	for (i = 0; i < nelems1; i++)
	{
		Datum		elt1;
		bool		isnull1;

		/* Get element, checking for NULL */
		elt1 = array_iter_next(&it1, &isnull1, i, typlen, typbyval, typalign);

		/*
		 * We assume that the comparison operator is strict, so a NULL can't
		 * match anything.  XXX this diverges from the "NULL=NULL" behavior of
		 * array_eq, should we act like that?
		 */
		if (isnull1)
		{
			if (matchall)
			{
				result = false;
				break;
			}
			continue;
		}

		for (j = 0; j < nelems2; j++)
```