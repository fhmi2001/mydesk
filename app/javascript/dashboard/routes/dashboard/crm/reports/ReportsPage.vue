<script setup>
// Custom (MyDesk): Sales > Reports: summary, funnel, agents, lost reasons, sales over time, CSV export
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import BarChart from 'shared/components/charts/BarChart.vue';
import { useAlert } from 'dashboard/composables';
import { crmReportsAPI } from 'dashboard/api/crm';
import { downloadCsvFile } from 'dashboard/helper/downloadHelper';
import CrmPageHeader from '../shared/CrmPageHeader.vue';
import CrmUnavailable from '../shared/CrmUnavailable.vue';
import AgentPicker from '../shared/AgentPicker.vue';
import { useCrmFormat } from '../shared/useCrmFormat';
import SummaryCards from './SummaryCards.vue';
import { periodRange } from './periods';

const { t, locale } = useI18n();
const store = useStore();
const { money, number } = useCrmFormat();

const pipelines = useMapGetter('crm/pipelines/all');
const isAdmin = useMapGetter('crm/status/isAdmin');

const period = ref('month');
const from = ref('');
const to = ref('');
const pipelineId = ref('');
const assigneeId = ref('');
const interval = ref('day');

const summary = ref(null);
const funnel = ref([]);
const agents = ref([]);
const lostReasons = ref([]);
const timeline = ref([]);
const isLoading = ref(true);
const isUnavailable = ref(false);

const periodOptions = computed(() =>
  ['today', 'week', 'month', 'quarter', 'custom'].map(p => ({
    value: p,
    label: t(`CRM.REPORTS.PERIODS.${p}`),
  }))
);
const intervalOptions = computed(() =>
  ['day', 'week', 'month'].map(i => ({
    value: i,
    label: t(`CRM.REPORTS.INTERVALS.${i}`),
  }))
);
const pipelineOptions = computed(() => [
  { value: '', label: t('CRM.COMMON.ALL') },
  ...pipelines.value.map(p => ({ value: p.id, label: p.name })),
]);
const currency = computed(
  () =>
    summary.value?.currency ||
    pipelines.value.find(p => p.id === Number(pipelineId.value))?.currency ||
    pipelines.value[0]?.currency ||
    'SAR'
);

const params = computed(() => ({
  from: from.value,
  to: to.value,
  pipeline_id: pipelineId.value || undefined,
  assignee_id: assigneeId.value || undefined,
}));

const applyPeriod = () => {
  if (period.value === 'custom') return;
  const range = periodRange(period.value);
  from.value = range.from;
  to.value = range.to;
};

const load = async () => {
  if (!from.value || !to.value) return;
  isLoading.value = true;
  isUnavailable.value = false;
  try {
    const [s, f, a, l, tl] = await Promise.all([
      crmReportsAPI.summary(params.value),
      crmReportsAPI.funnel(params.value),
      crmReportsAPI.agents(params.value),
      crmReportsAPI.lostReasons(params.value),
      crmReportsAPI.timeline({ ...params.value, interval: interval.value }),
    ]);
    summary.value = s.data;
    funnel.value = f.data;
    agents.value = a.data;
    lostReasons.value = l.data;
    timeline.value = tl.data;
  } catch (error) {
    isUnavailable.value = !error?.response || error.response.status >= 500;
  } finally {
    isLoading.value = false;
  }
};

onMounted(async () => {
  if (!pipelines.value.length)
    await store.dispatch('crm/pipelines/fetch').catch(() => {});
  applyPeriod();
  load();
});

watch(period, () => {
  applyPeriod();
  if (period.value !== 'custom') load();
});
watch([pipelineId, assigneeId, interval], load);

// Lost is where deals leave the pipeline, not a step forward, so the funnel stops at won
const funnelRows = computed(() =>
  funnel.value.filter(row => row.kind !== 'lost')
);

const funnelChart = computed(() => ({
  categories: funnelRows.value.map(row => row.name),
  series: [
    {
      id: 'reached',
      label: t('CRM.REPORTS.FUNNEL.REACHED'),
      color: 'rgb(var(--iris-9))',
      valueColor: 'rgb(var(--iris-11))',
      data: funnelRows.value.map(row => ({ value: row.reached_count })),
    },
  ],
}));

// Deal counts are whole numbers: about four steps, never a fraction
const countStep = values => Math.max(1, Math.ceil(Math.max(0, ...values) / 4));
const funnelStep = computed(() =>
  countStep(funnelRows.value.map(row => row.reached_count))
);
const timelineStep = computed(() =>
  countStep(timeline.value.flatMap(b => [b.created, b.won, b.lost]))
);

// Short axis labels ("1 نوفمبر", or "نوفمبر 2026" per month); buckets are plain dates, read as UTC
const shortDate = value =>
  new Intl.DateTimeFormat(locale.value, {
    timeZone: 'UTC',
    ...(interval.value === 'month'
      ? { month: 'short', year: 'numeric' }
      : { day: 'numeric', month: 'short' }),
  }).format(new Date(value));

const timelineChart = computed(() => ({
  categories: timeline.value.map(b => shortDate(b.bucket)),
  series: [
    {
      id: 'created',
      label: t('CRM.REPORTS.TIMELINE.CREATED'),
      color: 'rgb(var(--slate-7))',
      valueColor: 'rgb(var(--slate-11))',
      data: timeline.value.map(b => ({ value: b.created })),
    },
    {
      id: 'won',
      label: t('CRM.REPORTS.TIMELINE.WON'),
      color: 'rgb(var(--teal-9))',
      valueColor: 'rgb(var(--teal-11))',
      data: timeline.value.map(b => ({ value: b.won })),
    },
    {
      id: 'lost',
      label: t('CRM.REPORTS.TIMELINE.LOST'),
      color: 'rgb(var(--ruby-9))',
      valueColor: 'rgb(var(--ruby-11))',
      data: timeline.value.map(b => ({ value: b.lost })),
    },
  ],
}));

const lostMax = computed(() =>
  Math.max(1, ...lostReasons.value.map(r => r.count))
);
const hasFunnel = computed(() =>
  funnelRows.value.some(r => r.reached_count > 0)
);
const timelineLegend = computed(() => timelineChart.value.series);
// A rate or an average of no closed deals is not zero
const closedCount = row => (row.won_count || 0) + (row.lost_count || 0);
const hasTimeline = computed(() =>
  timeline.value.some(b => b.created || b.won || b.lost)
);

const conversionLabel = row => `(${row.conversion_from_previous}%)`;
const lostLabel = row =>
  `${number(row.count)} · ${money(row.total_cents, currency.value)}`;

const exportCsv = async () => {
  try {
    const { data } = await crmReportsAPI.export(params.value);
    downloadCsvFile(`deals-${from.value}-${to.value}.csv`, data);
  } catch (error) {
    useAlert(t('CRM.COMMON.ERROR'));
  }
};
</script>

<template>
  <div class="flex flex-col h-full min-w-0 overflow-y-auto">
    <CrmPageHeader
      :title="t('CRM.REPORTS.TITLE')"
      :subtitle="t('CRM.REPORTS.SUBTITLE')"
    >
      <template #actions>
        <!-- Exporting is for the manager (gap-analysis.md, question 5); the server refuses anyone else -->
        <Button
          v-if="isAdmin"
          :label="t('CRM.REPORTS.EXPORT')"
          variant="faded"
          size="sm"
          icon="i-lucide-download"
          @click="exportCsv"
        />
      </template>
    </CrmPageHeader>

    <!-- Employees only ever get their own numbers (the server scopes them, see Reports::Base); say so, so a
         single row is not read as the whole company's -->
    <p
      v-if="!isAdmin"
      class="flex items-center gap-2 px-6 pb-4 text-body-main text-n-slate-11"
    >
      <span class="i-lucide-user-round size-4 shrink-0" aria-hidden="true" />
      {{ t('CRM.REPORTS.OWN_ONLY') }}
    </p>

    <!-- Each select carries its caption as aria-label: the captions are not <label for> targets -->
    <div class="flex flex-wrap items-end gap-3 px-6 pb-4">
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
      <div v-if="pipelineOptions.length > 2" class="flex flex-col gap-1">
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
      <div v-if="isAdmin" class="flex flex-col gap-1 w-44">
        <span class="text-label-small text-n-slate-11" aria-hidden="true">
          {{ t('CRM.DEALS.ASSIGNEE') }}
        </span>
        <AgentPicker
          v-model="assigneeId"
          :none-label="t('CRM.COMMON.ANY_ASSIGNEE')"
          :aria-label="t('CRM.DEALS.ASSIGNEE')"
        />
      </div>
      <div class="flex flex-col gap-1">
        <span class="text-label-small text-n-slate-11" aria-hidden="true">
          {{ t('CRM.REPORTS.INTERVAL') }}
        </span>
        <Select
          v-model="interval"
          :options="intervalOptions"
          :aria-label="t('CRM.REPORTS.INTERVAL')"
          class="w-32"
        />
      </div>
      <span
        v-if="isLoading && summary"
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
      v-else-if="isLoading && !summary"
      class="flex items-center justify-center flex-1"
    >
      <Spinner />
    </div>

    <div
      v-else
      class="flex flex-col gap-6 px-6 pb-8 transition-opacity"
      :class="{ 'opacity-60': isLoading }"
      :aria-busy="isLoading"
    >
      <SummaryCards v-if="summary" :summary="summary" :currency="currency" />

      <div class="grid grid-cols-1 gap-6 xl:grid-cols-2">
        <section
          class="p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
        >
          <h2 class="mb-4 text-heading-3 text-n-slate-12">
            {{ t('CRM.REPORTS.FUNNEL.TITLE') }}
          </h2>
          <BarChart
            v-if="hasFunnel"
            :data="funnelChart"
            :aria-label="t('CRM.REPORTS.FUNNEL.TITLE')"
            :height="240"
            :bar-radius="4"
            :max-bar-width="40"
            :y-step-size="funnelStep"
          />
          <p v-else class="text-body-main text-n-slate-11">
            {{ t('CRM.REPORTS.FUNNEL.EMPTY') }}
          </p>
          <ol
            v-if="hasFunnel"
            class="grid grid-cols-2 gap-2 mt-4 text-label-small sm:grid-cols-3"
          >
            <li
              v-for="row in funnelRows"
              :key="row.stage_id"
              class="flex items-center gap-2 text-n-slate-11"
            >
              <span
                class="rounded-full size-2 shrink-0"
                :style="{ backgroundColor: row.color }"
                aria-hidden="true"
              />
              <span class="truncate">{{ row.name }}</span>
              <span class="ms-auto tabular-nums text-n-slate-12">{{
                number(row.reached_count)
              }}</span>
              <span
                v-if="row.conversion_from_previous !== null"
                class="tabular-nums"
                :title="t('CRM.REPORTS.FUNNEL.CONVERSION')"
              >
                {{ conversionLabel(row) }}
                <span class="sr-only">{{
                  t('CRM.REPORTS.FUNNEL.CONVERSION')
                }}</span>
              </span>
            </li>
          </ol>
        </section>

        <section
          class="p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
        >
          <h2 class="mb-4 text-heading-3 text-n-slate-12">
            {{ t('CRM.REPORTS.LOST_REASONS.TITLE') }}
          </h2>
          <ul v-if="lostReasons.length" class="flex flex-col gap-3">
            <li
              v-for="row in lostReasons"
              :key="row.reason"
              class="text-body-main"
            >
              <div class="flex items-center justify-between gap-3">
                <span class="truncate text-n-slate-12">{{ row.reason }}</span>
                <span class="tabular-nums text-n-slate-11 shrink-0">
                  {{ lostLabel(row) }}
                </span>
              </div>
              <div
                class="h-1.5 mt-1 rounded-full bg-n-slate-3"
                aria-hidden="true"
              >
                <div
                  class="h-full rounded-full bg-n-ruby-9"
                  :style="{ width: `${(row.count / lostMax) * 100}%` }"
                />
              </div>
            </li>
          </ul>
          <p v-else class="text-body-main text-n-slate-11">
            {{ t('CRM.REPORTS.LOST_REASONS.EMPTY') }}
          </p>
        </section>
      </div>

      <section
        class="p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
      >
        <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
          <h2 class="text-heading-3 text-n-slate-12">
            {{ t('CRM.REPORTS.TIMELINE.TITLE') }}
          </h2>
          <ul
            v-if="hasTimeline"
            class="flex flex-wrap items-center gap-x-4 gap-y-1 text-label-small text-n-slate-11"
            :aria-label="t('CRM.REPORTS.TIMELINE.LEGEND')"
          >
            <li
              v-for="series in timelineLegend"
              :key="series.id"
              class="inline-flex items-center gap-1.5"
            >
              <span
                class="size-2.5 rounded-sm shrink-0"
                :style="{ backgroundColor: series.color }"
                aria-hidden="true"
              />
              {{ series.label }}
            </li>
          </ul>
        </div>
        <BarChart
          v-if="hasTimeline"
          :data="timelineChart"
          :aria-label="t('CRM.REPORTS.TIMELINE.TITLE')"
          :height="260"
          :bar-radius="3"
          :bar-gap="2"
          :max-bar-width="24"
          :y-step-size="timelineStep"
          timeseries
        />
        <p v-else class="text-body-main text-n-slate-11">
          {{ t('CRM.REPORTS.FUNNEL.EMPTY') }}
        </p>
      </section>

      <section
        class="p-5 overflow-x-auto rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
      >
        <h2 class="mb-4 text-heading-3 text-n-slate-12">
          {{
            isAdmin
              ? t('CRM.REPORTS.AGENTS.TITLE')
              : t('CRM.REPORTS.AGENTS.MINE')
          }}
        </h2>
        <table v-if="agents.length" class="w-full text-body-main">
          <thead>
            <tr class="text-label-small text-n-slate-11">
              <th scope="col" class="py-2 font-medium text-start">
                {{ t('CRM.REPORTS.AGENTS.AGENT') }}
              </th>
              <th scope="col" class="py-2 font-medium text-end">
                {{ t('CRM.REPORTS.AGENTS.OPEN') }}
              </th>
              <th scope="col" class="py-2 font-medium text-end">
                {{ t('CRM.REPORTS.AGENTS.WON') }}
              </th>
              <th scope="col" class="py-2 font-medium text-end">
                {{ t('CRM.REPORTS.AGENTS.LOST') }}
              </th>
              <th scope="col" class="py-2 font-medium text-end">
                {{ t('CRM.REPORTS.AGENTS.WIN_RATE') }}
              </th>
              <th scope="col" class="py-2 font-medium text-end">
                {{ t('CRM.REPORTS.AGENTS.WON_TOTAL') }}
              </th>
              <th scope="col" class="py-2 font-medium text-end">
                {{ t('CRM.REPORTS.AGENTS.AVG_DAYS') }}
              </th>
              <th scope="col" class="py-2 font-medium text-end">
                {{ t('CRM.REPORTS.AGENTS.OVERDUE_TASKS') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak">
            <tr v-for="row in agents" :key="row.user_id">
              <th
                scope="row"
                class="py-2.5 font-normal text-start text-n-slate-12"
              >
                {{ row.name }}
              </th>
              <td class="py-2.5 text-end tabular-nums">
                {{ number(row.open_count) }}
              </td>
              <td
                class="py-2.5 text-end tabular-nums"
                :class="{ 'text-n-teal-11': row.won_count }"
              >
                {{ number(row.won_count) }}
              </td>
              <td
                class="py-2.5 text-end tabular-nums"
                :class="{ 'text-n-ruby-11': row.lost_count }"
              >
                {{ number(row.lost_count) }}
              </td>
              <td class="py-2.5 text-end tabular-nums">
                {{ closedCount(row) ? `${row.win_rate}%` : '—' }}
              </td>
              <td class="py-2.5 text-end tabular-nums" dir="auto">
                {{ money(row.won_total_cents, currency) }}
              </td>
              <td class="py-2.5 text-end tabular-nums">
                {{ closedCount(row) ? number(row.avg_days_to_close) : '—' }}
              </td>
              <td
                class="py-2.5 text-end tabular-nums"
                :class="{ 'text-n-ruby-11 font-medium': row.overdue_tasks }"
              >
                {{ number(row.overdue_tasks) }}
              </td>
            </tr>
          </tbody>
        </table>
        <p v-else class="text-body-main text-n-slate-11">
          {{ t('CRM.REPORTS.FUNNEL.EMPTY') }}
        </p>
      </section>
    </div>
  </div>
</template>
