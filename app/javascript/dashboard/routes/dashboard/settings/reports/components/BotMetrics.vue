<script setup>
import { computed, ref, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import ReportMetricCard from './ReportMetricCard.vue';
import ReportsAPI from 'dashboard/api/reports';
import { formatNumber, NO_VALUE } from 'dashboard/helper/reportFormatters';

const props = defineProps({
  filters: {
    type: Object,
    required: true,
  },
});

const { locale } = useI18n();
const route = useRoute();

const metrics = ref(null);

// Custom (MyDesk): with no bot conversations a rate is unknown, not 0%; say so instead of showing failure
const hasActivity = computed(
  () => (metrics.value?.conversation_count ?? 0) > 0
);

const formatToPercent = value =>
  hasActivity.value ? `${formatNumber(value, locale?.value)}%` : NO_VALUE;

const conversationCount = computed(() =>
  formatNumber(metrics.value?.conversation_count, locale?.value)
);
const messageCount = computed(() =>
  formatNumber(metrics.value?.message_count, locale?.value)
);

const botSettingsPath = computed(
  () => `/app/accounts/${route.params.accountId}/settings/agent-bots`
);

const fetchMetrics = () => {
  if (!props.filters.to || !props.filters.from) {
    return;
  }
  ReportsAPI.getBotMetrics(props.filters).then(response => {
    metrics.value = response.data;
  });
};

watch(() => props.filters, fetchMetrics, { deep: true });

onMounted(fetchMetrics);
</script>

<template>
  <div
    class="flex flex-col gap-4 mx-0 outline-1 outline -outline-offset-1 outline-n-weak rounded-xl bg-n-solid-2 px-6 py-5"
  >
    <div class="flex flex-wrap">
      <ReportMetricCard
        :label="$t('BOT_REPORTS.METRIC.TOTAL_CONVERSATIONS.LABEL')"
        :info-text="$t('BOT_REPORTS.METRIC.TOTAL_CONVERSATIONS.TOOLTIP')"
        :value="conversationCount"
        class="flex-1"
      />
      <ReportMetricCard
        :label="$t('BOT_REPORTS.METRIC.TOTAL_RESPONSES.LABEL')"
        :info-text="$t('BOT_REPORTS.METRIC.TOTAL_RESPONSES.TOOLTIP')"
        :value="messageCount"
        class="flex-1"
      />
      <ReportMetricCard
        :label="$t('BOT_REPORTS.METRIC.RESOLUTION_RATE.LABEL')"
        :info-text="$t('BOT_REPORTS.METRIC.RESOLUTION_RATE.TOOLTIP')"
        :value="formatToPercent(metrics?.resolution_rate)"
        class="flex-1"
      />
      <ReportMetricCard
        :label="$t('BOT_REPORTS.METRIC.HANDOFF_RATE.LABEL')"
        :info-text="$t('BOT_REPORTS.METRIC.HANDOFF_RATE.TOOLTIP')"
        :value="formatToPercent(metrics?.handoff_rate)"
        class="flex-1"
      />
    </div>
    <p
      v-if="metrics && !hasActivity"
      class="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-n-slate-11"
    >
      <span class="i-lucide-bot size-4 shrink-0" aria-hidden="true" />
      <span>{{ $t('BOT_REPORTS.NO_ACTIVITY') }}</span>
      <router-link
        :to="botSettingsPath"
        class="font-medium text-n-blue-11 hover:underline"
      >
        {{ $t('BOT_REPORTS.CONNECT_BOT') }}
      </router-link>
    </p>
  </div>
</template>
