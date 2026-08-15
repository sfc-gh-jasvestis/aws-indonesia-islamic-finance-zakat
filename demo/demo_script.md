# Demo Script: Zakat & Waqf Management
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake optimizes zakat impact — Dynamic Tables maintain real-time collection and distribution ledgers, ML.FORECAST projects seasonal patterns, and Cortex AI measures beneficiary outcomes and generates donor impact reports"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Prof. Dr. Noor Achmad** | Director of Collection | React App (SPCS) | Collection targets, donor retention, digital channel growth, Ramadan surge planning |
| **Fatimah Zahra** | Impact Measurement Analyst | Amazon QuickSight | Distribution equity, beneficiary outcomes, geographic coverage, poverty reduction metrics |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 6 tables | MUZAKKI (2000000), COLLECTIONS (5000000), MUSTAHIK (500000), DISTRIBUTIONS (1000000), PROGRAMS (200), IMPACT_REPORTS (80) |
| **CURATED** | 4 Dynamic Tables | COLLECTION_DASHBOARD, DISTRIBUTION_EQUITY, DONOR_SEGMENTATION, IMPACT_METRICS |
| **ML** | ML.FORECAST | Forecasting + anomaly detection |
| **AI** | COMPLETE, SUMMARIZE, AI_CLASSIFY | Classification + extraction |
| **Search** | Cortex Search | 80 documents indexed |
| **Agent** | ZAKAT_INTELLIGENCE_AGENT | Semantic View + Search tools |


---

## The Story

Indonesia's zakat potential is US$14 billion annually, but only 3% is collected through formal channels. BAZNAS must increase digital collection, retain high-value donors through personalized engagement, and prove impact through data-driven program evaluation — all while ensuring equitable distribution across 34 provinces to 8 asnaf categories.

---

## Script

### [0:00–0:45] NATIONAL OVERVIEW

**Show**: National Overview tab

> "Rp 21 trillion collected from 2 million muzakki — 23% growth year-on-year."

**Action**: Point at Rp 21T collection and 23% growth

### [0:45–1:30] DISTRIBUTION & IMPACT

**Show**: Distribution & Impact tab

> "500,000 mustahik served across 34 provinces — 8 asnaf categories."

**Action**: Show distribution map by province

### [1:30–2:15] PREDICTIVE PLANNING

**Show**: Predictive Planning tab

> "ML.FORECAST projects Rp 26T collection next year if digital growth continues."

**Action**: Show collection forecast with confidence bands

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Prof. Noor asks: 'Are we on track to meet the annual collection target?'"

**Action**: Type target tracking question

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Six Snowflake capabilities, six AWS services."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **ML.FORECAST on zakat collection trends** — Only demo using ML.FORECAST for Islamic social finance collection prediction
2. **Ramadan seasonal surge planning** — ML-enabled resource planning for annual zakat collection peak
3. **Poverty graduation rate tracking** — Unique impact metric for zakat economic empowerment programs
4. **Indonesian zakat national context** — US$14B potential, 2M+ muzakki, 34 provinces, 8 asnaf distribution model


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM ZAKAT_MANAGEMENT.RAW.MUZAKKI` → 2000000
- [ ] `SELECT COUNT(*) FROM ZAKAT_MANAGEMENT.RAW.COLLECTIONS` → 5000000
- [ ] `SELECT COUNT(*) FROM ZAKAT_MANAGEMENT.RAW.MUSTAHIK` → 500000

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM ZAKAT_MANAGEMENT.ML.COLLECTION_FORECAST_RESULTS` → >0

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM ZAKAT_MANAGEMENT.AI.MUSTAHIK_CLASSIFICATION` → 500000

