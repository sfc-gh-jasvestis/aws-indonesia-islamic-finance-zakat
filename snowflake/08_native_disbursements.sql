-- ============================================================================
-- 08_native_disbursements.sql - Snowflake-only build: live disbursement feed without AWS.
-- Creates RAW.LIVE_DISBURSEMENTS (same columns as the Snowpipe target created by
-- aws/setup_aws.py) and APP.SIMULATE_DISBURSEMENTS(N), which inserts synthetic
-- disbursement events with the same value ranges and ~10% DELAYED rate as
-- aws/publish_disbursements.py. Rows are inserted directly; this simulates an
-- disbursement feed and is not Snowpipe Streaming.
-- Run before 06_intelligence.sql (the alert reads RAW.LIVE_DISBURSEMENTS).
-- Idempotent: safe to run in the AWS build too.
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS APP;

CREATE TABLE IF NOT EXISTS RAW.LIVE_DISBURSEMENTS (
  PROGRAMME_ID VARCHAR, EVENT_TS TIMESTAMP_NTZ, AMOUNT_IDR FLOAT, DAYS_LATE FLOAT,
  STATUS VARCHAR, SENT_TS TIMESTAMP_NTZ, SOURCE_FILE VARCHAR,
  LOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());

CREATE OR REPLACE PROCEDURE APP.SIMULATE_DISBURSEMENTS(N NUMBER)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  IF (N < 1 OR N > 1000) THEN
    RETURN 0;
  END IF;
  INSERT INTO RAW.LIVE_DISBURSEMENTS (PROGRAMME_ID, EVENT_TS, AMOUNT_IDR, DAYS_LATE, STATUS, SENT_TS, SOURCE_FILE)
    WITH g AS (
      SELECT 'PRG-' || LPAD(UNIFORM(0, 39, RANDOM())::VARCHAR, 4, '0') AS PROGRAMME_ID,
             UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.1 AS IS_DELAYED,
             SYSDATE() AS TS, SEQ4() AS I
      FROM TABLE(GENERATOR(ROWCOUNT => 1000))
    )
    -- NORMAL() needs constant arguments, so the delayed offset is applied outside it.
    SELECT PROGRAMME_ID, TS,
           ROUND(IFF(IS_DELAYED, 2500000, 1200000) * EXP(NORMAL(0, 0.5, RANDOM())), 0),
           ROUND(IFF(IS_DELAYED, 9, 0.3) * EXP(NORMAL(0, 0.4, RANDOM())), 0),
           IFF(IS_DELAYED, 'DELAYED', 'DISBURSED'), TS, 'APP.SIMULATE_DISBURSEMENTS'
    FROM g
    WHERE I < :N;
  RETURN SQLROWCOUNT;
END;
$$;

-- Optional continuous feed for longer demos (suspended; RESUME to start, SUSPEND after).
CREATE OR REPLACE TASK APP.TASK_SIMULATE_DISBURSEMENTS
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '1 MINUTE'
AS
  CALL APP.SIMULATE_DISBURSEMENTS(5);
