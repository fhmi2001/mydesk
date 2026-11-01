<script setup>
// Custom (MyDesk): التقرير 19, each employee against the team, for the one-to-one (SalesCrm::Reports::Scorecard).
// The manager sees every active employee's card with the team average beside each number; an employee sees their
// own card only.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../../shared/useCrmFormat';
import CellButton from './CellButton.vue';

const props = defineProps({
  data: { type: Object, required: true },
  currency: { type: String, default: 'SAR' },
});
const emit = defineEmits(['drill']);

const { t } = useI18n();
const { money, number } = useCrmFormat();
const L = (key, args) => t(`CRM.REPORTS.WAVE.SCORECARD.${key}`, args);

// format, whether lower is better, and the deals a number opens
const METRICS = [
  { key: 'attainment', format: 'percent' },
  { key: 'won_cents', format: 'money', status: 'won' },
  { key: 'win_rate', format: 'percent' },
  { key: 'coverage', format: 'times', status: 'open' },
  { key: 'sales_cycle', format: 'days', lowerIsBetter: true },
  { key: 'average_deal_cents', format: 'money' },
  { key: 'activity_count', format: 'count' },
  { key: 'new_deal_count', format: 'count', status: 'new' },
  { key: 'completeness', format: 'percent' },
];

const format = (value, kind) => {
  if (value === null || value === undefined) return '—';
  if (kind === 'money') return money(value, props.currency);
  if (kind === 'percent') return `${number(value)}%`;
  if (kind === 'times') return `${number(value)}×`;
  if (kind === 'days') return L('DAYS', { days: number(value) });
  return number(value);
};

const average = computed(() => props.data.team_average);

// Above or below the team: green when better, red when worse
const compare = (card, metric) => {
  const mine = card[metric.key];
  const team = average.value?.[metric.key];
  if (mine === null || team === null || team === undefined || mine === team)
    return { arrow: '', tone: 'text-n-slate-11' };
  const better = metric.lowerIsBetter ? mine < team : mine > team;
  return {
    arrow: mine > team ? '▲' : '▼',
    tone: better ? 'text-n-teal-11' : 'text-n-ruby-11',
  };
};
const drill = (card, metric) =>
  emit(
    'drill',
    { ...card.cell, status: metric.status },
    `${card.name} · ${L(`METRICS.${metric.key}`)}`
  );
</script>

<template>
  <div class="flex flex-col gap-6">
    <p v-if="average" class="text-label-small text-n-slate-11">
      {{ L('AVERAGE_NOTE', { count: number(data.team_size) }) }}
    </p>
    <section
      v-for="card in data.cards"
      :key="card.assignee_id"
      class="p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
    >
      <header class="flex flex-wrap items-baseline justify-between gap-2 mb-4">
        <h2 class="text-heading-3 text-n-slate-12">{{ card.name }}</h2>
        <p class="text-label-small text-n-slate-11">
          {{
            L('TARGET_LINE', {
              won: money(card.won_cents, currency),
              target: money(card.target_cents, currency),
            })
          }}
        </p>
      </header>
      <dl class="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-5">
        <div
          v-for="metric in METRICS"
          :key="metric.key"
          class="p-3 rounded-lg bg-n-alpha-1"
        >
          <dt class="text-label-small text-n-slate-11">
            {{ L(`METRICS.${metric.key}`) }}
          </dt>
          <dd class="mt-1 text-lg font-semibold text-n-slate-12">
            <CellButton
              v-if="metric.status"
              :cell="card.cell"
              :label="format(card[metric.key], metric.format)"
              :title="L(`METRICS.${metric.key}`)"
              :empty="!card[metric.key]"
              @drill="() => drill(card, metric)"
            />
            <span v-else class="tabular-nums" dir="auto">
              {{ format(card[metric.key], metric.format) }}
            </span>
          </dd>
          <dd
            v-if="average"
            class="mt-0.5 text-label-small tabular-nums"
            :class="compare(card, metric).tone"
          >
            <bdi>{{ compare(card, metric).arrow }}</bdi>
            {{
              L('TEAM', {
                value: format(average[metric.key], metric.format),
              })
            }}
          </dd>
        </div>
      </dl>
    </section>
  </div>
</template>
