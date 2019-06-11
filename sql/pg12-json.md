# PostgreSQL 12 JSON

PostgreSQL 12 已经正式放出了[Beta1测试版本](https://ftp.postgresql.org/pub/snapshot/dev/postgresql-snapshot.tar.gz)。PostgreSQL12带来了很多给力的新功能，其中最有吸引力的特性之一莫过于新的JSONPATH支持。在以前的版本中，虽说PostgreSQL在JSON功能的支持上已经很不错了，但要实现一些特定的功能，还是需要写复杂难懂的SQL或者存储过程才能实现。

有了JSONPATH，PostgreSQL用户就能以一种简洁而高效的方式操作JSON数据。





### 8.14.6。jsonpath类型



该`jsonpath`类型实现了对PostgreSQL中 SQL / JSON路径语言的支持，以有效地查询JSON数据。它提供了已解析的SQL / JSON路径表达式的二进制表示，该表达式指定路径引擎从JSON数据中检索的项目，以便使用SQL / JSON查询函数进行进一步处理。

SQL / JSON路径语言完全集成到SQL引擎中：其谓词和运算符的语义通常遵循SQL。同时，为了提供一种最自然的JSON数据处理方式，SQL / JSON路径语法使用了一些JavaScript约定：

- Dot `.`用于成员访问。
- 方括号`[]`用于数组访问。
- SQL / JSON数组是0相对的，不像从1开始的常规SQL数组。

SQL / JSON路径表达式是SQL字符串文字，因此在传递给SQL / JSON查询函数时必须用单引号括起来。遵循JavaScript约定，路径表达式中的字符串文字必须用双引号括起来。此字符串文字中的任何单引号必须使用SQL约定的单引号进行转义。

路径表达式由一系列路径元素组成，可以是以下内容：

- JSON基元类型的路径文字：Unicode文本，数字，true，false或null。
- 路径变量列于[表8.24](https://www.postgresql.org/docs/devel/datatype-json.html#TYPE-JSONPATH-VARIABLES)。
- [表8.25中](https://www.postgresql.org/docs/devel/datatype-json.html#TYPE-JSONPATH-ACCESSORS)列出了访问者运算符。
- `jsonpath`[第9.15.1.2节中](https://www.postgresql.org/docs/devel/functions-json.html#FUNCTIONS-SQLJSON-PATH-OPERATORS)列出的运算符和方法
- 括号，可用于提供过滤器表达式或定义路径评估的顺序。

有关在`jsonpath`SQL / JSON查询函数中使用表达式的详细信息，请参见[第9.15.1节](https://www.postgresql.org/docs/devel/functions-json.html#FUNCTIONS-SQLJSON-PATH)。

**表8.24。 jsonpath变量**

| 变量       | 描述                                                         |
| ---------- | ------------------------------------------------------------ |
| `$`        | 表示要查询的JSON文本的变量（*上下文项*）。                   |
| `$varname` | 一个命名变量。其值必须在`PASSING`SQL / JSON查询函数的子句中设置。详情。 |
| `@`        | 表示过滤器表达式中路径评估结果的变量。                       |

**表8.25。 jsonpath访问器**

| 访问者操作员                                                 | 描述                                                         |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `.*key*``."$*varname*"`                                      | 成员访问器，返回具有指定键的对象成员。如果键名是以符号`$`或不符合标识符的JavaScript规则的命名变量，则必须将其括在双引号中作为字符串文字。 |
| `.*`                                                         | 通配符成员访问器，返回位于当前对象顶级的所有成员的值。       |
| `.**`                                                        | 递归通配符成员访问器，它处理当前对象的所有级别的JSON层次结构，并返回所有成员值，而不管其嵌套级别如何。这是SQL / JSON标准的PostgreSQL扩展。 |
| `.**{*level*}``.**{*lower_level* to*upper_level*}``.**{*lower_level* to last}` | 与`.**`，但是使用JSON层次结构的嵌套级别进行过滤。级别指定为整数。零级别对应于当前对象。这是SQL / JSON标准的PostgreSQL扩展。 |
| `[*subscript*, ...]`                                         | 数组元素访问器。`*subscript*`可能有两种形式：`*expr*`或。第一种形式通过索引指定单个数组元素。第二种形式通过索引范围指定数组切片。零索引对应于第一个数组元素。`*lower_expr* to *upper_expr*`下标中的表达式可以包括整数，数值表达式或`jsonpath`返回单个数值的任何其他表达式。的`last`关键字可以在表达式表示在阵列中的最后一个下标来使用。这对处理未知长度的数组很有帮助。 |
| `[*]`                                                        | 返回所有数组元素的通配符数组元素访问器。                     |

------

[[6\]](https://www.postgresql.org/docs/devel/datatype-json.html#id-1.5.7.22.18.9.3)为此，术语 “ 值 ”包括数组元素，尽管JSON术语有时会认为数组元素与对象内的值不同。