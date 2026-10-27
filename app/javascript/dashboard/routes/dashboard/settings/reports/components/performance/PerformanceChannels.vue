<script setup>
// Custom (MyDesk): conversations by channel, since bringing every channel into one place is the product.
// Each row: share of all conversations, how many were resolved, and the median first response.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { getInboxIconByType } from 'dashboard/helper/inbox';
import {
  formatDuration,
  formatNumber,
  NO_VALUE,
} from 'dashboard/helper/reportFormatters';

const props = defineProps({
  channels: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
});

const { t, locale } = useI18n();

const channelNames = computed(() => ({
  'Channel::Whatsapp': t('PERFORMANCE_REPORTS.CHANNELS.NAMES.WHATSAPP'),
  'Channel::WebWidget': t('PERFORMANCE_REPORTS.CHANNELS.NAMES.WEB_WIDGET'),
  'Channel::FacebookPage': t('PERFORMANCE_REPORTS.CHANNELS.NAMES.FACEBOOK'),
  'Channel::Instagram': t('PERFORMANCE_REPORTS.CHANNELS.NAMES.INSTAGRAM'),
  'Channel::TwitterProfile': t('PERFORMANCE_REPORTS.CHANNELS.NAMES.X'),
  'Channel::Telegram': t('PERFORMANCE_REPORTS.CHANNELS.NAMES.TELEGRAM'),
  'Channel::Email': t('PERFORMANCE_REPORTS.CHANNELS.NAMES.EMAIL'),
  'Channel::Sms': t('PERFORMANCE_REPORTS.CHANNELS.NAMES.SMS'),
  'Channel::TwilioSms': t('PERFORMANCE_REPORTS.CHANNELS.NAMES.SMS'),
  'Channel::Api': t('PERFORMANCE_REPORTS.CHANNELS.NAMES.API'),
  'Channel::Line': t('PERFORMANCE_REPORTS.CHANNELS.NAMES.LINE'),
}));

const total = computed(() =>
  props.channels.reduce((sum, row) => sum + row.conversations, 0)
);

const rows = computed(() =>
  props.channels.map(row => {
    const share = total.value
      ? Math.round((row.conversations / total.value) * 100)
      : 0;
    return {
      ...row,
      name:
        channelNames.value[row.channel_type] ??
        row.channel_type.replace('Channel::', ''),
      icon: getInboxIconByType(row.channel_type, null, 'line'),
      share,
      conversationsLabel: formatNumber(row.conversations, locale?.value),
      resolvedLabel: formatNumber(row.resolved, locale?.value),
      firstResponse: row.first_response_median
        ? formatDuration(row.first_response_median, locale?.value)
        : NO_VALUE,
    };
  })
);
</script>

<template>
  <section
    class="flex flex-col gap-4 p-6 rounded-xl bg-n-solid-2 outline outline-1 -outline-offset-1 outline-n-weak"
  >
    <div class="flex flex-col gap-1">
      <h2 class="text-heading-2 text-n-slate-12">
        {{ t('PERFORMANCE_REPORTS.CHANNELS.TITLE') }}
      </h2>
      <p class="text-sm text-n-slate-11">
        {{ t('PERFORMANCE_REPORTS.CHANNELS.HINT') }}
      </p>
    </div>

    <div v-if="isLoading && !rows.length" class="flex flex-col gap-3">
      <span
        v-for="index in 3"
        :key="index"
        class="h-10 rounded-lg bg-n-alpha-2 animate-loader-pulse"
      />
    </div>

    <p
      v-else-if="!rows.length"
      class="py-6 text-sm text-center text-n-slate-11"
    >
      {{ t('PERFORMANCE_REPORTS.CHANNELS.EMPTY') }}
    </p>

    <div v-else class="overflow-x-auto">
      <table class="w-full min-w-[36rem] text-sm">
        <thead>
          <tr class="text-start text-n-slate-11">
            <th scope="col" class="pb-3 font-medium text-start">
              {{ t('PERFORMANCE_REPORTS.CHANNELS.HEADERS.CHANNEL') }}
            </th>
            <th scope="col" class="w-1/3 pb-3 font-medium text-start">
              {{ t('PERFORMANCE_REPORTS.CHANNELS.HEADERS.CONVERSATIONS') }}
            </th>
            <th scope="col" class="pb-3 font-medium text-end">
              {{ t('PERFORMANCE_REPORTS.CHANNELS.HEADERS.RESOLVED') }}
            </th>
            <th scope="col" class="pb-3 font-medium text-end">
              {{ t('PERFORMANCE_REPORTS.CHANNELS.HEADERS.FIRST_RESPONSE') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-n-weak">
          <tr v-for="row in rows" :key="row.channel_type">
            <td class="py-3 pe-4">
              <span class="flex items-center gap-2 text-n-slate-12">
                <span
                  class="grid rounded-lg size-8 shrink-0 place-items-center bg-n-alpha-2 text-n-slate-11"
                  aria-hidden="true"
                >
                  <span class="size-4" :class="row.icon" />
                </span>
                <span class="font-medium truncate">{{ row.name }}</span>
              </span>
            </td>
            <td class="py-3 pe-4">
              <div class="flex items-center gap-3">
                <bdi class="w-12 tabular-nums text-n-slate-12 shrink-0">
                  {{ row.conversationsLabel }}
                </bdi>
                <progress
                  :value="row.share"
                  max="100"
                  :aria-label="
                    t('PERFORMANCE_REPORTS.CHANNELS.SHARE', {
                      value: row.share,
                    })
                  "
                  class="flex-1 h-1.5 overflow-hidden rounded-full appearance-none bg-n-alpha-2 [&::-webkit-progress-bar]:bg-n-alpha-2 [&::-webkit-progress-value]:bg-n-blue-9 [&::-webkit-progress-value]:rounded-full [&::-moz-progress-bar]:bg-n-blue-9"
                />
                <bdi class="w-10 text-xs tabular-nums text-end text-n-slate-11">
                  {{ row.share }}%
                </bdi>
              </div>
            </td>
            <td class="py-3 tabular-nums text-end text-n-slate-12">
              <bdi>{{ row.resolvedLabel }}</bdi>
            </td>
            <td class="py-3 tabular-nums text-end text-n-slate-12">
              <bdi>{{ row.firstResponse }}</bdi>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>
