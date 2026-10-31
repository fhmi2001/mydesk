<script setup>
// Custom (MyDesk): Sales settings > Lost reasons: add, rename, reorder by drag, delete
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { crmLostReasonsAPI } from 'dashboard/api/crm';
import { apiErrorMessage } from '../shared/dealHelpers';

const { t } = useI18n();
const reasons = ref([]);
const draft = ref('');
const editingId = ref(null);
const editingName = ref('');
const isSaving = ref(false);

const run = async request => {
  isSaving.value = true;
  try {
    const { data } = await request();
    reasons.value = data;
    return true;
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
    return false;
  } finally {
    isSaving.value = false;
  }
};

onMounted(() => run(() => crmLostReasonsAPI.get()));

const add = async () => {
  const name = draft.value.trim();
  if (!name) return;
  if (await run(() => crmLostReasonsAPI.create(name))) draft.value = '';
};

const startEdit = reason => {
  editingId.value = reason.id;
  editingName.value = reason.name;
};

const saveEdit = async () => {
  const name = editingName.value.trim();
  if (!name) return;
  if (await run(() => crmLostReasonsAPI.update(editingId.value, name))) {
    editingId.value = null;
  }
};

const remove = reason => run(() => crmLostReasonsAPI.delete(reason.id));

const onReorder = () =>
  run(() => crmLostReasonsAPI.reorder(reasons.value.map(r => r.id)));
</script>

<template>
  <section class="p-5 rounded-2xl border border-n-weak bg-n-solid-1">
    <h2 class="text-heading-3 text-n-slate-12">
      {{ t('CRM.SETTINGS.LOST_REASONS') }}
    </h2>
    <p class="mt-1 mb-4 text-xs text-n-slate-11">
      {{ t('CRM.SETTINGS.LOST_REASONS_HINT') }}
    </p>

    <Draggable
      v-model="reasons"
      item-key="id"
      handle=".drag-handle"
      :animation="150"
      class="flex flex-col gap-2"
      @end="onReorder"
    >
      <template #item="{ element }">
        <div
          class="flex items-center gap-2 p-2 rounded-xl bg-n-slate-2"
          :data-reason-id="element.id"
        >
          <span
            class="drag-handle i-lucide-grip-vertical size-4 shrink-0 text-n-slate-10 cursor-grab"
          />
          <form
            v-if="editingId === element.id"
            class="flex items-center flex-1 gap-2"
            @submit.prevent="saveEdit"
          >
            <Input v-model="editingName" size="sm" class="flex-1" autofocus />
            <Button
              :label="t('CRM.COMMON.SAVE')"
              size="xs"
              :is-loading="isSaving"
              type="submit"
            />
            <Button
              :label="t('CRM.COMMON.CANCEL')"
              size="xs"
              variant="ghost"
              color="slate"
              @click="editingId = null"
            />
          </form>
          <template v-else>
            <span class="flex-1 text-sm truncate text-n-slate-12">
              {{ element.name }}
            </span>
            <Button
              icon="i-lucide-pencil"
              size="xs"
              variant="ghost"
              color="slate"
              :aria-label="t('CRM.COMMON.EDIT')"
              @click="startEdit(element)"
            />
            <Button
              icon="i-lucide-trash-2"
              size="xs"
              variant="ghost"
              color="slate"
              :aria-label="t('CRM.COMMON.DELETE')"
              @click="remove(element)"
            />
          </template>
        </div>
      </template>
    </Draggable>

    <form class="flex items-center gap-2 mt-3" @submit.prevent="add">
      <Input
        v-model="draft"
        size="sm"
        class="flex-1"
        :placeholder="t('CRM.SETTINGS.NEW_LOST_REASON')"
      />
      <Button
        :label="t('CRM.SETTINGS.ADD_LOST_REASON')"
        size="sm"
        variant="faded"
        icon="i-lucide-plus"
        :disabled="!draft.trim()"
        :is-loading="isSaving"
        type="submit"
      />
    </form>
  </section>
</template>
