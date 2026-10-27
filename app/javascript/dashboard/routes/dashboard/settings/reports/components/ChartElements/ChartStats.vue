<script setup>
import { useReportMetrics } from 'dashboard/composables/useReportMetrics';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { STATUS } from 'dashboard/store/constants';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  metric: {
    type: Object,
    default: () => ({}),
  },
  accountSummaryKey: {
    type: String,
    default: 'getAccountSummary',
  },
  summaryFetchingKey: {
    type: String,
    default: 'getAccountSummaryFetchingStatus',
  },
});

const { t } = useI18n();

const { calculateTrend, displayMetric, isAverageMetricType, fetchingStatus } =
  useReportMetrics(props.accountSummaryKey, props.summaryFetchingKey);

const trendColor = (value, key) => {
  // Custom (MyDesk): 11-step text colors keep the trend readable (DESIGN.md signal inks)
  if (isAverageMetricType(key)) {
    return value > 0
      ? 'border-n-ruby-9 text-n-ruby-11'
      : 'border-n-teal-9 text-n-teal-11';
  }
  return value < 0
    ? 'border-n-ruby-9 text-n-ruby-11'
    : 'border-n-teal-9 text-n-teal-11';
};
</script>

<template>
  <div class="text-n-slate-11">
    <span class="text-sm">
      {{ metric.NAME }}
    </span>
    <div class="flex items-end text-n-slate-12">
      <div v-if="fetchingStatus === STATUS.FETCHING">
        <Spinner />
      </div>
      <div
        v-else-if="fetchingStatus === STATUS.FAILED"
        class="text-n-ruby-10 text-sm"
      >
        {{ t('REPORT.SUMMARY_FETCHING_FAILED') }}
      </div>
      <bdi
        v-else-if="fetchingStatus === STATUS.FINISHED"
        class="text-xl font-semibold tabular-nums"
      >
        {{ displayMetric(metric.KEY) }}
      </bdi>
      <div
        v-if="metric.trend && fetchingStatus === STATUS.FINISHED"
        class="text-xs ms-3 flex items-center gap-1 mb-0.5"
        :title="t('REPORT.TREND_VS_PREVIOUS')"
      >
        <div
          v-if="metric.trend < 0"
          class="h-0 w-0 border-x-4 medium border-x-transparent border-t-[8px]"
          :class="trendColor(metric.trend, metric.KEY)"
          aria-hidden="true"
        />
        <div
          v-else
          class="h-0 w-0 border-x-4 medium border-x-transparent border-b-[8px]"
          :class="trendColor(metric.trend, metric.KEY)"
          aria-hidden="true"
        />
        <bdi
          class="font-medium tabular-nums"
          :class="trendColor(metric.trend, metric.KEY)"
        >
          {{ calculateTrend(metric.KEY) }}%
        </bdi>
        <span class="sr-only">
          {{
            metric.trend < 0
              ? t('REPORT.TREND_DOWN_SR')
              : t('REPORT.TREND_UP_SR')
          }}
        </span>
      </div>
    </div>
  </div>
</template>
