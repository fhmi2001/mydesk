<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useIntervalFn } from '@vueuse/core';
import {
  useStore,
  useStoreGetters,
  useMapGetter,
} from 'dashboard/composables/store';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import SMSCampaignsTable from 'dashboard/components-next/Campaigns/SMSCampaign/SMSCampaignsTable.vue';
import { isSmsCampaignInProgress } from 'dashboard/components-next/Campaigns/SMSCampaign/smsCampaignStatus';
import ConfirmDeleteCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/ConfirmDeleteCampaignDialog.vue';
import SMSCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/SMSCampaignEmptyState.vue';

// Custom (MyDesk): while a campaign is sending, refresh its progress on this interval
const REFRESH_INTERVAL_MS = 10000;

const { t } = useI18n();
const router = useRouter();
const store = useStore();
const getters = useStoreGetters();

const selectedCampaign = ref(null);

const uiFlags = useMapGetter('campaigns/getUIFlags');

const confirmDeleteCampaignDialogRef = ref(null);

const SMSCampaigns = computed(() => getters['campaigns/getSMSCampaigns'].value);

// Only the first load shows a spinner; background refreshes keep the table on screen
const isFirstLoad = computed(
  () => uiFlags.value.isFetching && !SMSCampaigns.value?.length
);
const hasNoSMSCampaigns = computed(
  () => SMSCampaigns.value?.length === 0 && !uiFlags.value.isFetching
);

const isAnySending = computed(() =>
  SMSCampaigns.value.some(campaign => isSmsCampaignInProgress(campaign))
);
const { pause, resume } = useIntervalFn(
  () => store.dispatch('campaigns/get'),
  REFRESH_INTERVAL_MS,
  { immediate: false }
);
watch(isAnySending, sending => (sending ? resume() : pause()), {
  immediate: true,
});

// Custom (MyDesk): new SMS campaigns open the full-page form instead of a dialog
const openNewCampaign = () => router.push({ name: 'campaigns_sms_new' });

const openDetails = campaign =>
  router.push({
    name: 'campaigns_sms_details',
    params: { campaignId: campaign.id },
  });

const handleDelete = campaign => {
  selectedCampaign.value = campaign;
  confirmDeleteCampaignDialogRef.value.dialogRef.open();
};
</script>

<template>
  <CampaignLayout
    :header-title="t('CAMPAIGN.SMS.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.SMS.NEW_CAMPAIGN')"
    @click="openNewCampaign"
  >
    <div
      v-if="isFirstLoad"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <SMSCampaignsTable
      v-else-if="!hasNoSMSCampaigns"
      :campaigns="SMSCampaigns"
      @open="openDetails"
      @delete="handleDelete"
    />
    <SMSCampaignEmptyState
      v-else
      :title="t('CAMPAIGN.SMS.EMPTY_STATE.TITLE')"
      :subtitle="t('CAMPAIGN.SMS.EMPTY_STATE.SUBTITLE')"
      class="pt-14"
    />
    <ConfirmDeleteCampaignDialog
      ref="confirmDeleteCampaignDialogRef"
      :selected-campaign="selectedCampaign"
    />
  </CampaignLayout>
</template>
