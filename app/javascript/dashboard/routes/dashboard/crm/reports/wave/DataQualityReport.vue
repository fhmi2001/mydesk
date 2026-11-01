<script setup>
// Custom (MyDesk): التقرير 16, the open deals missing something or out of date (SalesCrm::Reports::DataQuality)
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../../shared/useCrmFormat';
import NumberTile from './NumberTile.vue';
import ReportSection from './ReportSection.vue';
import AssigneeTable from './AssigneeTable.vue';
import DealLines from './DealLines.vue';

const props = defineProps({
  data: { type: Object, required: true },
  currency: { type: String, default: 'SAR' },
});
const emit = defineEmits(['drill']);

const { t } = useI18n();
const { number } = useCrmFormat();
const L = (key, args) => t(`CRM.REPORTS.WAVE.DATA_QUALITY.${key}`, args);
const drill = (cell, title) => emit('drill', cell, title);

const ISSUES = [
  'no_amount',
  'no_close_date',
  'past_close_date',
  'no_owner',
  'stale',
];
const totals = computed(() => props.data.totals);
const rateTone = rate => {
  if (rate === null) return '';
  if (rate >= 90) return 'good';
  return rate >= 70 ? 'warn' : 'bad';
};
const issueLabel = issue =>
  t(`CRM.REPORTS.WAVE.ISSUES.${issue}`, {
    days: number(props.data.stale_days),
  });

const assigneeColumns = computed(() => [
  { key: 'open_count', label: L('OPEN'), format: 'count' },
  {
    key: 'to_fix',
    label: L('TO_FIX'),
    format: 'count',
    cell: row => row.cell,
    tone: row => (row.to_fix ? 'bad' : ''),
  },
  {
    key: 'rate',
    label: L('RATE'),
    format: 'percent',
    tone: row => rateTone(row.rate),
  },
]);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3">
      <NumberTile
        :label="L('RATE')"
        :value="totals.rate === null ? '—' : `${number(totals.rate)}%`"
        :note="
          L('RATE_NOTE', {
            complete: number(totals.complete_count),
            open: number(totals.open_count),
          })
        "
        :tone="rateTone(totals.rate)"
      />
      <NumberTile
        :label="L('TO_FIX')"
        :value="number(totals.to_fix)"
        :tone="totals.to_fix ? 'bad' : 'good'"
        :cell="{}"
        @drill="drill"
      />
    </div>
    <div class="grid grid-cols-2 gap-3 md:grid-cols-5">
      <NumberTile
        v-for="issue in ISSUES"
        :key="issue"
        :label="issueLabel(issue)"
        :value="number(totals.issues[issue])"
        :cell="{ issue }"
        @drill="drill"
      />
    </div>
    <p class="-mt-3 text-label-small text-n-slate-11">
      {{ L('COMPLETE_MEANS') }}
    </p>

    <ReportSection v-if="data.assignees" :title="L('BY_ASSIGNEE')">
      <AssigneeTable
        :rows="data.assignees"
        :columns="assigneeColumns"
        :currency="currency"
        @drill="drill"
      />
    </ReportSection>

    <ReportSection :title="L('DEALS')">
      <DealLines
        v-if="data.rows.length"
        :deals="data.rows"
        :columns="['issues', 'stage', 'close_date']"
        :currency="currency"
        :show-assignee="data.team"
      />
      <p v-else class="text-body-main text-n-slate-11">{{ L('ALL_GOOD') }}</p>
    </ReportSection>
  </div>
</template>
