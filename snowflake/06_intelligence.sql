-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live disbursement delay alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes checked __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_DISBURSEMENTS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic distribution knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.DISBURSEMENT_DOCS AS
WITH types AS (
  SELECT DISTINCT r.DELAY_REASON, a.CATEGORY
  FROM RAW.PROGRAMME_DAILY r JOIN RAW.PROGRAMMES a ON a.ID = r.ENTITY_ID
  WHERE r.ESCALATED_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, DELAY_REASON)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  DELAY_REASON,
  CATEGORY || ' - ' || DELAY_REASON || ' disbursement delay handling' AS TITLE,
  'Synthetic demo SOP for a fictional zakat and waqf management organisation. It is an operations procedure only and states no religious ruling or regulatory requirement. Programme: ' || CATEGORY
  || '. Delay reason: ' || DELAY_REASON || '. '
  || 'Step 1: open a delay case, link the affected disbursement batch and assign a distribution officer within one working day. '
  || 'Step 2: ' || CASE
       WHEN DELAY_REASON = 'Supplier delivery delay' THEN 'confirm the revised delivery date with the supplier, inform the local distribution point, and switch to the approved backup supplier if the delay exceeds three days.'
       WHEN DELAY_REASON = 'Beneficiary list not verified' THEN 'ask the field team to complete the pending verification visits and hold only the unverified part of the batch, releasing the verified part on schedule.'
       WHEN DELAY_REASON = 'Beneficiary unreachable' THEN 'try every registered contact channel over three working days, log each attempt, and ask the local partner to arrange a visit.'
       WHEN DELAY_REASON = 'Enrolment document pending' THEN 'request the enrolment confirmation from the school or university and release the scholarship payment once it is on file.'
       WHEN DELAY_REASON = 'Bank account mismatch' THEN 'ask the recipient or the partner institution to confirm the account details through the registered channel, and re-run the transfer after a second officer checks the change.'
       WHEN DELAY_REASON = 'Medical invoice pending' THEN 'request the invoice from the partner clinic or hospital and pay the provider directly once the invoice matches the approved referral.'
       WHEN DELAY_REASON = 'Field access restricted' THEN 'coordinate with the local disaster response coordinator, record the access constraint, and stage supplies at the nearest open distribution point.'
       WHEN DELAY_REASON = 'Business plan review pending' THEN 'schedule the business plan review with the programme mentor and release the grant tranche once the review is signed off.'
       ELSE 'review the case against the programme profile and escalate if unexplained.'
     END
  || ' Step 3: if the bank transfer rejection rate on the programme exceeds 5% or the average days to disburse exceeds 10 after triage, keep the case open and request a programme review. '
  || 'Step 4: record the resolution; if the case was escalated or missed its beneficiary notice SLA, log it for the distribution report.' AS CONTENT
FROM types;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.DISBURSEMENT_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, DELAY_REASON
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, DELAY_REASON, CONTENT FROM SEARCH.DISBURSEMENT_DOCS);

-- ---------- Bank transfer rejection rate anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.TRANSFER_REJECT_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, TRANSFER_REJECT_PCT::FLOAT AS TRANSFER_REJECT
FROM RAW.PROGRAMME_DAILY;
CREATE OR REPLACE VIEW ML.TRANSFER_REJECT_TRAIN AS
SELECT * FROM ML.TRANSFER_REJECT_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.TRANSFER_REJECT_SERIES);
CREATE OR REPLACE VIEW ML.TRANSFER_REJECT_DETECT AS
SELECT * FROM ML.TRANSFER_REJECT_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.TRANSFER_REJECT_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.TRANSFER_REJECT_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.TRANSFER_REJECT_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'TRANSFER_REJECT',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.TRANSFER_REJECT_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS TRANSFER_REJECT, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.TRANSFER_REJECT_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.TRANSFER_REJECT_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'TRANSFER_REJECT'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.ZAKAT_ANALYTICS
  TABLES (
    programmes AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      COMMENT = 'One row per distribution programme (one programme type in one city), 90-day totals',
    risk AS ML.ESCALATION_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day delay escalation probability per programme',
    delays AS CURATED.DELAY_SUMMARY PRIMARY KEY (DELAY_REASON)
      COMMENT = 'Delay cases, escalations and beneficiary notice SLA breaches by delay reason, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Organisation-wide disbursement totals per day',
    channels AS CURATED.CHANNEL_SUMMARY PRIMARY KEY (CHANNEL)
      COMMENT = 'Donations collected per donor channel, 90 days'
  )
  RELATIONSHIPS (risk_programme AS risk (ENTITY_ID) REFERENCES programmes)
  FACTS (
    programmes.delays_f AS DELAYED_COUNT,
    programmes.escalated_f AS ESCALATED_COUNT,
    programmes.breaches_f AS SLA_BREACH_COUNT,
    programmes.disbursements_f AS DISBURSEMENT_COUNT,
    programmes.value_f AS VALUE_IDR,
    programmes.review_due_f AS REVIEW_DUE,
    programmes.review_done_f AS REVIEW_COMPLETED,
    risk.escalation_prob_f AS ESCALATION_PROB_7D,
    delays.reason_delays_f AS DELAYED_COUNT,
    delays.reason_escalated_f AS ESCALATED_COUNT,
    delays.reason_breaches_f AS SLA_BREACH_COUNT,
    delays.reason_value_f AS EXPOSED_VALUE_IDR,
    daily.day_delays_f AS DELAYED_COUNT,
    daily.day_escalated_f AS ESCALATED_COUNT,
    daily.day_value_f AS VALUE_IDR,
    channels.channel_donations_f AS DONATION_COUNT,
    channels.channel_collected_f AS COLLECTED_IDR
  )
  DIMENSIONS (
    programmes.programme_id AS ENTITY_ID WITH SYNONYMS = ('programme', 'distribution programme', 'entity'),
    programmes.programme_name AS ENTITY_NAME,
    programmes.city AS REGION WITH SYNONYMS = ('city', 'region')
      COMMENT = 'Indonesian city where the programme pays out',
    programmes.programme_type AS CATEGORY WITH SYNONYMS = ('programme type', 'category')
      COMMENT = 'Food assistance, Education scholarship, Health assistance, Disaster relief or Economic empowerment',
    programmes.risk_tier AS RISK_TIER COMMENT = 'Operational risk grade 1 (low) to 3 (high)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    delays.delay_reason AS DELAY_REASON WITH SYNONYMS = ('delay reason', 'reason', 'cause'),
    daily.metric_date AS METRIC_DATE,
    channels.donor_channel AS CHANNEL WITH SYNONYMS = ('donor channel', 'collection channel', 'payment channel'),
    channels.is_digital AS IS_DIGITAL COMMENT = 'TRUE for QRIS, e-wallet and bank transfer'
  )
  METRICS (
    programmes.programme_count AS COUNT(programmes.programme_id)
      WITH SYNONYMS = ('number of programmes', 'entities', 'number of entities'),
    programmes.on_time_disbursement_pct AS 100 * (SUM(programmes.disbursements_f) - SUM(programmes.delays_f)) / NULLIF(SUM(programmes.disbursements_f), 0)
      WITH SYNONYMS = ('on-time disbursement rate', 'timeliness')
      COMMENT = 'Scheduled disbursements without a delay case / scheduled disbursements',
    programmes.escalation_rate_pct AS 100 * SUM(programmes.escalated_f) / NULLIF(SUM(programmes.delays_f), 0)
      COMMENT = 'Delay cases escalated to programme review / delay cases',
    programmes.delay_cases AS SUM(programmes.delays_f) WITH SYNONYMS = ('delays', 'late disbursements'),
    programmes.escalated_cases AS SUM(programmes.escalated_f) WITH SYNONYMS = ('escalations', 'programme reviews'),
    programmes.sla_breaches AS SUM(programmes.breaches_f) WITH SYNONYMS = ('beneficiary notice SLA misses'),
    programmes.disbursements_scheduled AS SUM(programmes.disbursements_f),
    programmes.total_value_idr AS SUM(programmes.value_f) WITH SYNONYMS = ('disbursed value', 'value in IDR'),
    programmes.verification_compliance_pct AS 100 * SUM(programmes.review_done_f) / NULLIF(SUM(programmes.review_due_f), 0)
      COMMENT = 'Field verification visits completed / visits due',
    risk.avg_escalation_prob AS AVG(risk.escalation_prob_f),
    delays.reason_delays AS SUM(delays.reason_delays_f),
    delays.reason_escalated AS SUM(delays.reason_escalated_f),
    delays.reason_breaches AS SUM(delays.reason_breaches_f),
    delays.reason_escalation_rate_pct AS 100 * SUM(delays.reason_escalated_f) / NULLIF(SUM(delays.reason_delays_f), 0),
    daily.daily_delays AS SUM(daily.day_delays_f),
    daily.daily_escalated AS SUM(daily.day_escalated_f),
    daily.daily_value_idr AS SUM(daily.day_value_f),
    channels.total_donations AS SUM(channels.channel_donations_f),
    channels.total_collected_idr AS SUM(channels.channel_collected_f) WITH SYNONYMS = ('collections', 'amount collected')
  )
  COMMENT = 'Synthetic Indonesia zakat and waqf operations analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.ZAKAT_AGENT
  COMMENT = 'Distribution operations assistant over a synthetic Indonesian zakat and waqf organisation'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give programme IDs and numbers with units (IDR, %). Do not give religious or regulatory rulings, and do not discuss individual beneficiaries."
  orchestration: "Use zakat_analyst for scheduled disbursements, delay cases, escalations to programme review, beneficiary notice SLA breaches, on-time disbursement rate, field verification compliance, programmes, cities, programme types, delay reasons, escalation risk and donations by donor channel. Use sop_search for disbursement delay procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: zakat_analyst
      description: "Scheduled disbursements, disbursed value in IDR, delay cases, escalations to programme review, beneficiary notice SLA breaches, on-time disbursement rate, field verification compliance, delay reasons and escalation risk scores by programme, city and programme type, plus donations collected by donor channel"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic disbursement delay handling SOPs by programme type and delay reason"
tool_resources:
  zakat_analyst:
    semantic_view: __DEMO_DB__.APP.ZAKAT_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.DISBURSEMENT_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live disbursement delay alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), PROGRAMME_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, AMOUNT_IDR FLOAT, DAYS_LATE FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION ID_ZAKAT_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (PROGRAMME_ID, EVENT_TS, AMOUNT_IDR, DAYS_LATE, SOP_HINT)
    SELECT p.PROGRAMME_ID, p.EVENT_TS, p.AMOUNT_IDR, p.DAYS_LATE,
           'Check ' || r.CATEGORY || ' disbursement SOPs; current risk band ' || COALESCE(s.RISK_BAND, 'n/a')
    FROM RAW.LIVE_DISBURSEMENTS p
    JOIN RAW.PROGRAMMES r ON r.ID = p.PROGRAMME_ID
    LEFT JOIN ML.ESCALATION_RISK_SCORES s ON s.ENTITY_ID = p.PROGRAMME_ID
    WHERE p.STATUS = 'DELAYED'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.PROGRAMME_ID = p.PROGRAMME_ID AND l.EVENT_TS = p.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('ID_ZAKAT_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Delayed disbursement alert',
      'New delayed disbursements logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_DELAY_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_DISBURSEMENTS p
    WHERE p.STATUS = 'DELAYED'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.PROGRAMME_ID = p.PROGRAMME_ID AND l.EVENT_TS = p.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();
-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.DELAY_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.CHANNEL_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.ESCALATION_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.ESCALATION_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.ESCALATION_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'RISK_TIER', RISK_TIER, 'PROGRAMME_AGE_YEARS', PROGRAMME_AGE_YEARS,
             'TRANSFER_REJECT_PCT', TRANSFER_REJECT_PCT, 'AVG_DAYS_TO_DISBURSE', AVG_DAYS_TO_DISBURSE,
             'TRANSFER_REJECT_7D', TRANSFER_REJECT_7D, 'ESCALATED_30D', ESCALATED_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:ESCALATED::FLOAT, 4) AS ESCALATION_PROB_7D,
         CASE WHEN PRED:probability:ESCALATED::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:ESCALATED::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
