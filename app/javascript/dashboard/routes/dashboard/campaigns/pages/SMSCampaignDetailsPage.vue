<script setup>
// Custom (MyDesk): everything about one SMS campaign — its message, times, sender and every number with the
// provider's SMS id, request id and refusal reason. Refreshes on its own while the campaign is sending, and
// while the provider is being asked whether the sent numbers received the message.
import { computed, onActivated, onDeactivated, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useIntervalFn } from '@vueuse/core';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import CampaignsAPI from 'dashboard/api/campaigns';
import {
  smsEncoding,
  smsSegmentCount,
  SMS_ENCODINGS,
} from 'dashboard/helper/smsSegments';
import { isSmsCampaignInProgress } from 'dashboard/components-next/Campaigns/SMSCampaign/smsCampaignStatus';

import Breadcrumb from 'dashboard/components-next/breadcrumb/Breadcrumb.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import SMSCampaignStatusBadge from 'dashboard/components-next/Campaigns/SMSCampaign/SMSCampaignStatusBadge.vue';
import SMSCampaignRecipientsTable from 'dashboard/components-next/Campaigns/SMSCampaign/SMSCampaignRecipientsTable.vue';

const PER_PAGE = 50;
const REFRESH_INTERVAL_MS = 5000;
const STATUS_FILTERS = ['all', 'sent', 'failed', 'queued'];
const NO_VALUE = '—';

const { t, locale } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const campaigns = useMapGetter('campaigns/getAllCampaigns');
const campaignsUiFlags = useMapGetter('campaigns/getUIFlags');
const labels = useMapGetter('labels/getLabels');

const state = reactive({
  recipients: [],
  count: 0,
  status: 'all',
  page: 1,
  isFetching: true,
  hasError: false,
  deliverySyncRunning: false,
  deliveryCheckedAt: null,
  isStartingSync: false,
});
let requestId = 0;

const campaignId = computed(() => Number(route.params.campaignId));
const campaign = computed(() =>
  campaigns.value.find(record => Number(record.id) === campaignId.value)
);
const stats = computed(
  () =>
    campaign.value?.sms_stats ?? {
      total: 0,
      sent: 0,
      failed: 0,
      queued: 0,
      delivered: 0,
    }
);
const segments = computed(() => smsSegmentCount(campaign.value?.message));

const numberFormat = computed(() => new Intl.NumberFormat(locale.value));
const formatNumber = value => numberFormat.value.format(value ?? 0);
const dateFormat = computed(
  () =>
    new Intl.DateTimeFormat(locale.value, {
      dateStyle: 'medium',
      timeStyle: 'short',
    })
);
const formatDate = value => {
  if (!value) return NO_VALUE;
  const date =
    typeof value === 'number' ? new Date(value * 1000) : new Date(value);
  return dateFormat.value.format(date);
};

const breadcrumbItems = computed(() => [
  { label: t('CAMPAIGN.SMS.HEADER_TITLE'), routeName: 'campaigns_sms_index' },
  {
    label: campaign.value
      ? `#${campaign.value.id} · ${campaign.value.title}`
      : `#${campaignId.value}`,
  },
]);

const metricCards = computed(() => [
  {
    key: 'total',
    icon: 'i-lucide-users',
    color: 'text-n-blue-11',
    value: stats.value.total,
    label: t('CAMPAIGN.SMS.DETAILS.METRICS.TOTAL'),
  },
  {
    key: 'sent',
    icon: 'i-lucide-check-check',
    color: 'text-n-teal-11',
    value: stats.value.sent,
    label: t('CAMPAIGN.SMS.DETAILS.METRICS.SENT'),
  },
  {
    key: 'delivered',
    icon: 'i-lucide-smartphone',
    color: 'text-n-teal-11',
    value: stats.value.delivered ?? 0,
    label: t('CAMPAIGN.SMS.DETAILS.METRICS.DELIVERED'),
  },
  {
    key: 'failed',
    icon: 'i-lucide-circle-alert',
    color: 'text-n-ruby-11',
    value: stats.value.failed,
    label: t('CAMPAIGN.SMS.DETAILS.METRICS.FAILED'),
  },
  {
    key: 'queued',
    icon: 'i-lucide-clock-3',
    color: 'text-n-amber-11',
    value: stats.value.queued,
    label: t('CAMPAIGN.SMS.DETAILS.METRICS.QUEUED'),
  },
  {
    key: 'sms',
    icon: 'i-lucide-message-square-text',
    color: 'text-n-slate-11',
    value: stats.value.sent * segments.value,
    label: t('CAMPAIGN.SMS.DETAILS.METRICS.SMS_USED'),
  },
]);

const audienceLabels = computed(() => {
  const ids = (campaign.value?.audience ?? [])
    .filter(item => item.type === 'Label')
    .map(item => Number(item.id));
  return labels.value
    .filter(label => ids.includes(label.id))
    .map(label => label.title);
});

const detailRows = computed(() => {
  const record = campaign.value;
  if (!record) return [];
  return [
    {
      key: 'id',
      label: t('CAMPAIGN.SMS.DETAILS.INFO.ID'),
      value: `#${record.id}`,
    },
    {
      key: 'title',
      label: t('CAMPAIGN.SMS.DETAILS.INFO.TITLE'),
      value: record.title,
    },
    {
      key: 'inbox',
      label: t('CAMPAIGN.SMS.DETAILS.INFO.INBOX'),
      value: record.inbox?.name || NO_VALUE,
    },
    {
      key: 'sender',
      label: t('CAMPAIGN.SMS.DETAILS.INFO.SENDER'),
      value: record.sms_sender_name || record.inbox?.phone_number || NO_VALUE,
    },
    {
      key: 'source',
      label: t('CAMPAIGN.SMS.DETAILS.INFO.SOURCE'),
      value: audienceLabels.value.length
        ? t('CAMPAIGN.SMS.DETAILS.SOURCE.LABELS', {
            labels: audienceLabels.value.join(', '),
          })
        : t('CAMPAIGN.SMS.DETAILS.SOURCE.NUMBERS'),
    },
    {
      key: 'created',
      label: t('CAMPAIGN.SMS.DETAILS.INFO.CREATED_AT'),
      value: formatDate(record.created_at),
    },
    {
      key: 'scheduled',
      label: t('CAMPAIGN.SMS.DETAILS.INFO.SCHEDULED_AT'),
      value: formatDate(record.scheduled_at),
    },
    {
      key: 'started',
      label: t('CAMPAIGN.SMS.DETAILS.INFO.STARTED_AT'),
      value: formatDate(record.started_at),
    },
    {
      key: 'completed',
      label: t('CAMPAIGN.SMS.DETAILS.INFO.COMPLETED_AT'),
      value: formatDate(record.completed_at),
    },
  ];
});

const encodingLabel = computed(() =>
  smsEncoding(campaign.value?.message) === SMS_ENCODINGS.TEXT
    ? t('CAMPAIGN.SMS.FORM_PAGE.ENCODING.text')
    : t('CAMPAIGN.SMS.FORM_PAGE.ENCODING.unicode')
);

const filterLabels = computed(() => ({
  all: t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.FILTERS.ALL'),
  sent: t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.STATUS.SENT'),
  failed: t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.STATUS.FAILED'),
  queued: t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.STATUS.QUEUED'),
}));
const statusTabs = computed(() =>
  STATUS_FILTERS.map(key => ({
    key,
    label: filterLabels.value[key],
    count: key === 'all' ? stats.value.total : stats.value[key],
  }))
);
const activeTabIndex = computed(() => STATUS_FILTERS.indexOf(state.status));

const noDataMessage = computed(() => {
  if (state.hasError) return t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.ERROR');
  return state.status === 'all'
    ? t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.EMPTY')
    : t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.EMPTY_FILTER');
});

const fetchRecipients = async ({ showLoading = true } = {}) => {
  requestId += 1;
  const currentRequest = requestId;
  const id = campaignId.value;
  if (showLoading) state.isFetching = true;

  try {
    const { data } = await CampaignsAPI.smsRecipients(id, {
      page: state.page,
      status: state.status === 'all' ? undefined : state.status,
    });
    if (currentRequest !== requestId) return;
    state.recipients = data.payload;
    state.count = data.meta.count;
    state.deliverySyncRunning = data.meta.delivery_sync_running;
    state.deliveryCheckedAt = data.meta.delivery_checked_at;
    state.hasError = false;
  } catch {
    if (currentRequest !== requestId) return;
    state.recipients = [];
    state.count = 0;
    state.hasError = true;
  } finally {
    if (currentRequest === requestId) state.isFetching = false;
  }
};

const isInProgress = computed(
  () => !!campaign.value && isSmsCampaignInProgress(campaign.value)
);
const { pause, resume } = useIntervalFn(
  () => {
    store.dispatch('campaigns/get');
    fetchRecipients({ showLoading: false });
  },
  REFRESH_INTERVAL_MS,
  { immediate: false }
);
let isPageActive = false;
const syncRefresh = () =>
  isPageActive && (isInProgress.value || state.deliverySyncRunning)
    ? resume()
    : pause();
watch(isInProgress, syncRefresh);
watch(
  () => state.deliverySyncRunning,
  (running, wasRunning) => {
    syncRefresh();
    // The delivered count lives on the campaign, so reload it once the check ends
    if (wasRunning && !running) {
      store.dispatch('campaigns/get');
      useAlert(t('CAMPAIGN.SMS.DETAILS.DELIVERY.DONE'));
    }
  }
);

const canCheckDelivery = computed(() => stats.value.sent > 0);
const checkDelivery = async () => {
  state.isStartingSync = true;
  try {
    const { data } = await CampaignsAPI.syncSmsDelivery(campaignId.value);
    state.deliverySyncRunning = data.delivery_sync_running;
    if (!data.delivery_sync_running) {
      useAlert(t('CAMPAIGN.SMS.DETAILS.DELIVERY.UP_TO_DATE'));
    }
  } catch {
    useAlert(t('CAMPAIGN.SMS.DETAILS.DELIVERY.ERROR'));
  } finally {
    state.isStartingSync = false;
  }
};

// The campaigns route keeps pages alive, so each visit reloads the campaign shown in the URL
const loadPage = () => {
  state.status = 'all';
  state.page = 1;
  state.recipients = [];
  if (!campaign.value) store.dispatch('campaigns/get');
  fetchRecipients();
};

watch(campaignId, id => {
  if (isPageActive && Number.isFinite(id)) loadPage();
});
watch(
  () => [state.status, state.page],
  () => fetchRecipients()
);

onActivated(() => {
  isPageActive = true;
  loadPage();
  syncRefresh();
});
onDeactivated(() => {
  isPageActive = false;
  pause();
});

const handleTabChange = tab => {
  if (tab.key === state.status) return;
  state.status = tab.key;
  state.page = 1;
};
</script>

<template>
  <div class="w-full h-full px-6 overflow-y-auto bg-n-surface-1">
    <header
      class="flex flex-wrap items-center justify-between w-full max-w-6xl gap-3 py-5 mx-auto"
    >
      <Breadcrumb
        :items="breadcrumbItems"
        @click="({ routeName }) => router.push({ name: routeName })"
      />
      <SMSCampaignStatusBadge v-if="campaign" :campaign="campaign" />
    </header>

    <div
      v-if="!campaign"
      class="flex items-center justify-center py-20 text-n-slate-11"
    >
      <Spinner v-if="campaignsUiFlags.isFetching" />
      <span v-else>{{ t('CAMPAIGN.SMS.DETAILS.NOT_FOUND') }}</span>
    </div>

    <div v-else class="flex flex-col w-full max-w-6xl gap-6 pb-10 mx-auto">
      <div class="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
        <div
          v-for="card in metricCards"
          :key="card.key"
          class="flex items-center gap-3 p-4 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
        >
          <span
            class="flex items-center justify-center rounded-lg size-9 shrink-0 bg-n-alpha-2"
            :class="card.color"
          >
            <span class="size-4" :class="card.icon" />
          </span>
          <div class="flex flex-col min-w-0">
            <span class="text-lg font-semibold tabular-nums text-n-slate-12">
              {{ formatNumber(card.value) }}
            </span>
            <span class="text-xs truncate text-n-slate-11">
              {{ card.label }}
            </span>
          </div>
        </div>
      </div>

      <div
        class="grid items-start grid-cols-1 gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.2fr)]"
      >
        <section
          class="flex flex-col gap-4 p-6 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
        >
          <h2 class="text-heading-2 text-n-slate-12">
            {{ t('CAMPAIGN.SMS.DETAILS.MESSAGE.TITLE') }}
          </h2>
          <div class="flex flex-col gap-3 p-4 rounded-2xl bg-n-alpha-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ campaign.sms_sender_name || campaign.inbox?.phone_number }}
            </span>
            <p
              dir="auto"
              class="px-3 py-2 text-sm whitespace-pre-wrap break-words rounded-2xl rounded-ss-sm bg-n-solid-1 text-n-slate-12"
            >
              {{ campaign.message }}
            </p>
          </div>
          <p class="text-sm text-n-slate-11">
            {{
              t('CAMPAIGN.SMS.FORM_PAGE.SEGMENTS', {
                count: segments,
                encoding: encodingLabel,
              })
            }}
          </p>
        </section>

        <section
          class="flex flex-col gap-4 p-6 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
        >
          <h2 class="text-heading-2 text-n-slate-12">
            {{ t('CAMPAIGN.SMS.DETAILS.INFO.SECTION') }}
          </h2>
          <dl
            class="grid grid-cols-[auto_minmax(0,1fr)] gap-x-6 gap-y-2.5 text-sm"
          >
            <template v-for="row in detailRows" :key="row.key">
              <dt class="text-n-slate-11">{{ row.label }}</dt>
              <dd dir="auto" class="break-words text-n-slate-12 text-start">
                {{ row.value }}
              </dd>
            </template>
          </dl>
        </section>
      </div>

      <section
        class="flex flex-col gap-4 p-6 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
      >
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div class="flex flex-col flex-1 gap-1 min-w-64">
            <h2 class="text-heading-2 text-n-slate-12">
              {{ t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.TITLE') }}
            </h2>
            <p class="text-sm text-n-slate-11">
              {{ t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.HINT') }}
            </p>
          </div>
          <div class="flex flex-col items-end gap-1">
            <Button
              size="sm"
              icon="i-lucide-refresh-cw"
              :label="
                state.deliverySyncRunning
                  ? t('CAMPAIGN.SMS.DETAILS.DELIVERY.CHECKING')
                  : t('CAMPAIGN.SMS.DETAILS.DELIVERY.CHECK')
              "
              :is-loading="state.isStartingSync || state.deliverySyncRunning"
              :disabled="!canCheckDelivery || state.deliverySyncRunning"
              @click="checkDelivery"
            />
            <span class="text-xs text-n-slate-11">
              {{
                state.deliveryCheckedAt
                  ? t('CAMPAIGN.SMS.DETAILS.DELIVERY.LAST_CHECKED', {
                      time: formatDate(state.deliveryCheckedAt),
                    })
                  : t('CAMPAIGN.SMS.DETAILS.DELIVERY.NEVER_CHECKED')
              }}
            </span>
          </div>
        </div>
        <TabBar
          :tabs="statusTabs"
          :initial-active-tab="activeTabIndex"
          @tab-changed="handleTabChange"
        />
        <div
          v-if="state.isFetching && !state.recipients.length"
          class="flex items-center justify-center py-10 text-n-slate-11"
        >
          <Spinner />
        </div>
        <SMSCampaignRecipientsTable
          v-else
          :recipients="state.recipients"
          :loading="state.isFetching"
          :no-data-message="noDataMessage"
        />
        <PaginationFooter
          v-if="state.count > PER_PAGE"
          :current-page="state.page"
          :total-items="state.count"
          :items-per-page="PER_PAGE"
          current-page-info="CAMPAIGN.SMS.DETAILS.RECIPIENTS.PAGE_INFO"
          class="!bg-transparent !px-0 before:hidden"
          @update:current-page="page => (state.page = page)"
        />
      </section>
    </div>
  </div>
</template>
