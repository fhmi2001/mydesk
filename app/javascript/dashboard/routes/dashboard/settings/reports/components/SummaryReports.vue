<script setup>
import OverviewReportFilters from './OverviewReportFilters.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import {
  formatDuration,
  formatNumber,
  NO_VALUE,
} from 'dashboard/helper/reportFormatters';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Table from 'dashboard/components/table/Table.vue';
import { generateFileName } from 'dashboard/helper/downloadHelper';
import {
  useVueTable,
  createColumnHelper,
  getCoreRowModel,
} from '@tanstack/vue-table';
import { computed, onMounted, ref, h, watch } from 'vue';

const props = defineProps({
  type: {
    type: String,
    default: 'account',
  },
  getterKey: {
    type: String,
    default: '',
  },
  actionKey: {
    type: String,
    default: '',
  },
  summaryKey: {
    type: String,
    default: '',
  },
  fetchItemsKey: {
    type: String,
    required: true,
  },
  // Custom (MyDesk): when the page owns the date / business-hours filter (performance report),
  // the table follows it instead of rendering its own
  filters: {
    type: Object,
    default: null,
  },
});

const store = useStore();

const from = ref(0);
const to = ref(0);
const businessHours = ref(false);
import { useI18n } from 'vue-i18n';
import SummaryReportLink from './SummaryReportLink.vue';

const flagMap = {
  agent: 'isFetchingAgentSummaryReports',
  inbox: 'isFetchingInboxSummaryReports',
  team: 'isFetchingTeamSummaryReports',
  label: 'isFetchingLabelSummaryReports',
};

const uiFlags = useMapGetter('summaryReports/getUIFlags');
const isLoading = computed(() => uiFlags.value[flagMap[props.type]] ?? false);

const rowItems = useMapGetter([props.getterKey]) || [];
const reportMetrics = useMapGetter([props.summaryKey]) || [];

const getMetrics = id =>
  reportMetrics.value.find(metrics => metrics.id === Number(id)) || {};
const columnHelper = createColumnHelper();
const { t, locale } = useI18n();

// Custom (MyDesk): figures line up (tabular) and stay in their own direction inside Arabic text
const defaulSpanRender = cellProps =>
  h(
    'bdi',
    {
      class: [
        'tabular-nums',
        cellProps.getValue() === NO_VALUE
          ? 'text-n-slate-10'
          : 'text-n-slate-12',
      ],
    },
    cellProps.getValue()
  );

const columns = computed(() => [
  columnHelper.accessor('name', {
    header: t(`SUMMARY_REPORTS.${props.type.toUpperCase()}`),
    width: 300,
    cell: cellProps => h(SummaryReportLink, cellProps),
  }),
  columnHelper.accessor('conversationsCount', {
    header: t('SUMMARY_REPORTS.CONVERSATIONS'),
    width: 200,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('avgFirstResponseTime', {
    header: t('SUMMARY_REPORTS.AVG_FIRST_RESPONSE_TIME'),
    width: 200,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('avgResolutionTime', {
    header: t('SUMMARY_REPORTS.AVG_RESOLUTION_TIME'),
    width: 200,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('avgReplyTime', {
    header: t('SUMMARY_REPORTS.AVG_REPLY_TIME'),
    width: 200,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('resolutionsCount', {
    header: t('SUMMARY_REPORTS.RESOLUTION_COUNT'),
    width: 200,
    cell: defaulSpanRender,
  }),
]);

// Custom (MyDesk): Arabic durations, and one sign («—») for "nothing measured" across all reports
const renderAvgTime = value =>
  value ? formatDuration(value, locale?.value) : NO_VALUE;

const renderCount = value =>
  value ? formatNumber(value, locale?.value) : NO_VALUE;

// Custom (MyDesk): an empty table says what is missing instead of showing bare headers
const emptyMessage = computed(
  () =>
    ({
      agent: t('SUMMARY_REPORTS.EMPTY.AGENT'),
      inbox: t('SUMMARY_REPORTS.EMPTY.INBOX'),
      label: t('SUMMARY_REPORTS.EMPTY.LABEL'),
      team: t('SUMMARY_REPORTS.EMPTY.TEAM'),
    })[props.type]
);

const tableData = computed(() =>
  rowItems.value.map(row => {
    const rowMetrics = getMetrics(row.id);
    const {
      conversationsCount,
      avgFirstResponseTime,
      avgResolutionTime,
      avgReplyTime,
      resolvedConversationsCount,
    } = rowMetrics;
    return {
      id: row.id,
      // we fallback on title, label for instance does not have a name property
      name: row.name ?? row.title,
      type: props.type,
      conversationsCount: renderCount(conversationsCount),
      avgFirstResponseTime: renderAvgTime(avgFirstResponseTime),
      avgReplyTime: renderAvgTime(avgReplyTime),
      avgResolutionTime: renderAvgTime(avgResolutionTime),
      resolutionsCount: renderCount(resolvedConversationsCount),
    };
  })
);

const fetchReportsWithRetry = async () => {
  const params = {
    since: from.value,
    until: to.value,
    businessHours: businessHours.value,
  };
  try {
    await store.dispatch(props.actionKey, params);
  } catch {
    try {
      await store.dispatch(props.actionKey, params);
    } catch {
      useAlert(t('REPORT.SUMMARY_FETCHING_FAILED'));
    }
  }
};

const fetchAllData = () => {
  store.dispatch(props.fetchItemsKey);
  fetchReportsWithRetry();
};

const onFilterChange = updatedFilter => {
  from.value = updatedFilter.from;
  to.value = updatedFilter.to;
  businessHours.value = updatedFilter.businessHours;
  fetchAllData();
};

onMounted(() => {
  if (!props.filters) fetchAllData();
});

watch(
  () => props.filters,
  value => {
    if (value?.from && value?.to) onFilterChange(value);
  },
  { immediate: true, deep: true }
);

const table = useVueTable({
  get data() {
    return tableData.value;
  },
  get columns() {
    return columns.value;
  },
  enableSorting: false,
  getCoreRowModel: getCoreRowModel(),
});

// downloadReports method is not used in this component
// but it is exposed to be used in the parent component
const downloadReports = () => {
  const dispatchMethods = {
    agent: 'downloadAgentReports',
    label: 'downloadLabelReports',
    inbox: 'downloadInboxReports',
    team: 'downloadTeamReports',
  };
  if (dispatchMethods[props.type]) {
    const fileName = generateFileName({
      type: props.type,
      to: to.value,
      businessHours: businessHours.value,
    });
    const params = {
      from: from.value,
      to: to.value,
      fileName,
      businessHours: businessHours.value,
    };
    store.dispatch(dispatchMethods[props.type], params);
  }
};

defineExpose({ downloadReports });
</script>

<template>
  <OverviewReportFilters
    v-if="!filters"
    :disabled="isLoading"
    @filter-change="onFilterChange"
  />
  <div
    class="relative flex-1 overflow-auto px-2 py-2 mt-5 outline-1 outline -outline-offset-1 outline-n-weak rounded-xl bg-n-solid-2"
  >
    <Table :table="table" />
    <p
      v-if="!isLoading && !tableData.length"
      class="px-4 py-10 text-sm text-center text-n-slate-11"
    >
      {{ emptyMessage }}
    </p>
    <Transition
      enter-active-class="transition-opacity duration-300 ease-out"
      leave-active-class="transition-opacity duration-200 ease-in"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="isLoading"
        class="absolute inset-0 flex justify-center pt-[12.5rem] bg-n-solid-1/70 rounded-xl pointer-events-none"
      >
        <Spinner :size="32" class="text-n-brand" />
      </div>
    </Transition>
  </div>
</template>
