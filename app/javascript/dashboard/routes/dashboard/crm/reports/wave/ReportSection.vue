<script setup>
// Custom (MyDesk): a titled card inside a report
defineProps({
  title: { type: String, required: true },
  note: { type: String, default: '' },
  // The note only helps on screen ("click a bar"): a printout leaves it out
  screenNote: { type: Boolean, default: false },
});
</script>

<template>
  <section
    class="p-5 min-w-0 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
  >
    <div class="flex flex-wrap items-baseline justify-between gap-2 mb-4">
      <h2 class="text-heading-3 text-n-slate-12">{{ title }}</h2>
      <p
        v-if="note"
        class="text-label-small text-n-slate-10"
        :data-print-hide="screenNote || undefined"
      >
        {{ note }}
      </p>
    </div>
    <slot />
  </section>
</template>
