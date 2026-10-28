<script setup>
// Custom (MyDesk): the conversation status under each card in the list, one colour per status.
// Each status also has its own icon, so it reads without the colour too. Colours follow DESIGN.md:
// open is what the employee acts on (brand violet), pending waits (amber), resolved is done
// (teal), snoozed is set aside (neutral).
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  status: { type: String, required: true },
});

const { t } = useI18n();

const STATUS_STYLES = {
  open: { icon: 'i-lucide-circle-dot', tone: 'bg-n-blue-3 text-n-blue-11' },
  pending: {
    icon: 'i-lucide-circle-pause',
    tone: 'bg-n-amber-3 text-n-amber-11',
  },
  snoozed: {
    icon: 'i-lucide-alarm-clock',
    tone: 'bg-n-slate-3 text-n-slate-11',
  },
  resolved: {
    icon: 'i-lucide-circle-check',
    tone: 'bg-n-teal-3 text-n-teal-11',
  },
};

const style = computed(() => STATUS_STYLES[props.status]);
</script>

<template>
  <span
    v-if="style"
    class="inline-flex items-center gap-1 h-5 px-2 rounded-full text-xs font-medium leading-none whitespace-nowrap"
    :class="style.tone"
  >
    <Icon :icon="style.icon" class="size-3 shrink-0" />
    {{ t(`CHAT_LIST.QUICK_FILTERS.${status}`) }}
  </span>
</template>
