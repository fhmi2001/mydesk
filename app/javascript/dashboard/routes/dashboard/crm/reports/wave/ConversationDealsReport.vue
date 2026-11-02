<script setup>
// Custom (MyDesk): التقرير 22, how many conversations become deals? (SalesCrm::Reports::ConversationDeals) The period's
// conversations, those that became a deal, the share, and what was won; per channel, and per employee for the manager.
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
const L = key => t(`CRM.REPORTS.WAVE.CONVERSATION_DEALS.${key}`);
const drill = (cell, title) => emit('drill', cell, title);

const inboxRows = computed(() =>
  (props.data.inboxes || []).map(row => ({ ...row, key: row.inbox_id }))
);
const columns = computed(() => [
  { key: 'conversation_count', label: L('CONVERSATIONS'), format: 'count' },
  {
    key: 'deal_count',
    label: L('BECAME_DEALS'),
    format: 'count',
    cell: row => row.cell,
  },
  { key: 'conversion', label: L('CONVERSION'), format: 'percent' },
  { key: 'won_count', label: L('WON'), format: 'count' },
  { key: 'won_cents', label: L('WON_VALUE'), format: 'money' },
]);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
      <NumberTile
        :label="L('CONVERSATIONS')"
        :value="number(data.totals.conversation_count)"
      />
      <NumberTile
        :label="L('BECAME_DEALS')"
        :value="number(data.totals.deal_count)"
        :cell="{}"
        @drill="drill"
      />
      <NumberTile
        :label="L('CONVERSION')"
        :value="
          data.totals.conversion === null
            ? '—'
            : `${number(data.totals.conversion)}%`
        "
      />
      <NumberTile
        :label="L('WON_VALUE')"
        :value="money(data.totals.won_cents, currency)"
        :note="`${number(data.totals.won_count)} ${L('WON')}`"
      />
    </div>

    <ReportSection :title="L('BY_CHANNEL')" :note="L('ONCE_HINT')">
      <AssigneeTable
        :rows="inboxRows"
        :columns="columns"
        :currency="currency"
        :name-label="L('CHANNEL')"
        @drill="drill"
      />
    </ReportSection>

    <ReportSection v-if="data.assignees?.length" :title="L('BY_ASSIGNEE')">
      <AssigneeTable
        :rows="data.assignees"
        :columns="columns"
        :currency="currency"
        @drill="drill"
      />
    </ReportSection>
  </div>
</template>
