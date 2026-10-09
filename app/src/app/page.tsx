'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';

interface ZakatData {
  platform: 'snowflake' | 'aws';
  kpiCards: { title: string; value: string }[];
  timeseries: { period: string; exceptions: number | null; failed: number | null }[];
  categories: { category: string; exceptions: number | null; failed: number | null }[];
  entities: Record<string, string | number | null>[];
  reconRisk: { name: string; compliance: number; failed: number }[];
  sourceWatermark: string | null;
  rawWatermark: string | null;
  requestedAt: string;
  stale: boolean;
  pipelineBehind: boolean;
  risk: Record<string, string | number | null>[];
  holdout: { n: number | null; baseRate: number | null; precision: number | null; recall: number | null } | null;
  forecast: { period: string; value: number | null; lower: number | null; upper: number | null }[];
  live: Record<string, string | number | null>[];
  liveSummary: { n: number | null; exceptions: number | null; lastLoaded: string | null; medianLagSeconds: number | null };
  anomalies: Record<string, string | number | null>[];
  alerts: Record<string, string | number | null>[];
  channels: { channel: string; digital: boolean; donations: number | null; collected: number | null; share: number | null }[];
}

const pct = (value: number | null) => (value === null ? 'n/a' : `${(value * 100).toFixed(0)}%`);

export default function HomePage() {
  const [data, setData] = useState<ZakatData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setData(null);
    fetch('/api/data', { cache: 'no-store', signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error('Data request failed');
        const payload = await response.json();
        if (!Array.isArray(payload.kpiCards) || !Array.isArray(payload.entities)) throw new Error('Invalid contract');
        return payload;
      })
      .then(setData)
      .catch(() => {
        if (!controller.signal.aborted) setError('Snowflake data is unavailable. No fallback values are displayed.');
      })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [attempt]);

  const isAws = (data?.platform ?? 'aws') === 'aws';
  const awsDiagram = { key: 'aws', title: 'AWS + Snowflake', src: '/architecture-aws.html' };
  const sfDiagram = { key: 'snowflake', title: 'Snowflake Only', src: '/architecture-snowflake.html' };
  const diagrams = isAws ? [awsDiagram, sfDiagram] : [sfDiagram, awsDiagram];
  const kpiVal = (title: string) => data?.kpiCards.find((card) => card.title === title)?.value ?? 'Unavailable';
  const executive = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {['On-Time Disbursement Rate', 'Delay Cases', 'Escalated to Programme Review', 'Disbursed Value (IDR B)'].map((title) => (
          <KPICard key={title} title={title} value={kpiVal(title)} status="neutral" />
        ))}
      </div>
      <p className="text-sm text-slate-600">On-time disbursement rate = scheduled disbursements without a delay case / scheduled disbursements. Escalation rate = delay cases escalated to programme review / delay cases. Disbursed value is the IDR value of all scheduled disbursements in the snapshot. Beneficiary figures are aggregate counts only.</p>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart data={data?.timeseries ?? []} type="line" xKey="period"
          yKeys={[{ key: 'exceptions', name: 'Delay cases' }, { key: 'failed', name: 'Escalated' }]} title="Daily Disbursement Delay Cases" />
        <Chart data={data?.categories ?? []} type="bar" xKey="category"
          yKeys={[{ key: 'exceptions', name: 'Delay cases' }, { key: 'failed', name: 'Escalated' }]} title="Delay Cases and Escalations by Delay Reason" />
      </div>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {['Collections (IDR B)', 'Digital Channel Share', 'Programmes Monitored', 'Beneficiary Notice SLA Breaches'].map((title) => (
          <KPICard key={title} title={title} value={kpiVal(title)} status="neutral" />
        ))}
      </div>
      <Chart data={data?.channels ?? []} type="bar" xKey="channel"
        yKeys={[{ key: 'collected', name: 'Collected (IDR B)' }]} title="Donations Collected by Donor Channel, 90 days (IDR B)" />
      <DataTable columns={[
        { key: 'id', header: 'Programme' }, { key: 'region', header: 'City' }, { key: 'category', header: 'Programme type' },
        { key: 'tier', header: 'Risk grade' }, { key: 'payments', header: 'Disbursements scheduled' }, { key: 'exceptions', header: 'Delay cases' },
        { key: 'failed', header: 'Escalated' }, { key: 'breaches', header: 'Notice SLA breaches' }, { key: 'value', header: 'Value (IDR B)' },
      ]} data={data?.entities ?? []} title="Programme observations (all programmes pay out in Indonesia)" />
    </div>
  );
  const predictive = (
    <div className="space-y-4">
      <h2 className="font-semibold">7-day delay escalation risk and delay-volume forecast</h2>
      <p className="text-sm text-slate-600">
        Snowflake ML classification predicts the probability that a programme has a disbursement delay escalated to programme review in the next 7 days,
        from the bank transfer rejection rate, average days to disburse, recent escalations, operational risk grade, programme age and programme type.
      </p>
      {data?.holdout ? (
        <p role="status" className="text-sm text-slate-700">
          Out-of-time holdout ({data.holdout.n} programme-days): precision {pct(data.holdout.precision)} and recall{' '}
          {pct(data.holdout.recall)} at a 0.5 threshold, versus a {pct(data.holdout.baseRate)} base rate.
        </p>
      ) : (
        <p role="status">Model outputs are not deployed. Run snowflake/05_ml.sql.</p>
      )}
      <DataTable columns={[
        { key: 'id', header: 'Programme' }, { key: 'band', header: 'Risk band' },
        { key: 'probability', header: 'P(escalation in 7 days)' }, { key: 'scoredAsOf', header: 'Scored as of' },
      ]} data={data?.risk ?? []} title="Delay escalation risk by programme" />
      <Chart data={data?.forecast ?? []} type="line" xKey="period"
        yKeys={[{ key: 'value', name: 'Forecast' }, { key: 'lower', name: 'Lower' }, { key: 'upper', name: 'Upper' }]}
        title="Organisation-wide delay forecast, next 14 days (delay cases per day)" />
      <DataTable columns={[
        { key: 'id', header: 'Programme' }, { key: 'date', header: 'Date' }, { key: 'screening', header: 'Bank transfer rejection rate (%)' },
        { key: 'expected', header: 'Expected' }, { key: 'upper', header: 'Upper bound' },
      ]} data={data?.anomalies ?? []} title="Bank transfer rejection rate anomalies, last 15 days (Snowflake ML anomaly detection, trained on the prior 75 days)" />
    </div>
  );
  const liveTab = (
    <div className="space-y-4">
      <h2 className="font-semibold">{isAws ? 'Live disbursements: Amazon Data Firehose to S3 to Snowpipe' : 'Live disbursements: Snowflake-native simulator'}</h2>
      <p className="text-sm text-slate-600">
        {isAws
          ? 'Simulated disbursement events are sent to the Firehose stream id-zakat-disbursements (aws/publish_disbursements.py). Firehose writes batches to S3, and Snowpipe auto-ingest loads them into RAW.LIVE_DISBURSEMENTS.'
          : 'CALL APP.SIMULATE_DISBURSEMENTS(n) inserts simulated disbursement events directly into RAW.LIVE_DISBURSEMENTS (or resume APP.TASK_SIMULATE_DISBURSEMENTS for a feed every minute). This simulates a disbursement feed; it is not Snowpipe Streaming.'}
        {' '}The alert APP.LIVE_DELAY_ALERT logs DELAYED disbursements and emails the on-call distribution officer.
      </p>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Disbursement events loaded" value={String(data?.liveSummary?.n ?? 'n/a')} />
        <KPICard title="Delayed disbursements" value={String(data?.liveSummary?.exceptions ?? 'n/a')} />
        <KPICard title={isAws ? 'Median send to table lag (s)' : 'Median generated to table lag (s)'} value={String(data?.liveSummary?.medianLagSeconds ?? 'n/a')} />
        <KPICard title="Last load" value={data?.liveSummary?.lastLoaded ?? 'none'} />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Programme' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'amount', header: 'Amount (IDR)' },
        { key: 'settle', header: 'Days late' }, { key: 'status', header: 'Status' }, { key: 'loadedAt', header: 'Loaded' },
      ]} data={data?.live ?? []} title="Latest 25 disbursement events" />
      <DataTable columns={[
        { key: 'id', header: 'Programme' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'amount', header: 'Amount (IDR)' },
        { key: 'settle', header: 'Days late' }, { key: 'hint', header: 'Action hint' },
      ]} data={data?.alerts ?? []} title="Alert log" />
    </div>
  );
  const planning = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <KPICard title="Field Verification Compliance" value={kpiVal('Field Verification Compliance')} />
        <KPICard title="Programme File Coverage" value={kpiVal('Programme File Coverage')} />
        <KPICard title="Programme Documents Pending" value={kpiVal('Programme Documents Pending')} />
      </div>
      <Chart data={data?.reconRisk ?? []} type="scatter" xKey="compliance" xName="Field verification compliance"
        yKeys={[{ key: 'failed', name: 'Escalated cases' }]} yDomain={[0, 'auto']}
        title="Field verification compliance (%) vs escalated cases by programme" />
      <p className="text-sm text-slate-600">Synthetic associations are not evidence that verification visits prevented escalations.</p>
      <ActionMemo persona={{ name: 'Siti Rahmawati', role: 'Head of Distribution (fictional persona)' }} context={{}}
        onGenerate={async () => {
          const r = await fetch('/api/ask', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mode: 'memo' }) });
          if (!r.ok) throw new Error('memo failed');
          const j = await r.json();
          return { subject: 'Draft distribution actions (synthetic data, human review required)', body: j.answer, urgency: 'review', actions: [] };
        }} />
      <p role="status" className="text-sm text-slate-600">{isAws ? 'Draft generated by Amazon Bedrock (Claude) through a Snowflake external-access function' : 'Draft generated by Snowflake Cortex AI_COMPLETE (Claude Sonnet 4.5)'}, from the KPI, programme, delay-reason, risk and donor-channel tables only. No notification is sent.</p>
    </div>
  );
  const ai = (
    <div className="space-y-4">
      <p role="status">Answers come from the Cortex Agent APP.ZAKAT_AGENT. It uses Cortex Analyst over the semantic view APP.ZAKAT_ANALYTICS for metrics, and Cortex Search over synthetic disbursement delay handling SOPs for procedures. The generated SQL is shown with each answer.</p>
      <div className="h-[500px]">
        <AskAI title="Ask the distribution agent" mode="advisor" sampleQuestions={['Which 3 programmes have the most escalated cases?', 'Which programmes are high risk this week and what SOP applies?', 'What is the escalation rate by delay reason?', 'Which donor channel collected the most?']}
          onSubmit={async (question) => {
            const r = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ question }) });
            if (!r.ok) throw new Error('agent failed');
            const j = await r.json();
            const cites = j.sops?.length ? `\n\nSOPs: ${j.sops.join(', ')}` : '';
            return { answer: `${j.answer}${cites}`, sql: j.sql ?? undefined };
          }} />
      </div>
    </div>
  );
  const architecture = (
    <div className="space-y-4">
      {diagrams.map((d, i) => (
        <div key={d.key} className="space-y-2">
          <h2 className="font-semibold">Architecture: {d.title}{i === 0 ? ' (this deployment)' : ''}</h2>
          <iframe src={d.src} title={`${d.title} architecture diagram`} className="h-[620px] w-full rounded border border-slate-200" />
          <p className="text-sm text-slate-600">Hover a component for details. <a className="underline" href={d.src} target="_blank" rel="noreferrer">Open full screen</a></p>
        </div>
      ))}
      <h2 className="font-semibold">Implementation status</h2>
      <p>Core source: 40 synthetic distribution programmes across 5 Indonesian cities, daily programme observations, programme file documents and daily donations by donor channel. Curated dynamic tables compute numerator/denominator metrics and are suspended after on-demand initialization.</p>
      <p>Application: Next.js server queries the explicit curated contract. Request time and source observation watermark are separate.</p>
      <p>ML: SNOWFLAKE.ML.CLASSIFICATION delay escalation risk model evaluated on a time-based holdout, plus a 14-day delay-volume FORECAST with prediction intervals.</p>
      <p>ML: ANOMALY_DETECTION flags bank transfer rejection rate outliers per programme over the last 15 days.</p>
      <p>AI: Cortex Agent (Cortex Analyst over a semantic view, plus Cortex Search over SOPs) answers questions. The action memo uses {isAws ? 'Amazon Bedrock Claude through an external-access UDF' : 'Cortex AI_COMPLETE (Claude Sonnet 4.5)'}.</p>
      {isAws ? (
        <>
          <p>AWS ingestion: Amazon Data Firehose to S3 to Snowpipe auto-ingest (SQS) into RAW.LIVE_DISBURSEMENTS, with a Snowflake alert and email on delayed disbursements.</p>
          <p>QuickSight: Snowflake DIRECT_QUERY dashboard (daily delay cases, escalations by programme, escalation risk) through a PAT-only service user, with a Q topic.</p>
        </>
      ) : (
        <>
          <p>Ingestion: APP.SIMULATE_DISBURSEMENTS inserts simulated disbursement events into RAW.LIVE_DISBURSEMENTS, with a Snowflake alert and email on delayed disbursements. No AWS account is used.</p>
          <p>BI: this SPCS app is the dashboard; natural-language questions go to the Cortex Agent.</p>
        </>
      )}
      <p>Orchestration: the task graph APP.TASK_REFRESH_CURATED, then TASK_RESCORE_RISK, runs on demand. Alerts and tasks stay suspended between demos.</p>
    </div>
  );
  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '', content: executive },
    { id: 'predictive', label: 'Predictive', icon: '', content: predictive },
    { id: 'planning', label: 'Controls', icon: '', content: planning },
    { id: 'live', label: 'Live Disbursements', icon: '', content: liveTab },
    { id: 'ask-ai', label: 'Ask AI', icon: '', content: ai },
    { id: 'architecture', label: 'Architecture & Data', icon: '', content: architecture },
  ].map((tab) => ({ ...tab, content: tab.id === 'architecture' ? tab.content : (
    <div className="space-y-4">
      <p className="text-sm text-slate-600">Synthetic demo data for a fictional Indonesian zakat and waqf management organisation. On-demand snapshots are not live operations, and no individual beneficiary is shown.</p>
      {loading ? <p role="status">Loading Snowflake data...</p> : error ? (
        <div role="alert" className="rounded border border-red-200 p-4">
          <p>{error}</p>
          <button className="mt-3 rounded border px-3 py-2" onClick={() => setAttempt((value) => value + 1)}>Retry data connection</button>
        </div>
      ) : !data?.entities.length ? <p role="status">No programme observations are available in this snapshot.</p> : (
        <>
          <p className="text-sm">Observation watermark: {data.sourceWatermark ?? 'Unavailable'}. Request time: {data.requestedAt}.</p>
          {(data.stale || data.pipelineBehind) && <p role="status" className="text-amber-700">Stale or lagging snapshot. Refresh the on-demand pipeline before presenting current results.</p>}
          {tab.content}
        </>
      )}
    </div>
  ) }));
  return <AppLayout title="Indonesia Zakat and Waqf Distribution Operations" tabs={tabs} />;
}
