<script setup>
// Custom (MyDesk): Sales > Tasks: mine / today / overdue / upcoming / done / all
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import CrmPageHeader from '../shared/CrmPageHeader.vue';
import CrmUnavailable from '../shared/CrmUnavailable.vue';
import { apiErrorMessage } from '../shared/dealHelpers';
import TaskRow from './TaskRow.vue';
import TaskForm from './TaskForm.vue';

const { t } = useI18n();
const store = useStore();

const tasks = useMapGetter('crm/tasks/all');
const scope = useMapGetter('crm/tasks/scope');
const flags = useMapGetter('crm/tasks/getUIFlags');
const isAdmin = useMapGetter('crm/status/isAdmin');
const overdueCount = useMapGetter('crm/status/overdueCount');
const currentUser = useMapGetter('getCurrentUser');

const scopes = computed(() => [
  'mine',
  'today',
  'overdue',
  'upcoming',
  'done',
  ...(isAdmin.value ? ['all'] : []),
]);
const tabs = computed(() =>
  scopes.value.map(key => ({
    key,
    label: t(`CRM.TASKS.TABS.${key}`),
    count:
      key === 'overdue' && overdueCount.value ? overdueCount.value : undefined,
  }))
);
const activeTabIndex = computed(() =>
  Math.max(0, scopes.value.indexOf(scope.value))
);

const taskForm = ref(null);
const editing = ref(null);
const deleting = ref(null);
const deleteDialog = ref(null);

const load = (kind = scope.value) =>
  store.dispatch('crm/tasks/fetch', { scope: kind }).catch(() => {});
onMounted(() => load('mine'));

const onTab = tab => load(tab.key);

const openNew = () => {
  editing.value = null;
  taskForm.value?.open();
};
const openEdit = task => {
  editing.value = task;
  taskForm.value?.open();
};

const onSubmit = async ({ payload, isEdit, id }) => {
  try {
    if (isEdit) await store.dispatch('crm/tasks/update', { id, ...payload });
    else await store.dispatch('crm/tasks/create', payload);
    taskForm.value?.close();
    useAlert(t('CRM.TASKS.FORM.SAVED'));
    load();
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  }
};

const onToggle = async task => {
  try {
    await store.dispatch(
      task.status === 'done' ? 'crm/tasks/reopen' : 'crm/tasks/complete',
      task.id
    );
    if (task.status !== 'done') useAlert(t('CRM.TASKS.COMPLETED'));
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  }
};

const askDelete = task => {
  deleting.value = task;
  deleteDialog.value?.open();
};
const confirmDelete = async () => {
  try {
    await store.dispatch('crm/tasks/delete', deleting.value.id);
    deleteDialog.value?.close();
    useAlert(t('CRM.TASKS.DELETED'));
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  }
};

const canDelete = task =>
  isAdmin.value || task.creator_id === currentUser.value?.id;
</script>

<template>
  <div class="flex flex-col h-full min-w-0">
    <CrmPageHeader
      :title="t('CRM.TASKS.TITLE')"
      :subtitle="t('CRM.TASKS.SUBTITLE')"
    >
      <template #actions>
        <Button
          :label="t('CRM.TASKS.NEW')"
          size="sm"
          icon="i-lucide-plus"
          @click="openNew"
        />
      </template>
    </CrmPageHeader>

    <div class="px-6 pb-3">
      <TabBar
        :tabs="tabs"
        :initial-active-tab="activeTabIndex"
        @tab-changed="onTab"
      />
    </div>

    <CrmUnavailable
      v-if="flags.isUnavailable"
      :is-loading="flags.isFetching"
      @retry="load()"
    />
    <div
      v-else-if="!flags.hasFetched"
      class="flex items-center justify-center flex-1"
    >
      <Spinner />
    </div>
    <div v-else class="flex-1 min-h-0 px-6 pb-6 overflow-y-auto">
      <ul
        v-if="tasks.length"
        class="flex flex-col divide-y divide-n-weak rounded-2xl border border-n-weak bg-n-solid-1 px-4"
      >
        <TaskRow
          v-for="task in tasks"
          :key="task.id"
          :task="task"
          :can-delete="canDelete(task)"
          @toggle="onToggle"
          @edit="openEdit"
          @delete="askDelete"
        />
      </ul>
      <div
        v-else
        class="flex flex-col items-center justify-center gap-2 py-16 text-center"
      >
        <span class="i-lucide-check-circle-2 size-8 text-n-slate-9" />
        <p class="text-body-main text-n-slate-11">
          {{ t(`CRM.TASKS.EMPTY.${scope}`) }}
        </p>
      </div>
    </div>

    <TaskForm
      ref="taskForm"
      :task="editing"
      :is-saving="flags.isSaving"
      @submit="onSubmit"
    />
    <Dialog
      ref="deleteDialog"
      type="alert"
      :title="t('CRM.TASKS.DELETE_CONFIRM')"
      :confirm-button-label="t('CRM.COMMON.DELETE')"
      :cancel-button-label="t('CRM.COMMON.CANCEL')"
      @confirm="confirmDelete"
    />
  </div>
</template>
