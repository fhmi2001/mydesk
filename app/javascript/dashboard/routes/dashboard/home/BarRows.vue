<script setup>
// Custom (MyDesk): ranked horizontal bars (charts.js rows: { id, name, value }); `label` is the text beside each bar
import { computed } from 'vue';

const props = defineProps({
  rows: { type: Array, required: true },
  label: { type: Function, required: true },
  barClass: { type: String, required: true },
  noName: { type: String, required: true },
});

const bars = computed(() => {
  const max = Math.max(1, ...props.rows.map(row => row.value));
  return props.rows.map(row => ({
    id: row.id,
    name: row.name || props.noName,
    text: props.label(row),
    width: `${(row.value / max) * 100}%`,
  }));
});
</script>

<template>
  <ul class="flex flex-col gap-3 m-0 list-none">
    <li
      v-for="bar in bars"
      :key="bar.id"
      class="grid items-center grid-cols-[7rem_1fr_auto] gap-3"
    >
      <span class="truncate text-body-main text-n-slate-12">{{
        bar.name
      }}</span>
      <span class="h-2 overflow-hidden rounded-full bg-n-alpha-2">
        <span
          class="block h-full rounded-full"
          :class="barClass"
          :style="{ width: bar.width }"
        />
      </span>
      <bdi class="text-label-small text-end tabular-nums text-n-slate-11">
        {{ bar.text }}
      </bdi>
    </li>
  </ul>
</template>
