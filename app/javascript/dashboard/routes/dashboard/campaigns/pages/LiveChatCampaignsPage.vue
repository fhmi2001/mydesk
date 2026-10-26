<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStoreGetters, useMapGetter } from 'dashboard/composables/store';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import LiveChatCampaignsTable from 'dashboard/components-next/Campaigns/LiveChatCampaign/LiveChatCampaignsTable.vue';
import ConfirmDeleteCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/ConfirmDeleteCampaignDialog.vue';
import LiveChatCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/LiveChatCampaignEmptyState.vue';

const { t } = useI18n();
const router = useRouter();
const getters = useStoreGetters();

const confirmDeleteCampaignDialogRef = ref(null);
const selectedCampaign = ref(null);

const uiFlags = useMapGetter('campaigns/getUIFlags');

const liveChatCampaigns = computed(
  () => getters['campaigns/getLiveChatCampaigns'].value
);

// Only the first load shows a spinner; later refreshes keep the table on screen
const isFirstLoad = computed(
  () => uiFlags.value.isFetching && !liveChatCampaigns.value?.length
);
const hasNoLiveChatCampaigns = computed(
  () => liveChatCampaigns.value?.length === 0 && !uiFlags.value.isFetching
);

// Custom (MyDesk): live chat campaigns are created, edited and viewed on full pages instead of dialogs
const openPage = (name, campaign) =>
  router.push({ name, params: campaign ? { campaignId: campaign.id } : {} });

const handleDelete = campaign => {
  selectedCampaign.value = campaign;
  confirmDeleteCampaignDialogRef.value.dialogRef.open();
};
</script>

<template>
  <CampaignLayout
    :header-title="t('CAMPAIGN.LIVE_CHAT.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.LIVE_CHAT.NEW_CAMPAIGN')"
    @click="openPage('campaigns_livechat_new')"
  >
    <div
      v-if="isFirstLoad"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <LiveChatCampaignsTable
      v-else-if="!hasNoLiveChatCampaigns"
      :campaigns="liveChatCampaigns"
      @open="campaign => openPage('campaigns_livechat_details', campaign)"
      @edit="campaign => openPage('campaigns_livechat_edit', campaign)"
      @delete="handleDelete"
    />
    <LiveChatCampaignEmptyState
      v-else
      :title="t('CAMPAIGN.LIVE_CHAT.EMPTY_STATE.TITLE')"
      :subtitle="t('CAMPAIGN.LIVE_CHAT.EMPTY_STATE.SUBTITLE')"
      class="pt-14"
    />
    <ConfirmDeleteCampaignDialog
      ref="confirmDeleteCampaignDialogRef"
      :selected-campaign="selectedCampaign"
    />
  </CampaignLayout>
</template>
