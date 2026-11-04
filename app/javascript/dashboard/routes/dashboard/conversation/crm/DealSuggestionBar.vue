<script setup>
// Custom (MyDesk): the conversation's «صفقة جديدة» suggestion, right above the reply box so it is seen while replying,
// even with the side panel closed (CONVERSATION_SALES_PLAN.md, أ2 and ج1). It arrives live (useSuggestionArrivals),
// «إنشاء صفقة» opens the deal form filled from it (saving the deal accepts it), «تجاهل» dismisses it.
// Rendered by Chatwoot's MessagesView with one marked line; nothing shows when the Sales section is off.
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { crmConversationsAPI, crmSuggestionsAPI } from 'dashboard/api/crm';
import DealSuggestionCard from './DealSuggestionCard.vue';
import { useSuggestionArrivals } from './useSuggestionArrivals';

const props = defineProps({
  chat: { type: Object, default: null },
});
const { t } = useI18n();
const router = useRouter();
const { accountScopedRoute } = useAccount();
const enabled = useMapGetter('crm/status/isEnabled');

const suggestions = ref([]);
const conversationId = computed(() => props.chat?.id || null);
const shown = computed(() =>
  suggestions.value.filter(s => s.kind === 'new_deal')
);

const load = async () => {
  if (!enabled.value || !conversationId.value) {
    suggestions.value = [];
    return;
  }
  try {
    const { data } = await crmConversationsAPI.show(conversationId.value);
    suggestions.value = data.suggestions || [];
  } catch {
    // The conversation works without it
    suggestions.value = [];
  }
};
watch(() => [conversationId.value, enabled.value], load, { immediate: true });
useSuggestionArrivals(() => conversationId.value, load);

const create = suggestion => {
  const { product, summary, title } = suggestion.content || {};
  const contact = props.chat?.meta?.sender || {};
  router.push(
    accountScopedRoute(
      'crm_deal_new',
      {},
      {
        contact_id: contact.id,
        contact_name: contact.name || undefined,
        assignee_id: props.chat?.meta?.assignee?.id || undefined,
        conversation_id: conversationId.value,
        title: product || title || undefined,
        description: summary || undefined,
        suggestion_id: suggestion.id,
        return_to: router.currentRoute.value.fullPath,
      }
    )
  );
};

const dismiss = async suggestion => {
  try {
    await crmSuggestionsAPI.dismiss(suggestion.id);
    suggestions.value = suggestions.value.filter(s => s.id !== suggestion.id);
  } catch {
    useAlert(t('CRM.COMMON.ERROR'));
  }
};
</script>

<template>
  <div v-if="shown.length" class="flex flex-col gap-2 mx-2 mb-2">
    <DealSuggestionCard
      v-for="suggestion in shown"
      :key="suggestion.id"
      :suggestion="suggestion"
      inline
      @create="create"
      @dismiss="dismiss"
    />
  </div>
</template>
