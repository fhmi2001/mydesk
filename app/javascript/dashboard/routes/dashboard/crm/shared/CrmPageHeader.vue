<script setup>
// Custom (MyDesk): the title block of a Sales CRM page, with its actions on the opposite side
defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
});
</script>

<template>
  <header
    class="flex flex-wrap items-start justify-between gap-4 px-6 pt-6 pb-4"
  >
    <div class="min-w-0">
      <h1 class="text-heading-1 text-n-slate-12">{{ title }}</h1>
      <p v-if="subtitle" class="mt-1 text-body-main text-n-slate-11">
        {{ subtitle }}
      </p>
    </div>
    <div class="flex flex-wrap items-center gap-2">
      <slot name="actions" />
    </div>
  </header>
</template>
