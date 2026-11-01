<script setup>
// Custom (MyDesk): التقرير 5, what closed in the period and how (SalesCrm::Reports::WonLost)
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import BarChart from 'shared/components/charts/BarChart.vue';
import { useCrmFormat } from '../../shared/useCrmFormat';
import { deltaFor } from '../summaryDelta';
import NumberTile from './NumberTile.vue';
import ReportSection from './ReportSection.vue';
import AssigneeTable from './AssigneeTable.vue';
import CellButton from './CellButton.vue';

const props = defineProps({
  data: { type: Object, required: true },
  currency: { type: String, default: 'SAR' },
});
const emit = defineEmits(['drill']);

const { t, locale } = useI18n();
const { money, number, date } = useCrmFormat();
const L = key => t(`CRM.REPORTS.WAVE.WON_LOST.${key}`);
const drill = (cell, title) => emit('drill', cell, title);

const cur = computed(() => props.data.totals);
const prev = computed(() => props.data.previous_totals);
const percent = value => (value === null ? '—' : `${number(value)}%`);

const tiles = computed(() => [
  {
    key: 'WON',
    value: number(cur.value.won_count),
    note: money(cur.value.won_cents, props.currency),
    delta: deltaFor(cur.value.won_count, prev.value.won_count),
    cell: { status: 'won' },
    tone: 'good',
  },
  {
    key: 'LOST',
    value: number(cur.value.lost_count),
    note: money(cur.value.lost_cents, props.currency),
    delta: deltaFor(cur.value.lost_count, prev.value.lost_count, true),
    cell: { status: 'lost' },
    tone: cur.value.lost_count ? 'bad' : '',
  },
  {
    key: 'WIN_RATE',
    value: percent(cur.value.by_count),
    delta: deltaFor(cur.value.by_count, prev.value.by_count),
  },
  {
    key: 'WIN_RATE_VALUE',
    value: percent(cur.value.by_value),
    delta: deltaFor(cur.value.by_value, prev.value.by_value),
  },
]);

// Short axis labels: a day, or a month ("نوفمبر"; the period above gives the year), from where each bucket starts inside the period (a week can
// start on the Saturday before it); buckets are plain dates, read as UTC
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
      id: 'won',
      label: t('CRM.REPORTS.TIMELINE.WON'),
      color: 'rgb(var(--teal-9))',
      valueColor: 'rgb(var(--teal-11))',
      data: props.data.buckets.map(b => ({ value: b.won_count })),
    },
    {
      id: 'lost',
      label: t('CRM.REPORTS.TIMELINE.LOST'),
      color: 'rgb(var(--ruby-9))',
      valueColor: 'rgb(var(--ruby-11))',
      data: props.data.buckets.map(b => ({ value: b.lost_count })),
    },
  ],
}));
const step = computed(() =>
  Math.max(
    1,
    Math.ceil(
      Math.max(
        0,
        ...props.data.buckets.flatMap(b => [b.won_count, b.lost_count])
      ) / 4
    )
  )
);

// A bar opens the deals closed in its day, week or month, won and lost together
const openBucket = ({ pointIndex }) => {
  const bucket = props.data.buckets[pointIndex];
  if (!bucket || !(bucket.won_count || bucket.lost_count)) return;
  drill(
    { ...bucket.cell, status: 'closed' },
    `${L('CLOSED_IN')} ${date(bucket.cell.from)}`
  );
};

const assigneeColumns = computed(() => [
  {
    key: 'won_count',
    label: L('WON'),
    format: 'count',
    cell: row => ({ ...row.cell, status: 'won' }),
  },
  { key: 'won_cents', label: L('WON_VALUE'), format: 'money' },
  {
    key: 'lost_count',
    label: L('LOST'),
    format: 'count',
    cell: row => ({ ...row.cell, status: 'lost' }),
  },
  { key: 'lost_cents', label: L('LOST_VALUE'), format: 'money' },
  { key: 'by_count', label: L('WIN_RATE'), format: 'percent' },
]);
const lostMax = computed(() =>
  Math.max(1, ...props.data.lost_reasons.map(r => r.count))
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
      <NumberTile
        v-for="tile in tiles"
        :key="tile.key"
        :label="L(tile.key)"
        :value="tile.value"
        :note="tile.note"
        :delta="tile.delta"
        :cell="tile.cell"
        :tone="tile.tone"
        @drill="drill"
      />
    </div>
    <p class="-mt-4 text-label-small text-n-slate-10">
      {{ t('CRM.REPORTS.DELTA_NOTE') }}
    </p>

    <ReportSection :title="L('OVER_TIME')" :note="L('BAR_HINT')" screen-note>
      <BarChart
        :data="chart"
        :aria-label="L('OVER_TIME')"
        :height="240"
        :bar-radius="3"
        :bar-gap="2"
        :max-bar-width="24"
        :y-step-size="step"
        clickable
        timeseries
        @item-click="openBucket"
      />
    </ReportSection>

    <div class="grid grid-cols-1 gap-6 xl:grid-cols-2">
      <ReportSection v-if="data.assignees" :title="L('BY_ASSIGNEE')">
        <AssigneeTable
          :rows="data.assignees"
          :columns="assigneeColumns"
          :currency="currency"
          @drill="drill"
        />
      </ReportSection>

      <ReportSection :title="t('CRM.REPORTS.LOST_REASONS.TITLE')">
        <ul v-if="data.lost_reasons.length" class="flex flex-col gap-3">
          <li
            v-for="row in data.lost_reasons"
            :key="row.cell.reason"
            class="text-body-main"
          >
            <div class="flex items-center justify-between gap-3">
              <span class="truncate text-n-slate-12">{{ row.reason }}</span>
              <span class="text-n-slate-11 shrink-0">
                <CellButton
                  :cell="row.cell"
                  :label="number(row.count)"
                  :title="row.reason"
                  @drill="drill"
                />
                ·
                <bdi class="tabular-nums">{{
                  money(row.total_cents, currency)
                }}</bdi>
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
      </ReportSection>
    </div>
  </div>
</template>
