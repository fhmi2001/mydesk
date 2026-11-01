<script setup>
// Custom (MyDesk): التقرير 6, won against the target, and what is left (SalesCrm::Reports::Quota)
import { COLORS } from './reportColors';
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
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

const { t } = useI18n();
const { money, number, date } = useCrmFormat();
const L = (key, args) => t(`CRM.REPORTS.WAVE.QUOTA.${key}`, args);
const drill = (cell, title) => emit('drill', cell, title);

const cur = computed(() => props.data.totals);
const prev = computed(() => props.data.previous_totals);
const percent = value => (value === null ? '—' : `${number(value)}%`);
const hasTarget = computed(() => cur.value.target_cents > 0);
const progress = computed(() =>
  Math.min(100, Number(cur.value.attainment) || 0)
);

// The cumulative line: value won so far against the target spread evenly over the days
const W = 600;
const H = 180;
const line = computed(() => {
  const points = props.data.cumulative;
  const top = Math.max(
    1,
    ...points.map(p => Math.max(p.target_cents, p.won_cents || 0))
  );
  const x = i => (points.length > 1 ? (i / (points.length - 1)) * W : 0);
  const y = v => H - (v / top) * H;
  const path = key =>
    points
      .map((p, i) => (p[key] === null ? null : `${x(i)},${y(p[key])}`))
      .filter(Boolean)
      .join(' ');
  return { won: path('won_cents'), target: path('target_cents') };
});
const lineLabel = computed(() =>
  L('LINE_LABEL', {
    won: money(cur.value.won_cents, props.currency),
    target: money(cur.value.target_cents, props.currency),
  })
);
const firstDay = computed(() => props.data.cumulative[0]?.date);
const lastDay = computed(() => props.data.cumulative.at(-1)?.date);

const assigneeColumns = computed(() => [
  { key: 'target_cents', label: L('TARGET'), format: 'money' },
  { key: 'won_cents', label: L('WON'), format: 'money', cell: row => row.cell },
  {
    key: 'attainment',
    label: L('ATTAINMENT'),
    format: 'percent',
    tone: row => (row.attainment >= 100 ? 'good' : ''),
  },
  { key: 'remaining_cents', label: L('REMAINING'), format: 'money' },
]);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
      <NumberTile
        :label="L('ATTAINMENT')"
        :value="percent(cur.attainment)"
        :note="hasTarget ? '' : L('NO_TARGET')"
        :delta="deltaFor(cur.attainment, prev.attainment)"
        :tone="cur.attainment >= 100 ? 'good' : ''"
      />
      <NumberTile
        :label="L('WON')"
        :value="money(cur.won_cents, currency)"
        :delta="deltaFor(cur.won_cents, prev.won_cents)"
        :cell="{}"
        @drill="drill"
      />
      <NumberTile
        :label="L('TARGET')"
        :value="money(cur.target_cents, currency)"
      />
      <NumberTile
        :label="L('REMAINING')"
        :value="money(cur.remaining_cents, currency)"
      />
    </div>

    <ReportSection :title="L('PROGRESS')">
      <div
        class="h-3 rounded-full bg-n-slate-3"
        role="progressbar"
        :aria-valuenow="progress"
        aria-valuemin="0"
        aria-valuemax="100"
        :aria-label="L('ATTAINMENT')"
      >
        <div
          class="h-full rounded-full transition-[width]"
          :class="progress >= 100 ? COLORS.won.bar : COLORS.open.bar"
          :style="{ width: `${progress}%` }"
        />
      </div>
      <svg
        v-if="hasTarget || cur.won_cents"
        :viewBox="`0 -6 ${W} ${H + 12}`"
        class="w-full mt-6 h-44"
        preserveAspectRatio="none"
        role="img"
        :aria-label="lineLabel"
      >
        <polyline
          :points="line.target"
          fill="none"
          :stroke="COLORS.neutral.rgb"
          stroke-width="2"
          stroke-dasharray="6 5"
          vector-effect="non-scaling-stroke"
        />
        <polyline
          :points="line.won"
          fill="none"
          :stroke="COLORS.won.rgb"
          stroke-width="2.5"
          vector-effect="non-scaling-stroke"
        />
      </svg>
      <div
        class="flex flex-wrap items-center justify-between gap-3 mt-2 text-label-small text-n-slate-11"
      >
        <span class="tabular-nums">{{ firstDay && date(firstDay) }}</span>
        <span class="inline-flex items-center gap-4">
          <span class="inline-flex items-center gap-1.5">
            <span
              class="w-4 h-0.5"
              :class="COLORS.won.bar"
              aria-hidden="true"
            />
            {{ L('WON_SO_FAR') }}
          </span>
          <span class="inline-flex items-center gap-1.5">
            <span
              class="w-4 border-t-2 border-dashed border-n-slate-8"
              aria-hidden="true"
            />
            {{ L('TARGET_PACE') }}
          </span>
        </span>
        <span class="tabular-nums">{{ lastDay && date(lastDay) }}</span>
      </div>
    </ReportSection>

    <ReportSection v-if="data.assignees" :title="L('RANKING')">
      <AssigneeTable
        :rows="data.assignees"
        :columns="assigneeColumns"
        :currency="currency"
        ranked
        @drill="drill"
      />
    </ReportSection>
  </div>
</template>
