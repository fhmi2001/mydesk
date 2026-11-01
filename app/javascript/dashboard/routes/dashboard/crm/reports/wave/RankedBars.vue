<script setup>
// Custom (MyDesk): groups ranked as horizontal bars (a lost reason, a competitor, a source…). rows:
// [{ key, name, count, total_cents, cell }]; the count opens the deals behind it. `measure(row)` overrides the bar's
// length (a rate, say) and `label(row)` the text beside it.
import { computed } from 'vue';
import { useCrmFormat } from '../../shared/useCrmFormat';
import CellButton from './CellButton.vue';

const props = defineProps({
  rows: { type: Array, required: true },
  currency: { type: String, default: 'SAR' },
  noName: { type: String, required: true },
  emptyLabel: { type: String, required: true },
  barClass: { type: String, default: 'bg-n-iris-9' },
  measure: { type: Function, default: null },
  label: { type: Function, default: null },
});
const emit = defineEmits(['drill']);

const { money, number } = useCrmFormat();

const size = row => (props.measure ? props.measure(row) : row.count) || 0;
const max = computed(() => Math.max(1, ...props.rows.map(size)));
const name = row => row.name || props.noName;
</script>

<template>
  <ul v-if="rows.length" class="flex flex-col gap-3">
    <li
      v-for="row in rows"
      :key="String(row.key ?? row.id ?? 'none')"
      class="text-body-main"
    >
      <div class="flex items-center justify-between gap-3">
        <span class="truncate text-n-slate-12">{{ name(row) }}</span>
        <span class="text-n-slate-11 shrink-0">
          <template v-if="label">
            <bdi class="tabular-nums">{{ label(row) }}</bdi>
            ·
          </template>
          <CellButton
            :cell="row.cell"
            :label="number(row.count)"
            :title="name(row)"
            @drill="(cell, title) => emit('drill', cell, title)"
          />
          <template v-if="row.total_cents !== undefined">
            ·
            <bdi class="tabular-nums">{{
              money(row.total_cents, currency)
            }}</bdi>
          </template>
        </span>
      </div>
      <div class="h-1.5 mt-1 rounded-full bg-n-slate-3" aria-hidden="true">
        <div
          class="h-full rounded-full"
          :class="barClass"
          :style="{ width: `${(size(row) / max) * 100}%` }"
        />
      </div>
    </li>
  </ul>
  <p v-else class="text-body-main text-n-slate-11">{{ emptyLabel }}</p>
</template>
