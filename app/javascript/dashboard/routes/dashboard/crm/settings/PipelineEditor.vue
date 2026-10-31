<script setup>
// Custom (MyDesk): edit one pipeline: name and stages (by drag or the up/down buttons), remove with a
// target stage when the removed stage still holds deals. Beside each open stage's probability sits its actual
// win rate from the account's last 12 months, as a suggestion the admin can copy in; it never changes alone.
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { crmReportsAPI } from 'dashboard/api/crm';
import { validateStages } from '../shared/dealHelpers';

const props = defineProps({
  pipeline: { type: Object, required: true },
  stageDealCounts: { type: Object, default: () => ({}) },
  isSaving: { type: Boolean, default: false },
  canDelete: { type: Boolean, default: false },
});
const emit = defineEmits(['save', 'delete']);
const { t } = useI18n();

const name = ref('');
const stages = ref([]);
const removed = ref([]); // { stage, targetId }
const errors = ref([]);
const moveDialog = ref(null);
const pendingRemoval = ref(null);
const moveTarget = ref('');

const load = () => {
  name.value = props.pipeline.name;
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
const dirty = computed(
  () =>
    name.value !== props.pipeline.name ||
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
    color: '#8B8D98', // DESIGN.md ink-faint: a neutral until the admin picks one
  });
};

// Keyboard alternative to dragging: move a stage one place up or down
const moveStage = (index, delta) => {
  const target = index + delta;
  if (target < 0 || target >= stages.value.length) return;
  const next = [...stages.value];
  [next[index], next[target]] = [next[target], next[index]];
  stages.value = next;
};
// stage_id -> { closed_count, won_count, win_rate (null below min_closed), min_closed }
const winRates = ref({});
onMounted(async () => {
  try {
    const { data } = await crmReportsAPI.stageWinRates({
      pipeline_id: props.pipeline.id,
    });
    winRates.value = Object.fromEntries(data.map(r => [r.stage_id, r]));
  } catch (e) {
    // the editor works without the suggestion
  }
});
// The server's threshold (SalesCrm::Reports::StageWinRates::MIN_CLOSED)
const minClosed = computed(
  () => Object.values(winRates.value)[0]?.min_closed ?? 20
);
const actualFor = stage =>
  stage.id && stage.kind === 'open' ? winRates.value[stage.id] : null;
const useActual = (stage, rate) => {
  stage.probability = Math.round(rate);
};

const stageLabel = (stage, index) =>
  stage.name?.trim() || t('CRM.SETTINGS.STAGE_N', { n: index + 1 });

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
  <section
    class="p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
    :aria-labelledby="`crm-pipeline-${pipeline.id}`"
  >
    <h2
      :id="`crm-pipeline-${pipeline.id}`"
      class="mb-4 text-heading-2 text-n-slate-12"
    >
      {{ pipeline.name }}
    </h2>
    <!-- No currency here: the Sales section has one, set in the General tab -->
    <Input v-model="name" :label="t('CRM.SETTINGS.PIPELINE_NAME')" />

    <h3 class="mt-5 text-heading-3 text-n-slate-12">
      {{ t('CRM.SETTINGS.STAGES') }}
    </h3>
    <p class="mt-1 mb-3 text-label-small text-n-slate-11">
      {{ t('CRM.SETTINGS.ACTUAL_HINT', { min: minClosed }) }}
    </p>
    <!-- Column captions for wide screens; every field also carries its own aria-label, and on phones a
         row wraps onto two lines so the stage name keeps a usable width -->
    <div
      class="hidden gap-2 px-2 mb-1 sm:flex text-label-small text-n-slate-11"
      aria-hidden="true"
    >
      <span class="w-4 shrink-0" />
      <span class="flex-1">{{ t('CRM.SETTINGS.STAGE_NAME') }}</span>
      <span class="w-20 shrink-0">{{ t('CRM.SETTINGS.PROBABILITY') }}</span>
      <span class="w-20 shrink-0">{{ t('CRM.SETTINGS.ACTUAL') }}</span>
      <span class="w-28 shrink-0">{{ t('CRM.SETTINGS.KIND') }}</span>
      <span class="w-8 shrink-0">{{ t('CRM.SETTINGS.COLOR') }}</span>
      <span class="w-[5.5rem] shrink-0" />
    </div>
    <Draggable
      v-model="stages"
      item-key="uiKey"
      handle=".drag-handle"
      :animation="150"
      tag="ol"
      class="flex flex-col gap-2"
    >
      <template #item="{ element, index }">
        <li
          class="flex flex-wrap items-center gap-2 p-2 rounded-xl bg-n-slate-2 sm:flex-nowrap"
        >
          <span
            class="drag-handle i-lucide-grip-vertical size-4 shrink-0 text-n-slate-10 cursor-grab"
            aria-hidden="true"
          />
          <!-- Input puts its class on the <input> itself, so each field sits in its own flex item -->
          <div class="flex-1 min-w-0 basis-40">
            <Input
              v-model="element.name"
              :placeholder="t('CRM.SETTINGS.STAGE_NAME')"
              :aria-label="t('CRM.SETTINGS.STAGE_NAME')"
              size="sm"
            />
          </div>
          <div class="w-20 shrink-0">
            <Input
              v-model="element.probability"
              type="number"
              min="0"
              max="100"
              size="sm"
              :aria-label="t('CRM.SETTINGS.PROBABILITY')"
            />
          </div>
          <!-- The actual rate: a button that copies it into the probability once there is enough history,
               otherwise how many closed deals it has so far -->
          <div
            class="flex items-center w-20 shrink-0 text-label-small tabular-nums"
          >
            <template v-if="actualFor(element)">
              <button
                v-if="actualFor(element).win_rate !== null"
                type="button"
                class="px-1.5 py-1 rounded-md text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline-2 focus-visible:outline-n-brand"
                :title="
                  t('CRM.SETTINGS.ACTUAL_FROM', {
                    count: actualFor(element).closed_count,
                  })
                "
                :aria-label="
                  t('CRM.SETTINGS.USE_ACTUAL', {
                    rate: Math.round(actualFor(element).win_rate),
                    name: stageLabel(element, index),
                  })
                "
                @click="useActual(element, actualFor(element).win_rate)"
              >
                {{ Math.round(actualFor(element).win_rate) }}%
              </button>
              <span
                v-else
                class="text-n-slate-10"
                :title="
                  t('CRM.SETTINGS.ACTUAL_NOT_ENOUGH', {
                    count: actualFor(element).closed_count,
                    min: actualFor(element).min_closed,
                  })
                "
              >
                —
                <span class="sr-only">
                  {{
                    t('CRM.SETTINGS.ACTUAL_NOT_ENOUGH', {
                      count: actualFor(element).closed_count,
                      min: actualFor(element).min_closed,
                    })
                  }}
                </span>
              </span>
            </template>
          </div>
          <div class="w-28 shrink-0">
            <Select
              v-model="element.kind"
              :options="kindOptions"
              :aria-label="t('CRM.SETTINGS.KIND')"
            />
          </div>
          <input
            v-model="element.color"
            type="color"
            class="w-8 h-8 p-0 bg-transparent border-0 rounded cursor-pointer shrink-0"
            :aria-label="t('CRM.SETTINGS.COLOR')"
          />
          <div class="flex items-center gap-0.5 shrink-0 ms-auto sm:ms-0">
            <Button
              icon="i-lucide-arrow-up"
              size="xs"
              variant="ghost"
              color="slate"
              :disabled="index === 0"
              :aria-label="
                t('CRM.SETTINGS.MOVE_UP', {
                  name: stageLabel(element, index),
                })
              "
              @click="moveStage(index, -1)"
            />
            <Button
              icon="i-lucide-arrow-down"
              size="xs"
              variant="ghost"
              color="slate"
              :disabled="index === stages.length - 1"
              :aria-label="
                t('CRM.SETTINGS.MOVE_DOWN', {
                  name: stageLabel(element, index),
                })
              "
              @click="moveStage(index, 1)"
            />
            <Button
              icon="i-lucide-x"
              size="xs"
              variant="ghost"
              color="slate"
              :aria-label="
                t('CRM.SETTINGS.REMOVE_STAGE_NAMED', {
                  name: stageLabel(element, index),
                })
              "
              @click="removeStage(element)"
            />
          </div>
        </li>
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

    <ul
      v-if="errors.length"
      class="mt-3 text-body-main text-n-ruby-11"
      role="alert"
    >
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
      <!-- Solid only while there is something to save, so several pipelines never show several solid buttons -->
      <Button
        :label="t('CRM.COMMON.SAVE')"
        size="sm"
        :variant="dirty ? 'solid' : 'faded'"
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
        <span class="text-heading-3 text-n-slate-12" aria-hidden="true">
          {{ t('CRM.SETTINGS.MOVE_DEALS_TARGET') }}
        </span>
        <Select
          v-model="moveTarget"
          :options="targetOptions"
          :aria-label="t('CRM.SETTINGS.MOVE_DEALS_TARGET')"
          placeholder="—"
        />
      </div>
    </Dialog>
  </section>
</template>
