-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Zakat & Waqf Management
-- ============================================================================
USE DATABASE ZAKAT_MANAGEMENT;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.ZAKAT_ANALYTICS
  COMMENT = 'Zakat collection, distribution, donor, beneficiary, and impact analytics'
AS
  TABLES (
    CURATED.COLLECTION_DASHBOARD AS collection_dashboard,CURATED.DISTRIBUTION_EQUITY AS distribution_equity,CURATED.DONOR_SEGMENTATION AS donor_segmentation,CURATED.IMPACT_METRICS AS impact_metrics
  );
