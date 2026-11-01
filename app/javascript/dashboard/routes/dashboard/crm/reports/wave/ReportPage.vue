<script setup>
// Custom (MyDesk): Sales > Reports > one report of phase 4 (docs/reports/CRM_REPORTS_PLAN.md). One page for the seven
// reports of wave أ: its title is the question it answers, the filters are the ones it takes (reportCatalog.js), every
// number opens the deals behind it (DrillPanel), and an employee sees only their own (the server scopes it).
import { ref, computed, watch, onMounted, nextTick } from 'vue';
import { useRoute } from 'vue-router';
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
  reportsFor,
  reportFor,
  forwardRange,
  PAST_PERIODS,
  FORWARD_PERIODS,
} from './reportCatalog';
import DrillPanel from './DrillPanel.vue';
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
};

const route = useRoute();
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
const isLoading = ref(true);
const isUnavailable = ref(false);
const drillPanel = ref(null);

const periodOptions = computed(() =>
  (report.value.period === 'forward' ? FORWARD_PERIODS : PAST_PERIODS).map(
    p => ({ value: p, label: t(`CRM.REPORTS.WAVE.PERIODS.${p}`) })
  )
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

const load = async () => {
  if (report.value.period && (!from.value || !to.value)) return;
  isLoading.value = true;
  isUnavailable.value = false;
  try {
    const key = report.value.key;
    const response = await crmReportsAPI.report(key, params.value);
    if (key === report.value.key) data.value = response.data;
  } catch (error) {
    isUnavailable.value = !error?.response || error.response.status >= 500;
  } finally {
    isLoading.value = false;
  }
};

onMounted(async () => {
  if (!pipelines.value.length)
    await store.dispatch('crm/pipelines/fetch').catch(() => {});
  lists.load();
  applyPeriod();
  load();
});

// Each report starts from its own default period (the month so far, or the whole month for what is still to close)
watch(
  () => report.value.key,
  () => {
    data.value = null;
    groupBy.value = '';
    if (!periodOptions.value.some(o => o.value === period.value))
      period.value = 'month';
    applyPeriod();
    load();
  }
);
watch(period, () => {
  applyPeriod();
  if (period.value !== 'custom') load();
});
watch(
  [pipelineId, assigneeId, productId, leadSourceId, stageId, groupBy],
  load
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

const printFilters = () => {
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
  rows.push([P('PRINTED_AT'), dateTime(new Date().toISOString())]);
  rows.push([P('PRINTED_BY'), currentUser.value?.name]);
  return rows;
};

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
  <div class="flex flex-col h-full min-w-0 overflow-y-auto">
    <nav
      class="flex gap-1 px-6 pt-5 overflow-x-auto shrink-0"
      :aria-label="t('CRM.REPORTS.WAVE.NAV')"
    >
      <router-link
        :to="{ name: 'crm_reports' }"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-label-small text-n-slate-11 hover:bg-n-alpha-2 whitespace-nowrap"
      >
        <span class="i-lucide-layout-dashboard size-4" aria-hidden="true" />
        {{ t('CRM.REPORTS.WAVE.OVERVIEW') }}
      </router-link>
      <router-link
        v-for="item in reportsFor(isAdmin)"
        :key="item.key"
        :to="{ name: 'crm_report', params: { reportKey: item.key } }"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-label-small whitespace-nowrap"
        :class="
          item.key === report.key
            ? 'bg-n-alpha-2 text-n-slate-12 font-medium'
            : 'text-n-slate-11 hover:bg-n-alpha-2'
        "
        :aria-current="item.key === report.key ? 'page' : undefined"
      >
        <span :class="item.icon" class="size-4" aria-hidden="true" />
        {{ t(`CRM.REPORTS.WAVE.REPORTS.${item.key}.NAME`) }}
      </router-link>
    </nav>

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
      </template>
    </CrmPageHeader>

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

    <div class="flex flex-wrap items-end gap-3 px-6 pb-4">
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
        v-if="!report.tasks && !report.noPipeline && pipelineOptions.length > 2"
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
      <span
        v-else-if="report.period && periodNote"
        class="pb-2 text-label-small text-n-slate-10"
      >
        {{ periodNote }}
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
