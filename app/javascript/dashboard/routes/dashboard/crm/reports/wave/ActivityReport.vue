<script setup>
// Custom (MyDesk): التقرير 14, the team's activity beside its results, for the manager (SalesCrm::Reports::Activity).
// Activity = tasks completed by kind, and notes written on deals.
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
const { money, number } = useCrmFormat();
const L = key => t(`CRM.REPORTS.WAVE.ACTIVITY.${key}`);
const drill = (cell, title) => emit('drill', cell, title);

const cur = computed(() => props.data.totals);
const prev = computed(() => props.data.previous_totals);

// One colour per kind of activity, the same in the bars, their legend and nowhere else
const PARTS = [
  { key: 'call', color: 'bg-n-iris-9' },
  { key: 'meeting', color: 'bg-n-teal-9' },
  { key: 'task', color: 'bg-n-amber-9' },
  { key: 'note', color: 'bg-n-slate-8' },
];
const partLabel = key =>
  key === 'note' ? L('NOTES') : t(`CRM.TASKS.KINDS.${key}`);
const partValue = (row, key) =>
  key === 'note' ? row.note_count : row.by_kind[key];
const maxActivity = computed(() =>
  Math.max(1, ...props.data.assignees.map(r => r.activity_count))
);

const assigneeColumns = computed(() => [
  ...['call', 'meeting', 'task'].map(kind => ({
    key: kind,
    label: t(`CRM.TASKS.KINDS.${kind}`),
    format: 'count',
    value: row => row.by_kind[kind],
    cell: row => ({ ...row.cell, kind }),
  })),
  { key: 'note_count', label: L('NOTES'), format: 'count' },
  { key: 'activity_count', label: L('TOTAL'), format: 'count' },
  {
    key: 'won_count',
    label: L('WON'),
    format: 'count',
    cell: row => row.cell,
  },
  { key: 'won_cents', label: L('WON_VALUE'), format: 'money' },
  { key: 'win_rate', label: L('WIN_RATE'), format: 'percent' },
]);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
      <NumberTile
        :label="L('TOTAL')"
        :value="number(cur.activity_count)"
        :delta="deltaFor(cur.activity_count, prev.activity_count)"
      />
      <NumberTile
        v-for="kind in ['call', 'meeting', 'task']"
        :key="kind"
        :label="t(`CRM.TASKS.KINDS.${kind}`)"
        :value="number(cur.by_kind[kind])"
        :delta="deltaFor(cur.by_kind[kind], prev.by_kind[kind])"
        :cell="{ kind }"
        @drill="drill"
      />
      <NumberTile
        :label="L('NOTES')"
        :value="number(cur.note_count)"
        :delta="deltaFor(cur.note_count, prev.note_count)"
      />
      <NumberTile
        :label="L('WON')"
        :value="number(cur.won_count)"
        :note="money(cur.won_cents, currency)"
        :cell="{}"
        tone="good"
        @drill="drill"
      />
    </div>

    <ReportSection :title="L('BY_ASSIGNEE')" :note="L('WHAT_COUNTS')">
      <ul class="flex flex-col gap-3 mb-6">
        <li
          v-for="row in data.assignees"
          :key="row.assignee_id"
          class="grid items-center grid-cols-[8rem_1fr_auto] gap-3 text-body-main"
        >
          <span class="truncate text-n-slate-12">{{ row.name }}</span>
          <div class="flex h-3 overflow-hidden rounded-full bg-n-slate-3">
            <div
              v-for="part in PARTS"
              :key="part.key"
              :class="part.color"
              :style="{
                width: `${(partValue(row, part.key) / maxActivity) * 100}%`,
              }"
              :title="`${partLabel(part.key)}: ${number(partValue(row, part.key))}`"
            />
          </div>
          <span class="tabular-nums text-n-slate-11">
            {{ number(row.activity_count) }}
          </span>
        </li>
      </ul>
      <ul
        class="flex flex-wrap gap-x-4 gap-y-1 mb-4 text-label-small text-n-slate-11"
      >
        <li
          v-for="part in PARTS"
          :key="part.key"
          class="inline-flex items-center gap-1.5"
        >
          <span
            class="size-2.5 rounded-sm"
            :class="part.color"
            aria-hidden="true"
          />
          {{ partLabel(part.key) }}
        </li>
      </ul>
      <AssigneeTable
        :rows="data.assignees"
        :columns="assigneeColumns"
        :currency="currency"
        @drill="drill"
      />
    </ReportSection>
  </div>
</template>
