<script setup>
// Custom (MyDesk): التقرير 18, are our deals getting bigger or smaller? (SalesCrm::Reports::DealSize)
import { COLORS } from './reportColors';
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import BarChart from 'shared/components/charts/BarChart.vue';
import { useCrmFormat } from '../../shared/useCrmFormat';
import { deltaFor } from '../summaryDelta';
import NumberTile from './NumberTile.vue';
import ReportSection from './ReportSection.vue';
import AssigneeTable from './AssigneeTable.vue';

const props = defineProps({
  data: { type: Object, required: true },
  currency: { type: String, default: 'SAR' },
});
const emit = defineEmits(['drill']);

const { t, locale } = useI18n();
const { money, number, date } = useCrmFormat();
const L = key => t(`CRM.REPORTS.WAVE.DEAL_SIZE.${key}`);
const drill = (cell, title) => emit('drill', cell, title);

// A month ("أكتوبر"), or a quarter's first month with its year; plain dates, read as UTC
const label = value =>
  new Intl.DateTimeFormat(locale.value, {
    timeZone: 'UTC',
    month: 'short',
    ...(props.data.interval === 'quarter' ? { year: 'numeric' } : {}),
  }).format(new Date(value));

// The chart counts in whole currency units
const chart = computed(() => ({
  categories: props.data.buckets.map(b => label(b.cell.from)),
  series: [
    {
      id: 'average',
      label: L('AVERAGE'),
      color: COLORS.won.rgb,
      valueColor: COLORS.won.rgbText,
      data: props.data.buckets.map(b => ({
        value: Math.round((b.average_cents || 0) / 100),
      })),
    },
  ],
}));
const openBucket = ({ pointIndex }) => {
  const bucket = props.data.buckets[pointIndex];
  if (bucket?.count)
    drill(bucket.cell, `${L('WON_FROM')} ${date(bucket.cell.from)}`);
};

const assigneeColumns = computed(() => [
  { key: 'average_cents', label: L('AVERAGE'), format: 'money' },
  { key: 'count', label: L('DEALS'), format: 'count', cell: row => row.cell },
]);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3">
      <NumberTile
        :label="L('AVERAGE')"
        :value="
          data.totals.average_cents === null
            ? '—'
            : money(data.totals.average_cents, currency)
        "
        :delta="
          deltaFor(
            data.totals.average_cents,
            data.previous_totals.average_cents
          )
        "
      />
      <NumberTile
        :label="L('DEALS')"
        :value="number(data.totals.won_count)"
        :note="L('NO_AMOUNT_LEFT_OUT')"
        :cell="{}"
        @drill="drill"
      />
    </div>

    <ReportSection
      :title="L(`TREND.${data.interval}`)"
      :note="t('CRM.REPORTS.WAVE.WON_LOST.BAR_HINT')"
      screen-note
    >
      <BarChart
        :data="chart"
        :aria-label="L(`TREND.${data.interval}`)"
        :height="240"
        :bar-radius="3"
        :max-bar-width="32"
        clickable
        @item-click="openBucket"
      />
    </ReportSection>

    <ReportSection v-if="data.assignees?.length" :title="L('BY_ASSIGNEE')">
      <AssigneeTable
        :rows="data.assignees"
        :columns="assigneeColumns"
        :currency="currency"
        @drill="drill"
      />
    </ReportSection>
  </div>
</template>
