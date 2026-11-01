<script setup>
// Custom (MyDesk): التقرير 15, how many new deals and from where (SalesCrm::Reports::NewDeals)
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import BarChart from 'shared/components/charts/BarChart.vue';
import { useCrmFormat } from '../../shared/useCrmFormat';
import { deltaFor } from '../summaryDelta';
import NumberTile from './NumberTile.vue';
import ReportSection from './ReportSection.vue';
import RankedBars from './RankedBars.vue';
import AssigneeTable from './AssigneeTable.vue';

const props = defineProps({
  data: { type: Object, required: true },
  currency: { type: String, default: 'SAR' },
});
const emit = defineEmits(['drill']);

const { t, locale } = useI18n();
const { money, number, date } = useCrmFormat();
const L = key => t(`CRM.REPORTS.WAVE.NEW_DEALS.${key}`);
const drill = (cell, title) => emit('drill', cell, title);

const cur = computed(() => props.data.totals);
const prev = computed(() => props.data.previous_totals);

// A day, or a month; each bucket from where it starts inside the period. Plain dates, read as UTC.
const shortDate = value =>
  new Intl.DateTimeFormat(locale.value, {
    timeZone: 'UTC',
    ...(props.data.interval === 'month'
      ? { month: 'short' }
      : { day: 'numeric', month: 'short' }),
  }).format(new Date(value));

const chart = computed(() => ({
  categories: props.data.buckets.map(b => shortDate(b.cell.from)),
  series: [
    {
      id: 'created',
      label: L('COUNT'),
      color: 'rgb(var(--iris-9))',
      valueColor: 'rgb(var(--iris-11))',
      data: props.data.buckets.map(b => ({ value: b.count })),
    },
  ],
}));
const step = computed(() =>
  Math.max(
    1,
    Math.ceil(Math.max(0, ...props.data.buckets.map(b => b.count)) / 4)
  )
);
const openBucket = ({ pointIndex }) => {
  const bucket = props.data.buckets[pointIndex];
  if (bucket?.count)
    drill(bucket.cell, `${L('CREATED_FROM')} ${date(bucket.cell.from)}`);
};

const sourceName = id =>
  props.data.sources.find(s => s.lead_source_id === id)?.name || L('NO_SOURCE');
const sourceSplit = row =>
  row.sources
    .map(s => `${sourceName(s.lead_source_id)} ${number(s.count)}`)
    .join(' · ');

const assigneeColumns = computed(() => [
  { key: 'count', label: L('COUNT'), format: 'count', cell: row => row.cell },
  { key: 'total_cents', label: L('VALUE'), format: 'money' },
  { key: 'sources', label: L('SOURCES'), format: 'text', value: sourceSplit },
]);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3">
      <NumberTile
        :label="L('COUNT')"
        :value="number(cur.count)"
        :delta="deltaFor(cur.count, prev.count)"
        :cell="{}"
        @drill="drill"
      />
      <NumberTile
        :label="L('VALUE')"
        :value="money(cur.total_cents, currency)"
        :delta="deltaFor(cur.total_cents, prev.total_cents)"
      />
    </div>
    <p class="-mt-3 text-label-small text-n-slate-10">
      {{ t('CRM.REPORTS.DELTA_NOTE') }}
    </p>

    <div class="grid grid-cols-1 gap-6 xl:grid-cols-2">
      <ReportSection :title="L('BY_SOURCE')">
        <RankedBars
          :rows="data.sources"
          :currency="currency"
          :no-name="L('NO_SOURCE')"
          :empty-label="L('NONE')"
          @drill="drill"
        />
      </ReportSection>
      <ReportSection
        :title="L('OVER_TIME')"
        :note="t('CRM.REPORTS.WAVE.WON_LOST.BAR_HINT')"
        screen-note
      >
        <BarChart
          :data="chart"
          :aria-label="L('OVER_TIME')"
          :height="220"
          :bar-radius="3"
          :max-bar-width="24"
          :y-step-size="step"
          clickable
          timeseries
          @item-click="openBucket"
        />
      </ReportSection>
    </div>

    <ReportSection v-if="data.assignees" :title="L('BY_ASSIGNEE')">
      <AssigneeTable
        :rows="data.assignees"
        :columns="assigneeColumns"
        :currency="currency"
        @drill="drill"
      />
    </ReportSection>
  </div>
</template>
