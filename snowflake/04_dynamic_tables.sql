-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for Zakat & Waqf Management
-- ============================================================================
USE DATABASE ZAKAT_MANAGEMENT;
USE SCHEMA CURATED;

-- COLLECTION_DASHBOARD: Real-time zakat collection by channel, type, and period vs target
-- Source: COLLECTIONS, MUZAKKI
CREATE OR REPLACE DYNAMIC TABLE CURATED.COLLECTION_DASHBOARD
  TARGET_LAG = '5 minutes'
  WAREHOUSE = ZAKAT_WH
AS
SELECT * FROM RAW.COLLECTIONS;
-- TODO: Replace with actual join/aggregation logic per demo

-- DISTRIBUTION_EQUITY: Distribution coverage by province, asnaf category, and program
-- Source: DISTRIBUTIONS, MUSTAHIK, PROGRAMS
CREATE OR REPLACE DYNAMIC TABLE CURATED.DISTRIBUTION_EQUITY
  TARGET_LAG = '5 minutes'
  WAREHOUSE = ZAKAT_WH
AS
SELECT * FROM RAW.DISTRIBUTIONS;
-- TODO: Replace with actual join/aggregation logic per demo

-- DONOR_SEGMENTATION: Muzakki segmentation by giving pattern, channel, and retention risk
-- Source: MUZAKKI, COLLECTIONS
CREATE OR REPLACE DYNAMIC TABLE CURATED.DONOR_SEGMENTATION
  TARGET_LAG = '5 minutes'
  WAREHOUSE = ZAKAT_WH
AS
SELECT * FROM RAW.MUZAKKI;
-- TODO: Replace with actual join/aggregation logic per demo

-- IMPACT_METRICS: Program outcomes: poverty graduation rate, education completion, health access
-- Source: DISTRIBUTIONS, MUSTAHIK, PROGRAMS
CREATE OR REPLACE DYNAMIC TABLE CURATED.IMPACT_METRICS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = ZAKAT_WH
AS
SELECT * FROM RAW.DISTRIBUTIONS;
-- TODO: Replace with actual join/aggregation logic per demo

