<script setup>
// Custom (MyDesk): التقرير 8, is the open value closing this period enough for what is left of the target?
// (SalesCrm::Reports::Coverage)
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
const L = (key, args) => t(`CRM.REPORTS.WAVE.COVERAGE.${key}`, args);
const drill = (cell, title) => emit('drill', cell, title);

const totals = computed(() => props.data.totals);
const times = value => (value === null ? '—' : `${number(value)}×`);
const tone = rating =>
  ({ good: 'good', warn: 'warn', bad: 'bad' })[rating] || '';
const verdict = computed(() =>
  totals.value.rating
    ? L(`RATING.${totals.value.rating}`, {
        multiple: number(props.data.multiple),
      })
    : L('NOTHING_LEFT')
);

const assigneeColumns = computed(() => [
  {
    key: 'coverage',
    label: L('COVERAGE'),
    format: 'times',
    tone: row => tone(row.rating),
  },
  {
    key: 'open_cents',
    label: L('OPEN'),
    format: 'money',
    cell: row => ({ ...row.cell, status: 'open' }),
  },
  { key: 'target_cents', label: L('TARGET'), format: 'money' },
  {
    key: 'won_cents',
    label: L('WON'),
    format: 'money',
    cell: row => ({ ...row.cell, status: 'won' }),
  },
  { key: 'remaining_cents', label: L('REMAINING'), format: 'money' },
]);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
      <NumberTile
        :label="L('COVERAGE')"
        :value="times(totals.coverage)"
        :note="verdict"
        :tone="tone(totals.rating)"
      />
      <NumberTile
        :label="L('OPEN')"
        :value="money(totals.open_cents, currency)"
        :note="L('OPEN_COUNT', { count: number(totals.open_count) })"
        :cell="{ status: 'open' }"
        @drill="drill"
      />
      <NumberTile
        :label="L('REMAINING')"
        :value="money(totals.remaining_cents, currency)"
        :note="
          L('TARGET_NOTE', { target: money(totals.target_cents, currency) })
        "
      />
      <NumberTile
        :label="L('WON')"
        :value="money(totals.won_cents, currency)"
        :cell="{ status: 'won' }"
        @drill="drill"
      />
    </div>
    <p class="-mt-3 text-label-small text-n-slate-11">
      {{ L('HOW', { multiple: number(data.multiple) }) }}
    </p>

    <ReportSection
      v-if="data.assignees"
      :title="L('BY_ASSIGNEE')"
      :note="L('LOWEST_FIRST')"
    >
      <AssigneeTable
        :rows="data.assignees"
        :columns="assigneeColumns"
        :currency="currency"
        @drill="drill"
      />
    </ReportSection>
  </div>
</template>
