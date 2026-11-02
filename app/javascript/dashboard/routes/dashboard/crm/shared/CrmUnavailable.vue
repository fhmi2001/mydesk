<script setup>
// Custom (MyDesk): shown when the CRM API is down; conversations keep working around it
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({ isLoading: { type: Boolean, default: false } });
const emit = defineEmits(['retry']);
const { t } = useI18n();
</script>

<template>
  <div
    class="flex flex-col items-center justify-center gap-3 px-6 py-16 text-center"
    role="alert"
  >
    <span class="i-lucide-cloud-off size-8 text-n-slate-9" />
    <h2 class="text-heading-2 text-n-slate-12">
      {{ t('CRM.COMMON.UNAVAILABLE_TITLE') }}
    </h2>
    <p class="text-body-main text-n-slate-11">
      {{ t('CRM.COMMON.UNAVAILABLE_BODY') }}
    </p>
    <Button
      :label="t('CRM.COMMON.RETRY')"
      :is-loading="isLoading"
      icon="i-lucide-refresh-cw"
      size="sm"
      @click="emit('retry')"
    />
  </div>
</template>
