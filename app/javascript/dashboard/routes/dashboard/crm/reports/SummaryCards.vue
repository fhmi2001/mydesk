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
  // A rate or an average of nothing is not zero: show a dash and say why
  const hasWon = Number(cur.won_count) > 0;
  const hasClosed = hasWon || Number(cur.lost_count) > 0;
  const noData = (key, reason) => ({
    key,
    value: '—',
    note: t(`CRM.REPORTS.SUMMARY.${reason}`),
    tone: 'flat',
  });
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
    hasClosed
      ? {
          key: 'WIN_RATE',
          value: `${cur.win_rate}%`,
          ...deltaFor(cur.win_rate, prev.win_rate),
        }
      : noData('WIN_RATE', 'NO_CLOSED'),
    hasWon
      ? {
          key: 'AVG_DEAL',
          value: m(cur.avg_deal_cents),
          ...deltaFor(cur.avg_deal_cents, prev.avg_deal_cents),
        }
      : noData('AVG_DEAL', 'NO_WON'),
    hasClosed
      ? {
          key: 'AVG_DAYS',
          value: number(cur.avg_days_to_close),
          ...deltaFor(cur.avg_days_to_close, prev.avg_days_to_close, true),
        }
      : noData('AVG_DAYS', 'NO_CLOSED'),
  ];
});
</script>

<template>
  <section :aria-label="t('CRM.REPORTS.SUMMARY.TITLE')">
    <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
      <div
        v-for="card in cards"
        :key="card.key"
        class="p-4 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
        :data-test-id="`crm-summary-${card.key}`"
      >
        <p class="text-label-small text-n-slate-11">
          {{ t(`CRM.REPORTS.SUMMARY.${card.key}`) }}
        </p>
        <p
          class="mt-1 text-lg font-semibold text-n-slate-12 tabular-nums"
          dir="auto"
        >
          {{ card.value }}
        </p>
        <p v-if="card.note" class="mt-1 text-label-small text-n-slate-10">
          {{ card.note }}
        </p>
        <p
          v-else-if="card.label"
          class="mt-1 text-label-small tabular-nums"
          :class="
            card.tone === 'up'
              ? 'text-n-teal-11'
              : card.tone === 'down'
                ? 'text-n-ruby-11'
                : 'text-n-slate-10'
          "
        >
          <bdi>{{ card.label }}</bdi>
          <span class="sr-only">{{ t('CRM.REPORTS.VS_PREVIOUS') }}</span>
        </p>
      </div>
    </div>
    <p class="mt-2 text-label-small text-n-slate-10">
      {{ t('CRM.REPORTS.DELTA_NOTE') }}
    </p>
  </section>
</template>
