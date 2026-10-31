<script setup>
// Custom (MyDesk): notes on a deal
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { useCrmFormat } from '../shared/useCrmFormat';

defineProps({
  notes: { type: Array, required: true },
  isSaving: { type: Boolean, default: false },
  canDelete: { type: Function, default: () => false },
});
const emit = defineEmits(['add', 'delete']);
const { t } = useI18n();
const { dateTime } = useCrmFormat();
const draft = ref('');

const submit = () => {
  if (!draft.value.trim()) return;
  emit('add', draft.value.trim());
  draft.value = '';
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <form class="flex flex-col gap-2" @submit.prevent="submit">
      <TextArea
        v-model="draft"
        :placeholder="t('CRM.DEALS.DETAIL.NOTE_PLACEHOLDER')"
        :max-length="10000"
        auto-height
      />
      <div class="flex justify-end">
        <Button
          :label="t('CRM.DEALS.DETAIL.ADD_NOTE')"
          size="sm"
          :is-loading="isSaving"
          :disabled="!draft.trim()"
          type="submit"
        />
      </div>
    </form>
    <ul v-if="notes.length" class="flex flex-col gap-3">
      <li
        v-for="note in notes"
        :key="note.id"
        class="flex items-start gap-3 p-3 rounded-xl bg-n-slate-2"
      >
        <Avatar
          :name="note.user?.name || '?'"
          :src="note.user?.avatar_url"
          :size="24"
          rounded-full
        />
        <div class="flex-1 min-w-0">
          <p class="text-sm whitespace-pre-wrap text-n-slate-12">
            {{ note.content }}
          </p>
          <p class="mt-1 text-xs text-n-slate-10">
            {{ note.user?.name }} · {{ dateTime(note.created_at) }}
          </p>
        </div>
        <Button
          v-if="canDelete(note)"
          icon="i-lucide-trash-2"
          variant="ghost"
          size="xs"
          color="slate"
          @click="emit('delete', note)"
        />
      </li>
    </ul>
    <p v-else class="text-sm text-n-slate-11">
      {{ t('CRM.DEALS.DETAIL.NO_NOTES') }}
    </p>
  </div>
</template>
