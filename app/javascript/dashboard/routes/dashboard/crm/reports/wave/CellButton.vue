<script setup>
// Custom (MyDesk): a number inside a report table that opens the deals behind it. A zero has nothing to open.
defineProps({
  cell: { type: Object, default: null },
  label: { type: String, required: true },
  title: { type: String, default: '' },
  empty: { type: Boolean, default: false },
});

const emit = defineEmits(['drill']);
</script>

<template>
  <button
    v-if="cell && !empty"
    type="button"
    class="tabular-nums rounded underline decoration-n-slate-7 decoration-dotted underline-offset-4 hover:text-n-brand hover:decoration-n-brand focus-visible:outline-2 focus-visible:outline-n-brand"
    dir="auto"
    @click="emit('drill', cell, title)"
  >
    {{ label }}
  </button>
  <span v-else class="tabular-nums text-n-slate-11" dir="auto">{{
    label
  }}</span>
</template>
