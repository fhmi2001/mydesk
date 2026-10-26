<script setup>
// Custom (MyDesk): SMS campaigns as a short table (id, numbers, sender, result); the full story is on the details page
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import { smsSegmentCount } from 'dashboard/helper/smsSegments';
import BaseTable from 'dashboard/components-next/table/BaseTable.vue';
import BaseTableRow from 'dashboard/components-next/table/BaseTableRow.vue';
import BaseTableCell from 'dashboard/components-next/table/BaseTableCell.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SMSCampaignStatusBadge from './SMSCampaignStatusBadge.vue';

const props = defineProps({
  campaigns: { type: Array, default: () => [] },
});

const emit = defineEmits(['delete', 'open']);
const { t, locale } = useI18n();

const NO_VALUE = '—';

const numberFormat = computed(() => new Intl.NumberFormat(locale.value));
const dateFormat = computed(
  () =>
    new Intl.DateTimeFormat(locale.value, {
      dateStyle: 'medium',
      timeStyle: 'short',
    })
);
const formatNumber = value => numberFormat.value.format(value ?? 0);
const formatDate = seconds =>
  seconds ? dateFormat.value.format(new Date(seconds * 1000)) : NO_VALUE;

const rows = computed(() =>
  [...props.campaigns]
    .sort((a, b) => b.id - a.id)
    .map(campaign => ({
      campaign,
      stats: campaign.sms_stats ?? null,
      sender:
        campaign.sms_sender_name || campaign.inbox?.phone_number || NO_VALUE,
      date: formatDate(campaign.completed_at || campaign.scheduled_at),
    }))
);

const totals = computed(() =>
  rows.value.reduce(
    (sum, row) => ({
      campaigns: sum.campaigns + 1,
      sent: sum.sent + (row.stats?.sent ?? 0),
      failed: sum.failed + (row.stats?.failed ?? 0),
      smsUsed:
        sum.smsUsed +
        (row.stats?.sent ?? 0) * smsSegmentCount(row.campaign.message),
    }),
    { campaigns: 0, sent: 0, failed: 0, smsUsed: 0 }
  )
);

const totalCards = computed(() => [
  {
    key: 'campaigns',
    icon: 'i-lucide-megaphone',
    value: totals.value.campaigns,
    label: t('CAMPAIGN.SMS.TABLE.TOTALS.CAMPAIGNS'),
  },
  {
    key: 'sent',
    icon: 'i-lucide-check-check',
    value: totals.value.sent,
    label: t('CAMPAIGN.SMS.TABLE.TOTALS.SENT'),
  },
  {
    key: 'failed',
    icon: 'i-lucide-circle-alert',
    value: totals.value.failed,
    label: t('CAMPAIGN.SMS.TABLE.TOTALS.FAILED'),
  },
  {
    key: 'sms',
    icon: 'i-lucide-message-square-text',
    value: totals.value.smsUsed,
    label: t('CAMPAIGN.SMS.TABLE.TOTALS.SMS_USED'),
  },
]);

const headers = computed(() => [
  t('CAMPAIGN.SMS.TABLE.HEADERS.ID'),
  t('CAMPAIGN.SMS.TABLE.HEADERS.CAMPAIGN'),
  t('CAMPAIGN.SMS.TABLE.HEADERS.RECIPIENTS'),
  t('CAMPAIGN.SMS.TABLE.HEADERS.SENDER'),
  t('CAMPAIGN.SMS.TABLE.HEADERS.RESULT'),
  t('CAMPAIGN.SMS.TABLE.HEADERS.DATE'),
  '',
]);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
      <div
        v-for="card in totalCards"
        :key="card.key"
        class="flex items-center gap-3 p-4 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
      >
        <span
          class="flex items-center justify-center rounded-lg size-9 shrink-0 bg-n-alpha-2 text-n-blue-11"
        >
          <span class="size-4" :class="card.icon" />
        </span>
        <div class="flex flex-col min-w-0">
          <span class="text-lg font-semibold tabular-nums text-n-slate-12">
            {{ formatNumber(card.value) }}
          </span>
          <span class="text-xs truncate text-n-slate-11">{{ card.label }}</span>
        </div>
      </div>
    </div>

    <div class="overflow-x-auto">
      <BaseTable :headers="headers" :items="rows" class="min-w-[48rem]">
        <template #row="{ items }">
          <BaseTableRow v-for="row in items" :key="row.campaign.id" :item="row">
            <BaseTableCell>
              <span class="font-mono text-xs tabular-nums text-n-slate-11">
                {{ `#${row.campaign.id}` }}
              </span>
            </BaseTableCell>
            <BaseTableCell>
              <button
                type="button"
                class="max-w-xs font-medium truncate text-start text-n-slate-12 hover:text-n-brand hover:underline"
                @click="emit('open', row.campaign)"
              >
                {{ row.campaign.title }}
              </button>
            </BaseTableCell>
            <BaseTableCell>
              <span class="tabular-nums text-n-slate-12">
                {{ row.stats ? formatNumber(row.stats.total) : NO_VALUE }}
              </span>
            </BaseTableCell>
            <BaseTableCell>
              <span class="text-n-slate-12">{{ row.sender }}</span>
            </BaseTableCell>
            <BaseTableCell>
              <div class="flex flex-col items-start gap-1">
                <SMSCampaignStatusBadge :campaign="row.campaign" />
                <span v-if="row.stats" class="flex gap-2 text-xs tabular-nums">
                  <span class="text-n-teal-11">
                    {{
                      t('CAMPAIGN.SMS.TABLE.SENT_COUNT', {
                        count: formatNumber(row.stats.sent),
                      })
                    }}
                  </span>
                  <span v-if="row.stats.failed" class="text-n-ruby-11">
                    {{
                      t('CAMPAIGN.SMS.TABLE.FAILED_COUNT', {
                        count: formatNumber(row.stats.failed),
                      })
                    }}
                  </span>
                </span>
              </div>
            </BaseTableCell>
            <BaseTableCell>
              <span class="text-xs whitespace-nowrap text-n-slate-11">
                {{ row.date }}
              </span>
            </BaseTableCell>
            <BaseTableCell align="end">
              <div class="flex items-center justify-end gap-1">
                <Button
                  variant="faded"
                  color="slate"
                  size="xs"
                  icon="i-lucide-file-text"
                  :label="t('CAMPAIGN.SMS.TABLE.DETAILS')"
                  @click="emit('open', row.campaign)"
                />
                <Button
                  variant="ghost"
                  color="ruby"
                  size="xs"
                  icon="i-lucide-trash-2"
                  :aria-label="t('CAMPAIGN.SMS.TABLE.DELETE')"
                  @click="emit('delete', row.campaign)"
                />
              </div>
            </BaseTableCell>
          </BaseTableRow>
        </template>
      </BaseTable>
    </div>
  </div>
</template>
