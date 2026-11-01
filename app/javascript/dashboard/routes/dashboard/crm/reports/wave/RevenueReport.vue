<script setup>
// Custom (MyDesk): التقرير 17, where revenue comes from, by product, industry or region (SalesCrm::Reports::Revenue)
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
const L = (key, args) => t(`CRM.REPORTS.WAVE.REVENUE.${key}`, args);
const drill = (cell, title) => emit('drill', cell, title);

const GROUPS = ['product', 'industry', 'region'];
const percent = value => (value === null ? '—' : `${number(value)}%`);
const rows = computed(() =>
  props.data.rows.map(row => ({ ...row, key: row.id }))
);
const rowLabel = row =>
  row.growth === null
    ? L('ROW_NEW', { share: percent(row.share) })
    : L('ROW', {
        share: percent(row.share),
        growth: `${row.growth > 0 ? '+' : ''}${percent(row.growth)}`,
      });
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3">
      <NumberTile
        :label="L('REVENUE')"
        :value="money(data.totals.won_cents, currency)"
        :delta="deltaFor(data.totals.won_cents, data.previous_totals.won_cents)"
        :cell="{}"
        tone="good"
        @drill="drill"
      />
      <NumberTile :label="L('DEALS')" :value="number(data.totals.won_count)" />
    </div>

    <ReportSection :title="L(`BY.${data.group_by}`)" :note="L('HINT')">
      <GroupSwitch
        :groups="GROUPS"
        :active="data.group_by"
        :label="L('GROUP_BY')"
        :label-for="group => L(`GROUPS.${group}`)"
        @select="group => emit('group', group)"
      />
      <RankedBars
        :rows="rows"
        :currency="currency"
        :no-name="L('NOT_SET')"
        :empty-label="L('NONE')"
        :measure="row => row.total_cents"
        :label="rowLabel"
        bar-class="bg-n-teal-9"
        @drill="drill"
      />
    </ReportSection>
  </div>
</template>
