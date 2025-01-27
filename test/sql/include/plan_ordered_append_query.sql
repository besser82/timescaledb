-- This file and its contents are licensed under the Apache License 2.0.
-- Please see the included NOTICE for copyright information and
-- LICENSE-APACHE for a copy of the license.

-- print chunks ordered by time to ensure ordering we want
SELECT
  ht.table_name AS hypertable,
  c.table_name AS chunk,
  ds.range_start
FROM
  _timescaledb_catalog.chunk c
  INNER JOIN LATERAL(SELECT * FROM _timescaledb_catalog.chunk_constraint cc WHERE c.id = cc.chunk_id ORDER BY cc.dimension_slice_id LIMIT 1) cc ON true
  INNER JOIN _timescaledb_catalog.dimension_slice ds ON ds.id=cc.dimension_slice_id
  INNER JOIN _timescaledb_catalog.dimension d ON ds.dimension_id = d.id
  INNER JOIN _timescaledb_catalog.hypertable ht ON d.hypertable_id = ht.id
ORDER BY ht.table_name, range_start, chunk;

-- test ASC for ordered chunks
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
ORDER BY time ASC LIMIT 1;

-- test DESC for ordered chunks
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
ORDER BY time DESC LIMIT 1;

-- test ASC for reverse ordered chunks
:PREFIX SELECT
  time, device_id, value
FROM ordered_append_reverse
ORDER BY time ASC LIMIT 1;

-- test DESC for reverse ordered chunks
:PREFIX SELECT
  time, device_id, value
FROM ordered_append_reverse
ORDER BY time DESC LIMIT 1;

-- test query with ORDER BY column not in targetlist
:PREFIX SELECT
  device_id, value
FROM ordered_append
ORDER BY time ASC LIMIT 1;

-- ORDER BY may include other columns after time column
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
ORDER BY time DESC, device_id LIMIT 1;

-- test RECORD in targetlist
:PREFIX SELECT
  (time, device_id, value)
FROM ordered_append
ORDER BY time DESC, device_id LIMIT 1;

-- test sort column not in targetlist
:PREFIX SELECT
  time_bucket('1h',time)
FROM ordered_append
ORDER BY time DESC LIMIT 1;

-- queries with ORDER BY non-time column shouldn't use ordered append
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
ORDER BY device_id LIMIT 1;

-- time column must be primary sort order
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
ORDER BY device_id, time LIMIT 1;

-- queries without LIMIT should use ordered append
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
ORDER BY time ASC;

-- queries without ORDER BY shouldnt use ordered append
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
LIMIT 1;

-- test interaction with constraint exclusion
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
WHERE time > '2000-01-07'
ORDER BY time ASC LIMIT 1;

:PREFIX SELECT
  time, device_id, value
FROM ordered_append
WHERE time > '2000-01-07'
ORDER BY time DESC LIMIT 1;

-- test interaction with constraint aware append
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
WHERE time > now_s()
ORDER BY time ASC LIMIT 1;

:PREFIX SELECT
  time, device_id, value
FROM ordered_append
WHERE time < now_s()
ORDER BY time ASC LIMIT 1;

-- test constraint exclusion
:PREFIX SELECT
  time, device_id, value
FROM ordered_append
WHERE time > now_s() AND time < '2000-01-10'
ORDER BY time ASC LIMIT 1;

:PREFIX SELECT
  time, device_id, value
FROM ordered_append
WHERE time < now_s() AND time > '2000-01-07'
ORDER BY time ASC LIMIT 1;

-- min/max queries
:PREFIX SELECT max(time) FROM ordered_append;

:PREFIX SELECT min(time) FROM ordered_append;

-- test first/last (doesn't use ordered append yet)
:PREFIX SELECT first(time, time) FROM ordered_append;

:PREFIX SELECT last(time, time) FROM ordered_append;

-- test query with time_bucket
:PREFIX SELECT
  time_bucket('1d',time), device_id, value
FROM ordered_append
ORDER BY time ASC LIMIT 1;

-- test query with ORDER BY time_bucket
:PREFIX SELECT
  time_bucket('1d',time), device_id, value
FROM ordered_append
ORDER BY 1 LIMIT 1;

-- test query with ORDER BY time_bucket
:PREFIX SELECT
  time_bucket('1d',time), device_id, value
FROM ordered_append
ORDER BY time_bucket('1d',time) LIMIT 1;

-- test query with ORDER BY time_bucket, device_id
-- must not use ordered append
:PREFIX SELECT
  time_bucket('1d',time), device_id, name
FROM dimension_last
ORDER BY time_bucket('1d',time), device_id LIMIT 1;

-- test query with ORDER BY date_trunc
:PREFIX SELECT
  time_bucket('1d',time), device_id, value
FROM ordered_append
ORDER BY date_trunc('day', time) LIMIT 1;

-- test query with ORDER BY date_trunc
:PREFIX SELECT
  date_trunc('day',time), device_id, value
FROM ordered_append
ORDER BY 1 LIMIT 1;

-- test query with ORDER BY date_trunc, device_id
-- must not use ordered append
:PREFIX SELECT
  date_trunc('day',time), device_id, name
FROM dimension_last
ORDER BY 1,2 LIMIT 1;

-- test query with now() should result in ordered ChunkAppend
:PREFIX SELECT * FROM ordered_append WHERE time < now() + '1 month'
ORDER BY time DESC limit 1;

-- test CTE
:PREFIX WITH i AS (SELECT * FROM ordered_append WHERE time < now() ORDER BY time DESC limit 100)
SELECT * FROM i;

-- test LATERAL with ordered append in the outer query
:PREFIX SELECT * FROM ordered_append, LATERAL(SELECT * FROM (VALUES (1),(2)) v) l ORDER BY time DESC limit 2;

-- test LATERAL with ordered append in the lateral query
:PREFIX SELECT * FROM (VALUES (1),(2)) v, LATERAL(SELECT * FROM ordered_append ORDER BY time DESC limit 2) l;

-- test plan with best index is chosen
-- this should use device_id, time index
:PREFIX SELECT * FROM ordered_append WHERE device_id = 1 ORDER BY time DESC LIMIT 1;

-- test plan with best index is chosen
-- this should use time index
:PREFIX SELECT * FROM ordered_append ORDER BY time DESC LIMIT 1;

-- test with table with only dimension column
:PREFIX SELECT * FROM dimension_only ORDER BY time DESC LIMIT 1;

-- test LEFT JOIN against hypertable
:PREFIX_NO_ANALYZE SELECT *
FROM dimension_last
LEFT JOIN dimension_only USING (time)
ORDER BY dimension_last.time DESC
LIMIT 2;

-- test INNER JOIN against non-hypertable
:PREFIX_NO_ANALYZE SELECT *
FROM dimension_last
INNER JOIN dimension_only USING (time)
ORDER BY dimension_last.time DESC
LIMIT 2;

-- test join against non-hypertable
:PREFIX SELECT *
FROM dimension_last
INNER JOIN devices USING(device_id)
ORDER BY dimension_last.time DESC
LIMIT 2;

-- test hypertable with index missing on one chunk
:PREFIX SELECT
  time, device_id, value
FROM ht_missing_indexes
ORDER BY time ASC LIMIT 1;

-- test hypertable with index missing on one chunk
-- and no data
:PREFIX SELECT
  time, device_id, value
FROM ht_missing_indexes
WHERE device_id = 2
ORDER BY time DESC LIMIT 1;

-- test hypertable with index missing on one chunk
-- and no data
:PREFIX SELECT
  time, device_id, value
FROM ht_missing_indexes
WHERE time > '2000-01-07'
ORDER BY time LIMIT 10;

-- test hypertable with dropped columns
:PREFIX SELECT
  time, device_id, value
FROM ht_dropped_columns
ORDER BY time ASC LIMIT 1;

-- test hypertable with dropped columns
:PREFIX SELECT
  time, device_id, value
FROM ht_dropped_columns
WHERE device_id = 1
ORDER BY time DESC;

-- test hypertable with space partitioning
:PREFIX SELECT
  time, device_id, value
FROM space
ORDER BY time;

-- test hypertable with space partitioning and exclusion in space
-- should remove 3 of 4 space partitions (2 chunks scanned)
:PREFIX SELECT
  time, device_id, value
FROM space
WHERE device_id = 1
ORDER BY time;

-- test hypertable with space partitioning and exclusion in space
-- should remove 2 of 4 space partitions (2 + 2 chunks scanned)
:PREFIX SELECT
  time, device_id, value
FROM space
WHERE device_id IN (1, 4)
ORDER BY time;

-- test hypertable with space partitioning and reverse order
:PREFIX SELECT
  time, device_id, value
FROM space
ORDER BY time DESC;

-- test hypertable with space partitioning ORDER BY multiple columns
-- does not use ordered append
:PREFIX SELECT
  time, device_id, value
FROM space
ORDER BY time, device_id LIMIT 1;

-- test hypertable with space partitioning ORDER BY non-time column
-- does not use ordered append
:PREFIX SELECT
  time, device_id, value
FROM space
ORDER BY device_id, time LIMIT 1;

-- test hypertable with 2 space dimensions
:PREFIX SELECT
  time, device_id, value
FROM space2
ORDER BY time DESC;

-- test hypertable with 3 space dimensions
:PREFIX SELECT
  time
FROM space3
ORDER BY time DESC;

-- expressions in ORDER BY clause
:PREFIX SELECT
  time_bucket('1h',time)
FROM space
ORDER BY 1 LIMIT 10;

:PREFIX SELECT
  time_bucket('1h',time)
FROM space
ORDER BY 1 DESC LIMIT 10;

-- test LATERAL with correlated query
-- only last chunk should be executed
:PREFIX SELECT *
FROM generate_series('2000-01-01'::timestamptz,'2000-01-03','1d') AS g(time)
LEFT OUTER JOIN LATERAL(
  SELECT * FROM ordered_append o
    WHERE o.time >= g.time AND o.time < g.time + '1d'::interval ORDER BY time DESC LIMIT 1
) l ON true;

-- test LATERAL with correlated query
-- only 2nd chunk should be executed
:PREFIX SELECT *
FROM generate_series('2000-01-10'::timestamptz,'2000-01-11','1d') AS g(time)
LEFT OUTER JOIN LATERAL(
  SELECT * FROM ordered_append o
    WHERE o.time >= g.time AND o.time < g.time + '1d'::interval ORDER BY time LIMIT 1
) l ON true;

-- test startup and runtime exclusion together
:PREFIX SELECT *
FROM generate_series('2000-01-01'::timestamptz,'2000-01-03','1d') AS g(time)
LEFT OUTER JOIN LATERAL(
  SELECT * FROM ordered_append o
    WHERE o.time >= g.time AND o.time < g.time + '1d'::interval AND o.time < now() ORDER BY time DESC LIMIT 1
) l ON true;

-- test startup and runtime exclusion together
-- all chunks should be filtered
:PREFIX SELECT *
FROM generate_series('2000-01-01'::timestamptz,'2000-01-03','1d') AS g(time)
LEFT OUTER JOIN LATERAL(
  SELECT * FROM ordered_append o
    WHERE o.time >= g.time AND o.time < g.time + '1d'::interval AND o.time > now() ORDER BY time DESC LIMIT 1
) l ON true;

-- test CTE
-- no chunk exclusion for CTE because cte query is not pulled up
:PREFIX WITH cte AS (SELECT * FROM ordered_append ORDER BY time)
SELECT * FROM cte WHERE time < '2000-02-01'::timestamptz;

-- test JOIN
-- no exclusion on joined table because quals are not propagated yet
:PREFIX SELECT *
FROM ordered_append o1
INNER JOIN ordered_append o2 ON o1.time = o2.time
WHERE o1.time < '2000-02-01'
ORDER BY o1.time;

-- test JOIN
-- last chunk of o2 should not be executed
:PREFIX SELECT *
FROM ordered_append o1
INNER JOIN (SELECT * FROM ordered_append o2 ORDER BY time) o2 ON o1.time = o2.time
WHERE o1.time < '2000-01-08'
ORDER BY o1.time;

-- test subquery
-- not ChunkAppend so no chunk exclusion
:PREFIX SELECT *
FROM ordered_append WHERE time = (SELECT max(time) FROM ordered_append) ORDER BY time;

-- test join against max query
-- not ChunkAppend so no chunk exclusion
:PREFIX SELECT *
FROM ordered_append o1 INNER JOIN (SELECT max(time) AS max_time FROM ordered_append) o2 ON o1.time = o2.max_time ORDER BY time;

-- test ordered append with limit expression
:PREFIX SELECT *
FROM ordered_append ORDER BY time LIMIT (SELECT length('four'));

-- test with ordered guc disabled
SET timescaledb.enable_ordered_append TO off;
:PREFIX SELECT *
FROM ordered_append ORDER BY time LIMIT 3;

RESET timescaledb.enable_ordered_append;
:PREFIX SELECT *
FROM ordered_append ORDER BY time LIMIT 3;

-- test with chunk append disabled
SET timescaledb.enable_chunk_append TO off;
:PREFIX SELECT *
FROM ordered_append ORDER BY time LIMIT 3;

RESET timescaledb.enable_chunk_append;
:PREFIX SELECT *
FROM ordered_append ORDER BY time LIMIT 3;

-- test space partitioning with startup exclusion
:PREFIX SELECT *
FROM space WHERE time < now() ORDER BY time;

-- test runtime exclusion together with space partitioning
:PREFIX SELECT *
FROM generate_series('2000-01-01'::timestamptz,'2000-01-03','1d') AS g(time)
LEFT OUTER JOIN LATERAL(
  SELECT * FROM space o
    WHERE o.time >= g.time AND o.time < g.time + '1d'::interval ORDER BY time DESC LIMIT 1
) l ON true;

-- test startup and runtime exclusion together with space partitioning
:PREFIX SELECT *
FROM generate_series('2000-01-01'::timestamptz,'2000-01-03','1d') AS g(time)
LEFT OUTER JOIN LATERAL(
  SELECT * FROM space o
    WHERE o.time >= g.time AND o.time < g.time + '1d'::interval AND o.time < now() ORDER BY time DESC LIMIT 1
) l ON true;

-- test JOIN on time column
-- should use 2 ChunkAppend
:PREFIX SELECT * FROM ordered_append o1 INNER JOIN ordered_append o2 ON o1.time = o2.time ORDER BY o1.time LIMIT 100;

-- test JOIN on time column with USING
-- should use 2 ChunkAppend
:PREFIX SELECT * FROM ordered_append o1 INNER JOIN ordered_append o2 USING(time) ORDER BY o1.time LIMIT 100;

-- test NATURAL JOIN on time column
-- should use 2 ChunkAppend
:PREFIX SELECT * FROM ordered_append o1 NATURAL INNER JOIN ordered_append o2 ORDER BY o1.time LIMIT 100;

-- test LEFT JOIN on time column
-- should use 2 ChunkAppend
:PREFIX SELECT * FROM ordered_append o1 LEFT JOIN ordered_append o2 ON o1.time=o2.time ORDER BY o1.time LIMIT 100;

-- test RIGHT JOIN on time column
-- should use 2 ChunkAppend
:PREFIX SELECT * FROM ordered_append o1 RIGHT JOIN ordered_append o2 ON o1.time=o2.time ORDER BY o2.time LIMIT 100;

-- test JOIN on time column with ON clause expression order switched
-- should use 2 ChunkAppend
:PREFIX SELECT * FROM ordered_append o1 INNER JOIN ordered_append o2 ON o2.time = o1.time ORDER BY o1.time LIMIT 100;

-- test JOIN on time column with equality condition in WHERE clause
-- should use 2 ChunkAppend
:PREFIX SELECT * FROM ordered_append o1 INNER JOIN ordered_append o2 ON true WHERE o1.time = o2.time ORDER BY o1.time LIMIT 100;

-- test JOIN on time column with ORDER BY 2nd hypertable
-- should use 2 ChunkAppend
:PREFIX SELECT * FROM ordered_append o1 INNER JOIN ordered_append o2 ON o1.time = o2.time ORDER BY o2.time LIMIT 100;

-- test JOIN on time column and device_id
-- should use 2 ChunkAppend
:PREFIX SELECT * FROM ordered_append o1 INNER JOIN ordered_append o2 ON o1.device_id = o2.device_id AND o1.time = o2.time ORDER BY o1.time LIMIT 100;

-- test JOIN on device_id
-- should not use ordered append for 2nd hypertable
:PREFIX SELECT * FROM ordered_append o1 INNER JOIN ordered_append o2 ON o1.device_id = o2.device_id ORDER BY o1.time LIMIT 100;

-- test JOIN on time column with implicit join
-- should use 2 ChunkAppend
:PREFIX SELECT * FROM ordered_append o1, ordered_append o2 WHERE o1.time = o2.time ORDER BY o1.time LIMIT 100;

-- test JOIN on time column with 3 hypertables
-- should use 3 ChunkAppend
:PREFIX SELECT * FROM ordered_append o1 INNER JOIN ordered_append o2 ON o1.time = o2.time INNER JOIN ordered_append o3 ON o1.time = o3.time ORDER BY o1.time LIMIT 100;

-- test with space partitioning
:PREFIX SELECT * FROM space s1 INNER JOIN space s2 ON s1.time = s2.time ORDER BY s1.time LIMIT 100;

-- test COLLATION
-- cant be tested in our ci because alpine doesnt support locales
-- :PREFIX SELECT * FROM sortopt_test ORDER BY time, device COLLATE "en_US.utf8";

-- test NULLS FIRST
:PREFIX SELECT * FROM sortopt_test ORDER BY time, device NULLS FIRST;

-- test NULLS LAST
:PREFIX SELECT * FROM sortopt_test ORDER BY time, device DESC NULLS LAST;
