-- Synthetic programme-day observations for a fictional Indonesian zakat and waqf
-- management organisation. A programme is one distribution programme type run in
-- one city. Nothing is seeded as a prediction. Randomness is HASH-seeded, so every
-- rebuild is reproducible: per-programme delay propensity, drift between field
-- verification visits, missed visits, programme-weighted delay reasons, delays
-- resolved without escalation, and two city-wide bank transfer outages.
-- Beneficiary data is aggregate only (counts per programme-day); no individuals.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.PROGRAMMES AS
WITH programmes AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS PROGRAMME_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT PROGRAMME_INDEX,
         MOD(ABS(HASH(PROGRAMME_INDEX, 'age')), 1000000) / 1e6 AS U_AGE,
         MOD(ABS(HASH(PROGRAMME_INDEX, 'rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(PROGRAMME_INDEX, 'review')), 1000000) / 1e6 AS U_REVIEW,
         MOD(ABS(HASH(PROGRAMME_INDEX, 'discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(PROGRAMME_INDEX, 'tier')), 1000000) / 1e6 AS U_TIER
  FROM programmes
)
SELECT 'PRG-' || LPAD(PROGRAMME_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic programme ' || LPAD(PROGRAMME_INDEX::VARCHAR, 4, '0') AS NAME,
       -- Deterministic spread (5 and 8 are coprime): every city and programme
       -- type is present. All programmes pay out in Indonesia (IDR).
       CASE MOD(PROGRAMME_INDEX, 5) WHEN 0 THEN 'Jakarta' WHEN 1 THEN 'Surabaya'
            WHEN 2 THEN 'Bandung' WHEN 3 THEN 'Medan' ELSE 'Makassar' END AS REGION,
       CASE MOD(PROGRAMME_INDEX, 8) WHEN 0 THEN 'Food assistance' WHEN 1 THEN 'Food assistance'
            WHEN 2 THEN 'Food assistance' WHEN 3 THEN 'Education scholarship'
            WHEN 4 THEN 'Education scholarship' WHEN 5 THEN 'Health assistance'
            WHEN 6 THEN 'Disaster relief' ELSE 'Economic empowerment' END AS CATEGORY,
       PROGRAMME_INDEX,
       1 + FLOOR(U_TIER * 3) AS RISK_TIER,
       ROUND(0.2 + U_AGE * 5.8, 1) AS PROGRAMME_AGE_YEARS,
       -- Base daily probability of an escalated disbursement delay 0.2%-3.2%;
       -- ~20% of programmes are chronically weak (x4).
       (0.002 + U_RATE * 0.03) * IFF(U_RATE > 0.8, 4, 1) AS BASE_ESCALATION_RATE,
       7 * (1 + FLOOR(U_REVIEW * 3)) AS REVIEW_INTERVAL_DAYS,
       0.55 + U_DISCIPLINE * 0.45 AS REVIEW_COMPLETION_PROB,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.PROGRAMME_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), city_events AS (
  -- Two city-wide bank transfer outages; every programme in the city logs a
  -- delay that resolves once transfers recover.
  SELECT * FROM VALUES (27, 'Jakarta'), (64, 'Medan') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT r.ID AS ENTITY_ID, r.PROGRAMME_INDEX, r.CATEGORY, r.REGION, r.PROGRAMME_AGE_YEARS,
         r.BASE_ESCALATION_RATE, r.REVIEW_INTERVAL_DAYS, r.REVIEW_COMPLETION_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + r.PROGRAMME_INDEX * 5, r.REVIEW_INTERVAL_DAYS) AS DAYS_SINCE_REVIEW,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'fail')), 1000000) / 1e6 AS U_FAIL,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'clear')), 1000000) / 1e6 AS U_CLEAR,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'type')), 1000000) / 1e6 AS U_TYPE,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'done')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'volume')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'sla')), 1000000) / 1e6 AS U_SLA,
         e.REGION IS NOT NULL AS CITY_EVENT
  FROM RAW.PROGRAMMES r CROSS JOIN days d
  LEFT JOIN city_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = r.REGION
), review AS (
  SELECT *,
         IFF(DAYS_SINCE_REVIEW = 0, 1, 0) AS REVIEW_DUE,
         IFF(DAYS_SINCE_REVIEW = 0 AND U_DONE < REVIEW_COMPLETION_PROB, 1, 0) AS REVIEW_COMPLETED,
         -- Data-quality drift rises between field verification visits; weak
         -- visit discipline carries it over.
         DAYS_SINCE_REVIEW / REVIEW_INTERVAL_DAYS + (1 - REVIEW_COMPLETION_PROB) AS DRIFT
  FROM base
), stress AS (
  SELECT *,
         CASE WHEN U_FAIL < LEAST(0.5, BASE_ESCALATION_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + PROGRAMME_AGE_YEARS))) / 4 THEN 2
              WHEN U_FAIL < LEAST(0.5, BASE_ESCALATION_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + PROGRAMME_AGE_YEARS))) THEN 1
              ELSE 0 END AS STRESS_COUNT
  FROM review
)
, cases AS (
  SELECT *,
         -- About 85% of stressed disbursement batches miss the 7-day payout
         -- target and are escalated to programme review; the rest catch up.
         IFF(CITY_EVENT, 0, IFF(U_DETECT < 0.85, STRESS_COUNT, 0)) AS ESCALATED_COUNT,
         -- Delays resolved by the distribution team without escalation.
         IFF(CITY_EVENT, 1, IFF(U_CLEAR < CASE CATEGORY WHEN 'Health assistance' THEN 0.20
                                                        WHEN 'Disaster relief' THEN 0.12
                                                        WHEN 'Economic empowerment' THEN 0.14 ELSE 0.08 END, 1, 0)) AS RESOLVED_COUNT
  FROM stress
), measured AS (
  SELECT *,
         ESCALATED_COUNT + RESOLVED_COUNT AS DELAYED_COUNT,
         ROUND(CASE CATEGORY WHEN 'Food assistance' THEN 380 WHEN 'Education scholarship' THEN 45
                             WHEN 'Health assistance' THEN 60 WHEN 'Disaster relief' THEN 90 ELSE 20 END
               * (0.7 + 0.6 * U_VOLUME) * (1 + 0.8 * STRESS_COUNT)) AS DISBURSEMENT_COUNT,
         CASE CATEGORY WHEN 'Food assistance' THEN 350000 WHEN 'Education scholarship' THEN 1500000
                       WHEN 'Health assistance' THEN 2500000 WHEN 'Disaster relief' THEN 750000
                       ELSE 5000000 END
           * (0.8 + 0.4 * U_NOISE) AS AVG_DISBURSEMENT_IDR
  FROM cases
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       DISBURSEMENT_COUNT,
       ROUND(DISBURSEMENT_COUNT * AVG_DISBURSEMENT_IDR, 0) AS VALUE_IDR,
       DELAYED_COUNT, ESCALATED_COUNT,
       IFF(ESCALATED_COUNT > 0 AND U_SLA < 0.6, 1, 0) AS SLA_BREACHED,
       CASE WHEN DELAYED_COUNT = 0 THEN 'None'
            WHEN CITY_EVENT THEN 'Bank transfer outage'
            WHEN CATEGORY = 'Food assistance' THEN IFF(U_TYPE < 0.5, 'Supplier delivery delay', IFF(U_TYPE < 0.8, 'Beneficiary list not verified', 'Beneficiary unreachable'))
            WHEN CATEGORY = 'Education scholarship' THEN IFF(U_TYPE < 0.45, 'Enrolment document pending', IFF(U_TYPE < 0.8, 'Bank account mismatch', 'Beneficiary unreachable'))
            WHEN CATEGORY = 'Health assistance' THEN IFF(U_TYPE < 0.55, 'Medical invoice pending', 'Bank account mismatch')
            WHEN CATEGORY = 'Disaster relief' THEN IFF(U_TYPE < 0.45, 'Field access restricted', IFF(U_TYPE < 0.8, 'Supplier delivery delay', 'Beneficiary list not verified'))
            ELSE IFF(U_TYPE < 0.5, 'Business plan review pending', IFF(U_TYPE < 0.75, 'Bank account mismatch', 'Beneficiary unreachable')) END AS DELAY_REASON,
       REVIEW_DUE, REVIEW_COMPLETED,
       ROUND(0.5 + 2.0 * DRIFT + 3.0 * STRESS_COUNT + U_NOISE * 0.8, 2) AS TRANSFER_REJECT_PCT,
       ROUND(2 + 2 * DRIFT + 4 * STRESS_COUNT + U_NOISE * 1.5, 1) AS AVG_DAYS_TO_DISBURSE,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM measured;

-- Programme file document coverage per programme (snapshot).
CREATE TABLE RAW.PROGRAMME_DOCUMENTS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Food assistance' THEN 'Beneficiary verification form'
                     WHEN 'Education scholarship' THEN 'Enrolment confirmation'
                     WHEN 'Health assistance' THEN 'Medical referral letter'
                     WHEN 'Disaster relief' THEN 'Field assessment report'
                     ELSE 'Business plan' END AS DOC_TYPE,
       1 + MOD(ABS(HASH(ID, 'req')), 4) AS REQUIRED_QTY,
       MOD(ABS(HASH(ID, 'file')), 5) AS ON_FILE_QTY,
       IFF(MOD(ABS(HASH(ID, 'file')), 5) < 1 + MOD(ABS(HASH(ID, 'req')), 4),
           MOD(ABS(HASH(ID, 'pending')), 3), 0) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.PROGRAMMES;

-- Daily donations collected per donor channel (organisation-wide, aggregate).
-- One day in seven and the last 30 days run higher (a generic weekly and seasonal
-- pattern keyed to the day index, so totals do not depend on the build day).
CREATE TABLE RAW.DONOR_CHANNEL_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), channels AS (
  SELECT * FROM VALUES ('QRIS', TRUE, 1400, 450000), ('E-wallet', TRUE, 1100, 350000),
                       ('Bank transfer', TRUE, 600, 4000000), ('Payroll deduction', FALSE, 250, 1200000),
                       ('Collection counter', FALSE, 500, 800000)
    AS c(CHANNEL, IS_DIGITAL, BASE_COUNT, AVG_IDR)
), base AS (
  SELECT c.CHANNEL, c.IS_DIGITAL, c.BASE_COUNT, c.AVG_IDR, d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(ABS(HASH(c.CHANNEL, d.DAY_INDEX, 'n')), 1000000) / 1e6 AS U_N,
         MOD(ABS(HASH(c.CHANNEL, d.DAY_INDEX, 'v')), 1000000) / 1e6 AS U_V
  FROM channels c CROSS JOIN days d
)
SELECT CHANNEL, IS_DIGITAL, EVENT_DATE,
       ROUND(BASE_COUNT * (0.8 + 0.4 * U_N) * IFF(MOD(DAY_INDEX, 7) = 6, 1.4, 1)
             * IFF(DAY_INDEX >= 60, 1.25, 1)) AS DONATION_COUNT,
       ROUND(BASE_COUNT * (0.8 + 0.4 * U_N) * IFF(MOD(DAY_INDEX, 7) = 6, 1.4, 1)
             * IFF(DAY_INDEX >= 60, 1.25, 1) * AVG_IDR * (0.85 + 0.3 * U_V), 0) AS COLLECTED_IDR
FROM base;
