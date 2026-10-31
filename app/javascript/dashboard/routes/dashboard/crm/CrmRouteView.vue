<script setup>
// Custom (MyDesk): the frame around every Sales CRM page: loads status and pipelines once, and tells the
// user when the CRM is not switched on for the account.
import { onMounted, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const store = useStore();
const { t } = useI18n();

const enabled = useMapGetter('crm/status/isEnabled');
const statusFlags = useMapGetter('crm/status/getUIFlags');
const accountId = useMapGetter('getCurrentAccountId');

const load = async () => {
  await store.dispatch('crm/status/fetch');
  if (enabled.value)
    await store.dispatch('crm/pipelines/fetch').catch(() => {});
};

onMounted(load);
watch(accountId, load);

const isLoading = computed(() => !statusFlags.value.hasFetched);
</script>

<template>
  <div
    class="flex flex-col flex-1 h-full min-w-0 overflow-hidden bg-n-surface-1"
  >
    <div v-if="isLoading" class="flex items-center justify-center flex-1">
      <Spinner />
    </div>
    <div
      v-else-if="!enabled"
      class="flex flex-col items-center justify-center flex-1 gap-2 px-6 text-center"
    >
      <span class="i-lucide-briefcase size-8 text-n-slate-9" />
      <p class="text-body-main text-n-slate-11">
        {{ t('CRM.COMMON.DISABLED') }}
      </p>
    </div>
    <router-view v-else />
  </div>
</template>
