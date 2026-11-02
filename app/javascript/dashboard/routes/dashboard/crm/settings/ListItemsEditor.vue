<script setup>
// Custom (MyDesk): Sales settings > Lists: one managed list (lead source, product, competitor, region, industry).
// Add, rename, reorder (drag, or the up/down buttons from the keyboard) and remove. Removing archives the item:
// it leaves the deal form's picker but stays on the deals that have it, so old reports keep their names.
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { crmListItemsAPI } from 'dashboard/api/crm';
import { apiErrorMessage } from '../shared/dealHelpers';
import { useCrmLists } from '../shared/useCrmLists';

const props = defineProps({ list: { type: String, required: true } });
const { t } = useI18n();
const lists = useCrmLists();

const items = ref([]);
const draft = ref('');
const editingId = ref(null);
const editingName = ref('');
const isSaving = ref(false);
const isLoading = ref(true);

// Every change answers with the whole list; the deal form's pickers follow it at once
const run = async request => {
  isSaving.value = true;
  try {
    const { data } = await request();
    items.value = data;
    lists.replace(props.list, data);
    return true;
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
    return false;
  } finally {
    isSaving.value = false;
  }
};

onMounted(async () => {
  try {
    const { data } = await crmListItemsAPI.get(props.list);
    items.value = data;
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  } finally {
    isLoading.value = false;
  }
});

const add = async () => {
  const name = draft.value.trim();
  if (!name) return;
  if (await run(() => crmListItemsAPI.create(props.list, name)))
    draft.value = '';
};

const startEdit = item => {
  editingId.value = item.id;
  editingName.value = item.name;
};

const saveEdit = async () => {
  const name = editingName.value.trim();
  if (!name) return;
  if (await run(() => crmListItemsAPI.update(editingId.value, name)))
    editingId.value = null;
};

const remove = item => run(() => crmListItemsAPI.archive(item.id));

const onReorder = () =>
  run(() =>
    crmListItemsAPI.reorder(
      props.list,
      items.value.map(i => i.id)
    )
  );

const move = (index, delta) => {
  const target = index + delta;
  if (target < 0 || target >= items.value.length) return;
  const next = [...items.value];
  [next[index], next[target]] = [next[target], next[index]];
  items.value = next;
  onReorder();
};
</script>

<template>
  <section
    class="p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
    :aria-labelledby="`crm-list-${list}`"
  >
    <h2 :id="`crm-list-${list}`" class="text-heading-3 text-n-slate-12">
      {{ t(`CRM.LISTS.${list}`) }}
    </h2>
    <p class="mt-1 mb-4 text-label-small text-n-slate-11">
      {{ t(`CRM.LISTS.HINTS.${list}`) }}
    </p>

    <div v-if="isLoading" class="flex justify-center py-4">
      <Spinner />
    </div>
    <template v-else>
      <p v-if="!items.length" class="mb-3 text-body-main text-n-slate-11">
        {{ t('CRM.LISTS.EMPTY') }}
      </p>
      <Draggable
        v-model="items"
        item-key="id"
        handle=".drag-handle"
        :animation="150"
        tag="ol"
        class="flex flex-col gap-2"
        @end="onReorder"
      >
        <template #item="{ element, index }">
          <li class="flex items-center gap-2 p-2 rounded-xl bg-n-slate-2">
            <span
              class="drag-handle i-lucide-grip-vertical size-4 shrink-0 text-n-slate-10 cursor-grab"
              aria-hidden="true"
            />
            <form
              v-if="editingId === element.id"
              class="flex items-center flex-1 gap-2"
              @submit.prevent="saveEdit"
            >
              <div class="flex-1 min-w-0">
                <Input
                  v-model="editingName"
                  size="sm"
                  :aria-label="t('CRM.LISTS.ITEM_NAME')"
                  autofocus
                />
              </div>
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
                :disabled="index === items.length - 1 || isSaving"
                :aria-label="
                  t('CRM.SETTINGS.MOVE_DOWN', { name: element.name })
                "
                @click="move(index, 1)"
              />
              <Button
                icon="i-lucide-pencil"
                size="xs"
                variant="ghost"
                color="slate"
                :aria-label="t('CRM.LISTS.EDIT_ITEM', { name: element.name })"
                @click="startEdit(element)"
              />
              <Button
                icon="i-lucide-archive"
                size="xs"
                variant="ghost"
                color="slate"
                :title="t('CRM.LISTS.ARCHIVE_HINT')"
                :aria-label="
                  t('CRM.LISTS.ARCHIVE_ITEM', { name: element.name })
                "
                @click="remove(element)"
              />
            </template>
          </li>
        </template>
      </Draggable>

      <form class="flex items-center gap-2 mt-3" @submit.prevent="add">
        <div class="flex-1 min-w-0">
          <Input
            v-model="draft"
            size="sm"
            :placeholder="t('CRM.LISTS.NEW_ITEM')"
            :aria-label="t('CRM.LISTS.NEW_ITEM')"
          />
        </div>
        <Button
          :label="t('CRM.LISTS.ADD')"
          size="sm"
          variant="faded"
          icon="i-lucide-plus"
          :disabled="!draft.trim()"
          :is-loading="isSaving && !editingId"
          type="submit"
        />
      </form>
    </template>
  </section>
</template>
