<script setup>
// Custom (MyDesk): the four numbers an owner checks first. Times are medians (one slow conversation
// cannot distort them) with the 90th percentile beside them; every tile compares with the previous period.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  formatDuration,
  formatNumber,
  NO_VALUE,
} from 'dashboard/helper/reportFormatters';

const props = defineProps({
  data: { type: Object, default: null },
  isLoading: { type: Boolean, default: false },
});

const { t, locale } = useI18n();

const percentChange = (current, previous) => {
  if (!previous || current === null || current === undefined) return null;
  return Math.round(((current - previous) / previous) * 100);
};

// For durations a drop is good news; for volume neither direction is good or bad
const deltaTone = (change, lowerIsBetter) => {
  if (!change || lowerIsBetter === null) return 'text-n-slate-11';
  const improved = lowerIsBetter ? change < 0 : change > 0;
  return improved ? 'text-n-teal-11' : 'text-n-ruby-11';
};

const duration = seconds =>
  seconds ? formatDuration(seconds, locale?.value) : NO_VALUE;

const tiles = computed(() => {
  const current = props.data?.current;
  const previous = props.data?.previous;
  if (!current) return [];

  return [
    {
      key: 'conversations',
      icon: 'i-lucide-messages-square',
      label: t('PERFORMANCE_REPORTS.KPI.CONVERSATIONS'),
      value: formatNumber(current.conversations, locale?.value),
      change: percentChange(current.conversations, previous?.conversations),
      lowerIsBetter: null,
      note: t('PERFORMANCE_REPORTS.KPI.RESOLVED', {
        count: formatNumber(current.resolved, locale?.value),
      }),
    },
    {
      key: 'first-response',
      icon: 'i-lucide-reply',
      label: t('PERFORMANCE_REPORTS.KPI.FIRST_RESPONSE'),
      value: duration(current.first_response.median),
      change: percentChange(
        current.first_response.median,
        previous?.first_response.median
      ),
      lowerIsBetter: true,
      note: current.first_response.count
        ? t('PERFORMANCE_REPORTS.KPI.P90', {
            value: duration(current.first_response.p90),
          })
        : t('PERFORMANCE_REPORTS.KPI.NOT_ENOUGH'),
    },
    {
      key: 'resolution',
      icon: 'i-lucide-circle-check',
      label: t('PERFORMANCE_REPORTS.KPI.RESOLUTION'),
      value: duration(current.resolution.median),
      change: percentChange(
        current.resolution.median,
        previous?.resolution.median
      ),
      lowerIsBetter: true,
      note: current.resolution.count
        ? t('PERFORMANCE_REPORTS.KPI.P90', {
            value: duration(current.resolution.p90),
          })
        : t('PERFORMANCE_REPORTS.KPI.NOT_ENOUGH'),
    },
    {
      key: 'unanswered',
      icon: 'i-lucide-clock-alert',
      label: t('PERFORMANCE_REPORTS.KPI.UNANSWERED'),
      value: formatNumber(props.data.unanswered_now, locale?.value),
      change: null,
      lowerIsBetter: null,
      note: t('PERFORMANCE_REPORTS.KPI.LIVE'),
      urgent: props.data.unanswered_now > 0,
    },
  ];
});
</script>

<template>
  <div
    class="grid grid-cols-1 gap-px overflow-hidden sm:grid-cols-2 xl:grid-cols-4 rounded-xl bg-n-weak outline outline-1 -outline-offset-1 outline-n-weak"
    :aria-busy="isLoading"
  >
    <template v-if="tiles.length">
      <div
        v-for="tile in tiles"
        :key="tile.key"
        class="flex flex-col gap-2 p-5 bg-n-solid-2"
      >
        <div class="flex items-center gap-2 text-n-slate-11">
          <span
            class="size-4 shrink-0"
            :class="[tile.icon, tile.urgent ? 'text-n-amber-11' : '']"
            aria-hidden="true"
          />
          <span class="text-sm">{{ tile.label }}</span>
        </div>
        <bdi
          class="text-2xl font-semibold leading-8 tabular-nums text-start"
          :class="tile.urgent ? 'text-n-amber-11' : 'text-n-slate-12'"
        >
          {{ tile.value }}
        </bdi>
        <div class="flex flex-wrap items-center text-xs gap-x-2 gap-y-1">
          <span class="text-n-slate-11">{{ tile.note }}</span>
          <span
            v-if="tile.change !== null"
            class="font-medium tabular-nums"
            :class="deltaTone(tile.change, tile.lowerIsBetter)"
          >
            <bdi>{{ tile.change > 0 ? '+' : '' }}{{ tile.change }}%</bdi>
            {{ t('PERFORMANCE_REPORTS.KPI.VS_PREVIOUS') }}
          </span>
        </div>
      </div>
    </template>
    <template v-else>
      <div
        v-for="index in 4"
        :key="index"
        class="flex flex-col gap-3 p-5 bg-n-solid-2"
      >
        <span class="w-24 h-4 rounded bg-n-alpha-2 animate-loader-pulse" />
        <span class="w-20 h-8 rounded bg-n-alpha-2 animate-loader-pulse" />
        <span class="w-32 h-3 rounded bg-n-alpha-2 animate-loader-pulse" />
      </div>
    </template>
  </div>
</template>
