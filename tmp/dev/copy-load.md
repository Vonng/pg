# PostgreSQL Copy Impl

How to copy a file into PostgreSQL ASAP?

## 0x01 DDL

```sql
DROP TABLE IF EXISTS classic_rock;
CREATE TABLE classic_rock (
  id         varchar(10) PRIMARY KEY,
  callsign   varchar(8),
  fullname   varchar(128),
  song       varchar(128),
  artist     varchar(128),
  song_raw   varchar(128),
  artist_raw varchar(128),
  is_first   boolean,
  mtime      timestamp
);

COMMENT ON TABLE classic_rock IS 'classic rock song list';
COMMENT ON COLUMN classic_rock.id IS 'unique ID of each play, callsign + 4digit';
COMMENT ON COLUMN classic_rock.callsign IS 'station callsign of the song play';
COMMENT ON COLUMN classic_rock.fullname IS 'combined full name: `song` by `artist`';
COMMENT ON COLUMN classic_rock.song IS 'cleansed song title';
COMMENT ON COLUMN classic_rock.artist IS 'cleansed artist title';
COMMENT ON COLUMN classic_rock.song_raw IS 'raw song title text';
COMMENT ON COLUMN classic_rock.artist_raw IS 'raw artist text';
COMMENT ON COLUMN classic_rock.is_first IS 'if it is the first mention of a given song';
COMMENT ON COLUMN classic_rock.mtime IS 'scraped timestamp';

```



## 0x02 Baseline

You can achieve this using `COPY` with psql just like this:

```sql
DROP TABLE IF EXISTS tmp_classic_rock;
CREATE TEMP TABLE tmp_classic_rock (
  song_raw     text,
  song_clean   text,
  artist_raw   text,
  artist_clean text,
  callsign     text,
  time         BIGINT,
  unique_id    text,
  combined     text,
  first        BOOLEAN
);

COPY tmp_classic_rock FROM '/Users/vonng/temp/classic-rock-raw-data.csv' CSV HEADER; 

SET CONSTRAINTS ALL DEFERRED;
INSERT INTO classic_rock
  SELECT
    unique_id          as id,
    callsign,
    combined           as fullname,
    song_clean         as song,
    artist_clean       as artist,
    song_raw,
    artist_raw,
    first              as is_first,
    to_timestamp(time) as time
  FROM tmp_classic_rock;

```

`COPY` takes **65ms** ,  ETL SQL takes **550ms**. Overall time is **615ms**  (or **130ms** without primary key)

### FAQ

- Do you think your program could be optimized to import the data faster? If yes, how?

  Copy protocal would be the best practice in normal case. But there are certain approaches can be used to improve the performance:

  - Using unlogged table to get rid of WAL
  - decrease WAL level
  - increase WAL buffer & max_wal_size
  - using copy protocol
  - Generate data in binary format directly, Just like what HBaseBulkLoad Does.

- Do you notice any problems with the data? If yes, how would you go about fixing them?

  - Bad taste for field names. (rename, rearrange)
  - Duplicated data (dedupe)
  - Use `\r` as line sep. (replace it with `\n`)
  - If there's a `*_raw` field, the `*_clean` field should have that field as fallback. (do it so)
  - Field `combined` depends on `sign_clean` & `artist_clean`  , and does not handle `NULL` case properly (use calcuated field instead)
  - Use `integer/bigint` epoch as timestamp. (use timestamp instead)

- Do you think your database schema could be improved? How?

  - It depends on what you want: OLTP or OLAP

  - The `id` is composed by `callsign` & `inner sequence`, which violate 1NF requirement.

    > Maybe I'd choose using global identifier  `id`, and treat `callsign` as a normal column. 
    >
    > While it depends. If valid callsign values is stable & limited, Consider using enum type or inheritance table instead. 

  - If the application can handler bad case well (very long string), Then remove varchar length constraint  (using text) could imporve performance.

 

## 0x03 Do it with Go

The idea is simple: CSV Reader → PostgreSQL Writer

The difference is putting  Transform logic in Golang instead of using SQL (0x02)

Using the `encoding/csv` is easy, While this file is using `\r` as line sep. Which requires more work.

Write to postgresql is easy, too, any pg driver would do the trick. (or even use psql directly with pipe)



### The Pipeline Way

To follow the Unix philosophy, Let's start with unix pipeline approach. 

suppose we have a transform program written in golang `pgcopy`：

```go
package main

import (
	"os"
	"io"
	"time"
	"strconv"
	"strings"
	"encoding/csv"
	"database/sql"
	_ "github.com/jackc/pgx/stdlib"
	"github.com/pkg/errors"
)

const timefmt = "2006-01-02 15:04:05"
const batchSQL = `INSERT INTO classic_rock VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9);`

// epochToTime convert unix timestamp str to date str
func epochToTime(timeStr string) string {
	i, err := strconv.ParseInt(timeStr, 10, 64)
	if err != nil {
		return ""
	}
	return time.Unix(i, 0).Format(timefmt)
}

// CleanseReader is wrapper for transforming data
type CleanseReader struct {
	Raw io.Reader
	Csv *csv.Reader
}

// NewCleanseReader constructor
func NewCleanseReader(input io.Reader) *CleanseReader {
	var cr CleanseReader
	cr.Raw = input
	cr.Csv = csv.NewReader(&cr)
	return &cr
}

// Read convert \r to \n
func (cr *CleanseReader) Read(p []byte) (n int, err error) {
	n, err = cr.Raw.Read(p)
	for i := 0; i < len(p); i++ {
		if p[i] == '\r' {
			p[i] = '\n'
		}
	}
	return n, err
}

// ReadNext record and do transform
func (cr *CleanseReader) ReadNext() ([]string, error) {
	input, err := cr.Csv.Read()
	if err != nil {
		return nil, err
	}
	output := make([]string, len(input))
	song, artist := strings.TrimSpace(input[1]), strings.TrimSpace(input[3])
	var fullname string

	if song == "" {
		song = input[0]
	}

	if artist == "" {
		artist = input[2]
	}

	if song != "" {
		if artist != "" {
			fullname = song + " by " + artist
		} else {
			fullname = song
		}
	} else {
		// whether artist name is exist, ' by xxx' would be weird
		fullname = ""
	}

	output[0] = input[6]              // unique_id as id
	output[1] = input[4]              // callsign
	output[2] = fullname              // fullname
	output[3] = song                  // song
	output[4] = artist                // artist
	output[5] = input[0]              // song_raw
	output[6] = input[2]              // artist_raw
	output[7] = input[8]              // is_first
	output[8] = epochToTime(input[5]) // mtime

	return output, nil
}

// PipeMode read csv from stdin and put it to stdout
func PipeMode() error {
	r := NewCleanseReader(os.Stdin)
	w := csv.NewWriter(os.Stdout)

	var err error
	var row []string

	row, err = r.ReadNext() // get first line ready
	for ; err == nil; row, err = r.ReadNext() {
		w.Write(row)
	}
	if err != nil && err != io.EOF {
		return errors.Wrap(err, "parse input csv failed")
	}
	w.Flush()
	return nil
}

// BatchMode use batch insert commit
func BatchMode() error {
	if len(os.Args) != 3 {
		return errors.New(`batch mode requires args: filepath & pgURL`)
	}
	filepath, pgURL := os.Args[1], os.Args[2]

	f, err := os.Open(filepath)
	if err != nil {
		return errors.Wrap(err, "invalid filename")
	}
	defer f.Close()

	db, err := sql.Open("pgx", pgURL)
	if err != nil {
		return errors.Wrap(err, "invalid postgres URL")
	}
	defer db.Close()

	if _, err = db.Exec(`TRUNCATE classic_rock;`); err != nil {
		return errors.Wrap(err, "truncate failed")
	}

	r := NewCleanseReader(f)
	var row []string

	row, err = r.ReadNext() // get first line ready
	row, err = r.ReadNext() // skip header line
	for ; err == nil; row, err = r.ReadNext() {
		// it may look stupid, while transform to []interface incurs more overhead.
		_, err2 := db.Exec(batchSQL, row[0], row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8])
		if err2 != nil {
			return errors.Wrap(err, "insert data failed")
		}
	}
	if err != nil && err != io.EOF {
		return errors.Wrap(err, "parse input csv failed")
	}
	return nil
}

func main() {
	if info, err := os.Stdin.Stat(); err == nil {
		if info.Mode()&os.ModeCharDevice == 0 && info.Size() > 0 {
			// read csv from stdin, write transformed csv file to stdout
			if err = PipeMode(); err != nil {
				println(err.Error())
			}
		} else {
			if err := BatchMode(); err != nil {
				println(err.Error())
			}
		}
	}
}

```

build that file `pgcopy.go` with `go build`, then treat it as part of the following pipeline:

```bash
psql -c 'TRUNCATE classic_rock;'

time ./pgcopy < ./classic-rock-raw-data.csv \
| psql -c 'COPY classic_rock FROM STDIN CSV HEADER;'
```

```
real	0m0.597s
user	0m0.086s
sys		0m0.034s
```

**600ms** , similar to baseline, great.  Since go's stdlib implementation is quiet [crude](https://github.com/Vonng/ac). I'm sure we can do a lot of optimizations there. 



### The SQL Way

I've translated a [tutorial](https://vonng.com/blog/go-database-tutorial/) about how to use `database/sql` in golang.

But I assure that sql approachs would always be much slower.

```
INSERT INTO classic_rock VALUES (?,?,?,?,?,?,?,?,?);
```

```go
const batchSQL = `INSERT INTO classic_rock VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9);`

// BatchMode use batch insert commit
func BatchMode() error {
	if len(os.Args) != 3 {
		return errors.New(`batch mode requires args: filepath & pgURL`)
	}
	filepath, pgURL := os.Args[1], os.Args[2]

	f, err := os.Open(filepath)
	if err != nil {
		return errors.Wrap(err, "invalid filename")
	}
	defer f.Close()

	db, err := sql.Open("pgx", pgURL)
	if err != nil {
		return errors.Wrap(err, "invalid postgres URL")
	}
	defer db.Close()

	if _, err = db.Exec(`TRUNCATE classic_rock;`); err != nil {
		return errors.Wrap(err, "truncate failed")
	}

	r := NewCleanseReader(f)
	var row []string

	row, err = r.ReadNext() // get first line ready
	row, err = r.ReadNext() // skip header line
	for ; err == nil; row, err = r.ReadNext() {
		// it may look stupid, while transform to []interface incurs more overhead.
		_, err2 := db.Exec(batchSQL, row[0], row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8])
		if err2 != nil {
			return errors.Wrap(err, "insert data failed")
		}
	}
	if err != nil && err != io.EOF {
		return errors.Wrap(err, "parse input csv failed")
	}
	return nil
}
```

And run it with batch mode

```bash
time ./pgcopy classic-rock-raw-data.csv postgres://:5432/vonng
```

It takes **14s**, hmmmm……



#### Impovement

* Using bulk insertion (requires manual sql concat)

  While go stdlib does not provide **BULK** operations. To achieve that, You need concat SQL string yourself. Which is commonly a bad practice, But it **can** impove throughput significantly (1x ~ 10x).

* Using Copy Protocal (requires non-standard API)

  Another approach is using `copy` protocal directly from client. Drivers like `pgx` provide non-standard API like `CopyFrom`.

* Using multiple workers (little help)

  Multiple copy workers & insert workers could do the trick. Acutally in some situation multiple insert workers may perform better than single copy worker. 

* Bulkload approach

  Generate table binary file directly and changing pg_catalog metadata to apply. EXTREAMLY DANGEROUS. But it could achieve dramatically throughput.

  

## Recap

Actually, for such a scale, psql copy would always be the best choice.

Multiple copier or binary file generator could have better performance, while brings much more complexity. 
