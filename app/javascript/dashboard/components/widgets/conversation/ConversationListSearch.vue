<script setup>
// Custom (MyDesk): below md the sidebar, and the search in it, sit behind the menu button, so the
// conversation list offers search itself. It opens the full search page with the query.
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';

const router = useRouter();
const { t } = useI18n();
const query = ref('');

const search = () => {
  const q = query.value.trim();
  router.push({ name: 'search', query: q ? { q } : {} });
};
</script>

<template>
  <form role="search" class="px-3 pb-2 md:hidden" @submit.prevent="search">
    <label class="relative flex items-center">
      <span class="sr-only">{{ t('CHAT_LIST.LIST_SEARCH.LABEL') }}</span>
      <span
        class="absolute pointer-events-none i-lucide-search start-3 size-4 text-n-slate-11"
        aria-hidden="true"
      />
      <input
        v-model="query"
        type="search"
        enterkeyhint="search"
        :placeholder="t('CHAT_LIST.LIST_SEARCH.PLACEHOLDER')"
        class="!mb-0 !ps-9 touch:!h-11 text-body-main placeholder:text-n-slate-11"
      />
    </label>
  </form>
</template>
