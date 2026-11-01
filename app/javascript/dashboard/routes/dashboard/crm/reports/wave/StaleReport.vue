<script setup>
// Custom (MyDesk): التقرير 3, the open deals that stopped or passed their close date (SalesCrm::Reports::Stale)
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
const L = (key, args) => t(`CRM.REPORTS.WAVE.STALE.${key}`, args);
const drill = (cell, title) => emit('drill', cell, title);

const KINDS = ['at_risk', 'stale', 'overdue'];
const tiles = computed(() =>
  KINDS.map(kind => ({
    kind,
    label: L(kind.toUpperCase(), { days: number(props.data.days) }),
    figures: props.data.totals[kind],
  }))
);
const assigneeColumns = computed(() => [
  ...KINDS.map(kind => ({
    key: `${kind}_count`,
    label: L(kind.toUpperCase(), { days: number(props.data.days) }),
    format: 'count',
    value: row => row[kind].count,
    cell: row => ({ ...row.cell, kind }),
    tone: row => (kind === 'at_risk' && row[kind].count ? 'bad' : ''),
  })),
  {
    key: 'at_risk_cents',
    label: L('AT_RISK_VALUE'),
    format: 'money',
    value: row => row.at_risk.total_cents,
  },
]);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
      <NumberTile
        v-for="tile in tiles"
        :key="tile.kind"
        :label="tile.label"
        :value="number(tile.figures.count)"
        :note="money(tile.figures.total_cents, currency)"
        :tone="tile.kind === 'at_risk' && tile.figures.count ? 'bad' : ''"
        :cell="{ kind: tile.kind }"
        @drill="drill"
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

    <ReportSection :title="L('DEALS')" :note="L('QUIET_FIRST')">
      <DealLines
        :deals="data.rows"
        :columns="['days_since_activity', 'days_overdue', 'stage']"
        :currency="currency"
        :show-assignee="data.team"
      />
    </ReportSection>
  </div>
</template>
