<script>
import FeaturePlaceholder from './FeaturePlaceholder.vue';
export default {
  components: { FeaturePlaceholder },
  props: {
    message: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <!-- Custom (MyDesk): a brand-violet mark and a heading instead of the stock illustration -->
  <div class="flex flex-col items-center justify-center h-full px-6">
    <div
      class="relative grid mb-5 rounded-3xl size-20 place-items-center bg-n-violet-3 text-n-violet-11"
      aria-hidden="true"
    >
      <span class="i-lucide-messages-square size-9" />
      <span
        class="absolute grid rounded-full -bottom-1.5 -end-1.5 size-7 place-items-center bg-n-violet-9 text-white ring-4 ring-n-surface-1"
      >
        <span class="i-lucide-reply size-3.5" />
      </span>
    </div>
    <h2
      class="max-w-sm text-center text-heading-1 text-n-slate-12 text-balance"
    >
      {{ message }}
    </h2>
    <!-- Cmd bar, keyboard shortcuts placeholder -->
    <FeaturePlaceholder />
  </div>
</template>
