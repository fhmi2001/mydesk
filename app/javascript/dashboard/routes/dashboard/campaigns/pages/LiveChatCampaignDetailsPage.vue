<script setup>
// Custom (MyDesk): everything about one live chat campaign — its message, where and when it appears,
// and the conversations it started with website visitors.
import { computed, onActivated, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import CampaignsAPI from 'dashboard/api/campaigns';
import { conversationUrl, frontendURL } from 'dashboard/helper/URLHelper';

import Breadcrumb from 'dashboard/components-next/breadcrumb/Breadcrumb.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import BaseTable from 'dashboard/components-next/table/BaseTable.vue';
import BaseTableRow from 'dashboard/components-next/table/BaseTableRow.vue';
import BaseTableCell from 'dashboard/components-next/table/BaseTableCell.vue';
import LiveChatCampaignStatusBadge from 'dashboard/components-next/Campaigns/LiveChatCampaign/LiveChatCampaignStatusBadge.vue';

const PER_PAGE = 25;
const NO_VALUE = '—';
const SECTION_CLASSES =
  'flex flex-col gap-4 p-6 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak';

const { t, locale } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const campaigns = useMapGetter('campaigns/getAllCampaigns');
const uiFlags = useMapGetter('campaigns/getUIFlags');

const state = reactive({
  conversations: [],
  count: 0,
  page: 1,
  isFetching: true,
  hasError: false,
});
let requestId = 0;

const campaignId = computed(() => Number(route.params.campaignId));
const campaign = computed(() =>
  campaigns.value.find(record => Number(record.id) === campaignId.value)
);

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

const senderName = computed(
  () =>
    campaign.value?.sender?.name ||
    t('CAMPAIGN.LIVE_CHAT.CARD.CAMPAIGN_DETAILS.BOT')
);
const delay = computed(() => campaign.value?.trigger_rules?.time_on_page ?? 0);
const hoursLabel = computed(() =>
  campaign.value?.trigger_only_during_business_hours
    ? t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.PREVIEW.BUSINESS_HOURS')
    : t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.PREVIEW.ANY_TIME')
);

const breadcrumbItems = computed(() => [
  {
    label: t('CAMPAIGN.LIVE_CHAT.HEADER_TITLE'),
    routeName: 'campaigns_livechat_index',
  },
  {
    label: campaign.value
      ? `#${campaign.value.id} · ${campaign.value.title}`
      : `#${campaignId.value}`,
  },
]);

const metricCards = computed(() => [
  {
    key: 'conversations',
    icon: 'i-lucide-messages-square',
    color: 'text-n-blue-11',
    value: formatNumber(campaign.value?.conversations_count),
    label: t('CAMPAIGN.LIVE_CHAT.DETAILS.METRICS.CONVERSATIONS'),
  },
  {
    key: 'last',
    icon: 'i-lucide-clock-3',
    color: 'text-n-teal-11',
    value: formatDate(campaign.value?.last_conversation_at),
    label: t('CAMPAIGN.LIVE_CHAT.DETAILS.METRICS.LAST_CONVERSATION'),
  },
  {
    key: 'delay',
    icon: 'i-lucide-timer',
    color: 'text-n-amber-11',
    value: t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.PREVIEW.SECONDS', {
      count: delay.value,
    }),
    label: t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.PREVIEW.DELAY'),
  },
  {
    key: 'hours',
    icon: 'i-lucide-calendar-clock',
    color: 'text-n-slate-11',
    value: hoursLabel.value,
    label: t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.PREVIEW.HOURS'),
  },
]);

const detailRows = computed(() => {
  const record = campaign.value;
  if (!record) return [];
  return [
    {
      key: 'id',
      label: t('CAMPAIGN.LIVE_CHAT.DETAILS.INFO.ID'),
      value: `#${record.id}`,
    },
    {
      key: 'title',
      label: t('CAMPAIGN.LIVE_CHAT.DETAILS.INFO.TITLE'),
      value: record.title,
    },
    {
      key: 'inbox',
      label: t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.INBOX'),
      value: record.inbox?.name || NO_VALUE,
    },
    {
      key: 'sender',
      label: t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.SENT_BY.LABEL'),
      value: senderName.value,
    },
    {
      key: 'url',
      label: t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.END_POINT.LABEL'),
      value: record.trigger_rules?.url || NO_VALUE,
      ltr: true,
    },
    {
      key: 'created',
      label: t('CAMPAIGN.LIVE_CHAT.DETAILS.INFO.CREATED_AT'),
      value: formatDate(record.created_at),
    },
    {
      key: 'updated',
      label: t('CAMPAIGN.LIVE_CHAT.DETAILS.INFO.UPDATED_AT'),
      value: formatDate(record.updated_at),
    },
  ];
});

const conversationStatusLabels = computed(() => ({
  open: t('CAMPAIGN.LIVE_CHAT.DETAILS.CONVERSATIONS.STATUS.OPEN'),
  resolved: t('CAMPAIGN.LIVE_CHAT.DETAILS.CONVERSATIONS.STATUS.RESOLVED'),
  pending: t('CAMPAIGN.LIVE_CHAT.DETAILS.CONVERSATIONS.STATUS.PENDING'),
  snoozed: t('CAMPAIGN.LIVE_CHAT.DETAILS.CONVERSATIONS.STATUS.SNOOZED'),
}));
const CONVERSATION_STATUS_STYLES = {
  open: 'bg-n-blue-3 text-n-blue-11',
  resolved: 'bg-n-teal-3 text-n-teal-11',
  pending: 'bg-n-amber-3 text-n-amber-11',
  snoozed: 'bg-n-alpha-2 text-n-slate-11',
};

const conversationHeaders = computed(() => [
  t('CAMPAIGN.LIVE_CHAT.DETAILS.CONVERSATIONS.HEADERS.ID'),
  t('CAMPAIGN.LIVE_CHAT.DETAILS.CONVERSATIONS.HEADERS.CONTACT'),
  t('CAMPAIGN.LIVE_CHAT.DETAILS.CONVERSATIONS.HEADERS.STATUS'),
  t('CAMPAIGN.LIVE_CHAT.DETAILS.CONVERSATIONS.HEADERS.ASSIGNEE'),
  t('CAMPAIGN.LIVE_CHAT.DETAILS.CONVERSATIONS.HEADERS.STARTED_AT'),
]);

const conversationLink = id =>
  frontendURL(conversationUrl({ accountId: route.params.accountId, id }));

const fetchConversations = async () => {
  requestId += 1;
  const currentRequest = requestId;
  state.isFetching = true;
  try {
    const { data } = await CampaignsAPI.conversations(campaignId.value, {
      page: state.page,
    });
    if (currentRequest !== requestId) return;
    state.conversations = data.payload;
    state.count = data.meta.count;
    state.hasError = false;
  } catch {
    if (currentRequest !== requestId) return;
    state.conversations = [];
    state.count = 0;
    state.hasError = true;
  } finally {
    if (currentRequest === requestId) state.isFetching = false;
  }
};

// The campaigns route keeps pages alive, so each visit reloads the campaign shown in the URL
let isPageActive = false;
const loadPage = () => {
  state.page = 1;
  state.conversations = [];
  // Refresh the campaign too, so its conversation count is current
  store.dispatch('campaigns/get');
  fetchConversations();
};
onActivated(() => {
  isPageActive = true;
  loadPage();
});
watch(campaignId, id => {
  if (isPageActive && Number.isFinite(id)) loadPage();
});
watch(
  () => state.page,
  () => fetchConversations()
);

const toggleEnabled = async () => {
  const enabled = !campaign.value.enabled;
  try {
    await store.dispatch('campaigns/update', {
      id: campaign.value.id,
      enabled,
    });
    useAlert(
      enabled
        ? t('CAMPAIGN.LIVE_CHAT.DETAILS.ENABLED_MESSAGE')
        : t('CAMPAIGN.LIVE_CHAT.DETAILS.DISABLED_MESSAGE')
    );
  } catch {
    useAlert(t('CAMPAIGN.LIVE_CHAT.EDIT.FORM.API.ERROR_MESSAGE'));
  }
};

const goTo = name =>
  router.push({ name, params: { campaignId: route.params.campaignId } });
</script>

<template>
  <div class="w-full h-full px-6 overflow-y-auto bg-n-surface-1">
    <header
      class="flex flex-wrap items-center justify-between w-full max-w-6xl gap-3 py-5 mx-auto"
    >
      <div class="flex flex-wrap items-center gap-3">
        <Breadcrumb
          :items="breadcrumbItems"
          @click="({ routeName }) => goTo(routeName)"
        />
        <LiveChatCampaignStatusBadge
          v-if="campaign"
          :enabled="campaign.enabled"
        />
      </div>
      <div v-if="campaign" class="flex items-center gap-2">
        <Button
          variant="faded"
          color="slate"
          size="sm"
          :icon="campaign.enabled ? 'i-lucide-pause' : 'i-lucide-play'"
          :label="
            campaign.enabled
              ? t('CAMPAIGN.LIVE_CHAT.DETAILS.DISABLE')
              : t('CAMPAIGN.LIVE_CHAT.DETAILS.ENABLE')
          "
          :is-loading="uiFlags.isUpdating"
          @click="toggleEnabled"
        />
        <Button
          size="sm"
          icon="i-lucide-pencil"
          :label="t('CAMPAIGN.LIVE_CHAT.TABLE.EDIT')"
          @click="goTo('campaigns_livechat_edit')"
        />
      </div>
    </header>

    <div
      v-if="!campaign"
      class="flex items-center justify-center py-20 text-n-slate-11"
    >
      <Spinner v-if="uiFlags.isFetching" />
      <span v-else>{{ t('CAMPAIGN.LIVE_CHAT.DETAILS.NOT_FOUND') }}</span>
    </div>

    <div v-else class="flex flex-col w-full max-w-6xl gap-6 pb-10 mx-auto">
      <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
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
            <span
              class="text-base font-semibold truncate tabular-nums text-n-slate-12"
            >
              {{ card.value }}
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
        <section :class="SECTION_CLASSES">
          <h2 class="text-heading-2 text-n-slate-12">
            {{ t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.MESSAGE.LABEL') }}
          </h2>
          <div class="flex flex-col gap-2 p-4 rounded-2xl bg-n-alpha-2">
            <div class="flex items-center gap-2">
              <span
                class="flex items-center justify-center text-white rounded-full size-8 bg-n-brand"
              >
                <span class="i-lucide-message-circle size-4" />
              </span>
              <span class="text-sm font-medium truncate text-n-slate-12">
                {{ senderName }}
              </span>
            </div>
            <p
              dir="auto"
              class="px-3 py-2 text-sm whitespace-pre-wrap break-words rounded-2xl rounded-ss-sm bg-n-solid-1 text-n-slate-12"
            >
              {{ campaign.message }}
            </p>
          </div>
          <p class="text-sm text-n-slate-11">
            {{
              t('CAMPAIGN.LIVE_CHAT.DETAILS.WHEN', {
                count: delay,
                hours: hoursLabel,
              })
            }}
          </p>
        </section>

        <section :class="SECTION_CLASSES">
          <h2 class="text-heading-2 text-n-slate-12">
            {{ t('CAMPAIGN.LIVE_CHAT.DETAILS.INFO.SECTION') }}
          </h2>
          <dl
            class="grid grid-cols-[auto_minmax(0,1fr)] gap-x-6 gap-y-2.5 text-sm"
          >
            <template v-for="row in detailRows" :key="row.key">
              <dt class="text-n-slate-11">{{ row.label }}</dt>
              <dd
                :dir="row.ltr ? 'ltr' : 'auto'"
                class="break-all text-n-slate-12 text-start"
              >
                {{ row.value }}
              </dd>
            </template>
          </dl>
        </section>
      </div>

      <section :class="SECTION_CLASSES">
        <div class="flex flex-col gap-1">
          <h2 class="text-heading-2 text-n-slate-12">
            {{ t('CAMPAIGN.LIVE_CHAT.DETAILS.CONVERSATIONS.TITLE') }}
          </h2>
          <p class="text-sm text-n-slate-11">
            {{ t('CAMPAIGN.LIVE_CHAT.DETAILS.CONVERSATIONS.HINT') }}
          </p>
        </div>
        <div
          v-if="state.isFetching && !state.conversations.length"
          class="flex items-center justify-center py-10 text-n-slate-11"
        >
          <Spinner />
        </div>
        <div v-else class="overflow-x-auto">
          <BaseTable
            :headers="conversationHeaders"
            :items="state.conversations"
            :loading="state.isFetching"
            :no-data-message="
              state.hasError
                ? t('CAMPAIGN.LIVE_CHAT.DETAILS.CONVERSATIONS.ERROR')
                : t('CAMPAIGN.LIVE_CHAT.DETAILS.CONVERSATIONS.EMPTY')
            "
            class="min-w-[44rem]"
          >
            <template #row="{ items }">
              <BaseTableRow
                v-for="conversation in items"
                :key="conversation.id"
              >
                <BaseTableCell>
                  <router-link
                    :to="conversationLink(conversation.id)"
                    class="font-mono text-xs text-n-brand hover:underline"
                  >
                    {{ `#${conversation.id}` }}
                  </router-link>
                </BaseTableCell>
                <BaseTableCell>
                  <div class="flex flex-col min-w-0 gap-0.5">
                    <span class="truncate text-n-slate-12">
                      {{ conversation.contact?.name || NO_VALUE }}
                    </span>
                    <span dir="ltr" class="text-xs truncate text-start">
                      {{
                        conversation.contact?.email ||
                        conversation.contact?.phone_number
                      }}
                    </span>
                  </div>
                </BaseTableCell>
                <BaseTableCell>
                  <span
                    class="inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-full whitespace-nowrap"
                    :class="CONVERSATION_STATUS_STYLES[conversation.status]"
                  >
                    {{ conversationStatusLabels[conversation.status] }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span class="text-n-slate-12">
                    {{ conversation.assignee?.name || NO_VALUE }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span class="text-xs whitespace-nowrap">
                    {{ formatDate(conversation.created_at) }}
                  </span>
                </BaseTableCell>
              </BaseTableRow>
            </template>
          </BaseTable>
        </div>
        <PaginationFooter
          v-if="state.count > PER_PAGE"
          :current-page="state.page"
          :total-items="state.count"
          :items-per-page="PER_PAGE"
          current-page-info="CAMPAIGN.LIVE_CHAT.DETAILS.CONVERSATIONS.PAGE_INFO"
          class="!bg-transparent !px-0 before:hidden"
          @update:current-page="page => (state.page = page)"
        />
      </section>
    </div>
  </div>
</template>
