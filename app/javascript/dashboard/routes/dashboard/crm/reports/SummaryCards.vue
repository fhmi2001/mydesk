<script setup>
// Custom (MyDesk): the headline numbers with the change against the previous period
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../shared/useCrmFormat';
import { deltaFor } from './summaryDelta';

const props = defineProps({
  summary: { type: Object, required: true },
  currency: { type: String, default: 'SAR' },
});
const { t } = useI18n();
const { money, number } = useCrmFormat();

const cards = computed(() => {
  const cur = props.summary.current;
  const prev = props.summary.previous || {};
  const m = cents => money(cents, props.currency);
  return [
    {
      key: 'OPEN',
      value: number(cur.open_count),
      ...deltaFor(cur.open_count, prev.open_count),
    },
    {
      key: 'EXPECTED',
      value: m(cur.expected_cents),
      ...deltaFor(cur.expected_cents, prev.expected_cents),
    },
    {
      key: 'WON',
      value: number(cur.won_count),
      ...deltaFor(cur.won_count, prev.won_count),
    },
    {
      key: 'WON_TOTAL',
      value: m(cur.won_total_cents),
      ...deltaFor(cur.won_total_cents, prev.won_total_cents),
    },
    {
      key: 'LOST',
      value: number(cur.lost_count),
      ...deltaFor(cur.lost_count, prev.lost_count, true),
    },
    {
      key: 'WIN_RATE',
      value: `${cur.win_rate}%`,
      ...deltaFor(cur.win_rate, prev.win_rate),
    },
    {
      key: 'AVG_DEAL',
      value: m(cur.avg_deal_cents),
      ...deltaFor(cur.avg_deal_cents, prev.avg_deal_cents),
    },
    {
      key: 'AVG_DAYS',
      value: number(cur.avg_days_to_close),
      ...deltaFor(cur.avg_days_to_close, prev.avg_days_to_close, true),
    },
  ];
});
</script>

<template>
  <section class="grid grid-cols-2 gap-3 md:grid-cols-4">
    <div
      v-for="card in cards"
      :key="card.key"
      class="p-4 rounded-2xl border border-n-weak bg-n-solid-1"
      :data-test-id="`crm-summary-${card.key}`"
    >
      <p class="text-xs text-n-slate-11">
        {{ t(`CRM.REPORTS.SUMMARY.${card.key}`) }}
      </p>
      <p
        class="mt-1 text-xl font-semibold text-n-slate-12 tabular-nums"
        dir="auto"
      >
        {{ card.value }}
      </p>
      <p
        v-if="card.label"
        class="mt-1 text-xs tabular-nums"
        :class="
          card.tone === 'up'
            ? 'text-n-teal-11'
            : card.tone === 'down'
              ? 'text-n-ruby-11'
              : 'text-n-slate-10'
        "
        :title="t('CRM.REPORTS.VS_PREVIOUS')"
      >
        <bdi>{{ card.label }}</bdi>
      </p>
    </div>
  </section>
</template>
