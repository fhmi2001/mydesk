<script setup>
// Custom (MyDesk): one row of chips under the list header, in place of the status dropdown.
// A chip is a status (open, pending...) or a quick view of the open conversations (unread, unreplied).
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: { type: String, required: true },
  // Unread/unreplied ride on conversation_type, so they are hidden where the route already sets one
  hideQuickFilters: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const QUICK_FILTERS = ['unread', 'unattended'];
const CHIPS = [
  'all',
  'open',
  'unread',
  'unattended',
  'pending',
  'snoozed',
  'resolved',
];

const chips = computed(() =>
  CHIPS.filter(
    key => !(props.hideQuickFilters && QUICK_FILTERS.includes(key))
  ).map(key => ({ key, label: t(`CHAT_LIST.QUICK_FILTERS.${key}`) }))
);

const select = key => {
  if (key !== props.modelValue) emit('update:modelValue', key);
};
</script>

<template>
  <div
    role="toolbar"
    :aria-label="t('CHAT_LIST.QUICK_FILTERS.LABEL')"
    class="flex flex-wrap items-center gap-1.5 px-3 pb-2.5 flex-none w-0 min-w-full"
  >
    <!-- Every chip stays in view: the row wraps. w-0 + min-w-full keeps it from widening the list -->
    <button
      v-for="chip in chips"
      :key="chip.key"
      type="button"
      :aria-pressed="chip.key === modelValue"
      class="h-7 touch:h-9 px-3 rounded-full text-sm whitespace-nowrap flex-none outline outline-1 -outline-offset-1 transition-colors duration-150 focus-visible:ring-2 focus-visible:ring-n-blue-8 focus-visible:ring-offset-1"
      :class="
        chip.key === modelValue
          ? 'bg-n-blue-9 outline-n-blue-9 text-white font-medium'
          : 'outline-n-weak text-n-slate-12 hover:bg-n-alpha-2'
      "
      @click="select(chip.key)"
    >
      {{ chip.label }}
    </button>
  </div>
</template>
