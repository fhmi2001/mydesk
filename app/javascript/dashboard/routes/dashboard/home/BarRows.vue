<script setup>
// Custom (MyDesk): ranked horizontal bars (charts.js rows: { id, name, sub?, value }); `label` is the text beside each
// bar. `sub` (a stage's pipeline) shows under the name; `barClassFor(row)` colours a bar by its own rule (the load
// chart's amber only for the overloaded).
import { computed } from 'vue';

const props = defineProps({
  rows: { type: Array, required: true },
  label: { type: Function, required: true },
  barClass: { type: String, required: true },
  barClassFor: { type: Function, default: null },
  noName: { type: String, required: true },
});

const bars = computed(() => {
  const max = Math.max(1, ...props.rows.map(row => row.value));
  return props.rows.map(row => ({
    id: row.id,
    name: row.name || props.noName,
    sub: row.sub || '',
    text: props.label(row),
    fill: props.barClassFor ? props.barClassFor(row) : props.barClass,
    width: `${(row.value / max) * 100}%`,
  }));
});
</script>

<template>
  <ul class="flex flex-col gap-3 m-0 list-none">
    <li
      v-for="bar in bars"
      :key="bar.id"
      class="grid items-center grid-cols-[minmax(0,9rem)_1fr_auto] gap-3"
    >
      <span class="flex flex-col min-w-0">
        <span
          class="text-body-main text-n-slate-12 line-clamp-2"
          :title="bar.name"
        >
          {{ bar.name }}
        </span>
        <span v-if="bar.sub" class="truncate text-label-small text-n-slate-11">
          {{ bar.sub }}
        </span>
      </span>
      <span class="h-2 overflow-hidden rounded-full bg-n-alpha-2">
        <span
          data-testid="bar-fill"
          class="block h-full rounded-full"
          :class="bar.fill"
          :style="{ width: bar.width }"
        />
      </span>
      <bdi class="text-label-small text-end tabular-nums text-n-slate-11">
        {{ bar.text }}
      </bdi>
    </li>
  </ul>
</template>
