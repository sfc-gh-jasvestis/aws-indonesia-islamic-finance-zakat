# Zakat & Waqf Management

**Indonesia - Islamic Finance**
Use case: Zakat & Social Finance

> Data-driven zakat collection and distribution for Indonesia's US$14B potential — ML.FORECAST predicts collection trends, Dynamic Tables build real-time muzakki/mustahik dashboards, and Cortex AI generates impact reports.

## Why Snowflake

Snowflake optimizes zakat impact — Dynamic Tables maintain real-time collection and distribution ledgers, ML.FORECAST projects seasonal patterns, and Cortex AI measures beneficiary outcomes and generates donor impact reports

- **ML.FORECAST on zakat collection trends** - Only demo using ML.FORECAST for Islamic social finance collection prediction
- **Ramadan seasonal surge planning** - ML-enabled resource planning for annual zakat collection peak
- **Poverty graduation rate tracking** - Unique impact metric for zakat economic empowerment programs
- **Indonesian zakat national context** - US$14B potential, 2M+ muzakki, 34 provinces, 8 asnaf distribution model

## What is deployed

| | |
|---|---|
| Database | `ID_ISLAMIC_FINANCE_ZAKAT` |
| Service | `ID_ISLAMIC_FINANCE_ZAKAT_APP` |
| Compute pool | `SEA_DEMOS_INDONESIA_POOL` |
| Dimension table | `RAW.IMPACT_REPORTS` (20 rows) |
| Fact table | `RAW.COLLECTIONS` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | IDR (Rp) |

Regions in play: Jakarta, North Sumatra, Riau, East Kalimantan, Sulawesi
Segments: Zakat Maal, Zakat Fitrah, Cash Waqf, Productive Waqf

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh ID_ISLAMIC_FINANCE_ZAKAT
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Zakat Collected (YTD) | `Rp 18.4T` | total across Impact Reports |
| Beneficiaries Reached | `8.4M` | total across Impact Reports |
| Distribution Efficiency | `94%` | average per event |
| Collection Growth | `+12%` | average per event |
| Poverty Alleviation | `1.2M families` | total across Impact Reports |
| Education Scholarships | `84K` | total across Impact Reports |
| Healthcare Support | `420K` | total across Impact Reports |


## Demo flow

1. National Overview
2. Distribution & Impact
3. Predictive Planning
4. Ask AI
5. Architecture & Data

## Talking points

- **Rp 21T** - annual zakat collection (23% YoY growth)
- **2M muzakki** - registered zakat payers
- **500K mustahik** - beneficiaries served across 34 provinces
- **64% digital** - collection via digital channels
- **23% graduation** - poverty graduation rate from economic programs

## Business impact

- Indonesia's zakat potential estimated at US$14B — only Rp 21T (US$1.3B) collected formally (BAZNAS)
- Digital zakat collection grew 45% in 2023 as fintech platforms expanded reach (BAZNAS)
- Zakat economic empowerment programs show 20-25% poverty graduation rates within 2 years (World Bank Islamic Finance)
- Indonesia has 87% Muslim population (237 million) — largest Islamic economy globally (Pew Research)

---
Generated from `generator/demo_specs/aws-indonesia-islamic-finance-zakat.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-indonesia-islamic-finance-zakat` instead.
