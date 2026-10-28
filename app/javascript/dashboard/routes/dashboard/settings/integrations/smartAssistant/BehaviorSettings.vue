<script setup>
// Custom (MyDesk): how the assistant presents itself and when it hands over to the team
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  assistant: { type: Object, required: true },
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['save']);

const TONES = ['friendly', 'formal'];
const MAX_INSTRUCTIONS = 4000;
const MAX_HANDOFF_MESSAGE = 500;
const REPLIES_RANGE = { min: 1, max: 50 };
const FIELDS = [
  'name',
  'tone',
  'instructions',
  'handoff_when_unsure',
  'max_replies',
  'handoff_message',
];

const { t } = useI18n();

const pick = assistant =>
  Object.fromEntries(FIELDS.map(field => [field, assistant[field] ?? '']));

const form = ref(pick(props.assistant));
watch(
  () => props.assistant,
  value => {
    form.value = pick(value);
  }
);

const maxReplies = computed({
  get: () => String(form.value.max_replies),
  set: value => {
    form.value.max_replies = Number(value);
  },
});

const isValid = computed(
  () =>
    !!form.value.name.trim() &&
    Number.isInteger(form.value.max_replies) &&
    form.value.max_replies >= REPLIES_RANGE.min &&
    form.value.max_replies <= REPLIES_RANGE.max
);
const isDirty = computed(
  () => JSON.stringify(form.value) !== JSON.stringify(pick(props.assistant))
);

const save = () => {
  if (!isValid.value) return;
  emit('save', { ...form.value, name: form.value.name.trim() });
};
</script>

<template>
  <form class="flex flex-col gap-8" @submit.prevent="save">
    <section class="flex flex-col gap-5">
      <Input
        v-model="form.name"
        :label="t('SMART_ASSISTANT.BEHAVIOR.NAME')"
        :placeholder="assistant.default_name"
        :message="t('SMART_ASSISTANT.BEHAVIOR.NAME_HINT')"
        class="max-w-md"
      />

      <fieldset class="flex flex-col gap-2">
        <legend class="mb-2 text-sm font-medium text-n-slate-12">
          {{ t('SMART_ASSISTANT.BEHAVIOR.TONE') }}
        </legend>
        <div class="grid gap-2 sm:grid-cols-2">
          <label
            v-for="tone in TONES"
            :key="tone"
            class="flex items-start gap-3 p-3 rounded-xl outline outline-1 -outline-offset-1 cursor-pointer transition-colors has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-n-blue-9"
            :class="
              form.tone === tone
                ? 'bg-n-blue-3 outline-n-blue-6'
                : 'outline-n-weak hover:bg-n-alpha-2'
            "
          >
            <input
              v-model="form.tone"
              type="radio"
              name="tone"
              :value="tone"
              class="mt-0.5 accent-n-brand"
            />
            <span class="flex flex-col gap-0.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t(`SMART_ASSISTANT.BEHAVIOR.TONES.${tone}.LABEL`) }}
              </span>
              <span class="text-xs text-n-slate-11">
                {{ t(`SMART_ASSISTANT.BEHAVIOR.TONES.${tone}.DESCRIPTION`) }}
              </span>
            </span>
          </label>
        </div>
      </fieldset>

      <TextArea
        v-model="form.instructions"
        :label="t('SMART_ASSISTANT.BEHAVIOR.INSTRUCTIONS')"
        :placeholder="t('SMART_ASSISTANT.BEHAVIOR.INSTRUCTIONS_PLACEHOLDER')"
        :message="t('SMART_ASSISTANT.BEHAVIOR.INSTRUCTIONS_HINT')"
        :max-length="MAX_INSTRUCTIONS"
        show-character-count
        auto-height
        min-height="7rem"
        max-height="18rem"
      />
    </section>

    <section class="flex flex-col gap-5 pt-6 border-t border-n-weak">
      <div class="flex flex-col gap-1">
        <h3 class="text-heading-3 text-n-slate-12">
          {{ t('SMART_ASSISTANT.BEHAVIOR.HANDOFF_TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11">
          {{ t('SMART_ASSISTANT.BEHAVIOR.HANDOFF_HINT') }}
        </p>
      </div>
      <div class="flex items-start justify-between gap-4">
        <div class="flex flex-col gap-0.5">
          <span id="handoff-unsure" class="text-sm text-n-slate-12">
            {{ t('SMART_ASSISTANT.BEHAVIOR.UNSURE') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ t('SMART_ASSISTANT.BEHAVIOR.UNSURE_HINT') }}
          </span>
        </div>
        <Switch
          v-model="form.handoff_when_unsure"
          aria-labelledby="handoff-unsure"
          class="mt-0.5"
        />
      </div>
      <Input
        v-model="maxReplies"
        type="number"
        :min="String(REPLIES_RANGE.min)"
        :max="String(REPLIES_RANGE.max)"
        :label="t('SMART_ASSISTANT.BEHAVIOR.MAX_REPLIES')"
        class="max-w-xs"
      />
      <TextArea
        v-model="form.handoff_message"
        :label="t('SMART_ASSISTANT.BEHAVIOR.HANDOFF_MESSAGE')"
        :placeholder="t('SMART_ASSISTANT.BEHAVIOR.HANDOFF_MESSAGE_PLACEHOLDER')"
        :max-length="MAX_HANDOFF_MESSAGE"
        auto-height
      />
    </section>

    <div class="flex justify-end">
      <Button
        type="submit"
        :label="t('SMART_ASSISTANT.BEHAVIOR.SAVE')"
        :is-loading="isSaving"
        :disabled="!isValid || !isDirty"
      />
    </div>
  </form>
</template>
