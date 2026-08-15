-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Zakat & Waqf Management
-- ============================================================================
USE DATABASE ZAKAT_MANAGEMENT;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.ZAKAT_INTELLIGENCE_AGENT
  COMMENT = 'Zakat & Waqf Management AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'ZAKAT_MANAGEMENT.APP.ZAKAT_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'ZAKAT_MANAGEMENT.SEARCH.IMPACT_REPORTS_SEARCH', TOOL_DESCRIPTION => 'Search documents for Islamic Finance information')
  )
  SYSTEM_PROMPT = 'You are the Zakat Intelligence Agent for Indonesia''s national zakat authority (BAZNAS), managing Rp 21 trillion in annual collection and distribution across 34 provinces to 8 asnaf categories.';
