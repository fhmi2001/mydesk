<script setup>
// Custom (MyDesk): the home screen's charts. The manager sees the support charts (the last 7 days, the channels, each
// agent's load) and the sales ones; an employee only the sales ones, for their own deals (the support reports are
// the manager's only). Each card reads one source and says so when it failed.
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import BarChart from 'shared/components/charts/BarChart.vue';
import { COLORS } from '../crm/reports/wave/reportColors';
import { useCrmFormat } from '../crm/shared/useCrmFormat';
import ChartCard from './ChartCard.vue';
import BarRows from './BarRows.vue';
import TrendLine from './TrendLine.vue';
import {
  dailySeries,
  cumulativeSeries,
  channelRows,
  loadRows,
  stageRows,
  gapsWhereNone,
} from './charts';

const props = defineProps({
  data: { type: Object, required: true },
  isAdmin: { type: Boolean, default: false },
  crmEnabled: { type: Boolean, default: false },
  currency: { type: String, default: 'SAR' },
});

const { t } = useI18n();
const store = useStore();
const { accountScopedRoute } = useAccount();
const { number, compactMoney, date, lang } = useCrmFormat();
const inboxes = useMapGetter('inboxes/getInboxes');
const agents = useMapGetter('agents/getAgents');

// The agents' names for the load chart
onMounted(() => {
  if (props.isAdmin && !agents.value?.length)
    store.dispatch('agents/get').catch(() => {});
});

const d = key => props.data?.[key];
const report = (reportKey, query) =>
  accountScopedRoute('crm_report', { reportKey }, query);
const weekday = at =>
  new Intl.DateTimeFormat(lang.value, { weekday: 'short' }).format(at);

// 2. New conversations a day
const traffic = computed(() => dailySeries(d('traffic')));
const trafficChart = computed(() => ({
  categories: traffic.value.map(day => weekday(day.at)),
  series: [
    {
      id: 'conversations',
      label: t('HOME.CHARTS.TRAFFIC'),
      color: COLORS.neutral.rgb,
      valueColor: COLORS.neutral.rgbText,
      data: traffic.value.map(day => ({ value: day.value })),
    },
  ],
}));
const trafficStep = computed(() =>
  Math.max(
    1,
    Math.ceil(Math.max(0, ...traffic.value.map(day => day.value)) / 4)
  )
);

// 3. Average first response a day, in minutes; a day with no conversations has no average (a gap, not zero)
const response = computed(() => {
  const days = dailySeries(d('responseTrend'));
  // An average's point carries how many first responses it averages (Reports::RawDataSource#average_timeseries)
  const minutes = gapsWhereNone(
    days.map(day => Math.round(day.value / 60)),
    (d('responseTrend') || []).map(point => Number(point.count) || 0)
  );
  return days.map((day, i) => ({ at: day.at, value: minutes[i] }));
});
const responseLines = computed(() => [
  {
    id: 'response',
    label: t('HOME.CHARTS.RESPONSE_LEGEND'),
    values: response.value.map(day => day.value),
    color: COLORS.neutral.rgbText,
  },
]);
const responseMax = computed(() =>
  Math.max(1, ...response.value.map(day => day.value ?? 0))
);
const responseTable = computed(() => ({
  headers: [t('HOME.CHARTS.DAY'), t('HOME.CHARTS.RESPONSE_LEGEND')],
  rows: response.value.map(day => [
    weekday(day.at),
    day.value === null ? '—' : number(day.value),
  ]),
}));

// 4. Won so far against the target
const cumulative = computed(() => cumulativeSeries(d('quota')?.cumulative));
const wonLines = computed(() => [
  {
    id: 'target',
    label: t('HOME.CHARTS.TARGET_LEGEND'),
    values: cumulative.value.target,
    color: COLORS.neutral.rgb,
    dashed: true,
  },
  {
    id: 'won',
    label: t('HOME.CHARTS.WON_LEGEND'),
    values: cumulative.value.won,
    color: COLORS.won.rgb,
  },
]);
const wonTable = computed(() => ({
  headers: [
    t('HOME.CHARTS.DAY'),
    t('HOME.CHARTS.WON_LEGEND'),
    t('HOME.CHARTS.TARGET_LEGEND'),
  ],
  rows: (d('quota')?.cumulative || [])
    .filter(day => day.won_cents !== null)
    .map(day => [
      date(day.date),
      compactMoney(day.won_cents, props.currency),
      compactMoney(day.target_cents, props.currency),
    ]),
}));
const monthStart = computed(() => d('quota')?.cumulative?.[0]?.date);
const monthEnd = computed(() => d('quota')?.cumulative?.at(-1)?.date);

// 5, 6, 7. Ranked bars
const stages = computed(() => stageRows(d('pipeline')));
const channels = computed(() => channelRows(d('channels'), inboxes.value));
const load = computed(() => loadRows(d('load'), agents.value));

const failed = key => !d(key);
</script>

<template>
  <div class="grid gap-4 lg:grid-cols-2">
    <template v-if="isAdmin">
      <ChartCard
        :title="t('HOME.CHARTS.TRAFFIC')"
        :to="accountScopedRoute('account_overview_reports')"
        :failed="failed('traffic')"
        :empty="!traffic.length"
      >
        <BarChart
          :data="trafficChart"
          :aria-label="t('HOME.CHARTS.TRAFFIC')"
          :height="180"
          :bar-radius="3"
          :max-bar-width="28"
          :y-step-size="trafficStep"
        />
      </ChartCard>
      <ChartCard
        :title="t('HOME.CHARTS.RESPONSE')"
        :to="accountScopedRoute('account_overview_reports')"
        :failed="failed('responseTrend')"
        :empty="!response.length"
      >
        <TrendLine
          :lines="responseLines"
          :max="responseMax"
          :start="response[0] && date(response[0].at.toISOString())"
          :end="response.at(-1) && date(response.at(-1).at.toISOString())"
          :aria-label="t('HOME.CHARTS.RESPONSE')"
          :table="responseTable"
        />
      </ChartCard>
    </template>

    <template v-if="crmEnabled">
      <ChartCard
        :title="t('HOME.CHARTS.WON_VS_TARGET')"
        :to="report('quota')"
        :failed="failed('quota')"
        :empty="!cumulative.max"
      >
        <TrendLine
          :lines="wonLines"
          :max="cumulative.max"
          :start="monthStart && date(monthStart)"
          :end="monthEnd && date(monthEnd)"
          :aria-label="t('HOME.CHARTS.WON_VS_TARGET')"
          :table="wonTable"
        />
      </ChartCard>
      <ChartCard
        :title="t('HOME.CHARTS.PIPELINE')"
        :to="report('pipeline_by_stage')"
        :failed="failed('pipeline')"
        :empty="!stages.length"
      >
        <BarRows
          :rows="stages"
          :label="row => compactMoney(row.value, currency)"
          :bar-class="COLORS.open.bar"
          :no-name="t('CRM.COMMON.UNASSIGNED')"
        />
      </ChartCard>
    </template>

    <template v-if="isAdmin">
      <ChartCard
        :title="t('HOME.CHARTS.CHANNELS')"
        :to="accountScopedRoute('account_overview_reports')"
        :failed="failed('channels')"
        :empty="!channels.length"
      >
        <BarRows
          :rows="channels"
          :label="row => number(row.value)"
          :bar-class="COLORS.neutral.bar"
          :no-name="t('HOME.CHARTS.NO_INBOX')"
        />
      </ChartCard>
      <ChartCard
        :title="t('HOME.CHARTS.LOAD')"
        :to="accountScopedRoute('account_overview_reports')"
        :failed="failed('load')"
        :empty="!load.length"
      >
        <BarRows
          :rows="load"
          :label="row => number(row.value)"
          :bar-class="COLORS.warn.bar"
          :no-name="t('CRM.COMMON.UNASSIGNED')"
        />
      </ChartCard>
    </template>
  </div>
</template>
