<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import {
  smsCampaignStatus,
  SMS_CAMPAIGN_STATUS_STYLES,
} from './smsCampaignStatus';

const props = defineProps({
  campaign: { type: Object, required: true },
});

const { t } = useI18n();

const status = computed(() => smsCampaignStatus(props.campaign));
const label = computed(
  () =>
    ({
      scheduled: t('CAMPAIGN.SMS.TABLE.STATUS.SCHEDULED'),
      starting: t('CAMPAIGN.SMS.TABLE.STATUS.STARTING'),
      sending: t('CAMPAIGN.SMS.TABLE.STATUS.SENDING'),
      completed: t('CAMPAIGN.SMS.TABLE.STATUS.COMPLETED'),
      partial: t('CAMPAIGN.SMS.TABLE.STATUS.PARTIAL'),
      failed: t('CAMPAIGN.SMS.TABLE.STATUS.FAILED'),
    })[status.value]
);
</script>

<template>
  <span
    class="inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-full whitespace-nowrap"
    :class="SMS_CAMPAIGN_STATUS_STYLES[status]"
  >
    {{ label }}
  </span>
</template>
