<script setup>
// Custom (MyDesk): one chart on the home screen. Its title opens the full report; a source that failed or holds
// nothing says so in its own card.
import { useI18n } from 'vue-i18n';

defineProps({
  title: { type: String, required: true },
  to: { type: Object, default: null },
  failed: { type: Boolean, default: false },
  empty: { type: Boolean, default: false },
});

const { t } = useI18n();
</script>

<template>
  <section
    class="relative flex flex-col p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
    :class="{ 'hover:bg-n-alpha-1': to }"
  >
    <h2 class="mb-4 text-heading-3 text-n-slate-12">
      <router-link
        v-if="to"
        :to="to"
        class="after:absolute after:inset-0 after:rounded-xl focus-visible:outline-none focus-visible:after:outline focus-visible:after:outline-2 focus-visible:after:outline-n-brand"
      >
        {{ title }}
      </router-link>
      <template v-else>{{ title }}</template>
    </h2>
    <p v-if="failed" class="py-8 text-center text-label-small text-n-slate-11">
      {{ t('HOME.LOAD_FAILED') }}
    </p>
    <p
      v-else-if="empty"
      class="py-8 text-center text-label-small text-n-slate-11"
    >
      {{ t('HOME.CHARTS.EMPTY') }}
    </p>
    <slot v-else />
  </section>
</template>
