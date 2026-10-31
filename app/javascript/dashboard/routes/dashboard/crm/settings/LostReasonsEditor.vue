<script setup>
// Custom (MyDesk): Sales settings > Lost reasons: add, rename, reorder (drag, or the up/down buttons from
// the keyboard), delete
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
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

// The first load shows its own spinner; isSaving is only for the user's changes
const isLoading = ref(true);
onMounted(async () => {
  try {
    const { data } = await crmLostReasonsAPI.get();
    reasons.value = data;
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  } finally {
    isLoading.value = false;
  }
});

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

const move = (index, delta) => {
  const target = index + delta;
  if (target < 0 || target >= reasons.value.length) return;
  const next = [...reasons.value];
  [next[index], next[target]] = [next[target], next[index]];
  reasons.value = next;
  onReorder();
};
</script>

<template>
  <section
    class="p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
    aria-labelledby="crm-lost-reasons-title"
  >
    <h2 id="crm-lost-reasons-title" class="text-heading-3 text-n-slate-12">
      {{ t('CRM.SETTINGS.LOST_REASONS') }}
    </h2>
    <p class="mt-1 mb-4 text-label-small text-n-slate-11">
      {{ t('CRM.SETTINGS.LOST_REASONS_HINT') }}
    </p>

    <div v-if="isLoading" class="flex justify-center py-6">
      <Spinner />
    </div>
    <Draggable
      v-else
      v-model="reasons"
      item-key="id"
      handle=".drag-handle"
      :animation="150"
      tag="ol"
      class="flex flex-col gap-2"
      @end="onReorder"
    >
      <template #item="{ element, index }">
        <li
          class="flex items-center gap-2 p-2 rounded-xl bg-n-slate-2"
          :data-reason-id="element.id"
        >
          <span
            class="drag-handle i-lucide-grip-vertical size-4 shrink-0 text-n-slate-10 cursor-grab"
            aria-hidden="true"
          />
          <form
            v-if="editingId === element.id"
            class="flex items-center flex-1 gap-2"
            @submit.prevent="saveEdit"
          >
            <Input
              v-model="editingName"
              size="sm"
              class="flex-1"
              :aria-label="t('CRM.SETTINGS.REASON_NAME')"
              autofocus
            />
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
            <span class="flex-1 truncate text-body-main text-n-slate-12">
              {{ element.name }}
            </span>
            <Button
              icon="i-lucide-arrow-up"
              size="xs"
              variant="ghost"
              color="slate"
              :disabled="index === 0 || isSaving"
              :aria-label="t('CRM.SETTINGS.MOVE_UP', { name: element.name })"
              @click="move(index, -1)"
            />
            <Button
              icon="i-lucide-arrow-down"
              size="xs"
              variant="ghost"
              color="slate"
              :disabled="index === reasons.length - 1 || isSaving"
              :aria-label="t('CRM.SETTINGS.MOVE_DOWN', { name: element.name })"
              @click="move(index, 1)"
            />
            <Button
              icon="i-lucide-pencil"
              size="xs"
              variant="ghost"
              color="slate"
              :aria-label="
                t('CRM.SETTINGS.EDIT_REASON', { name: element.name })
              "
              @click="startEdit(element)"
            />
            <Button
              icon="i-lucide-trash-2"
              size="xs"
              variant="ghost"
              color="slate"
              :aria-label="
                t('CRM.SETTINGS.DELETE_REASON', { name: element.name })
              "
              @click="remove(element)"
            />
          </template>
        </li>
      </template>
    </Draggable>

    <form class="flex items-center gap-2 mt-3" @submit.prevent="add">
      <Input
        v-model="draft"
        size="sm"
        class="flex-1"
        :placeholder="t('CRM.SETTINGS.NEW_LOST_REASON')"
        :aria-label="t('CRM.SETTINGS.NEW_LOST_REASON')"
      />
      <Button
        :label="t('CRM.SETTINGS.ADD_LOST_REASON')"
        size="sm"
        variant="faded"
        icon="i-lucide-plus"
        :disabled="!draft.trim() || isLoading"
        :is-loading="isSaving && !editingId"
        type="submit"
      />
    </form>
  </section>
</template>
