<script setup>
// Custom (MyDesk): link a WhatsApp number by scanning its QR code inside the platform. Polls the gateway
// while waiting; the code rotates on its own, and polling stops after a few minutes without a scan.
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import whatsappWebChannel from 'dashboard/api/channel/whatsappWebChannel';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  inboxId: { type: [Number, String], required: true },
  // Settings page: when linked, offer to unlink instead of finishing setup
  manage: { type: Boolean, default: false },
});

const emit = defineEmits(['connected']);

const POLL_INTERVAL = 4000;
const WAIT_LIMIT = 3 * 60 * 1000;

const { t } = useI18n();

const state = ref(null);
const qrCode = ref(null);
const isExpired = ref(false);
const isDisconnecting = ref(false);
let timer = null;
let startedAt = 0;

const isConnected = computed(() => state.value === 'open');
const isLoading = computed(() => state.value === null && !isExpired.value);

const steps = computed(() => [
  t('INBOX_MGMT.WHATSAPP_WEB.QR.STEP_OPEN'),
  t('INBOX_MGMT.WHATSAPP_WEB.QR.STEP_LINKED'),
  t('INBOX_MGMT.WHATSAPP_WEB.QR.STEP_SCAN'),
]);

const stopPolling = () => {
  clearTimeout(timer);
  timer = null;
};

const poll = async () => {
  try {
    const { data } = await whatsappWebChannel.getConnection(props.inboxId);
    state.value = data.state;
    qrCode.value = data.qr_code;
    if (isConnected.value) {
      stopPolling();
      emit('connected');
      return;
    }
  } catch {
    useAlert(t('INBOX_MGMT.WHATSAPP_WEB.ERROR'));
  }

  if (Date.now() - startedAt > WAIT_LIMIT) {
    isExpired.value = true;
    qrCode.value = null;
    stopPolling();
    return;
  }
  timer = setTimeout(poll, POLL_INTERVAL);
};

const startPolling = () => {
  stopPolling();
  isExpired.value = false;
  startedAt = Date.now();
  poll();
};

const disconnect = async () => {
  isDisconnecting.value = true;
  try {
    await whatsappWebChannel.disconnect(props.inboxId);
    state.value = 'close';
    startPolling();
  } catch {
    useAlert(t('INBOX_MGMT.WHATSAPP_WEB.ERROR'));
  } finally {
    isDisconnecting.value = false;
  }
};

onMounted(startPolling);
onBeforeUnmount(stopPolling);
</script>

<template>
  <div
    class="rounded-xl outline outline-1 -outline-offset-1 outline-n-weak bg-n-solid-2"
  >
    <div
      v-if="isConnected"
      class="flex flex-wrap items-center justify-between gap-4 p-5"
    >
      <div class="flex items-center gap-3">
        <span
          class="flex items-center justify-center rounded-full size-10 bg-n-teal-3 text-n-teal-11"
          aria-hidden="true"
        >
          <span class="i-lucide-check size-5" />
        </span>
        <div>
          <p class="text-sm font-medium text-n-slate-12">
            {{ t('INBOX_MGMT.WHATSAPP_WEB.CONNECTED.TITLE') }}
          </p>
          <p class="text-sm text-n-slate-11">
            {{ t('INBOX_MGMT.WHATSAPP_WEB.CONNECTED.DESCRIPTION') }}
          </p>
        </div>
      </div>
      <NextButton
        v-if="manage"
        faded
        ruby
        sm
        icon="i-lucide-unlink"
        :is-loading="isDisconnecting"
        :label="t('INBOX_MGMT.WHATSAPP_WEB.DISCONNECT')"
        @click="disconnect"
      />
    </div>

    <div v-else class="grid gap-6 p-5 md:grid-cols-[1fr_auto] md:items-center">
      <div class="flex flex-col gap-4">
        <div class="flex items-center gap-2" role="status" aria-live="polite">
          <span
            class="rounded-full size-2"
            :class="isExpired ? 'bg-n-slate-9' : 'bg-n-amber-9 animate-pulse'"
            aria-hidden="true"
          />
          <span class="text-sm font-medium text-n-slate-12">
            {{
              isExpired
                ? t('INBOX_MGMT.WHATSAPP_WEB.QR.EXPIRED')
                : t('INBOX_MGMT.WHATSAPP_WEB.QR.WAITING')
            }}
          </span>
        </div>
        <ol class="flex flex-col gap-3 text-sm text-n-slate-11">
          <li v-for="(step, index) in steps" :key="step" class="flex gap-3">
            <span
              class="flex items-center justify-center text-xs font-medium rounded-full shrink-0 size-6 bg-n-alpha-2 text-n-slate-12 tabular-nums"
              aria-hidden="true"
            >
              {{ index + 1 }}
            </span>
            <span>{{ step }}</span>
          </li>
        </ol>
        <p class="text-xs text-n-slate-11">
          {{ t('INBOX_MGMT.WHATSAPP_WEB.QR.NOTE') }}
        </p>
      </div>

      <!-- QR codes need a light, high-contrast background to scan, also in dark mode -->
      <div
        class="flex items-center justify-center justify-self-center p-3 bg-white rounded-xl outline outline-1 -outline-offset-1 outline-n-weak size-64"
      >
        <img
          v-if="qrCode"
          :src="qrCode"
          :alt="t('INBOX_MGMT.WHATSAPP_WEB.QR.ALT')"
          class="size-full"
        />
        <NextButton
          v-else-if="isExpired"
          faded
          slate
          sm
          icon="i-lucide-refresh-cw"
          :label="t('INBOX_MGMT.WHATSAPP_WEB.QR.REFRESH')"
          @click="startPolling"
        />
        <Spinner
          v-else-if="isLoading || !qrCode"
          :size="28"
          class="text-n-brand"
        />
      </div>
    </div>
  </div>
</template>
