<script setup>
import { useI18n } from 'vue-i18n';

defineProps({
  enabled: { type: Boolean, default: false },
});

const { t } = useI18n();
</script>

<template>
  <span
    class="inline-flex items-center gap-1.5 px-2 py-0.5 text-xs font-medium rounded-full whitespace-nowrap"
    :class="
      enabled ? 'bg-n-teal-3 text-n-teal-11' : 'bg-n-alpha-2 text-n-slate-11'
    "
  >
    <span
      class="rounded-full size-1.5"
      :class="enabled ? 'bg-n-teal-9' : 'bg-n-slate-8'"
    />
    {{
      enabled
        ? t('CAMPAIGN.LIVE_CHAT.CARD.STATUS.ENABLED')
        : t('CAMPAIGN.LIVE_CHAT.CARD.STATUS.DISABLED')
    }}
  </span>
</template>
