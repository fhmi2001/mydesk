<script setup>
// Custom (MyDesk): full-page form to create or edit a live chat campaign, with a live preview of the
// message as the website widget shows it and a summary of when it appears.
import { computed, onActivated, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useVuelidate } from '@vuelidate/core';
import { required, minValue } from '@vuelidate/validators';
import { URLPattern } from 'urlpattern-polyfill';

import { CAMPAIGN_TYPES } from 'shared/constants/campaign';
import { CAMPAIGNS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import { useAlert, useTrack } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import Breadcrumb from 'dashboard/components-next/breadcrumb/Breadcrumb.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const BOT_SENDER = 0;
const NO_VALUE = '—';
const STATUS = { ENABLED: 'enabled', DISABLED: 'disabled' };
const COMBOBOX_CLASSES =
  '[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6';
const SECTION_CLASSES =
  'flex flex-col gap-4 p-6 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const uiFlags = useMapGetter('campaigns/getUIFlags');
const campaigns = useMapGetter('campaigns/getAllCampaigns');
const websiteInboxes = useMapGetter('inboxes/getWebsiteInboxes');

const buildState = () => ({
  title: '',
  message: '',
  inboxId: null,
  senderId: BOT_SENDER,
  endPoint: '',
  timeOnPage: 10,
  status: STATUS.ENABLED,
  businessHoursOnly: false,
});
const state = reactive(buildState());
const senders = ref([]);
// The editor keeps its own content, so it is re-created whenever the form is filled from outside
const editorKey = ref(0);

const isEdit = computed(() => route.name === 'campaigns_livechat_edit');
const campaignId = computed(() => Number(route.params.campaignId));
const campaign = computed(() =>
  isEdit.value
    ? campaigns.value.find(record => Number(record.id) === campaignId.value)
    : null
);

const rules = {
  title: { required },
  message: { required },
  inboxId: { required },
  endPoint: {
    required,
    startsWithHttp: value => /^https?:\/\//i.test(value ?? ''),
    validPattern: value => {
      try {
        // eslint-disable-next-line no-new
        new URLPattern(value);
        return true;
      } catch {
        return false;
      }
    },
  },
  timeOnPage: { required, minValue: minValue(0) },
};
const v$ = useVuelidate(rules, state, { $autoDirty: true });

const fieldError = (field, message) => (v$.value[field].$error ? message : '');
const errors = computed(() => ({
  title: fieldError('title', t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.TITLE.ERROR')),
  message: fieldError(
    'message',
    t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.MESSAGE.ERROR')
  ),
  inbox: fieldError('inboxId', t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.INBOX.ERROR')),
  endPoint: fieldError(
    'endPoint',
    t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.END_POINT.ERROR')
  ),
  timeOnPage: fieldError(
    'timeOnPage',
    t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.TIME_ON_PAGE.ERROR')
  ),
}));

const fillFromCampaign = record => {
  Object.assign(state, {
    title: record.title,
    message: record.message,
    inboxId: record.inbox?.id ?? null,
    senderId: record.sender?.id ?? BOT_SENDER,
    endPoint: record.trigger_rules?.url ?? '',
    timeOnPage: record.trigger_rules?.time_on_page ?? 10,
    status: record.enabled ? STATUS.ENABLED : STATUS.DISABLED,
    businessHoursOnly: !!record.trigger_only_during_business_hours,
  });
};

// The campaigns route keeps pages alive, so every visit starts from an empty form or the edited campaign
const resetForm = () => {
  Object.assign(state, buildState());
  if (campaign.value) fillFromCampaign(campaign.value);
  editorKey.value += 1;
  v$.value.$reset();
};
onActivated(() => {
  if (isEdit.value && !campaign.value) store.dispatch('campaigns/get');
  resetForm();
});
// Opening the edit page directly loads the campaigns after the page is shown
watch(campaign, (record, previous) => {
  if (record && !previous) resetForm();
});

const inboxOptions = computed(() =>
  (websiteInboxes.value ?? []).map(inbox => ({
    value: inbox.id,
    label: inbox.name,
  }))
);
const selectedInbox = computed(() =>
  websiteInboxes.value?.find(inbox => inbox.id === state.inboxId)
);

watch(
  () => state.inboxId,
  async inboxId => {
    senders.value = [];
    if (!inboxId) return;
    try {
      const response = await store.dispatch('inboxMembers/get', { inboxId });
      senders.value = response?.data?.payload ?? [];
    } catch {
      useAlert(t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.API.ERROR_MESSAGE'));
    }
  }
);

const senderOptions = computed(() => [
  {
    value: BOT_SENDER,
    label: t('CAMPAIGN.LIVE_CHAT.CARD.CAMPAIGN_DETAILS.BOT'),
  },
  ...senders.value.map(agent => ({ value: agent.id, label: agent.name })),
]);
const senderName = computed(
  () =>
    senderOptions.value.find(option => option.value === state.senderId)
      ?.label ?? t('CAMPAIGN.LIVE_CHAT.CARD.CAMPAIGN_DETAILS.BOT')
);

// People usually type "www.store.com"; add the https:// the URL rule requires
const completeEndPoint = () => {
  const value = state.endPoint.trim();
  state.endPoint =
    value && !/^https?:\/\//i.test(value) ? `https://${value}` : value;
};

const isSubmitting = computed(
  () => uiFlags.value.isCreating || uiFlags.value.isUpdating
);

const breadcrumbItems = computed(() => [
  {
    label: t('CAMPAIGN.LIVE_CHAT.HEADER_TITLE'),
    routeName: 'campaigns_livechat_index',
  },
  ...(isEdit.value && campaign.value
    ? [
        {
          label: `#${campaign.value.id} · ${campaign.value.title}`,
          routeName: 'campaigns_livechat_details',
        },
      ]
    : []),
  {
    label: isEdit.value
      ? t('CAMPAIGN.LIVE_CHAT.EDIT.TITLE')
      : t('CAMPAIGN.LIVE_CHAT.CREATE.TITLE'),
  },
]);

const goTo = name =>
  router.push({ name, params: { campaignId: route.params.campaignId } });
const goBack = () =>
  goTo(
    isEdit.value ? 'campaigns_livechat_details' : 'campaigns_livechat_index'
  );

const payload = () => ({
  title: state.title.trim(),
  message: state.message,
  inbox_id: state.inboxId,
  sender_id: state.senderId || null,
  enabled: state.status === STATUS.ENABLED,
  trigger_only_during_business_hours: state.businessHoursOnly,
  trigger_rules: {
    url: state.endPoint,
    time_on_page: Number(state.timeOnPage),
  },
});

const handleSubmit = async () => {
  completeEndPoint();
  if (!(await v$.value.$validate())) return;

  try {
    if (isEdit.value) {
      await store.dispatch('campaigns/update', {
        id: campaignId.value,
        ...payload(),
      });
      useAlert(t('CAMPAIGN.LIVE_CHAT.EDIT.FORM.API.SUCCESS_MESSAGE'));
    } else {
      await store.dispatch('campaigns/create', payload());
      useTrack(CAMPAIGNS_EVENTS.CREATE_CAMPAIGN, {
        type: CAMPAIGN_TYPES.ONGOING,
      });
      useAlert(t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.API.SUCCESS_MESSAGE'));
    }
    goBack();
  } catch {
    useAlert(t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.API.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <div class="w-full h-full px-6 overflow-y-auto bg-n-surface-1">
    <header
      class="flex flex-wrap items-center justify-between w-full max-w-5xl gap-3 py-5 mx-auto"
    >
      <Breadcrumb
        :items="breadcrumbItems"
        @click="({ routeName }) => goTo(routeName)"
      />
      <div class="flex items-center gap-2">
        <Button
          variant="faded"
          color="slate"
          size="sm"
          :label="t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.BUTTONS.CANCEL')"
          @click="goBack"
        />
        <Button
          size="sm"
          icon="i-lucide-check"
          :label="
            isEdit
              ? t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.SAVE')
              : t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.BUTTONS.CREATE')
          "
          :is-loading="isSubmitting"
          :disabled="isSubmitting"
          @click="handleSubmit"
        />
      </div>
    </header>

    <div
      v-if="isEdit && !campaign"
      class="flex items-center justify-center py-20 text-n-slate-11"
    >
      <Spinner v-if="uiFlags.isFetching" />
      <span v-else>{{ t('CAMPAIGN.LIVE_CHAT.DETAILS.NOT_FOUND') }}</span>
    </div>

    <div
      v-else
      class="grid items-start w-full max-w-5xl grid-cols-1 gap-6 pb-10 mx-auto lg:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)]"
    >
      <form class="flex flex-col gap-6" @submit.prevent="handleSubmit">
        <section :class="SECTION_CLASSES">
          <h2 class="text-heading-2 text-n-slate-12">
            {{ t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.SECTIONS.DETAILS') }}
          </h2>
          <Input
            v-model="state.title"
            :label="t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.TITLE.LABEL')"
            :placeholder="t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.TITLE.PLACEHOLDER')"
            :message="errors.title"
            :message-type="errors.title ? 'error' : 'info'"
          />
          <div class="grid gap-4 sm:grid-cols-2">
            <div class="flex flex-col gap-1">
              <label class="mb-0.5 text-sm font-medium text-n-slate-12">
                {{ t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.INBOX') }}
              </label>
              <ComboBox
                v-model="state.inboxId"
                :options="inboxOptions"
                :has-error="!!errors.inbox"
                :message="errors.inbox"
                :placeholder="
                  t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.INBOX.PLACEHOLDER')
                "
                :class="COMBOBOX_CLASSES"
              />
            </div>
            <div class="flex flex-col gap-1">
              <label class="mb-0.5 text-sm font-medium text-n-slate-12">
                {{ t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.SENT_BY.LABEL') }}
              </label>
              <ComboBox
                v-model="state.senderId"
                :options="senderOptions"
                :disabled="!state.inboxId"
                :placeholder="
                  t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.SENT_BY.PLACEHOLDER')
                "
                :message="t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.SENDER_HELP')"
                :class="COMBOBOX_CLASSES"
              />
            </div>
          </div>
        </section>

        <section :class="SECTION_CLASSES">
          <h2 class="text-heading-2 text-n-slate-12">
            {{ t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.MESSAGE.LABEL') }}
          </h2>
          <Editor
            :key="editorKey"
            v-model="state.message"
            :placeholder="
              t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.MESSAGE.PLACEHOLDER')
            "
            :max-length="500"
            :enable-canned-responses="false"
            :message="errors.message"
            :message-type="errors.message ? 'error' : 'info'"
          />
        </section>

        <section :class="SECTION_CLASSES">
          <div class="flex flex-col gap-1">
            <h2 class="text-heading-2 text-n-slate-12">
              {{ t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.SECTIONS.TRIGGER') }}
            </h2>
            <p class="text-sm text-n-slate-11">
              {{ t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.TRIGGER_HELP') }}
            </p>
          </div>
          <Input
            v-model="state.endPoint"
            type="url"
            :label="t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.END_POINT.LABEL')"
            :placeholder="
              t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.END_POINT.PLACEHOLDER')
            "
            :message="
              errors.endPoint || t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.URL_HELP')
            "
            :message-type="errors.endPoint ? 'error' : 'info'"
            @blur="completeEndPoint"
          />
          <Input
            v-model="state.timeOnPage"
            type="number"
            min="0"
            :label="t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.TIME_ON_PAGE.LABEL')"
            :placeholder="
              t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.TIME_ON_PAGE.PLACEHOLDER')
            "
            :message="errors.timeOnPage"
            :message-type="errors.timeOnPage ? 'error' : 'info'"
          />
          <label class="flex items-start gap-2">
            <input
              v-model="state.businessHoursOnly"
              type="checkbox"
              class="mt-1"
            />
            <span class="flex flex-col">
              <span class="text-sm font-medium text-n-slate-12">
                {{
                  t(
                    'CAMPAIGN.LIVE_CHAT.CREATE.FORM.OTHER_PREFERENCES.TRIGGER_ONLY_BUSINESS_HOURS'
                  )
                }}
              </span>
              <span class="text-xs text-n-slate-11">
                {{ t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.BUSINESS_HOURS_HELP') }}
              </span>
            </span>
          </label>
        </section>

        <section :class="SECTION_CLASSES">
          <h2 class="text-heading-2 text-n-slate-12">
            {{ t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.SECTIONS.STATUS') }}
          </h2>
          <div class="grid gap-3 sm:grid-cols-2">
            <RadioCard
              :id="STATUS.ENABLED"
              name="status"
              :label="t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.STATUS.ENABLED.LABEL')"
              :description="
                t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.STATUS.ENABLED.DESCRIPTION')
              "
              :is-active="state.status === STATUS.ENABLED"
              @select="state.status = $event"
            />
            <RadioCard
              :id="STATUS.DISABLED"
              name="status"
              :label="t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.STATUS.DISABLED.LABEL')"
              :description="
                t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.STATUS.DISABLED.DESCRIPTION')
              "
              :is-active="state.status === STATUS.DISABLED"
              @select="state.status = $event"
            />
          </div>
        </section>
      </form>

      <aside :class="SECTION_CLASSES" class="lg:sticky lg:top-6">
        <h2 class="text-heading-2 text-n-slate-12">
          {{ t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.PREVIEW.TITLE') }}
        </h2>
        <div class="flex flex-col gap-2 p-4 rounded-2xl bg-n-alpha-2">
          <div class="flex items-center gap-2">
            <span
              class="flex items-center justify-center text-white rounded-full size-8 bg-n-brand"
            >
              <span class="i-lucide-message-circle size-4" />
            </span>
            <div class="flex flex-col min-w-0">
              <span class="text-sm font-medium truncate text-n-slate-12">
                {{ senderName }}
              </span>
              <span class="text-xs truncate text-n-slate-11">
                {{
                  selectedInbox?.name ||
                  t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.PREVIEW.NO_INBOX')
                }}
              </span>
            </div>
          </div>
          <p
            dir="auto"
            class="px-3 py-2 text-sm whitespace-pre-wrap break-words rounded-2xl rounded-ss-sm bg-n-solid-1 text-n-slate-12"
          >
            {{
              state.message || t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.PREVIEW.EMPTY')
            }}
          </p>
        </div>
        <dl class="grid grid-cols-[auto_minmax(0,1fr)] gap-x-4 gap-y-2 text-sm">
          <dt class="text-n-slate-11">
            {{ t('CAMPAIGN.LIVE_CHAT.CREATE.FORM.END_POINT.LABEL') }}
          </dt>
          <dd dir="ltr" class="break-all text-n-slate-12 text-start">
            {{ state.endPoint || NO_VALUE }}
          </dd>
          <dt class="text-n-slate-11">
            {{ t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.PREVIEW.DELAY') }}
          </dt>
          <dd class="text-n-slate-12">
            {{
              t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.PREVIEW.SECONDS', {
                count: Number(state.timeOnPage) || 0,
              })
            }}
          </dd>
          <dt class="text-n-slate-11">
            {{ t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.PREVIEW.HOURS') }}
          </dt>
          <dd class="text-n-slate-12">
            {{
              state.businessHoursOnly
                ? t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.PREVIEW.BUSINESS_HOURS')
                : t('CAMPAIGN.LIVE_CHAT.FORM_PAGE.PREVIEW.ANY_TIME')
            }}
          </dd>
        </dl>
      </aside>
    </div>
  </div>
</template>
