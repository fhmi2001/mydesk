<script setup>
// Custom (MyDesk): التقرير 10, from which employee, product or source do we win most? (SalesCrm::Reports::WinRates)
// The grouping is chosen here and sent back to the page (`group`), which asks the server again.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../../shared/useCrmFormat';
import { deltaFor } from '../summaryDelta';
import NumberTile from './NumberTile.vue';
import ReportSection from './ReportSection.vue';
import RankedBars from './RankedBars.vue';
import GroupSwitch from './GroupSwitch.vue';

const props = defineProps({
  data: { type: Object, required: true },
  currency: { type: String, default: 'SAR' },
});
const emit = defineEmits(['drill', 'group']);

const { t } = useI18n();
const { money, number } = useCrmFormat();
const L = (key, args) => t(`CRM.REPORTS.WAVE.WIN_RATE.${key}`, args);
const drill = (cell, title) => emit('drill', cell, title);

const cur = computed(() => props.data.totals);
const prev = computed(() => props.data.previous_totals);
const percent = value => (value === null ? '—' : `${number(value)}%`);

// An employee has no colleagues to compare with: products and sources only
const groups = computed(() =>
  (props.data.team ? ['assignee'] : []).concat(['product', 'lead_source'])
);

const rows = computed(() =>
  props.data.rows.map(row => ({
    ...row,
    key: row.id,
    count: row.won_count + row.lost_count,
    cell: { ...row.cell },
  }))
);
const rowLabel = row =>
  L('ROW', {
    rate: percent(row.by_count),
    value: percent(row.by_value),
  });
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
      <NumberTile
        :label="L('BY_COUNT')"
        :value="percent(cur.by_count)"
        :delta="deltaFor(cur.by_count, prev.by_count)"
      />
      <NumberTile
        :label="L('BY_VALUE')"
        :value="percent(cur.by_value)"
        :delta="deltaFor(cur.by_value, prev.by_value)"
      />
      <NumberTile
        :label="L('WON')"
        :value="number(cur.won_count)"
        :note="money(cur.won_cents, currency)"
        :cell="{ status: 'won' }"
        tone="good"
        @drill="drill"
      />
      <NumberTile
        :label="L('LOST')"
        :value="number(cur.lost_count)"
        :note="money(cur.lost_cents, currency)"
        :cell="{ status: 'lost' }"
        @drill="drill"
      />
    </div>

    <ReportSection :title="L(`BY.${data.group_by}`)" :note="L('HINT')">
      <GroupSwitch
        :groups="groups"
        :active="data.group_by"
        :label="L('GROUP_BY')"
        :label-for="group => L(`GROUPS.${group}`)"
        @select="group => emit('group', group)"
      />
      <RankedBars
        :rows="rows"
        :no-name="L(`NONE.${data.group_by}`)"
        :empty-label="L('EMPTY_GROUP')"
        :measure="row => row.by_count"
        :label="rowLabel"
        bar-class="bg-n-teal-9"
        @drill="drill"
      />
    </ReportSection>
  </div>
</template>
