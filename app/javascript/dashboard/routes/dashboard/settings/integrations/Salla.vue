<script setup>
// Custom (MyDesk): connect the account's Salla store (OAuth on accounts.salla.sa) and watch the order
// events it sends. These events are the base for automatic WhatsApp / SMS order notifications.
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useFunctionGetter, useStore } from 'dashboard/composables/store';
import sallaAPI from 'dashboard/api/integrations/salla';

import Integration from './Integration.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import BaseTable from 'dashboard/components-next/table/BaseTable.vue';
import BaseTableRow from 'dashboard/components-next/table/BaseTableRow.vue';
import BaseTableCell from 'dashboard/components-next/table/BaseTableCell.vue';

const props = defineProps({
  result: { type: String, default: '' },
});

const NO_VALUE = '—';
const SECTION_CLASSES =
  'flex flex-col gap-4 p-6 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak bg-n-card';

const { t, locale } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const integration = useFunctionGetter('integrations/getIntegration', 'salla');
const isLoaded = ref(false);
const isConnecting = ref(false);
const events = ref([]);
const isFetchingEvents = ref(false);
const eventsError = ref(false);
const resultMessage = ref('');

// Stores can be connected once the MyDesk Salla app keys are set in Super Admin
const isConfigured = computed(() => integration.value?.configured !== false);
const hook = computed(() => integration.value?.hooks?.[0] ?? null);
const storeInfo = computed(() => hook.value?.settings ?? {});
const isConnected = computed(() => !!hook.value);
const isActive = computed(() => !!hook.value?.status);

const dateFormat = computed(
  () =>
    new Intl.DateTimeFormat(locale.value, {
      dateStyle: 'medium',
      timeStyle: 'short',
    })
);
const formatDate = value => {
  if (!value) return NO_VALUE;
  const date =
    typeof value === 'number' ? new Date(value * 1000) : new Date(value);
  return dateFormat.value.format(date);
};

const storeInitial = computed(() =>
  (storeInfo.value.store_name || 'S').trim().charAt(0)
);

const eventLabels = computed(() => ({
  'order.created': t('INTEGRATION_SETTINGS.SALLA.EVENTS.TYPES.CREATED'),
  'order.updated': t('INTEGRATION_SETTINGS.SALLA.EVENTS.TYPES.UPDATED'),
  'order.status.updated': t(
    'INTEGRATION_SETTINGS.SALLA.EVENTS.TYPES.STATUS_UPDATED'
  ),
  'order.cancelled': t('INTEGRATION_SETTINGS.SALLA.EVENTS.TYPES.CANCELLED'),
  'order.refunded': t('INTEGRATION_SETTINGS.SALLA.EVENTS.TYPES.REFUNDED'),
  'order.deleted': t('INTEGRATION_SETTINGS.SALLA.EVENTS.TYPES.DELETED'),
  'order.payment.updated': t(
    'INTEGRATION_SETTINGS.SALLA.EVENTS.TYPES.PAYMENT_UPDATED'
  ),
  'order.shipment.created': t(
    'INTEGRATION_SETTINGS.SALLA.EVENTS.TYPES.SHIPMENT_CREATED'
  ),
}));
const EVENT_STYLES = {
  'order.created': 'bg-n-blue-3 text-n-blue-11',
  'order.status.updated': 'bg-n-blue-3 text-n-blue-11',
  'order.cancelled': 'bg-n-ruby-3 text-n-ruby-11',
  'order.refunded': 'bg-n-amber-3 text-n-amber-11',
  'order.deleted': 'bg-n-ruby-3 text-n-ruby-11',
};
const eventLabel = name =>
  eventLabels.value[name] ?? t('INTEGRATION_SETTINGS.SALLA.EVENTS.TYPES.OTHER');

const eventHeaders = computed(() => [
  t('INTEGRATION_SETTINGS.SALLA.EVENTS.HEADERS.EVENT'),
  t('INTEGRATION_SETTINGS.SALLA.EVENTS.HEADERS.ORDER'),
  t('INTEGRATION_SETTINGS.SALLA.EVENTS.HEADERS.STATUS'),
  t('INTEGRATION_SETTINGS.SALLA.EVENTS.HEADERS.CUSTOMER'),
  t('INTEGRATION_SETTINGS.SALLA.EVENTS.HEADERS.TIME'),
]);

const resultMessages = computed(() => ({
  denied: t('INTEGRATION_SETTINGS.SALLA.RESULT.DENIED'),
  store_taken: t('INTEGRATION_SETTINGS.SALLA.RESULT.STORE_TAKEN'),
  failed: t('INTEGRATION_SETTINGS.SALLA.RESULT.FAILED'),
}));

const fetchEvents = async () => {
  isFetchingEvents.value = true;
  try {
    const { data } = await sallaAPI.events();
    events.value = data.payload;
    eventsError.value = false;
  } catch {
    eventsError.value = true;
  } finally {
    isFetchingEvents.value = false;
  }
};

const connect = async () => {
  isConnecting.value = true;
  try {
    const { data } = await sallaAPI.authorizeUrl();
    window.location.assign(data.redirect_url);
  } catch {
    resultMessage.value = t('INTEGRATION_SETTINGS.SALLA.RESULT.ERROR');
    isConnecting.value = false;
  }
};

// Salla sends the merchant back with ?salla=connected|denied|store_taken|failed
const showConnectionResult = async () => {
  if (!props.result) return;
  if (props.result === 'connected') {
    useAlert(t('INTEGRATION_SETTINGS.SALLA.RESULT.CONNECTED'));
  } else {
    resultMessage.value =
      resultMessages.value[props.result] ?? resultMessages.value.failed;
  }
  const query = { ...route.query };
  delete query.salla;
  await router.replace({ query });
};

onMounted(async () => {
  await store.dispatch('integrations/get', 'salla');
  isLoaded.value = true;
  await showConnectionResult();
  if (isConnected.value) fetchEvents();
});
</script>

<template>
  <SettingsLayout :is-loading="!isLoaded">
    <template #header>
      <BaseSettingsHeader
        :title="t('INTEGRATION_SETTINGS.SALLA.HEADER')"
        description=""
        :back-button-label="t('INTEGRATION_SETTINGS.HEADER')"
      />
    </template>
    <template #body>
      <div class="flex flex-col gap-6">
        <Integration
          :integration-id="integration.id"
          :integration-name="integration.name"
          :integration-description="integration.description"
          :integration-enabled="isConnected"
          integration-action="disconnect"
          :delete-confirmation-text="{
            title: t('INTEGRATION_SETTINGS.SALLA.DELETE.TITLE'),
            message: t('INTEGRATION_SETTINGS.SALLA.DELETE.MESSAGE'),
          }"
        >
          <template #action>
            <Button
              icon="i-lucide-link"
              :label="t('INTEGRATION_SETTINGS.SALLA.CONNECT')"
              :is-loading="isConnecting"
              :disabled="!isConfigured"
              @click="connect"
            />
          </template>
        </Integration>

        <div
          v-if="!isConfigured && !isConnected"
          role="status"
          class="flex items-start gap-3 px-4 py-3 text-sm rounded-xl bg-n-amber-3 text-n-amber-11"
        >
          <span class="i-lucide-key-round size-4 mt-0.5 shrink-0" />
          <span>{{ t('INTEGRATION_SETTINGS.SALLA.NOT_CONFIGURED') }}</span>
        </div>

        <div
          v-if="resultMessage"
          role="alert"
          class="flex items-start gap-3 px-4 py-3 text-sm rounded-xl bg-n-ruby-3 text-n-ruby-11"
        >
          <span class="i-lucide-circle-alert size-4 mt-0.5 shrink-0" />
          <span>{{ resultMessage }}</span>
        </div>

        <section v-if="isConnected" :class="SECTION_CLASSES">
          <h2 class="text-heading-2 text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.SALLA.STORE.TITLE') }}
          </h2>
          <div class="flex flex-wrap items-center gap-4">
            <img
              v-if="storeInfo.store_avatar"
              :src="storeInfo.store_avatar"
              :alt="storeInfo.store_name"
              class="object-cover rounded-xl size-12 outline outline-1 -outline-offset-1 outline-n-weak"
            />
            <span
              v-else
              class="grid text-lg font-semibold rounded-xl size-12 place-items-center bg-n-blue-3 text-n-blue-11"
            >
              {{ storeInitial }}
            </span>
            <div class="flex flex-col min-w-0 gap-0.5">
              <span class="truncate text-heading-2 text-n-slate-12">
                {{ storeInfo.store_name || hook.reference_id }}
              </span>
              <a
                v-if="storeInfo.store_domain"
                :href="storeInfo.store_domain"
                target="_blank"
                rel="noopener noreferrer"
                dir="ltr"
                class="text-sm truncate text-start text-n-blue-11 hover:underline"
              >
                {{ storeInfo.store_domain }}
              </a>
            </div>
          </div>
          <dl
            class="grid grid-cols-[auto_minmax(0,1fr)] gap-x-6 gap-y-2 text-sm"
          >
            <dt class="text-n-slate-11">
              {{ t('INTEGRATION_SETTINGS.SALLA.STORE.CONNECTED_AT') }}
            </dt>
            <dd class="text-n-slate-12">
              {{ formatDate(storeInfo.connected_at) }}
            </dd>
            <dt class="text-n-slate-11">
              {{ t('INTEGRATION_SETTINGS.SALLA.STORE.VALID_UNTIL') }}
            </dt>
            <dd class="text-n-slate-12">
              {{ formatDate(storeInfo.expires_at) }}
            </dd>
          </dl>
          <div
            v-if="!isActive"
            class="flex flex-wrap items-center justify-between gap-3 px-4 py-3 text-sm rounded-xl bg-n-amber-3 text-n-amber-11"
          >
            <span>{{ t('INTEGRATION_SETTINGS.SALLA.STORE.DISABLED') }}</span>
            <Button
              size="sm"
              :label="t('INTEGRATION_SETTINGS.SALLA.RECONNECT')"
              :is-loading="isConnecting"
              @click="connect"
            />
          </div>
        </section>

        <section v-if="isConnected" :class="SECTION_CLASSES">
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div class="flex flex-col flex-1 gap-1 min-w-64">
              <h2 class="text-heading-2 text-n-slate-12">
                {{ t('INTEGRATION_SETTINGS.SALLA.EVENTS.TITLE') }}
              </h2>
              <p class="text-sm text-n-slate-11">
                {{ t('INTEGRATION_SETTINGS.SALLA.EVENTS.HINT') }}
              </p>
            </div>
            <Button
              variant="faded"
              color="slate"
              size="sm"
              icon="i-lucide-refresh-cw"
              :label="t('INTEGRATION_SETTINGS.SALLA.EVENTS.REFRESH')"
              :is-loading="isFetchingEvents"
              @click="fetchEvents"
            />
          </div>
          <div
            v-if="isFetchingEvents && !events.length"
            class="flex items-center justify-center py-10 text-n-slate-11"
          >
            <Spinner />
          </div>
          <div v-else class="overflow-x-auto">
            <BaseTable
              :headers="eventHeaders"
              :items="events"
              :loading="isFetchingEvents"
              :no-data-message="
                eventsError
                  ? t('INTEGRATION_SETTINGS.SALLA.EVENTS.ERROR')
                  : t('INTEGRATION_SETTINGS.SALLA.EVENTS.EMPTY')
              "
              class="min-w-[44rem]"
            >
              <template #row="{ items }">
                <BaseTableRow v-for="item in items" :key="item.id">
                  <BaseTableCell>
                    <span
                      class="inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-full whitespace-nowrap"
                      :class="
                        EVENT_STYLES[item.event] ??
                        'bg-n-alpha-2 text-n-slate-11'
                      "
                    >
                      {{ eventLabel(item.event) }}
                    </span>
                  </BaseTableCell>
                  <BaseTableCell>
                    <span
                      class="font-mono text-xs tabular-nums text-n-slate-12"
                    >
                      {{
                        item.order_reference
                          ? `#${item.order_reference}`
                          : NO_VALUE
                      }}
                    </span>
                  </BaseTableCell>
                  <BaseTableCell>
                    <span class="text-n-slate-12">
                      {{ item.status_name || NO_VALUE }}
                    </span>
                  </BaseTableCell>
                  <BaseTableCell>
                    <div class="flex flex-col min-w-0 gap-0.5">
                      <span class="truncate text-n-slate-12">
                        {{ item.customer_name || NO_VALUE }}
                      </span>
                      <span
                        v-if="item.customer_mobile"
                        dir="ltr"
                        class="text-xs tabular-nums text-start"
                      >
                        {{ item.customer_mobile }}
                      </span>
                    </div>
                  </BaseTableCell>
                  <BaseTableCell>
                    <span class="text-xs whitespace-nowrap">
                      {{ formatDate(item.created_at) }}
                    </span>
                  </BaseTableCell>
                </BaseTableRow>
              </template>
            </BaseTable>
          </div>
        </section>
      </div>
    </template>
  </SettingsLayout>
</template>
