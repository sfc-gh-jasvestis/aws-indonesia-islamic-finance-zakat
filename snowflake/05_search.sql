-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Zakat & Waqf Management
-- ============================================================================
USE DATABASE ZAKAT_MANAGEMENT;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.IMPACT_REPORTS_SEARCH
  ON CONTENT
  ATTRIBUTES PROGRAM_TYPE, PROVINCE, YEAR
  WAREHOUSE = ZAKAT_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.IMPACT_REPORTS
);
