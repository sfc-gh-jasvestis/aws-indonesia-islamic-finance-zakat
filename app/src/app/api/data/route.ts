import { NextResponse } from 'next/server';
import { demoPlatform } from '@/lib/platform';
import { executeQuery } from '@/lib/snowflake';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export async function GET() {
  try {
    const [kpis, trend, types, routes, freshness, risk, holdout, forecast, live, liveSummary, anomalies, alerts, channels] = await Promise.all([
      executeQuery<{ TITLE: string; DISPLAY: string; STATUS: string }>(
        'SELECT TITLE, DISPLAY, STATUS FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER'),
      executeQuery<{ PERIOD: string; EXCEPTIONS: number | null; FAILED: number | null }>(`
        SELECT TO_CHAR(METRIC_DATE, 'YYYY-MM-DD') AS PERIOD,
               DELAYED_COUNT AS EXCEPTIONS, ESCALATED_COUNT AS FAILED
        FROM CURATED.TREND_ANALYSIS ORDER BY METRIC_DATE`),
      executeQuery<{ DELAY_REASON: string; EXCEPTIONS: number; FAILED: number }>(`
        SELECT DELAY_REASON, DELAYED_COUNT AS EXCEPTIONS, ESCALATED_COUNT AS FAILED
        FROM CURATED.DELAY_SUMMARY ORDER BY ESCALATED_COUNT DESC, DELAYED_COUNT DESC`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, RISK_TIER, EVENT_COUNT, DISBURSEMENT_COUNT, DELAYED_COUNT,
               ESCALATED_COUNT, SLA_BREACH_COUNT, ESCALATION_SHARE_PCT, REVIEW_COMPLIANCE_PCT, ROUND(VALUE_IDR / 1e9, 2) AS VALUE_IDR_B
        FROM CURATED.PERFORMANCE_SUMMARY ORDER BY ENTITY_ID LIMIT 200`),
      executeQuery<{ RAW_WATERMARK: string | null; CURATED_WATERMARK: string | null }>(`
        SELECT (SELECT TO_CHAR(MAX(EVENT_DATE), 'YYYY-MM-DD') FROM RAW.PROGRAMME_DAILY) AS RAW_WATERMARK,
               (SELECT TO_CHAR(MAX(METRIC_DATE), 'YYYY-MM-DD') FROM CURATED.TREND_ANALYSIS) AS CURATED_WATERMARK`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(SCORED_AS_OF, 'YYYY-MM-DD') AS SCORED_AS_OF, ESCALATION_PROB_7D, RISK_BAND
        FROM ML.ESCALATION_RISK_SCORES ORDER BY ESCALATION_PROB_7D DESC`),
      executeQuery<Record<string, string | number | null>>(
        'SELECT N, BASE_RATE, PRECISION_AT_50, RECALL_AT_50 FROM ML.ESCALATION_RISK_HOLDOUT_METRICS'),
      executeQuery<Record<string, string | number | null>>(`
        SELECT TO_CHAR(FORECAST_DATE, 'YYYY-MM-DD') AS PERIOD, DELAYED_COUNT, LOWER_BOUND, UPPER_BOUND
        FROM ML.DELAY_FORECAST ORDER BY FORECAST_DATE`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT PROGRAMME_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(AMOUNT_IDR, 0) AS AMOUNT_IDR,
               DAYS_LATE, STATUS, TO_CHAR(LOADED_AT, 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LOADED_AT
        FROM RAW.LIVE_DISBURSEMENTS ORDER BY EVENT_TS DESC LIMIT 25`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT COUNT(*) AS N, COUNT_IF(STATUS = 'DELAYED') AS EXCEPTIONS,
               TO_CHAR(MAX(LOADED_AT), 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LAST_LOADED,
               ROUND(MEDIAN(DATEDIFF('second', SENT_TS, CONVERT_TIMEZONE('UTC', LOADED_AT)::TIMESTAMP_NTZ)), 0) AS MEDIAN_LAG_S
        FROM RAW.LIVE_DISBURSEMENTS`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(EVENT_DATE, 'YYYY-MM-DD') AS EVENT_DATE, ROUND(TRANSFER_REJECT, 2) AS TRANSFER_REJECT,
               ROUND(EXPECTED, 2) AS EXPECTED, ROUND(UPPER_BOUND, 2) AS UPPER_BOUND
        FROM ML.TRANSFER_REJECT_ANOMALIES WHERE IS_ANOMALY ORDER BY EVENT_DATE DESC, ENTITY_ID LIMIT 50`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT PROGRAMME_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(AMOUNT_IDR, 0) AS AMOUNT_IDR,
               DAYS_LATE, SOP_HINT
        FROM APP.ALERT_LOG ORDER BY ALERTED_AT DESC, EVENT_TS DESC LIMIT 25`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT CHANNEL, IS_DIGITAL, DONATION_COUNT, ROUND(COLLECTED_IDR / 1e9, 2) AS COLLECTED_IDR_B, ROUND(SHARE_PCT, 1) AS SHARE_PCT
        FROM CURATED.CHANNEL_SUMMARY ORDER BY COLLECTED_IDR DESC`),
    ]);
    const numberOrNull = (value: unknown): number | null => {
      if (value === null || value === undefined) return null;
      const numeric = Number(value);
      if (!Number.isFinite(numeric)) throw new Error('Non-numeric measure in curated contract');
      return numeric;
    };
    const watermark = freshness[0]?.CURATED_WATERMARK ?? null;
    const ageDays = watermark ? (Date.now() - Date.parse(`${watermark}T00:00:00Z`)) / 86400000 : null;
    return NextResponse.json({
      platform: demoPlatform(),
      kpiCards: kpis.map((row) => ({ title: row.TITLE, value: row.DISPLAY, status: row.STATUS })),
      timeseries: trend.map((row) => ({ period: row.PERIOD, exceptions: numberOrNull(row.EXCEPTIONS), failed: numberOrNull(row.FAILED) })),
      categories: types.map((row) => ({ category: row.DELAY_REASON, exceptions: numberOrNull(row.EXCEPTIONS), failed: numberOrNull(row.FAILED) })),
      entities: routes.map((row) => ({
        id: row.ENTITY_ID, name: row.ENTITY_NAME, region: row.REGION, category: row.CATEGORY, tier: row.RISK_TIER,
        payments: numberOrNull(row.DISBURSEMENT_COUNT), exceptions: numberOrNull(row.DELAYED_COUNT), failed: numberOrNull(row.ESCALATED_COUNT),
        breaches: numberOrNull(row.SLA_BREACH_COUNT), failureRate: numberOrNull(row.ESCALATION_SHARE_PCT),
        value: numberOrNull(row.VALUE_IDR_B), recon: numberOrNull(row.REVIEW_COMPLIANCE_PCT), events: numberOrNull(row.EVENT_COUNT),
      })),
      reconRisk: routes.map((row) => ({
        name: row.ENTITY_NAME, compliance: numberOrNull(row.REVIEW_COMPLIANCE_PCT), failed: numberOrNull(row.ESCALATED_COUNT),
      })).filter((row) => row.compliance !== null && row.failed !== null),
      sourceWatermark: watermark,
      rawWatermark: freshness[0]?.RAW_WATERMARK ?? null,
      stale: ageDays === null || ageDays > 2,
      pipelineBehind: freshness[0]?.RAW_WATERMARK !== watermark,
      requestedAt: new Date().toISOString(),
      synthetic: true,
      risk: risk.map((row) => ({
        id: row.ENTITY_ID, scoredAsOf: row.SCORED_AS_OF,
        probability: numberOrNull(row.ESCALATION_PROB_7D), band: row.RISK_BAND,
      })),
      holdout: holdout[0] ? {
        n: numberOrNull(holdout[0].N), baseRate: numberOrNull(holdout[0].BASE_RATE),
        precision: numberOrNull(holdout[0].PRECISION_AT_50), recall: numberOrNull(holdout[0].RECALL_AT_50),
      } : null,
      forecast: forecast.map((row) => ({
        period: row.PERIOD, value: numberOrNull(row.DELAYED_COUNT),
        lower: numberOrNull(row.LOWER_BOUND), upper: numberOrNull(row.UPPER_BOUND),
      })),
      modelStatus: holdout[0] ? 'holdout_evaluated' : 'missing',
      live: live.map((row) => ({
        id: row.PROGRAMME_ID, eventTs: row.EVENT_TS, amount: numberOrNull(row.AMOUNT_IDR),
        settle: numberOrNull(row.DAYS_LATE), status: row.STATUS, loadedAt: row.LOADED_AT,
      })),
      liveSummary: {
        n: numberOrNull(liveSummary[0]?.N), exceptions: numberOrNull(liveSummary[0]?.EXCEPTIONS),
        lastLoaded: liveSummary[0]?.LAST_LOADED ?? null, medianLagSeconds: numberOrNull(liveSummary[0]?.MEDIAN_LAG_S),
      },
      anomalies: anomalies.map((row) => ({
        id: row.ENTITY_ID, date: row.EVENT_DATE, screening: numberOrNull(row.TRANSFER_REJECT),
        expected: numberOrNull(row.EXPECTED), upper: numberOrNull(row.UPPER_BOUND),
      })),
      alerts: alerts.map((row) => ({
        id: row.PROGRAMME_ID, eventTs: row.EVENT_TS, amount: numberOrNull(row.AMOUNT_IDR),
        settle: numberOrNull(row.DAYS_LATE), hint: row.SOP_HINT,
      })),
      channels: channels.map((row) => ({
        channel: row.CHANNEL, digital: String(row.IS_DIGITAL).toLowerCase() === 'true',
        donations: numberOrNull(row.DONATION_COUNT), collected: numberOrNull(row.COLLECTED_IDR_B), share: numberOrNull(row.SHARE_PCT),
      })),
    }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json({ error: 'Zakat operations data is unavailable. Verify the core deployment and application role.' },
      { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }
}
