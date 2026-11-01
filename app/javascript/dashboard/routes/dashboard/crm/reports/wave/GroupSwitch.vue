<script setup>
// Custom (MyDesk): what a report groups by (owner, product, source, industry, region…), as a row of buttons. Left out
// of a printout: the section title already says the grouping.
defineProps({
  groups: { type: Array, required: true },
  active: { type: String, required: true },
  label: { type: String, required: true },
  labelFor: { type: Function, required: true },
});
const emit = defineEmits(['select']);
</script>

<template>
  <div
    class="inline-flex gap-1 p-1 mb-4 rounded-lg bg-n-alpha-1"
    role="group"
    :aria-label="label"
    data-print-hide
  >
    <button
      v-for="group in groups"
      :key="group"
      type="button"
      class="px-3 py-1 rounded-md text-label-small"
      :class="
        group === active
          ? 'bg-n-solid-1 text-n-slate-12 shadow-sm font-medium'
          : 'text-n-slate-11 hover:text-n-slate-12'
      "
      :aria-pressed="group === active"
      @click="emit('select', group)"
    >
      {{ labelFor(group) }}
    </button>
  </div>
</template>
