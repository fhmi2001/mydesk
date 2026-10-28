<script setup>
// Custom (MyDesk): the inboxes the assistant answers on, and whether it answers always or only after hours
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';

import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  assistant: { type: Object, required: true },
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['save']);

const MODES = ['always', 'outside_working_hours'];

const { t } = useI18n();
const inboxes = useMapGetter('inboxes/getInboxes');

const selected = ref([...props.assistant.inbox_ids]);
const replyMode = ref(props.assistant.reply_mode);
watch(
  () => props.assistant,
  value => {
    selected.value = [...value.inbox_ids];
    replyMode.value = value.reply_mode;
  }
);

const isSelected = id => selected.value.includes(id);
const toggle = (id, checked) => {
  selected.value = checked
    ? [...selected.value, id]
    : selected.value.filter(item => item !== id);
};

const isDirty = computed(
  () =>
    replyMode.value !== props.assistant.reply_mode ||
    [...selected.value].sort().join() !==
      [...props.assistant.inbox_ids].sort().join()
);

const save = () =>
  emit('save', { inbox_ids: selected.value, reply_mode: replyMode.value });
</script>

<template>
  <form class="flex flex-col gap-8" @submit.prevent="save">
    <section class="flex flex-col gap-3">
      <div class="flex flex-col gap-1">
        <h3 class="text-heading-3 text-n-slate-12">
          {{ t('SMART_ASSISTANT.CHANNELS.TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11">
          {{ t('SMART_ASSISTANT.CHANNELS.HINT') }}
        </p>
      </div>
      <p v-if="!inboxes.length" class="text-sm text-n-slate-11">
        {{ t('SMART_ASSISTANT.CHANNELS.EMPTY') }}
      </p>
      <div v-else class="grid gap-2 sm:grid-cols-2">
        <label
          v-for="inbox in inboxes"
          :key="inbox.id"
          class="flex items-center gap-3 px-3 py-2.5 rounded-xl outline outline-1 -outline-offset-1 cursor-pointer transition-colors touch:min-h-11"
          :class="
            isSelected(inbox.id)
              ? 'bg-n-blue-3 outline-n-blue-6'
              : 'outline-n-weak hover:bg-n-alpha-2'
          "
        >
          <Checkbox
            :model-value="isSelected(inbox.id)"
            @update:model-value="checked => toggle(inbox.id, checked)"
          />
          <ChannelIcon :inbox="inbox" class="size-4 shrink-0 text-n-slate-11" />
          <span class="flex-1 min-w-0 text-sm truncate text-n-slate-12">
            {{ inbox.name }}
          </span>
        </label>
      </div>
    </section>

    <fieldset class="flex flex-col gap-2 pt-6 border-t border-n-weak">
      <legend class="mb-2 text-heading-3 text-n-slate-12">
        {{ t('SMART_ASSISTANT.CHANNELS.WHEN_TITLE') }}
      </legend>
      <div class="grid gap-2 sm:grid-cols-2">
        <label
          v-for="mode in MODES"
          :key="mode"
          class="flex items-start gap-3 p-3 rounded-xl outline outline-1 -outline-offset-1 cursor-pointer transition-colors has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-n-blue-9"
          :class="
            replyMode === mode
              ? 'bg-n-blue-3 outline-n-blue-6'
              : 'outline-n-weak hover:bg-n-alpha-2'
          "
        >
          <input
            v-model="replyMode"
            type="radio"
            name="reply-mode"
            :value="mode"
            class="mt-0.5 accent-n-brand"
          />
          <span class="flex flex-col gap-0.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t(`SMART_ASSISTANT.CHANNELS.MODES.${mode}.LABEL`) }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{ t(`SMART_ASSISTANT.CHANNELS.MODES.${mode}.DESCRIPTION`) }}
            </span>
          </span>
        </label>
      </div>
      <p
        v-if="replyMode === 'outside_working_hours'"
        class="flex items-start gap-2 mt-1 text-xs text-n-slate-11"
      >
        <span
          class="i-lucide-clock size-3.5 mt-px shrink-0"
          aria-hidden="true"
        />
        {{ t('SMART_ASSISTANT.CHANNELS.WORKING_HOURS_HINT') }}
      </p>
    </fieldset>

    <div class="flex justify-end">
      <Button
        type="submit"
        :label="t('SMART_ASSISTANT.BEHAVIOR.SAVE')"
        :is-loading="isSaving"
        :disabled="!isDirty"
      />
    </div>
  </form>
</template>
