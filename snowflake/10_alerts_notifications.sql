-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for Zakat & Waqf Management
-- ============================================================================
USE DATABASE ZAKAT_MANAGEMENT;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_indonesia_islamic_finance_zakat_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('<YOUR_EMAIL>');

-- Alert: COLLECTION_TARGET_ALERT
CREATE OR REPLACE ALERT APP.COLLECTION_TARGET_ALERT
  WAREHOUSE = ZAKAT_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Monthly collection below target — acceleration needed'
IF (EXISTS (
  SELECT 1 FROM CURATED.COLLECTION_DASHBOARD
  WHERE 1=1 -- Condition: Monthly collection below 90% of target trajectory
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_indonesia_islamic_finance_zakat_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] Zakat & Waqf Management: Monthly collection below target — acceleration needed',
    'Monthly collection below target — acceleration needed'
  );

ALTER ALERT APP.COLLECTION_TARGET_ALERT RESUME;

-- Alert: DISTRIBUTION_GAP_ALERT
CREATE OR REPLACE ALERT APP.DISTRIBUTION_GAP_ALERT
  WAREHOUSE = ZAKAT_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Distribution coverage gap detected in province'
IF (EXISTS (
  SELECT 1 FROM CURATED.COLLECTION_DASHBOARD
  WHERE 1=1 -- Condition: Province distribution coverage below 60%
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_indonesia_islamic_finance_zakat_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] Zakat & Waqf Management: Distribution coverage gap detected in province',
    'Distribution coverage gap detected in province'
  );

ALTER ALERT APP.DISTRIBUTION_GAP_ALERT RESUME;

