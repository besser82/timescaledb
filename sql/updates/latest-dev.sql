DROP FUNCTION IF EXISTS drop_chunks("any",name,name,boolean,"any",boolean,boolean);
DROP FUNCTION IF EXISTS add_drop_chunks_policy(REGCLASS,INTERVAL,BOOL,BOOL,BOOL);

ALTER TABLE _timescaledb_catalog.dimension
ADD COLUMN integer_now_func_schema     NAME     NULL;

ALTER TABLE _timescaledb_catalog.dimension
ADD COLUMN integer_now_func            NAME     NULL;

ALTER TABLE _timescaledb_catalog.dimension
ADD CONSTRAINT dimension_check2
CHECK (
        (integer_now_func_schema IS NULL AND integer_now_func IS NULL) OR
        (integer_now_func_schema IS NOT NULL AND integer_now_func IS NOT NULL)
);
-- ----------------------
CREATE TYPE _timescaledb_catalog.ts_interval AS (
    is_time_interval        BOOLEAN,
    time_interval		    INTERVAL,
    integer_interval        BIGINT
    );

-- q -- todo:: this is probably necessary if we keep the validation constraint in the table definition.
CREATE OR REPLACE FUNCTION _timescaledb_internal.valid_ts_interval(invl _timescaledb_catalog.ts_interval)
RETURNS BOOLEAN AS '@MODULE_PATHNAME@', 'ts_valid_ts_interval' LANGUAGE C VOLATILE STRICT;

DROP VIEW IF EXISTS timescaledb_information.drop_chunks_policies;
DROP VIEW IF EXISTS timescaledb_information.policy_stats;

CREATE TABLE IF NOT EXISTS _timescaledb_config.bgw_policy_drop_chunks_tmp (
    job_id          		    INTEGER                 PRIMARY KEY REFERENCES _timescaledb_config.bgw_job(id) ON DELETE CASCADE,
    hypertable_id   		    INTEGER     UNIQUE      NOT NULL REFERENCES _timescaledb_catalog.hypertable(id) ON DELETE CASCADE,
    older_than	    _timescaledb_catalog.ts_interval    NOT NULL,
	cascade					    BOOLEAN                 NOT NULL,
    cascade_to_materializations BOOLEAN                 NOT NULL,
    CONSTRAINT valid_older_than CHECK(_timescaledb_internal.valid_ts_interval(older_than))
);

INSERT INTO _timescaledb_config.bgw_policy_drop_chunks_tmp
(SELECT job_id, hypertable_id, ROW('t',older_than,NULL)::_timescaledb_catalog.ts_interval  as older_than, cascade, cascade_to_materializations
FROM _timescaledb_config.bgw_policy_drop_chunks);

ALTER EXTENSION timescaledb DROP TABLE _timescaledb_config.bgw_policy_drop_chunks;
DROP TABLE _timescaledb_config.bgw_policy_drop_chunks;

CREATE TABLE IF NOT EXISTS _timescaledb_config.bgw_policy_drop_chunks (
    job_id          		    INTEGER                 PRIMARY KEY REFERENCES _timescaledb_config.bgw_job(id) ON DELETE CASCADE,
    hypertable_id   		    INTEGER     UNIQUE      NOT NULL REFERENCES _timescaledb_catalog.hypertable(id) ON DELETE CASCADE,
    older_than	    _timescaledb_catalog.ts_interval    NOT NULL,
	cascade					    BOOLEAN                 NOT NULL,
    cascade_to_materializations BOOLEAN                 NOT NULL,
    CONSTRAINT valid_older_than CHECK(_timescaledb_internal.valid_ts_interval(older_than))
);

INSERT INTO _timescaledb_config.bgw_policy_drop_chunks
(SELECT * FROM _timescaledb_config.bgw_policy_drop_chunks_tmp);

SELECT pg_catalog.pg_extension_config_dump('_timescaledb_config.bgw_policy_drop_chunks', '');
DROP TABLE _timescaledb_config.bgw_policy_drop_chunks_tmp;
GRANT SELECT ON _timescaledb_config.bgw_policy_drop_chunks TO PUBLIC;

DROP FUNCTION IF EXISTS alter_job_schedule(INTEGER, INTERVAL, INTERVAL, INTEGER, INTERVAL, BOOL);


--ADDS last_successful_finish column
--Must remove from extension first
ALTER EXTENSION timescaledb DROP TABLE _timescaledb_internal.bgw_job_stat;
DROP VIEW IF EXISTS timescaledb_information.policy_stats;
DROP VIEW IF EXISTS timescaledb_information.continuous_aggregate_stats;

--create table and drop instead of rename so that all indexes dropped as well
CREATE TABLE _timescaledb_internal.bgw_job_stat_tmp AS SELECT * FROM _timescaledb_internal.bgw_job_stat;
DROP TABLE _timescaledb_internal.bgw_job_stat;

CREATE TABLE IF NOT EXISTS _timescaledb_internal.bgw_job_stat (
    job_id                  INTEGER         PRIMARY KEY REFERENCES _timescaledb_config.bgw_job(id) ON DELETE CASCADE,
    last_start              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_finish             TIMESTAMPTZ NOT NULL,
    next_start              TIMESTAMPTZ NOT NULL,
    last_successful_finish  TIMESTAMPTZ NOT NULL,
    last_run_success        BOOL        NOT NULL,
    total_runs              BIGINT      NOT NULL,
    total_duration          INTERVAL    NOT NULL,
    total_successes         BIGINT      NOT NULL,
    total_failures          BIGINT      NOT NULL,
    total_crashes           BIGINT      NOT NULL,
    consecutive_failures    INT         NOT NULL,
    consecutive_crashes     INT         NOT NULL
);
--The job_stat table is not dumped by pg_dump on purpose because (see tables.sql for details)

INSERT INTO _timescaledb_internal.bgw_job_stat
    SELECT job_id,
        last_start,
        last_finish,
        next_start,
        CASE WHEN last_run_success THEN last_finish ELSE '-infinity'::timestamptz END as last_successful_finish,
        last_run_success,
        total_runs,
        total_duration,
        total_successes,
        total_failures,
        total_crashes,
        consecutive_failures,
        consecutive_crashes
    FROM _timescaledb_internal.bgw_job_stat_tmp;

DROP TABLE _timescaledb_internal.bgw_job_stat_tmp;
GRANT SELECT ON _timescaledb_internal.bgw_job_stat TO PUBLIC;
