-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for Zakat & Waqf Management
-- ============================================================================
USE DATABASE ZAKAT_MANAGEMENT;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_REFRESH_COLLECTIONS
  WAREHOUSE = ZAKAT_WH
  SCHEDULE = 'USING CRON 0 */2 * * * UTC'
  COMMENT = 'Refresh collection dashboard with latest transactions'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_FORECAST_COLLECTIONS
  WAREHOUSE = ZAKAT_WH
  AFTER APP.TASK_REFRESH_COLLECTIONS
  COMMENT = 'Run collection trend forecast by channel'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_UPDATE_IMPACT
  WAREHOUSE = ZAKAT_WH
  AFTER APP.TASK_FORECAST_COLLECTIONS
  COMMENT = 'Refresh impact metrics and distribution equity analysis'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_UPDATE_IMPACT RESUME;
ALTER TASK APP.TASK_FORECAST_COLLECTIONS RESUME;
ALTER TASK APP.TASK_REFRESH_COLLECTIONS RESUME;
