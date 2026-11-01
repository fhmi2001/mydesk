<script setup>
// Custom (MyDesk): التقرير 13, what moved forward, back or out in the period (SalesCrm::Reports::Changes). The
// waterfall runs from the open value at the start, through what was added and taken away, to the open value at the end.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../../shared/useCrmFormat';
import NumberTile from './NumberTile.vue';
import ReportSection from './ReportSection.vue';
import AssigneeTable from './AssigneeTable.vue';

const props = defineProps({
  data: { type: Object, required: true },
  currency: { type: String, default: 'SAR' },
});
const emit = defineEmits(['drill']);

const { t } = useI18n();
const { money, number } = useCrmFormat();
const L = key => t(`CRM.REPORTS.WAVE.CHANGES.${key}`);
const M = move => t(`CRM.REPORTS.WAVE.CHANGES.MOVES.${move}`);
const drill = (cell, title) => emit('drill', cell, title);

const MOVES = [
  { key: 'new', tone: 'good' },
  { key: 'advanced', tone: 'good' },
  { key: 'moved_back', tone: 'bad' },
  { key: 'slipped', tone: 'warn' },
  { key: 'won', tone: 'good' },
  { key: 'lost', tone: 'bad' },
];

// Each step floats from where the running total stood; totals stand on the ground
const STEPS = [
  { key: 'start', kind: 'total' },
  { key: 'new', sign: 1, move: 'new' },
  { key: 'increased', sign: 1, move: 'increased' },
  { key: 'decreased', sign: -1, move: 'decreased' },
  { key: 'won', sign: -1, move: 'won' },
  { key: 'lost', sign: -1, move: 'lost' },
  { key: 'end', kind: 'total' },
];
const steps = computed(() => {
  const w = props.data.totals.waterfall;
  let running = 0;
  const bars = STEPS.map(step => {
    const value = w[step.key];
    if (step.kind === 'total') {
      running = value;
      return { ...step, value, low: 0, high: value };
    }
    const before = running;
    running += step.sign * value;
    return {
      ...step,
      value,
      low: Math.min(before, running),
      high: Math.max(before, running),
    };
  });
  const top = Math.max(1, ...bars.map(b => b.high));
  return bars.map(b => ({
    ...b,
    left: (b.low / top) * 100,
    width: Math.max(((b.high - b.low) / top) * 100, b.value ? 0.6 : 0),
  }));
});
const barClass = step => {
  if (step.kind === 'total') return 'bg-n-slate-9';
  return step.sign > 0 ? 'bg-n-teal-9' : 'bg-n-ruby-9';
};
const signed = step => {
  if (step.kind === 'total') return money(step.value, props.currency);
  return `${step.sign > 0 ? '+' : '−'} ${money(step.value, props.currency)}`;
};

const assigneeColumns = computed(() =>
  MOVES.map(move => ({
    key: move.key,
    label: M(move.key),
    format: 'count',
    value: row => row.counts[move.key],
    cell: row => ({ ...row.cell, move: move.key }),
  }))
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
      <NumberTile
        v-for="move in MOVES"
        :key="move.key"
        :label="M(move.key)"
        :value="number(data.totals.counts[move.key])"
        :tone="data.totals.counts[move.key] ? move.tone : ''"
        :cell="{ move: move.key }"
        @drill="drill"
      />
    </div>

    <ReportSection :title="L('WATERFALL')" :note="L('WATERFALL_HINT')">
      <ol class="flex flex-col gap-2.5">
        <li
          v-for="step in steps"
          :key="step.key"
          class="grid items-center grid-cols-[8rem_1fr_11rem] gap-3 text-body-main"
        >
          <span
            class="truncate"
            :class="
              step.kind === 'total'
                ? 'font-medium text-n-slate-12'
                : 'text-n-slate-11'
            "
          >
            {{ L(`STEPS.${step.key}`) }}
          </span>
          <div class="relative h-5" aria-hidden="true">
            <div class="absolute inset-y-0 w-full rounded bg-n-slate-2" />
            <div
              class="absolute inset-y-0 rounded"
              :class="barClass(step)"
              :style="{
                insetInlineStart: `${step.left}%`,
                width: `${step.width}%`,
              }"
            />
          </div>
          <span class="text-end whitespace-nowrap">
            <button
              v-if="step.move && step.value"
              type="button"
              class="tabular-nums underline rounded decoration-n-slate-7 decoration-dotted underline-offset-4 hover:text-n-brand"
              dir="auto"
              @click="drill({ move: step.move }, L(`STEPS.${step.key}`))"
            >
              {{ signed(step) }}
            </button>
            <bdi
              v-else
              class="tabular-nums"
              :class="
                step.kind === 'total'
                  ? 'font-medium text-n-slate-12'
                  : 'text-n-slate-10'
              "
            >
              {{ signed(step) }}
            </bdi>
          </span>
        </li>
      </ol>
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
