-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for Zakat & Waqf Management
-- Country: INDONESIA | Currency: IDR
-- ============================================================================
USE DATABASE ZAKAT_MANAGEMENT;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- MUZAKKI: 2,000,000 rows — Zakat payers (muzakki) with demographics, payment history, and channel preference
-- COLLECTIONS: 5,000,000 rows — Individual zakat, infaq, and sadaqah collection transactions
-- MUSTAHIK: 500,000 rows — Zakat beneficiaries (mustahik) with needs assessment and eligibility category
-- DISTRIBUTIONS: 1,000,000 rows — Zakat distribution records to 8 asnaf categories
-- PROGRAMS: 200 rows — Zakat distribution programs: education, health, economic empowerment, disaster relief
-- IMPACT_REPORTS: 80 rows — Program impact assessments, beneficiary surveys, and outcome evaluations
