<script setup>
// Custom (MyDesk): last check before an SMS campaign goes out — message, numbers and how many SMS it will use
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import {
  smsEncoding,
  smsSegmentCount,
  SMS_ENCODINGS,
} from 'dashboard/helper/smsSegments';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  title: { type: String, required: true },
  inboxName: { type: String, required: true },
  senderName: { type: String, default: '' },
  message: { type: String, required: true },
  sourceLabel: { type: String, required: true },
  deliveryLabel: { type: String, required: true },
  recipientCount: { type: Number, required: true },
  // Cleaning details only exist for typed/imported numbers, not for contact labels
  cleaning: { type: Object, default: null },
  confirmLabel: { type: String, required: true },
  isSubmitting: { type: Boolean, default: false },
});

const emit = defineEmits(['back', 'confirm']);
const { t } = useI18n();

const numberFormat = new Intl.NumberFormat();
const format = value => numberFormat.format(value ?? 0);

const segments = computed(() => smsSegmentCount(props.message));
const totalSms = computed(() => props.recipientCount * segments.value);
const encodingLabel = computed(() =>
  smsEncoding(props.message) === SMS_ENCODINGS.TEXT
    ? t('CAMPAIGN.SMS.FORM_PAGE.ENCODING.text')
    : t('CAMPAIGN.SMS.FORM_PAGE.ENCODING.unicode')
);

const highlights = computed(() => [
  {
    key: 'recipients',
    icon: 'i-lucide-users',
    value: format(props.recipientCount),
    label: t('CAMPAIGN.SMS.REVIEW.RECIPIENTS'),
  },
  {
    key: 'segments',
    icon: 'i-lucide-layers',
    value: format(segments.value),
    label: t('CAMPAIGN.SMS.REVIEW.PARTS_PER_NUMBER'),
  },
  {
    key: 'total',
    icon: 'i-lucide-message-square-text',
    value: format(totalSms.value),
    label: t('CAMPAIGN.SMS.REVIEW.TOTAL_SMS'),
  },
]);

const details = computed(() => {
  const rows = [
    {
      key: 'title',
      label: t('CAMPAIGN.SMS.CREATE.FORM.TITLE.LABEL'),
      value: props.title,
    },
    {
      key: 'inbox',
      label: t('CAMPAIGN.SMS.REVIEW.INBOX'),
      value: props.inboxName,
    },
    {
      key: 'sender',
      label: t('CAMPAIGN.SMS.FORM_PAGE.SENDER.LABEL'),
      value: props.senderName || '—',
    },
    {
      key: 'source',
      label: t('CAMPAIGN.SMS.REVIEW.SOURCE'),
      value: props.sourceLabel,
    },
    {
      key: 'delivery',
      label: t('CAMPAIGN.SMS.FORM_PAGE.SECTIONS.DELIVERY'),
      value: props.deliveryLabel,
    },
    {
      key: 'encoding',
      label: t('CAMPAIGN.SMS.REVIEW.ENCODING'),
      value: encodingLabel.value,
    },
    {
      key: 'length',
      label: t('CAMPAIGN.SMS.REVIEW.LENGTH'),
      value: format(props.message.length),
    },
  ];
  if (props.cleaning) {
    rows.push(
      {
        key: 'duplicates',
        label: t('CAMPAIGN.SMS.RECIPIENTS.SUMMARY.DUPLICATES'),
        value: format(props.cleaning.duplicate_count),
      },
      {
        key: 'invalid',
        label: t('CAMPAIGN.SMS.RECIPIENTS.SUMMARY.INVALID'),
        value: format(props.cleaning.invalid_count),
      },
      {
        key: 'code',
        label: t('CAMPAIGN.SMS.RECIPIENTS.SUMMARY.CODE_ADDED'),
        value: format(props.cleaning.country_code_added_count),
      }
    );
  }
  return rows;
});
</script>

<template>
  <div class="flex flex-col w-full max-w-3xl gap-6 pb-10 mx-auto">
    <div class="flex flex-col gap-1">
      <h1 class="text-heading-1 text-n-slate-12">
        {{ t('CAMPAIGN.SMS.REVIEW.TITLE') }}
      </h1>
      <p class="text-sm text-n-slate-11">
        {{ t('CAMPAIGN.SMS.REVIEW.SUBTITLE') }}
      </p>
    </div>

    <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
      <div
        v-for="item in highlights"
        :key="item.key"
        class="flex items-center gap-3 p-4 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
      >
        <span
          class="flex items-center justify-center rounded-lg size-10 bg-n-alpha-2 text-n-blue-11"
        >
          <span class="size-5" :class="item.icon" />
        </span>
        <div class="flex flex-col">
          <span class="text-xl font-semibold tabular-nums text-n-slate-12">
            {{ item.value }}
          </span>
          <span class="text-xs text-n-slate-11">{{ item.label }}</span>
        </div>
      </div>
    </div>

    <p
      v-if="recipientCount === 0"
      class="px-4 py-3 text-sm rounded-xl bg-n-ruby-2 text-n-ruby-11"
    >
      {{ t('CAMPAIGN.SMS.REVIEW.NO_RECIPIENTS') }}
    </p>

    <section
      class="flex flex-col gap-3 p-6 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
    >
      <h2 class="text-heading-2 text-n-slate-12">
        {{ t('CAMPAIGN.SMS.CREATE.FORM.MESSAGE.LABEL') }}
      </h2>
      <p
        dir="auto"
        class="px-4 py-3 text-sm whitespace-pre-wrap break-words rounded-2xl rounded-ss-sm bg-n-alpha-2 text-n-slate-12"
      >
        {{ message }}
      </p>
    </section>

    <section
      class="rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
    >
      <dl class="divide-y divide-n-weak">
        <div
          v-for="row in details"
          :key="row.key"
          class="grid grid-cols-[minmax(0,1fr)_minmax(0,1.5fr)] gap-4 px-6 py-3 text-sm"
        >
          <dt class="text-n-slate-11">{{ row.label }}</dt>
          <dd class="text-n-slate-12 tabular-nums break-words">
            {{ row.value }}
          </dd>
        </div>
      </dl>
    </section>

    <div class="flex items-center justify-end gap-2">
      <Button
        variant="faded"
        color="slate"
        icon="i-lucide-pencil"
        :label="t('CAMPAIGN.SMS.REVIEW.BACK')"
        @click="emit('back')"
      />
      <Button
        icon="i-lucide-send"
        :label="confirmLabel"
        :is-loading="isSubmitting"
        :disabled="isSubmitting || recipientCount === 0"
        @click="emit('confirm')"
      />
    </div>
  </div>
</template>
