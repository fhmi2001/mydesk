<script setup>
// Custom (MyDesk): live chat campaigns as a table (id, website, sender, page, delay, status, conversations);
// the full story is on the details page
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import BaseTable from 'dashboard/components-next/table/BaseTable.vue';
import BaseTableRow from 'dashboard/components-next/table/BaseTableRow.vue';
import BaseTableCell from 'dashboard/components-next/table/BaseTableCell.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import LiveChatCampaignStatusBadge from './LiveChatCampaignStatusBadge.vue';

const props = defineProps({
  campaigns: { type: Array, default: () => [] },
});

const emit = defineEmits(['open', 'edit', 'delete']);
const { t, locale } = useI18n();

const numberFormat = computed(() => new Intl.NumberFormat(locale.value));
const formatNumber = value => numberFormat.value.format(value ?? 0);

const rows = computed(() =>
  [...props.campaigns]
    .sort((a, b) => b.id - a.id)
    .map(campaign => ({
      campaign,
      sender:
        campaign.sender?.name ||
        t('CAMPAIGN.LIVE_CHAT.CARD.CAMPAIGN_DETAILS.BOT'),
      url: campaign.trigger_rules?.url,
      delay: campaign.trigger_rules?.time_on_page ?? 0,
    }))
);

const totalCards = computed(() => {
  const list = props.campaigns;
  return [
    {
      key: 'campaigns',
      icon: 'i-lucide-megaphone',
      value: list.length,
      label: t('CAMPAIGN.LIVE_CHAT.TABLE.TOTALS.CAMPAIGNS'),
    },
    {
      key: 'enabled',
      icon: 'i-lucide-circle-play',
      value: list.filter(campaign => campaign.enabled).length,
      label: t('CAMPAIGN.LIVE_CHAT.TABLE.TOTALS.ENABLED'),
    },
    {
      key: 'disabled',
      icon: 'i-lucide-circle-pause',
      value: list.filter(campaign => !campaign.enabled).length,
      label: t('CAMPAIGN.LIVE_CHAT.TABLE.TOTALS.DISABLED'),
    },
    {
      key: 'conversations',
      icon: 'i-lucide-messages-square',
      value: list.reduce(
        (sum, campaign) => sum + (campaign.conversations_count ?? 0),
        0
      ),
      label: t('CAMPAIGN.LIVE_CHAT.TABLE.TOTALS.CONVERSATIONS'),
    },
  ];
});

const headers = computed(() => [
  t('CAMPAIGN.LIVE_CHAT.TABLE.HEADERS.ID'),
  t('CAMPAIGN.LIVE_CHAT.TABLE.HEADERS.CAMPAIGN'),
  t('CAMPAIGN.LIVE_CHAT.TABLE.HEADERS.INBOX'),
  t('CAMPAIGN.LIVE_CHAT.TABLE.HEADERS.SENDER'),
  t('CAMPAIGN.LIVE_CHAT.TABLE.HEADERS.TRIGGER'),
  t('CAMPAIGN.LIVE_CHAT.TABLE.HEADERS.CONVERSATIONS'),
  t('CAMPAIGN.LIVE_CHAT.TABLE.HEADERS.STATUS'),
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
      <BaseTable :headers="headers" :items="rows" class="min-w-[60rem]">
        <template #row="{ items }">
          <BaseTableRow v-for="row in items" :key="row.campaign.id" :item="row">
            <BaseTableCell>
              <span class="font-mono text-xs tabular-nums text-n-slate-11">
                {{ `#${row.campaign.id}` }}
              </span>
            </BaseTableCell>
            <BaseTableCell>
              <div class="flex flex-col max-w-xs min-w-0 gap-0.5">
                <button
                  type="button"
                  class="font-medium truncate text-start text-n-slate-12 hover:text-n-brand hover:underline"
                  @click="emit('open', row.campaign)"
                >
                  {{ row.campaign.title }}
                </button>
                <span dir="auto" class="text-xs truncate text-n-slate-11">
                  {{ row.campaign.message }}
                </span>
              </div>
            </BaseTableCell>
            <BaseTableCell>
              <span class="text-n-slate-12">{{
                row.campaign.inbox?.name
              }}</span>
            </BaseTableCell>
            <BaseTableCell>
              <span class="text-n-slate-12">{{ row.sender }}</span>
            </BaseTableCell>
            <BaseTableCell>
              <div class="flex flex-col max-w-[14rem] min-w-0 gap-0.5">
                <span
                  dir="ltr"
                  class="text-xs truncate text-start text-n-slate-12"
                  :title="row.url"
                >
                  {{ row.url }}
                </span>
                <span class="text-xs text-n-slate-11">
                  {{
                    t('CAMPAIGN.LIVE_CHAT.TABLE.AFTER_SECONDS', {
                      count: row.delay,
                    })
                  }}
                </span>
              </div>
            </BaseTableCell>
            <BaseTableCell>
              <span class="tabular-nums text-n-slate-12">
                {{ formatNumber(row.campaign.conversations_count) }}
              </span>
            </BaseTableCell>
            <BaseTableCell>
              <LiveChatCampaignStatusBadge :enabled="row.campaign.enabled" />
            </BaseTableCell>
            <BaseTableCell align="end">
              <div class="flex items-center justify-end gap-1">
                <Button
                  variant="faded"
                  color="slate"
                  size="xs"
                  icon="i-lucide-file-text"
                  :label="t('CAMPAIGN.LIVE_CHAT.TABLE.DETAILS')"
                  @click="emit('open', row.campaign)"
                />
                <Button
                  variant="ghost"
                  color="slate"
                  size="xs"
                  icon="i-lucide-pencil"
                  :aria-label="t('CAMPAIGN.LIVE_CHAT.TABLE.EDIT')"
                  @click="emit('edit', row.campaign)"
                />
                <Button
                  variant="ghost"
                  color="ruby"
                  size="xs"
                  icon="i-lucide-trash-2"
                  :aria-label="t('CAMPAIGN.LIVE_CHAT.TABLE.DELETE')"
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
