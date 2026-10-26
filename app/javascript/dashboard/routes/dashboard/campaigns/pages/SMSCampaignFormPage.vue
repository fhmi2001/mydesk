<script setup>
// Custom (MyDesk): full-page SMS campaign form. Numbers come from contact labels, typed text or an Excel/CSV file;
// "Review" opens a confirmation step with the message, valid numbers and SMS count before anything is sent.
import { computed, onActivated, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';

import { CAMPAIGN_TYPES } from 'shared/constants/campaign';
import { CAMPAIGNS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import {
  smsEncoding,
  smsSegmentCount,
  SMS_ENCODINGS,
} from 'dashboard/helper/smsSegments';
import { useAlert, useTrack } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import Breadcrumb from 'dashboard/components-next/breadcrumb/Breadcrumb.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import SMSRecipientsSection from 'dashboard/components-next/Campaigns/SMSCampaign/SMSRecipientsSection.vue';
import SMSCampaignReview from 'dashboard/components-next/Campaigns/SMSCampaign/SMSCampaignReview.vue';

const DELIVERY = { NOW: 'now', SCHEDULE: 'schedule' };
const STEPS = { FORM: 'form', REVIEW: 'review' };
const COMBOBOX_CLASSES =
  '[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6';

const { t, locale } = useI18n();
const router = useRouter();
const store = useStore();

const uiFlags = useMapGetter('campaigns/getUIFlags');
const labels = useMapGetter('labels/getLabels');
const smsInboxes = useMapGetter('inboxes/getSMSInboxes');

const buildState = () => ({
  title: '',
  inboxId: null,
  senderName: null,
  message: '',
  recipientSource: 'manual',
  labelIds: [],
  numbersText: '',
  file: null,
  recipientsPreview: null,
  delivery: DELIVERY.NOW,
  scheduledAt: '',
});

const step = ref(STEPS.FORM);
const state = reactive(buildState());

// The campaigns route keeps pages alive, so every visit must start from an empty form
onActivated(() => {
  Object.assign(state, buildState());
  step.value = STEPS.FORM;
});

const toOptions = (items, valueKey, labelKey) =>
  (items ?? []).map(item => ({ value: item[valueKey], label: item[labelKey] }));

const inboxOptions = computed(() => toOptions(smsInboxes.value, 'id', 'name'));

const selectedInbox = computed(() =>
  smsInboxes.value.find(inbox => inbox.id === state.inboxId)
);
// Twilio SMS inboxes have no sender name list; they always send from their number
const senderNames = computed(() => {
  const inbox = selectedInbox.value;
  if (!inbox) return [];
  return inbox.sms_sender_names ?? [inbox.phone_number].filter(Boolean);
});
const senderOptions = computed(() =>
  senderNames.value.map(name => ({ value: name, label: name }))
);

watch(senderNames, names => {
  if (!names.includes(state.senderName)) state.senderName = names[0] ?? null;
});

const encodingLabel = computed(() =>
  smsEncoding(state.message) === SMS_ENCODINGS.TEXT
    ? t('CAMPAIGN.SMS.FORM_PAGE.ENCODING.text')
    : t('CAMPAIGN.SMS.FORM_PAGE.ENCODING.unicode')
);
const segmentCount = computed(() => smsSegmentCount(state.message));

const isLabelSource = computed(() => state.recipientSource === 'labels');
const recipientCount = computed(() => {
  const preview = state.recipientsPreview;
  if (!preview) return 0;
  return isLabelSource.value
    ? preview.label_recipients_count
    : preview.valid_count;
});

const minScheduleTime = computed(() => {
  const now = new Date();
  return new Date(now.getTime() - now.getTimezoneOffset() * 60000)
    .toISOString()
    .slice(0, 16);
});

const isScheduled = computed(() => state.delivery === DELIVERY.SCHEDULE);

const isValid = computed(
  () =>
    !!state.title.trim() &&
    !!state.inboxId &&
    !!state.message.trim() &&
    recipientCount.value > 0 &&
    (!isScheduled.value || state.scheduledAt >= minScheduleTime.value)
);

const confirmLabel = computed(() =>
  isScheduled.value
    ? t('CAMPAIGN.SMS.FORM_PAGE.SUBMIT.SCHEDULE')
    : t('CAMPAIGN.SMS.FORM_PAGE.SUBMIT.SEND_NOW')
);

const deliveryTime = computed(() =>
  isScheduled.value && state.scheduledAt
    ? new Intl.DateTimeFormat(locale.value, {
        dateStyle: 'medium',
        timeStyle: 'short',
      }).format(new Date(state.scheduledAt))
    : t('CAMPAIGN.SMS.FORM_PAGE.PREVIEW.NOW')
);

const sourceLabel = computed(
  () =>
    ({
      labels: t('CAMPAIGN.SMS.RECIPIENTS.SOURCES.LABELS'),
      manual: t('CAMPAIGN.SMS.RECIPIENTS.SOURCES.MANUAL'),
      file: t('CAMPAIGN.SMS.RECIPIENTS.SOURCES.FILE'),
    })[state.recipientSource]
);

const breadcrumbItems = computed(() => [
  { label: t('CAMPAIGN.SMS.HEADER_TITLE'), routeName: 'campaigns_sms_index' },
  {
    label:
      step.value === STEPS.REVIEW
        ? t('CAMPAIGN.SMS.REVIEW.TITLE')
        : t('CAMPAIGN.SMS.FORM_PAGE.TITLE'),
  },
]);

const goBack = () => router.push({ name: 'campaigns_sms_index' });
const openReview = () => {
  if (isValid.value) step.value = STEPS.REVIEW;
};

const recipientsPayload = () =>
  isLabelSource.value
    ? { audience: state.labelIds.map(id => ({ id, type: 'Label' })) }
    : { recipient_numbers: state.recipientsPreview.valid_numbers };

const handleConfirm = async () => {
  if (!isValid.value) return;

  try {
    await store.dispatch('campaigns/create', {
      title: state.title.trim(),
      message: state.message,
      inbox_id: state.inboxId,
      sms_sender_name: state.senderName,
      ...recipientsPayload(),
      // Without a time the server schedules it for now and sends it immediately
      scheduled_at: isScheduled.value
        ? new Date(state.scheduledAt).toISOString()
        : null,
    });
    useTrack(CAMPAIGNS_EVENTS.CREATE_CAMPAIGN, {
      type: CAMPAIGN_TYPES.ONE_OFF,
    });
    useAlert(
      isScheduled.value
        ? t('CAMPAIGN.SMS.FORM_PAGE.API.SCHEDULED')
        : t('CAMPAIGN.SMS.FORM_PAGE.API.SENT')
    );
    goBack();
  } catch (error) {
    useAlert(
      error?.response?.data?.message ||
        t('CAMPAIGN.SMS.CREATE.FORM.API.ERROR_MESSAGE')
    );
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
        @click="({ routeName }) => router.push({ name: routeName })"
      />
      <div v-if="step === STEPS.FORM" class="flex items-center gap-2">
        <Button
          variant="faded"
          color="slate"
          size="sm"
          :label="t('CAMPAIGN.SMS.CREATE.FORM.BUTTONS.CANCEL')"
          @click="goBack"
        />
        <Button
          size="sm"
          icon="i-lucide-clipboard-check"
          :label="t('CAMPAIGN.SMS.REVIEW.OPEN')"
          :disabled="!isValid"
          @click="openReview"
        />
      </div>
    </header>

    <SMSCampaignReview
      v-if="step === STEPS.REVIEW"
      :title="state.title.trim()"
      :inbox-name="selectedInbox?.name ?? ''"
      :sender-name="state.senderName ?? ''"
      :message="state.message"
      :source-label="sourceLabel"
      :delivery-label="deliveryTime"
      :recipient-count="recipientCount"
      :cleaning="isLabelSource ? null : state.recipientsPreview"
      :confirm-label="confirmLabel"
      :is-submitting="uiFlags.isCreating"
      @back="step = STEPS.FORM"
      @confirm="handleConfirm"
    />

    <div
      v-else
      class="grid items-start w-full max-w-5xl grid-cols-1 gap-6 pb-10 mx-auto lg:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)]"
    >
      <form class="flex flex-col gap-6" @submit.prevent="openReview">
        <section
          class="flex flex-col gap-4 p-6 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
        >
          <h2 class="text-heading-2 text-n-slate-12">
            {{ t('CAMPAIGN.SMS.FORM_PAGE.SECTIONS.DETAILS') }}
          </h2>
          <Input
            v-model="state.title"
            :label="t('CAMPAIGN.SMS.CREATE.FORM.TITLE.LABEL')"
            :placeholder="t('CAMPAIGN.SMS.CREATE.FORM.TITLE.PLACEHOLDER')"
          />
          <div class="grid gap-4 sm:grid-cols-2">
            <div class="flex flex-col gap-1">
              <label class="mb-0.5 text-sm font-medium text-n-slate-12">
                {{ t('CAMPAIGN.SMS.CREATE.FORM.INBOX.LABEL') }}
              </label>
              <ComboBox
                v-model="state.inboxId"
                :options="inboxOptions"
                :placeholder="t('CAMPAIGN.SMS.CREATE.FORM.INBOX.PLACEHOLDER')"
                :class="COMBOBOX_CLASSES"
              />
            </div>
            <div class="flex flex-col gap-1">
              <label class="mb-0.5 text-sm font-medium text-n-slate-12">
                {{ t('CAMPAIGN.SMS.FORM_PAGE.SENDER.LABEL') }}
              </label>
              <ComboBox
                v-model="state.senderName"
                :options="senderOptions"
                :disabled="senderOptions.length < 2"
                :placeholder="t('CAMPAIGN.SMS.FORM_PAGE.SENDER.PLACEHOLDER')"
                :message="
                  state.inboxId ? t('CAMPAIGN.SMS.FORM_PAGE.SENDER.HELP') : ''
                "
                :class="COMBOBOX_CLASSES"
              />
            </div>
          </div>
        </section>

        <section
          class="flex flex-col gap-4 p-6 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
        >
          <h2 class="text-heading-2 text-n-slate-12">
            {{ t('CAMPAIGN.SMS.CREATE.FORM.MESSAGE.LABEL') }}
          </h2>
          <TextArea
            v-model="state.message"
            :placeholder="t('CAMPAIGN.SMS.CREATE.FORM.MESSAGE.PLACEHOLDER')"
            :max-length="1000"
            show-character-count
            auto-height
          />
          <p class="text-sm text-n-slate-11">
            {{
              t('CAMPAIGN.SMS.FORM_PAGE.SEGMENTS', {
                count: segmentCount,
                encoding: encodingLabel,
              })
            }}
          </p>
        </section>

        <section
          class="flex flex-col gap-4 p-6 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
        >
          <h2 class="text-heading-2 text-n-slate-12">
            {{ t('CAMPAIGN.SMS.RECIPIENTS.TITLE') }}
          </h2>
          <SMSRecipientsSection
            v-model:source="state.recipientSource"
            v-model:label-ids="state.labelIds"
            v-model:numbers-text="state.numbersText"
            v-model:file="state.file"
            v-model:preview="state.recipientsPreview"
            :labels="labels"
          />
        </section>

        <section
          class="flex flex-col gap-4 p-6 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
        >
          <h2 class="text-heading-2 text-n-slate-12">
            {{ t('CAMPAIGN.SMS.FORM_PAGE.SECTIONS.DELIVERY') }}
          </h2>
          <div class="grid gap-3 sm:grid-cols-2">
            <RadioCard
              :id="DELIVERY.NOW"
              name="delivery"
              :label="t('CAMPAIGN.SMS.FORM_PAGE.DELIVERY.NOW.LABEL')"
              :description="
                t('CAMPAIGN.SMS.FORM_PAGE.DELIVERY.NOW.DESCRIPTION')
              "
              :is-active="state.delivery === DELIVERY.NOW"
              @select="state.delivery = $event"
            />
            <RadioCard
              :id="DELIVERY.SCHEDULE"
              name="delivery"
              :label="t('CAMPAIGN.SMS.FORM_PAGE.DELIVERY.SCHEDULE.LABEL')"
              :description="
                t('CAMPAIGN.SMS.FORM_PAGE.DELIVERY.SCHEDULE.DESCRIPTION')
              "
              :is-active="isScheduled"
              @select="state.delivery = $event"
            />
          </div>
          <Input
            v-if="isScheduled"
            v-model="state.scheduledAt"
            type="datetime-local"
            :min="minScheduleTime"
            :label="t('CAMPAIGN.SMS.CREATE.FORM.SCHEDULED_AT.LABEL')"
          />
        </section>
      </form>

      <aside
        class="flex flex-col gap-4 p-6 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak lg:sticky lg:top-6"
      >
        <h2 class="text-heading-2 text-n-slate-12">
          {{ t('CAMPAIGN.SMS.FORM_PAGE.PREVIEW.TITLE') }}
        </h2>
        <div class="flex flex-col gap-3 p-4 rounded-2xl bg-n-alpha-2">
          <div class="flex items-center gap-2">
            <span
              class="flex items-center justify-center rounded-full size-8 bg-n-blue-9 text-white i-lucide-message-square"
            />
            <div class="flex flex-col min-w-0">
              <span class="text-sm font-medium truncate text-n-slate-12">
                {{
                  state.senderName ||
                  t('CAMPAIGN.SMS.FORM_PAGE.PREVIEW.NO_SENDER')
                }}
              </span>
              <span class="text-xs text-n-slate-11">{{ deliveryTime }}</span>
            </div>
          </div>
          <p
            dir="auto"
            class="px-3 py-2 text-sm whitespace-pre-wrap break-words rounded-2xl rounded-ss-sm bg-n-solid-1 text-n-slate-12"
          >
            {{ state.message || t('CAMPAIGN.SMS.FORM_PAGE.PREVIEW.EMPTY') }}
          </p>
        </div>
        <dl class="grid grid-cols-2 gap-2 text-sm">
          <dt class="text-n-slate-11">
            {{ t('CAMPAIGN.SMS.REVIEW.RECIPIENTS') }}
          </dt>
          <dd class="text-n-slate-12 tabular-nums">{{ recipientCount }}</dd>
          <dt class="text-n-slate-11">
            {{ t('CAMPAIGN.SMS.FORM_PAGE.PREVIEW.PER_CONTACT') }}
          </dt>
          <dd class="text-n-slate-12">
            {{
              t('CAMPAIGN.SMS.FORM_PAGE.PREVIEW.SMS_COUNT', {
                count: segmentCount,
              })
            }}
          </dd>
          <dt class="text-n-slate-11">
            {{ t('CAMPAIGN.SMS.REVIEW.TOTAL_SMS') }}
          </dt>
          <dd class="font-medium text-n-slate-12 tabular-nums">
            {{ recipientCount * segmentCount }}
          </dd>
        </dl>
      </aside>
    </div>
  </div>
</template>
