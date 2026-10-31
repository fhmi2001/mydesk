<script setup>
// Custom (MyDesk): edit one pipeline: name, currency (until it has deals), stages by drag, remove with a
// target stage when the removed stage still holds deals
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { validateStages } from '../shared/dealHelpers';

const props = defineProps({
  pipeline: { type: Object, required: true },
  currencies: {
    type: Array,
    default: () => [
      'SAR',
      'AED',
      'USD',
      'EUR',
      'KWD',
      'BHD',
      'QAR',
      'OMR',
      'EGP',
      'JOD',
    ],
  },
  stageDealCounts: { type: Object, default: () => ({}) },
  isSaving: { type: Boolean, default: false },
  canDelete: { type: Boolean, default: false },
});
const emit = defineEmits(['save', 'delete']);
const { t } = useI18n();

const name = ref('');
const currency = ref('SAR');
const stages = ref([]);
const removed = ref([]); // { stage, targetId }
const errors = ref([]);
const moveDialog = ref(null);
const pendingRemoval = ref(null);
const moveTarget = ref('');

const load = () => {
  name.value = props.pipeline.name;
  currency.value = props.pipeline.currency;
  stages.value = props.pipeline.stages.map(s => ({ ...s, uiKey: s.id }));
  removed.value = [];
  errors.value = [];
};
watch(() => props.pipeline, load, { immediate: true, deep: true });

const kindOptions = computed(() =>
  ['open', 'won', 'lost'].map(k => ({
    value: k,
    label: t(`CRM.SETTINGS.KINDS.${k}`),
  }))
);
const currencyOptions = computed(() =>
  props.currencies.map(c => ({ value: c, label: c }))
);
const dirty = computed(
  () =>
    name.value !== props.pipeline.name ||
    currency.value !== props.pipeline.currency ||
    removed.value.length > 0 ||
    JSON.stringify(stages.value.map(({ uiKey, ...s }) => s)) !==
      JSON.stringify(props.pipeline.stages)
);

let keySeq = 0;
const addStage = () => {
  keySeq += 1;
  stages.value.push({
    uiKey: `new-${keySeq}`,
    name: '',
    probability: 50,
    kind: 'open',
    color: '#94a3b8',
  });
};

const removeStage = stage => {
  const count = stage.id ? props.stageDealCounts[stage.id] || 0 : 0;
  if (count > 0) {
    pendingRemoval.value = stage;
    moveTarget.value = '';
    moveDialog.value?.open();
    return;
  }
  stages.value = stages.value.filter(s => s.uiKey !== stage.uiKey);
};

const targetOptions = computed(() =>
  stages.value
    .filter(s => s.id && s.uiKey !== pendingRemoval.value?.uiKey)
    .map(s => ({ value: s.id, label: s.name }))
);

const confirmRemoval = () => {
  if (!moveTarget.value) return;
  removed.value.push({
    stage: pendingRemoval.value,
    targetId: Number(moveTarget.value),
  });
  stages.value = stages.value.filter(
    s => s.uiKey !== pendingRemoval.value.uiKey
  );
  pendingRemoval.value = null;
  moveDialog.value?.close();
};

const save = () => {
  const result = validateStages(stages.value);
  errors.value = result.errors;
  if (!result.valid) return;
  const stageMoves = Object.fromEntries(
    removed.value.map(r => [r.stage.id, r.targetId])
  );
  emit('save', {
    id: props.pipeline.id,
    name: name.value.trim(),
    currency: currency.value,
    stages: stages.value.map(({ uiKey, ...s }) => ({
      id: s.id,
      name: s.name.trim(),
      probability: Number(s.probability),
      kind: s.kind,
      color: s.color,
    })),
    stage_moves: stageMoves,
  });
};

const errorText = key =>
  ({
    NEED_WON_LOST: t('CRM.SETTINGS.NEED_WON_LOST'),
    NEED_OPEN: t('CRM.SETTINGS.NEED_OPEN'),
    STAGE_NAME: t('CRM.SETTINGS.STAGE_NAME'),
    PROBABILITY: t('CRM.SETTINGS.PROBABILITY'),
  })[key];
</script>

<template>
  <section class="p-5 rounded-2xl border border-n-weak bg-n-solid-1">
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-[minmax(0,1fr)_10rem]">
      <Input v-model="name" :label="t('CRM.SETTINGS.PIPELINE_NAME')" />
      <div class="flex flex-col gap-1">
        <label class="text-heading-3 text-n-slate-12">{{
          t('CRM.SETTINGS.CURRENCY')
        }}</label>
        <Select
          v-model="currency"
          :options="currencyOptions"
          :disabled="pipeline.currency_locked"
        />
        <p v-if="pipeline.currency_locked" class="text-xs text-n-slate-10">
          {{ t('CRM.SETTINGS.CURRENCY_LOCKED') }}
        </p>
      </div>
    </div>

    <h3 class="mt-5 mb-2 text-heading-3 text-n-slate-12">
      {{ t('CRM.SETTINGS.STAGES') }}
    </h3>
    <Draggable
      v-model="stages"
      item-key="uiKey"
      handle=".drag-handle"
      :animation="150"
      class="flex flex-col gap-2"
    >
      <template #item="{ element }">
        <div
          class="grid items-center gap-2 p-2 rounded-xl bg-n-slate-2 grid-cols-[auto_minmax(0,1fr)_5.5rem_7rem_2.5rem_auto]"
        >
          <span
            class="drag-handle i-lucide-grip-vertical size-4 text-n-slate-10 cursor-grab"
          />
          <Input
            v-model="element.name"
            :placeholder="t('CRM.SETTINGS.STAGE_NAME')"
            size="sm"
          />
          <Input
            v-model="element.probability"
            type="number"
            min="0"
            max="100"
            size="sm"
            :placeholder="t('CRM.SETTINGS.PROBABILITY')"
          />
          <Select v-model="element.kind" :options="kindOptions" />
          <input
            v-model="element.color"
            type="color"
            class="w-8 h-8 p-0 bg-transparent border-0 rounded cursor-pointer"
            :aria-label="t('CRM.SETTINGS.COLOR')"
          />
          <Button
            icon="i-lucide-x"
            size="xs"
            variant="ghost"
            color="slate"
            :aria-label="t('CRM.SETTINGS.REMOVE_STAGE')"
            @click="removeStage(element)"
          />
        </div>
      </template>
    </Draggable>
    <Button
      :label="t('CRM.SETTINGS.ADD_STAGE')"
      size="sm"
      variant="faded"
      icon="i-lucide-plus"
      class="mt-3"
      @click="addStage"
    />

    <ul v-if="errors.length" class="mt-3 text-sm text-n-ruby-11">
      <li v-for="error in errors" :key="error">{{ errorText(error) }}</li>
    </ul>

    <div class="flex flex-wrap items-center justify-between gap-2 mt-5">
      <Button
        v-if="canDelete"
        :label="t('CRM.SETTINGS.DELETE_PIPELINE')"
        size="sm"
        variant="ghost"
        color="ruby"
        icon="i-lucide-trash-2"
        @click="emit('delete', pipeline)"
      />
      <span v-else />
      <Button
        :label="t('CRM.COMMON.SAVE')"
        size="sm"
        :disabled="!dirty"
        :is-loading="isSaving"
        @click="save"
      />
    </div>

    <Dialog
      ref="moveDialog"
      type="alert"
      :title="t('CRM.SETTINGS.MOVE_DEALS_TITLE')"
      :description="
        t('CRM.SETTINGS.MOVE_DEALS_BODY', {
          count: pendingRemoval?.id ? stageDealCounts[pendingRemoval.id] : 0,
        })
      "
      :confirm-button-label="t('CRM.SETTINGS.REMOVE_STAGE')"
      :cancel-button-label="t('CRM.COMMON.CANCEL')"
      :disable-confirm-button="!moveTarget"
      @confirm="confirmRemoval"
      @close="pendingRemoval = null"
    >
      <div class="flex flex-col gap-1">
        <label class="text-heading-3 text-n-slate-12">{{
          t('CRM.SETTINGS.MOVE_DEALS_TARGET')
        }}</label>
        <Select v-model="moveTarget" :options="targetOptions" placeholder="—" />
      </div>
    </Dialog>
  </section>
</template>
