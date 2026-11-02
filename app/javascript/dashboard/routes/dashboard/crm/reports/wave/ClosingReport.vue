<script setup>
// Custom (MyDesk): التقرير 2, the open deals expected to close in the period (SalesCrm::Reports::Closing)
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
const { money, number } = useCrmFormat();
const L = key => t(`CRM.REPORTS.WAVE.CLOSING.${key}`);
const drill = (cell, title) => emit('drill', cell, title);

const percent = value => (value === null ? '—' : `${number(value)}%`);
const assigneeColumns = computed(() => [
  { key: 'count', label: L('COUNT'), format: 'count', cell: row => row.cell },
  { key: 'total_cents', label: L('VALUE'), format: 'money' },
  { key: 'weighted_cents', label: L('WEIGHTED'), format: 'money' },
  {
    key: 'average_probability',
    label: L('AVG_PROBABILITY'),
    format: 'percent',
  },
]);
const isPartial = computed(
  () => props.data.rows.length < props.data.totals.count
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
      <NumberTile
        :label="L('COUNT')"
        :value="number(data.totals.count)"
        :cell="{}"
        @drill="drill"
      />
      <NumberTile
        :label="L('VALUE')"
        :value="money(data.totals.total_cents, currency)"
        :cell="{}"
        @drill="drill"
      />
      <NumberTile
        :label="L('WEIGHTED')"
        :value="money(data.totals.weighted_cents, currency)"
      />
      <NumberTile
        :label="L('AVG_PROBABILITY')"
        :value="percent(data.totals.average_probability)"
      />
    </div>

    <ReportSection v-if="data.assignees" :title="L('BY_ASSIGNEE')">
      <AssigneeTable
        :rows="data.assignees"
        :columns="assigneeColumns"
        :currency="currency"
        @drill="drill"
      />
    </ReportSection>

    <ReportSection
      :title="L('DEALS')"
      :note="
        isPartial
          ? L('PARTIAL', {
              shown: number(data.rows.length),
              total: number(data.totals.count),
            })
          : ''
      "
    >
      <DealLines
        :deals="data.rows"
        :columns="['close_date', 'days_overdue', 'stage', 'probability']"
        :currency="currency"
        :show-assignee="data.team"
      />
    </ReportSection>
  </div>
</template>
