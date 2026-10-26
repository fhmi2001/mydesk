<script setup>
// Custom (MyDesk): the numbers of one SMS campaign with what the provider answered for each
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import BaseTable from 'dashboard/components-next/table/BaseTable.vue';
import BaseTableRow from 'dashboard/components-next/table/BaseTableRow.vue';
import BaseTableCell from 'dashboard/components-next/table/BaseTableCell.vue';

defineProps({
  recipients: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  noDataMessage: { type: String, default: '' },
});

const { t, locale } = useI18n();

const NO_VALUE = '—';
const STATUS_STYLES = {
  queued: 'bg-n-alpha-2 text-n-slate-11',
  sent: 'bg-n-teal-3 text-n-teal-11',
  failed: 'bg-n-ruby-3 text-n-ruby-11',
};

// Deewan's handset delivery results; numbers not checked yet have none
const DELIVERY_STYLES = {
  delivered: 'bg-n-teal-3 text-n-teal-11',
  undelivered: 'bg-n-ruby-3 text-n-ruby-11',
  blocked: 'bg-n-ruby-3 text-n-ruby-11',
  rejected: 'bg-n-ruby-3 text-n-ruby-11',
  expired: 'bg-n-ruby-3 text-n-ruby-11',
  sent: 'bg-n-amber-3 text-n-amber-11',
  buffered: 'bg-n-amber-3 text-n-amber-11',
  in_progress: 'bg-n-amber-3 text-n-amber-11',
  unknown: 'bg-n-alpha-2 text-n-slate-11',
};
const deliveryLabels = computed(() => ({
  delivered: t('CAMPAIGN.SMS.DETAILS.DELIVERY.STATUS.DELIVERED'),
  undelivered: t('CAMPAIGN.SMS.DETAILS.DELIVERY.STATUS.UNDELIVERED'),
  blocked: t('CAMPAIGN.SMS.DETAILS.DELIVERY.STATUS.BLOCKED'),
  rejected: t('CAMPAIGN.SMS.DETAILS.DELIVERY.STATUS.REJECTED'),
  expired: t('CAMPAIGN.SMS.DETAILS.DELIVERY.STATUS.EXPIRED'),
  sent: t('CAMPAIGN.SMS.DETAILS.DELIVERY.STATUS.SENT'),
  buffered: t('CAMPAIGN.SMS.DETAILS.DELIVERY.STATUS.BUFFERED'),
  in_progress: t('CAMPAIGN.SMS.DETAILS.DELIVERY.STATUS.IN_PROGRESS'),
  unknown: t('CAMPAIGN.SMS.DETAILS.DELIVERY.STATUS.UNKNOWN'),
}));

const statusLabels = computed(() => ({
  queued: t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.STATUS.QUEUED'),
  sent: t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.STATUS.SENT'),
  failed: t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.STATUS.FAILED'),
}));

const dateFormat = computed(
  () =>
    new Intl.DateTimeFormat(locale.value, {
      dateStyle: 'medium',
      timeStyle: 'medium',
    })
);
const formatDate = seconds =>
  seconds ? dateFormat.value.format(new Date(seconds * 1000)) : NO_VALUE;
// Failed numbers have no sent time; the row was last updated when the provider refused it
const processedAt = recipient =>
  recipient.status === 'queued'
    ? NO_VALUE
    : formatDate(recipient.sent_at || recipient.updated_at);

const headers = computed(() => [
  t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.HEADERS.NUMBER'),
  t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.HEADERS.STATUS'),
  t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.HEADERS.DELIVERY'),
  t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.HEADERS.SMS_ID'),
  t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.HEADERS.REQUEST_ID'),
  t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.HEADERS.ERROR'),
  t('CAMPAIGN.SMS.DETAILS.RECIPIENTS.HEADERS.SENT_AT'),
]);
</script>

<template>
  <div class="overflow-x-auto">
    <BaseTable
      :headers="headers"
      :items="recipients"
      :loading="loading"
      :no-data-message="noDataMessage"
      class="min-w-[56rem]"
    >
      <template #row="{ items }">
        <BaseTableRow v-for="recipient in items" :key="recipient.id">
          <BaseTableCell>
            <span dir="ltr" class="tabular-nums text-n-slate-12">
              {{ recipient.phone_number }}
            </span>
          </BaseTableCell>
          <BaseTableCell>
            <span
              class="inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-full whitespace-nowrap"
              :class="STATUS_STYLES[recipient.status]"
            >
              {{ statusLabels[recipient.status] }}
            </span>
          </BaseTableCell>
          <BaseTableCell>
            <div
              v-if="recipient.delivery_status"
              class="flex flex-col items-start gap-0.5"
            >
              <span
                class="inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-full whitespace-nowrap"
                :class="DELIVERY_STYLES[recipient.delivery_status]"
              >
                {{ deliveryLabels[recipient.delivery_status] }}
              </span>
              <span
                v-if="recipient.delivery_price !== null"
                class="text-xs tabular-nums"
              >
                {{
                  t('CAMPAIGN.SMS.DETAILS.DELIVERY.PRICE', {
                    price: recipient.delivery_price,
                  })
                }}
              </span>
            </div>
            <span v-else class="text-xs">
              {{
                recipient.status === 'sent'
                  ? t('CAMPAIGN.SMS.DETAILS.DELIVERY.NOT_CHECKED')
                  : NO_VALUE
              }}
            </span>
          </BaseTableCell>
          <BaseTableCell>
            <span
              dir="ltr"
              class="font-mono text-xs break-all select-all text-n-slate-12"
            >
              {{ recipient.source_id || NO_VALUE }}
            </span>
          </BaseTableCell>
          <BaseTableCell>
            <span
              dir="ltr"
              class="font-mono text-xs break-all select-all text-n-slate-12"
            >
              {{ recipient.provider_request_id || NO_VALUE }}
            </span>
          </BaseTableCell>
          <BaseTableCell>
            <span
              dir="auto"
              class="text-xs"
              :class="recipient.error_message ? 'text-n-ruby-11' : ''"
            >
              {{ recipient.error_message || NO_VALUE }}
            </span>
          </BaseTableCell>
          <BaseTableCell>
            <span class="text-xs whitespace-nowrap">
              {{ processedAt(recipient) }}
            </span>
          </BaseTableCell>
        </BaseTableRow>
      </template>
    </BaseTable>
  </div>
</template>
