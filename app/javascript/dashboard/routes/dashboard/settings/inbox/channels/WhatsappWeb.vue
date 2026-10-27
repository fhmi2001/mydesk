<script setup>
// Custom (MyDesk): add a WhatsApp number by QR code (WhatsApp Web). Step 1 names the inbox and creates
// it on the gateway; step 2 shows the QR code until the phone is linked.
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import whatsappWebChannel from 'dashboard/api/channel/whatsappWebChannel';
import PageHeader from '../../SettingsSubPageHeader.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import WhatsappWebConnection from '../components/WhatsappWebConnection.vue';

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const isConfigured = ref(true);
const inboxName = ref('');
const isCreating = ref(false);
const inbox = ref(null);
const isConnected = ref(false);

const canCreate = computed(() => inboxName.value.trim().length > 0);

const goToAgents = () =>
  router.replace({
    name: 'settings_inboxes_add_agents',
    params: { page: 'new', inbox_id: inbox.value.id },
  });

const createInbox = async () => {
  if (!canCreate.value) return;
  isCreating.value = true;
  try {
    const { data } = await whatsappWebChannel.createInbox(
      inboxName.value.trim()
    );
    inbox.value = data;
    store.dispatch('inboxes/get');
  } catch (error) {
    useAlert(
      error.response?.data?.code === 'name_taken'
        ? t('INBOX_MGMT.WHATSAPP_WEB.NAME.TAKEN')
        : t('INBOX_MGMT.WHATSAPP_WEB.ERROR')
    );
  } finally {
    isCreating.value = false;
  }
};

onMounted(async () => {
  try {
    const { data } = await whatsappWebChannel.getStatus();
    isConfigured.value = data.configured;
  } catch {
    isConfigured.value = false;
  }
});
</script>

<template>
  <div class="w-full h-full col-span-6 p-6">
    <PageHeader
      :header-title="t('INBOX_MGMT.WHATSAPP_WEB.TITLE')"
      :header-content="t('INBOX_MGMT.WHATSAPP_WEB.DESC')"
    />

    <p
      v-if="!isConfigured"
      class="p-4 text-sm rounded-xl bg-n-amber-3 text-n-amber-12"
    >
      {{ t('INBOX_MGMT.WHATSAPP_WEB.NOT_CONFIGURED') }}
    </p>

    <form
      v-else-if="!inbox"
      class="flex flex-col max-w-lg gap-4"
      @submit.prevent="createInbox"
    >
      <Input
        v-model="inboxName"
        :label="t('INBOX_MGMT.WHATSAPP_WEB.NAME.LABEL')"
        :placeholder="t('INBOX_MGMT.WHATSAPP_WEB.NAME.PLACEHOLDER')"
        :message="t('INBOX_MGMT.WHATSAPP_WEB.NAME.HELP')"
      />
      <p class="text-xs text-n-slate-11">
        {{ t('INBOX_MGMT.WHATSAPP_WEB.WARNING') }}
      </p>
      <div>
        <NextButton
          type="submit"
          solid
          blue
          :disabled="!canCreate"
          :is-loading="isCreating"
          :label="t('INBOX_MGMT.WHATSAPP_WEB.SUBMIT')"
        />
      </div>
    </form>

    <div v-else class="flex flex-col max-w-3xl gap-4">
      <WhatsappWebConnection
        :inbox-id="inbox.id"
        @connected="isConnected = true"
      />
      <div class="flex flex-wrap gap-2">
        <NextButton
          v-if="isConnected"
          solid
          blue
          :label="t('INBOX_MGMT.WHATSAPP_WEB.CONTINUE')"
          @click="goToAgents"
        />
        <NextButton
          v-else
          ghost
          slate
          :label="t('INBOX_MGMT.WHATSAPP_WEB.LATER')"
          @click="goToAgents"
        />
      </div>
    </div>
  </div>
</template>
