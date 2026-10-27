<script setup>
// Custom (MyDesk): one performance report instead of four near-identical pages (employees, inboxes,
// labels, teams). One date / business-hours filter drives the headline numbers, the channel breakdown
// and the table; a switch chooses what the table is broken down by.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import ReportsAPI from 'dashboard/api/reports';

import ReportHeader from './components/ReportHeader.vue';
import OverviewReportFilters from './components/OverviewReportFilters.vue';
import SummaryReports from './components/SummaryReports.vue';
import PerformanceKpis from './components/performance/PerformanceKpis.vue';
import PerformanceChannels from './components/performance/PerformanceChannels.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const VIEWS = {
  agent: {
    actionKey: 'summaryReports/fetchAgentSummaryReports',
    getterKey: 'agents/getAgents',
    fetchItemsKey: 'agents/get',
    summaryKey: 'summaryReports/getAgentSummaryReports',
  },
  inbox: {
    actionKey: 'summaryReports/fetchInboxSummaryReports',
    getterKey: 'inboxes/getInboxes',
    fetchItemsKey: 'inboxes/get',
    summaryKey: 'summaryReports/getInboxSummaryReports',
  },
  label: {
    actionKey: 'summaryReports/fetchLabelSummaryReports',
    getterKey: 'labels/getLabels',
    fetchItemsKey: 'labels/get',
    summaryKey: 'summaryReports/getLabelSummaryReports',
  },
  team: {
    actionKey: 'summaryReports/fetchTeamSummaryReports',
    getterKey: 'teams/getTeams',
    fetchItemsKey: 'teams/get',
    summaryKey: 'summaryReports/getTeamSummaryReports',
  },
};
const VIEW_KEYS = Object.keys(VIEWS);

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const filters = ref(null);
const performance = ref(null);
const isLoadingPerformance = ref(false);
const summaryRef = ref(null);
let requestId = 0;

const activeView = computed(() =>
  VIEW_KEYS.includes(route.query.view) ? route.query.view : 'agent'
);
const view = computed(() => VIEWS[activeView.value]);

const tabs = computed(() => [
  { key: 'agent', label: t('PERFORMANCE_REPORTS.VIEWS.AGENT') },
  { key: 'inbox', label: t('PERFORMANCE_REPORTS.VIEWS.INBOX') },
  { key: 'label', label: t('PERFORMANCE_REPORTS.VIEWS.LABEL') },
  { key: 'team', label: t('PERFORMANCE_REPORTS.VIEWS.TEAM') },
]);
const activeTabIndex = computed(() => VIEW_KEYS.indexOf(activeView.value));

const fetchPerformance = async () => {
  requestId += 1;
  const current = requestId;
  isLoadingPerformance.value = true;
  try {
    const { data } = await ReportsAPI.getPerformance(filters.value);
    if (current === requestId) performance.value = data;
  } catch {
    if (current === requestId) useAlert(t('REPORT.SUMMARY_FETCHING_FAILED'));
  } finally {
    if (current === requestId) isLoadingPerformance.value = false;
  }
};

const onFilterChange = value => {
  filters.value = { ...value };
  fetchPerformance();
};

// The view is kept in the URL (with the filter params) so links and refreshes keep it
const onTabChange = tab => {
  if (tab.key === activeView.value) return;
  router.replace({ query: { ...route.query, view: tab.key } });
};

const downloadTable = () => summaryRef.value?.downloadReports();
</script>

<template>
  <ReportHeader
    :header-title="t('PERFORMANCE_REPORTS.HEADER')"
    :header-description="t('PERFORMANCE_REPORTS.DESCRIPTION')"
  >
    <Button
      variant="faded"
      color="slate"
      size="sm"
      icon="i-lucide-download"
      :label="t('PERFORMANCE_REPORTS.DOWNLOAD')"
      @click="downloadTable"
    />
  </ReportHeader>

  <div class="flex flex-col gap-6 pb-8">
    <OverviewReportFilters
      :disabled="isLoadingPerformance"
      @filter-change="onFilterChange"
    />

    <PerformanceKpis :data="performance" :is-loading="isLoadingPerformance" />

    <PerformanceChannels
      :channels="performance?.channels ?? []"
      :is-loading="isLoadingPerformance"
    />

    <section class="flex flex-col gap-2">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <h2 class="text-heading-2 text-n-slate-12">
          {{ t('PERFORMANCE_REPORTS.BREAKDOWN') }}
        </h2>
        <TabBar
          :tabs="tabs"
          :initial-active-tab="activeTabIndex"
          @tab-changed="onTabChange"
        />
      </div>
      <SummaryReports
        :key="activeView"
        ref="summaryRef"
        :type="activeView"
        :action-key="view.actionKey"
        :getter-key="view.getterKey"
        :fetch-items-key="view.fetchItemsKey"
        :summary-key="view.summaryKey"
        :filters="filters"
      />
    </section>
  </div>
</template>
