<script setup>
// Custom (MyDesk): one headline number of a report. With a `cell` it is a button that opens the deals behind it; with
// a delta it says how it moved against the previous period.
import { COLORS, TONE_TEXT } from './reportColors';
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  label: { type: String, required: true },
  value: { type: String, required: true },
  note: { type: String, default: '' },
  delta: { type: Object, default: null },
  cell: { type: Object, default: null },
  tone: { type: String, default: '' },
});

const emit = defineEmits(['drill']);
const { t } = useI18n();

const toneClass = computed(
  () =>
    ({
      ...TONE_TEXT,
      bad: COLORS.lost.text,
    })[props.tone] || 'text-n-slate-12'
);
const deltaClass = computed(() => {
  if (props.delta?.tone === 'up') return COLORS.won.text;
  if (props.delta?.tone === 'down') return COLORS.lost.text;
  return 'text-n-slate-11';
});
</script>

<template>
  <component
    :is="cell ? 'button' : 'div'"
    :type="cell ? 'button' : undefined"
    class="flex flex-col items-start p-4 text-start rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
    :class="{
      'hover:bg-n-alpha-1 focus-visible:outline-2 focus-visible:outline-n-brand cursor-pointer transition-colors':
        cell,
    }"
    :aria-label="
      cell
        ? `${label}: ${value}. ${t('CRM.REPORTS.WAVE.OPEN_DEALS')}`
        : undefined
    "
    @click="cell && emit('drill', cell, label)"
  >
    <span class="text-label-small text-n-slate-11">{{ label }}</span>
    <span
      class="mt-1 text-lg font-semibold tabular-nums"
      :class="toneClass"
      dir="auto"
    >
      {{ value }}
    </span>
    <span v-if="note" class="mt-1 text-label-small text-n-slate-11">
      {{ note }}
    </span>
    <span
      v-if="delta?.label"
      class="mt-1 text-label-small tabular-nums"
      :class="deltaClass"
    >
      <bdi>{{ delta.label }}</bdi>
      <span class="sr-only">{{ t('CRM.REPORTS.VS_PREVIOUS') }}</span>
    </span>
  </component>
</template>
