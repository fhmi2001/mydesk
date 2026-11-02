<script setup>
// Custom (MyDesk): التقرير 12, why we lose and to whom (SalesCrm::Reports::Losses)
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../../shared/useCrmFormat';
import { deltaFor } from '../summaryDelta';
import NumberTile from './NumberTile.vue';
import ReportSection from './ReportSection.vue';
import RankedBars from './RankedBars.vue';
import AssigneeTable from './AssigneeTable.vue';

const props = defineProps({
  data: { type: Object, required: true },
  currency: { type: String, default: 'SAR' },
});
const emit = defineEmits(['drill']);

const { t } = useI18n();
const { money, number } = useCrmFormat();
const L = key => t(`CRM.REPORTS.WAVE.LOSSES.${key}`);
const drill = (cell, title) => emit('drill', cell, title);

const cur = computed(() => props.data.totals);
const prev = computed(() => props.data.previous_totals);
const stages = computed(() =>
  props.data.stages.map(s => ({
    ...s,
    name: s.key === 'unknown' ? L('UNKNOWN_STAGE') : s.name,
  }))
);
const assigneeColumns = computed(() => [
  { key: 'count', label: L('COUNT'), format: 'count', cell: row => row.cell },
  { key: 'total_cents', label: L('VALUE'), format: 'money' },
  {
    key: 'top_reason',
    label: L('TOP_REASON'),
    value: row => row.top_reason || '—',
    format: 'text',
  },
]);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3">
      <NumberTile
        :label="L('COUNT')"
        :value="number(cur.count)"
        :delta="deltaFor(cur.count, prev.count, true)"
        :cell="{}"
        tone="bad"
        @drill="drill"
      />
      <NumberTile
        :label="L('VALUE')"
        :value="money(cur.total_cents, currency)"
        :delta="deltaFor(cur.total_cents, prev.total_cents, true)"
      />
    </div>
    <p class="-mt-3 text-label-small text-n-slate-11">
      {{ t('CRM.REPORTS.DELTA_NOTE') }}
    </p>

    <div class="grid grid-cols-1 gap-6 xl:grid-cols-3">
      <ReportSection :title="L('REASONS')">
        <RankedBars
          :rows="data.reasons"
          :currency="currency"
          no-name="-"
          :empty-label="L('NONE')"
          bar-class="bg-n-ruby-9"
          @drill="drill"
        />
      </ReportSection>
      <ReportSection :title="L('COMPETITORS')">
        <RankedBars
          :rows="data.competitors"
          :currency="currency"
          :no-name="L('NO_COMPETITOR')"
          :empty-label="L('NONE')"
          bar-class="bg-n-amber-9"
          @drill="drill"
        />
      </ReportSection>
      <ReportSection :title="L('STAGES')" :note="L('STAGES_HINT')">
        <RankedBars
          :rows="stages"
          :currency="currency"
          :no-name="L('UNKNOWN_STAGE')"
          :empty-label="L('NONE')"
          bar-class="bg-n-slate-9"
          @drill="drill"
        />
      </ReportSection>
    </div>

    <ReportSection v-if="data.assignees" :title="L('BY_ASSIGNEE')">
      <AssigneeTable
        :rows="data.assignees"
        :columns="assigneeColumns"
        :currency="currency"
        @drill="drill"
      />
    </ReportSection>
  </div>
</template>
