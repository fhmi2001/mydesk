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

const { t } = useI18n();
const store = useStore();
const { money, number, date } = useCrmFormat();

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

const funnelChart = computed(() => ({
  categories: funnel.value.map(row => row.name),
  series: [
    {
      id: 'reached',
      label: t('CRM.REPORTS.FUNNEL.REACHED'),
      color: 'rgb(var(--iris-9))',
      valueColor: 'rgb(var(--iris-11))',
      data: funnel.value.map(row => ({ value: row.reached_count })),
    },
  ],
}));

const timelineChart = computed(() => ({
  categories: timeline.value.map(b => date(b.bucket)),
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
const hasFunnel = computed(() => funnel.value.some(r => r.reached_count > 0));
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
        <Button
          :label="t('CRM.REPORTS.EXPORT')"
          variant="faded"
          size="sm"
          icon="i-lucide-download"
          @click="exportCsv"
        />
      </template>
    </CrmPageHeader>

    <div class="flex flex-wrap items-end gap-3 px-6 pb-4">
      <div class="flex flex-col gap-1">
        <label class="text-xs text-n-slate-11">{{
          t('CRM.REPORTS.PERIOD')
        }}</label>
        <Select v-model="period" :options="periodOptions" class="w-40" />
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
        <label class="text-xs text-n-slate-11">{{
          t('CRM.DEALS.PIPELINE')
        }}</label>
        <Select v-model="pipelineId" :options="pipelineOptions" class="w-44" />
      </div>
      <div v-if="isAdmin" class="flex flex-col gap-1 w-44">
        <label class="text-xs text-n-slate-11">{{
          t('CRM.DEALS.ASSIGNEE')
        }}</label>
        <AgentPicker
          v-model="assigneeId"
          :none-label="t('CRM.COMMON.ANY_ASSIGNEE')"
        />
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-xs text-n-slate-11">{{
          t('CRM.REPORTS.INTERVAL')
        }}</label>
        <Select v-model="interval" :options="intervalOptions" class="w-32" />
      </div>
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

    <div v-else class="flex flex-col gap-6 px-6 pb-8">
      <SummaryCards v-if="summary" :summary="summary" :currency="currency" />

      <div class="grid grid-cols-1 gap-6 xl:grid-cols-2">
        <section class="p-5 rounded-2xl border border-n-weak bg-n-solid-1">
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
          />
          <p v-else class="text-sm text-n-slate-11">
            {{ t('CRM.REPORTS.FUNNEL.EMPTY') }}
          </p>
          <ol
            v-if="hasFunnel"
            class="grid grid-cols-2 gap-2 mt-4 text-xs sm:grid-cols-3"
          >
            <li
              v-for="row in funnel"
              :key="row.stage_id"
              class="flex items-center gap-2 text-n-slate-11"
            >
              <span
                class="size-2 rounded-full shrink-0"
                :style="{ backgroundColor: row.color }"
              />
              <span class="truncate">{{ row.name }}</span>
              <span class="ms-auto tabular-nums text-n-slate-12">{{
                number(row.reached_count)
              }}</span>
              <span
                v-if="row.conversion_from_previous !== null"
                class="tabular-nums"
              >
                {{ conversionLabel(row) }}
              </span>
            </li>
          </ol>
        </section>

        <section class="p-5 rounded-2xl border border-n-weak bg-n-solid-1">
          <h2 class="mb-4 text-heading-3 text-n-slate-12">
            {{ t('CRM.REPORTS.LOST_REASONS.TITLE') }}
          </h2>
          <ul v-if="lostReasons.length" class="flex flex-col gap-3">
            <li v-for="row in lostReasons" :key="row.reason" class="text-sm">
              <div class="flex items-center justify-between gap-3">
                <span class="truncate text-n-slate-12">{{ row.reason }}</span>
                <span class="tabular-nums text-n-slate-11 shrink-0">
                  {{ lostLabel(row) }}
                </span>
              </div>
              <div class="h-1.5 mt-1 rounded-full bg-n-slate-3">
                <div
                  class="h-full rounded-full bg-n-ruby-9"
                  :style="{ width: `${(row.count / lostMax) * 100}%` }"
                />
              </div>
            </li>
          </ul>
          <p v-else class="text-sm text-n-slate-11">
            {{ t('CRM.REPORTS.LOST_REASONS.EMPTY') }}
          </p>
        </section>
      </div>

      <section class="p-5 rounded-2xl border border-n-weak bg-n-solid-1">
        <h2 class="mb-4 text-heading-3 text-n-slate-12">
          {{ t('CRM.REPORTS.TIMELINE.TITLE') }}
        </h2>
        <BarChart
          v-if="hasTimeline"
          :data="timelineChart"
          :aria-label="t('CRM.REPORTS.TIMELINE.TITLE')"
          :height="260"
          :bar-radius="3"
          :bar-gap="2"
          :max-bar-width="24"
        />
        <p v-else class="text-sm text-n-slate-11">
          {{ t('CRM.REPORTS.FUNNEL.EMPTY') }}
        </p>
      </section>

      <section
        class="p-5 overflow-x-auto rounded-2xl border border-n-weak bg-n-solid-1"
      >
        <h2 class="mb-4 text-heading-3 text-n-slate-12">
          {{ t('CRM.REPORTS.AGENTS.TITLE') }}
        </h2>
        <table class="w-full text-sm">
          <thead>
            <tr class="text-xs text-n-slate-11">
              <th class="py-2 font-medium text-start">
                {{ t('CRM.REPORTS.AGENTS.AGENT') }}
              </th>
              <th class="py-2 font-medium text-end">
                {{ t('CRM.REPORTS.AGENTS.OPEN') }}
              </th>
              <th class="py-2 font-medium text-end">
                {{ t('CRM.REPORTS.AGENTS.WON') }}
              </th>
              <th class="py-2 font-medium text-end">
                {{ t('CRM.REPORTS.AGENTS.LOST') }}
              </th>
              <th class="py-2 font-medium text-end">
                {{ t('CRM.REPORTS.AGENTS.WIN_RATE') }}
              </th>
              <th class="py-2 font-medium text-end">
                {{ t('CRM.REPORTS.AGENTS.WON_TOTAL') }}
              </th>
              <th class="py-2 font-medium text-end">
                {{ t('CRM.REPORTS.AGENTS.AVG_DAYS') }}
              </th>
              <th class="py-2 font-medium text-end">
                {{ t('CRM.REPORTS.AGENTS.OVERDUE_TASKS') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak">
            <tr v-for="row in agents" :key="row.user_id">
              <td class="py-2.5 text-n-slate-12">{{ row.name }}</td>
              <td class="py-2.5 text-end tabular-nums">
                {{ number(row.open_count) }}
              </td>
              <td class="py-2.5 text-end tabular-nums text-n-teal-11">
                {{ number(row.won_count) }}
              </td>
              <td class="py-2.5 text-end tabular-nums text-n-ruby-11">
                {{ number(row.lost_count) }}
              </td>
              <td class="py-2.5 text-end tabular-nums">{{ row.win_rate }}%</td>
              <td class="py-2.5 text-end tabular-nums" dir="auto">
                {{ money(row.won_total_cents, currency) }}
              </td>
              <td class="py-2.5 text-end tabular-nums">
                {{ row.avg_days_to_close }}
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
      </section>
    </div>
  </div>
</template>
