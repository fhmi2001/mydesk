<script setup>
// Custom (MyDesk): التقرير 21, what did each campaign bring? (SalesCrm::Reports::Campaigns, the manager's only) Deals
// credited directly (a live chat campaign's conversation) and influenced (an SMS shortly before) side by side, never
// added together; for SMS, the recipients, the share that became deals, the cost and the revenue per riyal.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../../shared/useCrmFormat';
import ReportSection from './ReportSection.vue';
import AssigneeTable from './AssigneeTable.vue';

const props = defineProps({
  data: { type: Object, required: true },
  currency: { type: String, default: 'SAR' },
});
const emit = defineEmits(['drill']);

const { t } = useI18n();
const { number } = useCrmFormat();
const L = key => t(`CRM.REPORTS.WAVE.CAMPAIGNS.${key}`);

const rows = computed(() =>
  (props.data.rows || []).map(row => ({
    ...row,
    key: row.campaign_id,
    name: row.title,
  }))
);

// The cost in the account's currency units (delivery prices are per message), or why there is none
const costText = row => {
  if (!row.sms || !row.recipients) return '—';
  const cost = number(row.cost);
  return row.cost_known ? cost : `${cost} · ${L('COST_PARTIAL')}`;
};

const columns = computed(() => [
  {
    key: 'direct_count',
    label: L('DIRECT'),
    format: 'count',
    value: row => row.direct.count,
    cell: row => row.direct.cell,
  },
  {
    key: 'direct_won',
    label: `${L('DIRECT')} · ${L('WON')}`,
    format: 'money',
    value: row => row.direct.won_cents,
  },
  {
    key: 'influenced_count',
    label: L('INFLUENCED'),
    format: 'count',
    value: row => row.influenced.count,
    cell: row => row.influenced.cell,
  },
  {
    key: 'influenced_won',
    label: `${L('INFLUENCED')} · ${L('WON')}`,
    format: 'money',
    value: row => row.influenced.won_cents,
  },
  {
    key: 'recipients',
    label: L('RECIPIENTS'),
    format: 'count',
    value: row => (row.sms ? row.recipients : null),
  },
  { key: 'conversion', label: L('CONVERSION'), format: 'percent' },
  { key: 'cost', label: L('COST'), format: 'text', value: costText },
  {
    key: 'return_per_riyal',
    label: L('RETURN'),
    format: 'times',
  },
]);
</script>

<template>
  <div class="flex flex-col gap-6">
    <ReportSection :title="L('BY_CAMPAIGN')" :note="L('HOW_CREDITED')">
      <AssigneeTable
        :rows="rows"
        :columns="columns"
        :currency="currency"
        :name-label="L('CAMPAIGN')"
        @drill="(cell, title) => emit('drill', cell, title)"
      />
    </ReportSection>
  </div>
</template>
