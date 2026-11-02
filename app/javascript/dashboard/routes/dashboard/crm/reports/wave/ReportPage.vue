<script setup>
// Custom (MyDesk): Sales > Reports > one report of phase 4 (docs/reports/CRM_REPORTS_PLAN.md). One page for the seven
// reports of wave أ: its title is the question it answers, the filters are the ones it takes (reportCatalog.js), every
// number opens the deals behind it (DrillPanel), and an employee sees only their own (the server scopes it).
import { ref, computed, watch, onMounted, nextTick } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Select from 'dashboard/components-next/select/Select.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';
import { crmReportsAPI } from 'dashboard/api/crm';
import CrmPageHeader from '../../shared/CrmPageHeader.vue';
import CrmUnavailable from '../../shared/CrmUnavailable.vue';
import AgentPicker from '../../shared/AgentPicker.vue';
import { useCrmLists } from '../../shared/useCrmLists';
import { useCrmFormat } from '../../shared/useCrmFormat';
import { periodRange } from '../periods';
import {
  reportFor,
  forwardRange,
  PAST_PERIODS,
  FORWARD_PERIODS,
} from './reportCatalog';
import DrillPanel from './DrillPanel.vue';
import ReportNav from './ReportNav.vue';
import { saveFile } from './saveFile';
import { toQuery, fromQuery } from './reportQuery';
import { printReport, escapeHtml } from './printReport';
import PipelineByStageReport from './PipelineByStageReport.vue';
import ClosingReport from './ClosingReport.vue';
import StaleReport from './StaleReport.vue';
import MyTasksReport from './MyTasksReport.vue';
import WonLostReport from './WonLostReport.vue';
import QuotaReport from './QuotaReport.vue';
import ForecastReport from './ForecastReport.vue';
import CoverageReport from './CoverageReport.vue';
import WinRateReport from './WinRateReport.vue';
import LossesReport from './LossesReport.vue';
import ActivityReport from './ActivityReport.vue';
import NewDealsReport from './NewDealsReport.vue';
import DataQualityReport from './DataQualityReport.vue';
import ScorecardReport from './ScorecardReport.vue';
import ConversionReport from './ConversionReport.vue';
import CycleReport from './CycleReport.vue';
import ChangesReport from './ChangesReport.vue';
import RevenueReport from './RevenueReport.vue';
import DealSizeReport from './DealSizeReport.vue';

const BODIES = {
  pipeline_by_stage: PipelineByStageReport,
  closing: ClosingReport,
  stale: StaleReport,
  my_tasks: MyTasksReport,
  won_lost: WonLostReport,
  quota: QuotaReport,
  forecast: ForecastReport,
  coverage: CoverageReport,
  win_rate: WinRateReport,
  losses: LossesReport,
  activity: ActivityReport,
  new_deals: NewDealsReport,
  data_quality: DataQualityReport,
  scorecard: ScorecardReport,
  conversion: ConversionReport,
  cycle: CycleReport,
  changes: ChangesReport,
  revenue: RevenueReport,
  deal_size: DealSizeReport,
};

const route = useRoute();
const router = useRouter();
const { t, locale } = useI18n();
const store = useStore();
const lists = useCrmLists();
const { date, dateTime, number } = useCrmFormat();

const pipelines = useMapGetter('crm/pipelines/all');
const isAdmin = useMapGetter('crm/status/isAdmin');
const agents = useMapGetter('agents/getAgents');
const currentUser = useMapGetter('getCurrentUser');
const currentAccount = useMapGetter('getCurrentAccount');

// An employee who follows a link to a manager's report lands on the first one instead
const report = computed(() => {
  const found = reportFor(route.params.reportKey);
  return found.adminOnly && !isAdmin.value ? reportFor('') : found;
});
const R = key => t(`CRM.REPORTS.WAVE.REPORTS.${report.value.key}.${key}`);

const period = ref('month');
const from = ref('');
const to = ref('');
const pipelineId = ref('');
const assigneeId = ref('');
const productId = ref('');
const leadSourceId = ref('');
const stageId = ref('');
const days = ref('');
// Report 10: what to compare (assignee, product, lead_source); empty lets the server pick
const groupBy = ref('');

const data = ref(null);
// When the numbers on screen were fetched (shown under the title)
const updatedAt = ref('');
const filtersOpen = ref(false);
const isLoading = ref(true);
const isUnavailable = ref(false);
const drillPanel = ref(null);

const periodOptions = computed(() =>
  (
    report.value.periods ||
    (report.value.period === 'forward' ? FORWARD_PERIODS : PAST_PERIODS)
  ).map(p => ({ value: p, label: t(`CRM.REPORTS.WAVE.PERIODS.${p}`) }))
);
const pipelineOptions = computed(() => [
  { value: '', label: t('CRM.COMMON.ALL') },
  ...pipelines.value.map(p => ({ value: p.id, label: p.name })),
]);
const stageOptions = computed(() => {
  const shown = pipelineId.value
    ? pipelines.value.filter(p => p.id === Number(pipelineId.value))
    : pipelines.value;
  return [
    { value: '', label: t('CRM.COMMON.ALL') },
    ...shown.flatMap(p =>
      p.stages
        .filter(s => s.kind === 'open')
        .map(s => ({
          value: s.id,
          label: shown.length > 1 ? `${p.name} · ${s.name}` : s.name,
        }))
    ),
  ];
});
const productOptions = computed(() =>
  lists.options('product', t('CRM.COMMON.ALL'))
);
const sourceOptions = computed(() =>
  lists.options('lead_source', t('CRM.COMMON.ALL'))
);
const showAssignee = computed(() => isAdmin.value && !report.value.tasks);

const params = computed(() => ({
  from: report.value.period ? from.value : undefined,
  to: report.value.period ? to.value : undefined,
  pipeline_id:
    (!report.value.tasks && !report.value.noPipeline && pipelineId.value) ||
    undefined,
  assignee_id: (showAssignee.value && assigneeId.value) || undefined,
  product_id: (report.value.lists && productId.value) || undefined,
  lead_source_id: (report.value.lists && leadSourceId.value) || undefined,
  stage_id: (report.value.stage && stageId.value) || undefined,
  days: (report.value.days && days.value) || undefined,
  group_by: (report.value.groups && groupBy.value) || undefined,
}));

const applyPeriod = () => {
  if (period.value === 'custom' || !report.value.period) return;
  const range =
    report.value.period === 'forward'
      ? forwardRange(period.value)
      : periodRange(period.value);
  from.value = range.from;
  to.value = range.to;
};

// Only the latest request is shown: an answer to filters already changed again is dropped, even when it arrives last
let lastRequest = 0;
const load = async () => {
  if (report.value.period && (!from.value || !to.value)) return;
  lastRequest += 1;
  const request = lastRequest;
  isLoading.value = true;
  isUnavailable.value = false;
  try {
    const response = await crmReportsAPI.report(report.value.key, params.value);
    if (request !== lastRequest) return;
    data.value = response.data;
    updatedAt.value = new Intl.DateTimeFormat(locale.value, {
      hour: 'numeric',
      minute: '2-digit',
    }).format(new Date());
  } catch (error) {
    if (request !== lastRequest) return;
    isUnavailable.value = !error?.response || error.response.status >= 500;
  } finally {
    if (request === lastRequest) isLoading.value = false;
  }
};

// A report may start on its own period (the last 7 days, this year); otherwise the one chosen stays when it fits
const pickPeriod = () => {
  if (report.value.defaultPeriod) period.value = report.value.defaultPeriod;
  else if (!periodOptions.value.some(o => o.value === period.value))
    period.value = 'month';
};

// The filters as the address carries them (reportQuery.js)
const filterState = computed(() => ({
  period: report.value.period ? period.value : '',
  from: from.value,
  to: to.value,
  pipeline_id: pipelineId.value,
  assignee_id: assigneeId.value,
  stage_id: stageId.value,
  product_id: productId.value,
  lead_source_id: leadSourceId.value,
  days: days.value,
  group_by: groupBy.value,
}));

// The address's filters, when it has them, then the report's own period for what it leaves out
let restoring = false;
const restoreFilters = () => {
  const saved = fromQuery(route.query);
  const known = periodOptions.value.some(o => o.value === saved.period);
  if (known) period.value = saved.period;
  else pickPeriod();
  if (saved.period === 'custom') {
    from.value = saved.from || '';
    to.value = saved.to || '';
  }
  // An id no longer offered (a removed pipeline, employee or list item) falls back to «all»
  const offered = (options, id) =>
    options.some(o => o.value === id) ? id : '';
  pipelineId.value = offered(pipelineOptions.value, saved.pipeline_id);
  assigneeId.value = offered(
    (agents.value || []).map(a => ({ value: a.id })),
    saved.assignee_id
  );
  stageId.value = offered(stageOptions.value, saved.stage_id);
  productId.value = offered(productOptions.value, saved.product_id);
  leadSourceId.value = offered(sourceOptions.value, saved.lead_source_id);
  days.value = saved.days ?? '';
  groupBy.value = saved.group_by ?? '';
};

onMounted(async () => {
  // The address's filters are checked against what is offered, so the lists come first
  await Promise.all([
    pipelines.value.length
      ? null
      : store.dispatch('crm/pipelines/fetch').catch(() => {}),
    agents.value?.length ? null : store.dispatch('agents/get').catch(() => {}),
    lists.load(),
  ]);
  // The watchers below would each load on the restored values: one load follows instead
  restoring = true;
  restoreFilters();
  applyPeriod();
  await nextTick();
  restoring = false;
  load();
});

// Each report starts from its own default period (the month so far, or the whole month for what is still to close)
watch(
  () => report.value.key,
  () => {
    data.value = null;
    groupBy.value = '';
    pickPeriod();
    applyPeriod();
    load();
  }
);
watch(period, () => {
  applyPeriod();
  if (period.value !== 'custom' && !restoring) load();
});
watch(
  [pipelineId, assigneeId, productId, leadSourceId, stageId, groupBy],
  () => {
    if (!restoring) load();
  }
);
// A reload or a shared link opens the same view (replace: changing a filter adds no history step)
watch(
  () => [toQuery(filterState.value), report.value.key],
  ([query]) => {
    if (JSON.stringify(query) === JSON.stringify(route.query)) return;
    router.replace({ params: route.params, query });
  }
);

const periodNote = computed(() =>
  data.value?.period
    ? t('CRM.REPORTS.WAVE.PERIOD_NOTE', {
        from: date(data.value.period.from),
        to: date(data.value.period.to),
      })
    : ''
);

const openDrill = (cell, title) => drillPanel.value?.open(cell, title);
const currency = computed(() => data.value?.currency || 'SAR');
const body = computed(() => BODIES[report.value.key]);

// Printing (PDF): the whole report, every deal listed (`full`), under a header naming each filter that shaped it
const reportBody = ref(null);
const isPrinting = ref(false);
const P = key => t(`CRM.REPORTS.WAVE.PRINT.${key}`);
const optionLabel = (options, value) =>
  options.find(o => String(o.value) === String(value))?.label;

// What shaped the numbers: the period and each filter, named as the page shows them
const filterRows = () => {
  const p = params.value;
  const rows = [];
  if (data.value?.period && report.value.period)
    rows.push([t('CRM.REPORTS.PERIOD'), periodNote.value]);
  if (!report.value.tasks) {
    let who = t('CRM.REPORTS.WAVE.WHOLE_TEAM');
    if (!isAdmin.value) who = currentUser.value?.name;
    else if (p.assignee_id)
      who = agents.value?.find(a => a.id === Number(p.assignee_id))?.name;
    rows.push([t('CRM.DEALS.ASSIGNEE'), who]);
  }
  if (p.pipeline_id)
    rows.push([
      t('CRM.DEALS.PIPELINE'),
      optionLabel(pipelineOptions.value, p.pipeline_id),
    ]);
  if (p.stage_id)
    rows.push([
      t('CRM.REPORTS.WAVE.STAGE'),
      optionLabel(stageOptions.value, p.stage_id),
    ]);
  if (p.product_id)
    rows.push([
      t('CRM.LISTS.product'),
      optionLabel(productOptions.value, p.product_id),
    ]);
  if (p.lead_source_id)
    rows.push([
      t('CRM.LISTS.lead_source'),
      optionLabel(sourceOptions.value, p.lead_source_id),
    ]);
  if (report.value.days && data.value?.days)
    rows.push([t('CRM.REPORTS.WAVE.STALE_DAYS'), number(data.value.days)]);
  return rows;
};

const printFilters = () => [
  ...filterRows(),
  [P('PRINTED_AT'), dateTime(new Date().toISOString())],
  [P('PRINTED_BY'), currentUser.value?.name],
];

// Exporting (the manager): the report as Excel, or its deals as CSV, under the same heading as a printout
const X = (key, args) => t(`CRM.REPORTS.WAVE.EXPORT.${key}`, args);
const exporting = ref('');
const exportAs = async format => {
  exporting.value = format;
  try {
    const heading = [
      [X('REPORT'), R('NAME')],
      [X('QUESTION'), R('QUESTION')],
      ...filterRows(),
    ].map(([label, value]) => ({ label, value: value || '—' }));
    const { data: blob } = await crmReportsAPI.download(report.value.key, {
      ...params.value,
      file_format: format,
      heading: JSON.stringify(heading),
    });
    const span = data.value?.period
      ? `-${data.value.period.from}-${data.value.period.to}`
      : '';
    saveFile(blob, `${report.value.key}${span}.${format}`);
  } catch {
    useAlert(t('CRM.COMMON.ERROR'));
  } finally {
    exporting.value = '';
  }
};

// How many filters narrow the report beyond the period, on the phone's button
const FILTER_KEYS = [
  'pipeline_id',
  'assignee_id',
  'product_id',
  'lead_source_id',
  'stage_id',
  'days',
];
const filterToggleLabel = computed(() => {
  const count = FILTER_KEYS.filter(key => params.value[key]).length;
  return count ? X('FILTERS_ON', { count: number(count) }) : X('FILTERS');
});

const printHeader = () => {
  const meta = printFilters()
    .map(
      ([label, value]) =>
        `<div><dt>${escapeHtml(label)}</dt><dd>${escapeHtml(value || '—')}</dd></div>`
    )
    .join('');
  const scope = isAdmin.value
    ? ''
    : P(report.value.tasks ? 'OWN_TASKS' : 'OWN_DEALS');
  return `<header class="rp-head">
    <div class="rp-brand"><span class="rp-logo">MyDesk</span>
      <span>${escapeHtml(currentAccount.value?.name)}</span></div>
    <h1 class="rp-title">${escapeHtml(R('NAME'))}
      <span class="rp-number">${escapeHtml(t('CRM.REPORTS.WAVE.PRINT.REPORT_NUMBER', { n: number(report.value.number) }))}</span></h1>
    <p class="rp-question">${escapeHtml(R('QUESTION'))}</p>
    <dl class="rp-meta">${meta}</dl>
    ${scope ? `<p class="rp-note">${escapeHtml(scope)}</p>` : ''}
  </header>`;
};

const print = async () => {
  isPrinting.value = true;
  try {
    const key = report.value.key;
    const { data: full } = await crmReportsAPI.report(key, {
      ...params.value,
      full: true,
    });
    if (key !== report.value.key) return;
    data.value = full;
    await nextTick();
    const dir = getComputedStyle(reportBody.value).direction;
    await printReport({
      title: [R('NAME'), periodNote.value].filter(Boolean).join(' · '),
      dir,
      lang: locale.value,
      header: printHeader(),
      body: reportBody.value.innerHTML,
      footer: `MyDesk · ${currentAccount.value?.name || ''}`,
    });
  } catch {
    useAlert(t('CRM.COMMON.ERROR'));
  } finally {
    isPrinting.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-full min-w-0 lg:flex-row">
    <ReportNav :current="report.key" />
    <!-- below md the menu button floats over the bottom: the page scrolls clear of it -->
    <div class="flex flex-col flex-1 min-w-0 pb-20 overflow-y-auto md:pb-0">
      <CrmPageHeader :title="R('QUESTION')" :subtitle="R('DESCRIPTION')">
        <template #actions>
          <Button
            :label="P('BUTTON')"
            variant="faded"
            size="sm"
            icon="i-lucide-printer"
            :is-loading="isPrinting"
            :disabled="!data || isLoading"
            @click="print"
          />
          <!-- Exporting is for the manager (gap-analysis.md, question 5); the server refuses anyone else -->
          <template v-if="isAdmin">
            <Button
              :label="X('EXCEL')"
              variant="faded"
              size="sm"
              icon="i-lucide-sheet"
              :is-loading="exporting === 'xlsx'"
              :disabled="!data || isLoading"
              @click="exportAs('xlsx')"
            />
            <Button
              :label="X('CSV')"
              variant="faded"
              size="sm"
              icon="i-lucide-download"
              :is-loading="exporting === 'csv'"
              :disabled="!data || isLoading"
              @click="exportAs('csv')"
            />
          </template>
        </template>
      </CrmPageHeader>
      <p
        v-if="updatedAt"
        class="px-6 -mt-2 pb-3 text-label-small text-n-slate-11"
        aria-live="polite"
      >
        {{
          report.period && periodNote
            ? X('UPDATED_WITH_PERIOD', { period: periodNote, time: updatedAt })
            : X('UPDATED', { time: updatedAt })
        }}
      </p>

      <p
        v-if="!isAdmin"
        class="flex items-center gap-2 px-6 pb-4 text-body-main text-n-slate-11"
      >
        <span class="i-lucide-user-round size-4 shrink-0" aria-hidden="true" />
        {{
          report.tasks
            ? t('CRM.REPORTS.WAVE.OWN_TASKS')
            : t('CRM.REPORTS.OWN_ONLY')
        }}
      </p>

      <!-- On a phone the filters fold behind one button -->
      <div class="px-6 pb-3 lg:hidden">
        <Button
          :label="filterToggleLabel"
          variant="faded"
          size="sm"
          icon="i-lucide-sliders-horizontal"
          :aria-expanded="filtersOpen"
          @click="filtersOpen = !filtersOpen"
        />
      </div>
      <div
        class="flex-wrap items-end gap-3 px-6 pb-4"
        :class="filtersOpen ? 'flex' : 'hidden lg:flex'"
      >
        <template v-if="report.period">
          <div class="flex flex-col gap-1">
            <span class="text-label-small text-n-slate-11" aria-hidden="true">
              {{ t('CRM.REPORTS.PERIOD') }}
            </span>
            <Select
              v-model="period"
              :options="periodOptions"
              :aria-label="t('CRM.REPORTS.PERIOD')"
              class="w-40"
            />
          </div>
          <template v-if="period === 'custom'">
            <Input
              v-model="from"
              type="date"
              :label="t('CRM.REPORTS.FROM')"
              size="sm"
              @change="load"
            />
            <Input
              v-model="to"
              type="date"
              :label="t('CRM.REPORTS.TO')"
              size="sm"
              @change="load"
            />
          </template>
        </template>
        <div
          v-if="
            !report.tasks && !report.noPipeline && pipelineOptions.length > 2
          "
          class="flex flex-col gap-1"
        >
          <span class="text-label-small text-n-slate-11" aria-hidden="true">
            {{ t('CRM.DEALS.PIPELINE') }}
          </span>
          <Select
            v-model="pipelineId"
            :options="pipelineOptions"
            :aria-label="t('CRM.DEALS.PIPELINE')"
            class="w-44"
          />
        </div>
        <div v-if="showAssignee" class="flex flex-col gap-1 w-44">
          <span class="text-label-small text-n-slate-11" aria-hidden="true">
            {{ t('CRM.DEALS.ASSIGNEE') }}
          </span>
          <AgentPicker
            v-model="assigneeId"
            :none-label="t('CRM.REPORTS.WAVE.WHOLE_TEAM')"
            :aria-label="t('CRM.DEALS.ASSIGNEE')"
          />
        </div>
        <div v-if="report.stage" class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11" aria-hidden="true">
            {{ t('CRM.REPORTS.WAVE.STAGE') }}
          </span>
          <Select
            v-model="stageId"
            :options="stageOptions"
            :aria-label="t('CRM.REPORTS.WAVE.STAGE')"
            class="w-44"
          />
        </div>
        <template v-if="report.lists">
          <div v-if="productOptions.length > 1" class="flex flex-col gap-1">
            <span class="text-label-small text-n-slate-11" aria-hidden="true">
              {{ t('CRM.LISTS.product') }}
            </span>
            <Select
              v-model="productId"
              :options="productOptions"
              :aria-label="t('CRM.LISTS.product')"
              class="w-40"
            />
          </div>
          <div v-if="sourceOptions.length > 1" class="flex flex-col gap-1">
            <span class="text-label-small text-n-slate-11" aria-hidden="true">
              {{ t('CRM.LISTS.lead_source') }}
            </span>
            <Select
              v-model="leadSourceId"
              :options="sourceOptions"
              :aria-label="t('CRM.LISTS.lead_source')"
              class="w-40"
            />
          </div>
        </template>
        <Input
          v-if="report.days"
          v-model="days"
          type="number"
          min="1"
          max="365"
          :label="t('CRM.REPORTS.WAVE.STALE_DAYS')"
          :placeholder="data?.days ? String(data.days) : ''"
          size="sm"
          class="w-32"
          @change="load"
        />
        <span
          v-if="isLoading && data"
          class="flex items-center gap-2 pb-2 text-label-small text-n-slate-11"
          role="status"
        >
          <Spinner class="!size-4" />
          {{ t('CRM.REPORTS.UPDATING') }}
        </span>
      </div>

      <CrmUnavailable
        v-if="isUnavailable"
        :is-loading="isLoading"
        @retry="load"
      />
      <div
        v-else-if="!data"
        class="flex items-center justify-center flex-1 py-16"
      >
        <Spinner />
      </div>
      <!-- reportBody: what a printout copies -->
      <div v-else ref="reportBody">
        <div
          v-if="data.empty"
          class="flex flex-col items-center gap-2 px-6 py-16 mx-6 mb-8 text-center rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
        >
          <span
            :class="report.icon"
            class="size-8 text-n-slate-9"
            aria-hidden="true"
          />
          <p class="text-heading-3 text-n-slate-12">{{ R('EMPTY') }}</p>
          <p class="max-w-md text-body-main text-n-slate-11">
            {{ R('EMPTY_HINT') }}
          </p>
        </div>
        <div
          v-else
          class="px-6 pb-8 transition-opacity"
          :class="{ 'opacity-60': isLoading }"
          :aria-busy="isLoading"
        >
          <component
            :is="body"
            :data="data"
            :currency="currency"
            @drill="openDrill"
            @group="value => (groupBy = value)"
          />
        </div>
      </div>
    </div>

    <DrillPanel
      ref="drillPanel"
      :report-key="report.key"
      :params="params"
      :currency="currency"
      :columns="report.columns"
      :show-assignee="Boolean(data?.team)"
    />
  </div>
</template>
