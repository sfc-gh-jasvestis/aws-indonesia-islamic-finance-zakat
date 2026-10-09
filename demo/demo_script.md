# Zakat and Waqf Distribution Operations

**Indonesia - Zakat and Waqf Management**
Use case: Disbursement delays, escalation to programme review, distribution controls and donor channels

> Distribution monitoring for 40 zakat distribution programmes at a fictional Indonesian zakat and waqf management organisation across 5 cities: dynamic tables, a holdout-evaluated escalation classifier, a delay-volume forecast and grounded AI answers.

## Why Snowflake

- **Dynamic tables** reconcile disbursements scheduled, delay cases, escalations, notice SLA breaches, field verification compliance and donor-channel collections from RAW data, with checks in `run_core.py`
- **Escalation classification** gives a holdout-evaluated next-7-day probability per programme
- **Delay forecast** projects 14 days of organisation-wide delay volume with prediction intervals, for distribution team staffing
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live disbursements**: a native simulator (Snowflake only) or Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.PROGRAMMES` (40 rows) |
| Fact tables | `RAW.PROGRAMME_DAILY` (3,600 programme-days, 90 days), `RAW.DONOR_CHANNEL_DAILY` (450 channel-days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `DELAY_SUMMARY`, `CHANNEL_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.ESCALATION_RISK_SCORES`, `ML.ESCALATION_RISK_HOLDOUT_METRICS`, `ML.DELAY_FORECAST`, `ML.TRANSFER_REJECT_ANOMALIES` |

Cities: Jakarta, Surabaya, Bandung, Medan, Makassar (IDR).
Programme types: Food assistance, Education scholarship, Health assistance, Disaster relief, Economic empowerment.
Donor channels: QRIS, E-wallet, Bank transfer, Payroll deduction, Collection counter.

Presenter note: the demo describes distribution operations only, with aggregate beneficiary and donor counts. It makes no religious or regulatory rulings, and the SOPs are synthetic.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| On-Time Disbursement Rate | 99.91% |
| Delay Cases | 583 |
| Escalated to Programme Review | 198 |
| Escalation Rate | 34.0% |
| Beneficiary Notice SLA Breaches | 95 |
| Disbursed Value (IDR B) | 406 |
| Disbursements Scheduled | 665,094 |
| Field Verification Compliance | 81.0% |
| Programmes Monitored | 40 |
| Programme File Coverage | 49.0% |
| Programme Documents Pending | 22 |
| Collections (IDR B) | 426 |
| Digital Channel Share | 83.1% |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily delay cases against escalations, delays and escalations by reason, collections by donor channel, programme table
2. Predictive: holdout metrics, risk bands, 14-day delay forecast, bank transfer rejection rate anomalies
3. Controls: field verification compliance, programme file coverage and pending documents, verification compliance against escalated cases, then generate the action memo
4. Live Disbursements: run `CALL APP.SIMULATE_DISBURSEMENTS(20)` (Snowflake only) or `python aws/publish_disbursements.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_DELAY_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- 99.91% of scheduled disbursements go out without a delay case; the 583 delay cases are where distribution time goes, and 34.0% of them are escalated to programme review.
- Supplier delivery delay produces the most escalations (49 of 127 cases). Bank transfer outages hit every programme in a city at once and always resolve without escalation.
- The risk model is evaluated on a time-based holdout: precision 0.49 and recall 0.34 at 0.5, against a 0.22 base rate. Present it as triage, not a verdict.
- Bank transfer outages are excluded from model training, because they are not programme-driven.
- Digital channels bring in 83.1% of the IDR 426 B collected; bank transfer alone is 58.4%.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
