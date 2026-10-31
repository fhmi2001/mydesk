<script setup>
// Custom (MyDesk): one deal: its fields, won / lost / reopen / delete, tasks, notes and activity
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { crmDealsAPI, crmTasksAPI } from 'dashboard/api/crm';
import CrmUnavailable from '../shared/CrmUnavailable.vue';
import StatusBadge from '../shared/StatusBadge.vue';
import { useCrmFormat } from '../shared/useCrmFormat';
import { apiErrorMessage, isStale, isUnavailable } from '../shared/dealHelpers';
import DealForm from './DealForm.vue';
import LostReasonDialog from './LostReasonDialog.vue';
import DealActivityList from './DealActivityList.vue';
import DealNotes from './DealNotes.vue';
import TaskForm from '../tasks/TaskForm.vue';
import TaskRow from '../tasks/TaskRow.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const { accountScopedRoute } = useAccount();
const { money, date, dateTime } = useCrmFormat();

const pipelines = useMapGetter('crm/pipelines/all');
const isAdmin = useMapGetter('crm/status/isAdmin');
const currentUser = useMapGetter('getCurrentUser');
const flags = useMapGetter('crm/deals/getUIFlags');

const deal = ref(null);
const notes = ref([]);
const activities = ref([]);
const tasks = ref([]);
const isLoading = ref(true);
const isUnavailableState = ref(false);
const isStaleState = ref(false);
const isSavingNote = ref(false);
const dealForm = ref(null);
const lostDialog = ref(null);
const taskForm = ref(null);
const deleteDialog = ref(null);

const pipeline = computed(() =>
  pipelines.value.find(p => p.id === deal.value?.pipeline_id)
);
const stagesById = computed(() =>
  Object.fromEntries((pipeline.value?.stages || []).map(s => [s.id, s]))
);
const stage = computed(() => stagesById.value[deal.value?.stage_id]);
const canDelete = computed(
  () => isAdmin.value || deal.value?.assignee?.id === currentUser.value?.id
);

const load = async () => {
  isLoading.value = true;
  isUnavailableState.value = false;
  try {
    if (!pipelines.value.length) await store.dispatch('crm/pipelines/fetch');
    const [{ data: d }, { data: n }, { data: a }, { data: tk }] =
      await Promise.all([
        crmDealsAPI.show(route.params.dealId),
        crmDealsAPI.notes(route.params.dealId),
        crmDealsAPI.activities(route.params.dealId),
        crmTasksAPI.get({ deal_id: route.params.dealId, scope: 'all' }),
      ]);
    deal.value = d;
    notes.value = n;
    activities.value = a;
    tasks.value = tk.tasks;
    isStaleState.value = false;
  } catch (error) {
    if (isUnavailable(error)) isUnavailableState.value = true;
    else if (error?.response?.status === 404)
      router.replace(accountScopedRoute('crm_deals'));
  } finally {
    isLoading.value = false;
  }
};

onMounted(load);
watch(() => route.params.dealId, load);

const handleError = error => {
  if (isStale(error)) {
    isStaleState.value = true;
    return;
  }
  useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
};

const onEdit = async ({ payload, id }) => {
  try {
    deal.value = await store.dispatch('crm/deals/update', { id, ...payload });
    dealForm.value?.close();
    useAlert(t('CRM.DEALS.FORM.SAVED'));
    load();
  } catch (error) {
    handleError(error);
  }
};

const moveTo = async (stageId, lostReason, lostNote) => {
  try {
    deal.value = await store.dispatch('crm/deals/move', {
      id: deal.value.id,
      stageId,
      lostReason,
      lostNote,
      lockVersion: deal.value.lock_version,
    });
    load();
  } catch (error) {
    handleError(error);
  }
};

const openStageOptions = computed(() =>
  (pipeline.value?.stages || [])
    .filter(s => s.kind === 'open')
    .map(s => ({ value: s.id, label: s.name }))
);
const onStagePick = value => {
  const id = Number(value);
  if (id && id !== deal.value.stage_id) moveTo(id);
};

const markWon = () =>
  moveTo(pipeline.value?.stages.find(s => s.kind === 'won')?.id);
const markLost = () => lostDialog.value?.open();
const onLostConfirm = ({ reason, note }) => {
  lostDialog.value?.close();
  moveTo(pipeline.value?.stages.find(s => s.kind === 'lost')?.id, reason, note);
};
const reopen = async () => {
  try {
    deal.value = await store.dispatch('crm/deals/reopen', deal.value.id);
    load();
  } catch (error) {
    handleError(error);
  }
};

const confirmDelete = async () => {
  try {
    await store.dispatch('crm/deals/discard', deal.value.id);
    deleteDialog.value?.close();
    useAlert(t('CRM.DEALS.DELETED'));
    router.push(accountScopedRoute('crm_deals'));
  } catch (error) {
    handleError(error);
  }
};

const addNote = async content => {
  isSavingNote.value = true;
  try {
    const { data } = await crmDealsAPI.addNote(deal.value.id, content);
    notes.value = [data, ...notes.value];
    const { data: a } = await crmDealsAPI.activities(deal.value.id);
    activities.value = a;
  } catch (error) {
    handleError(error);
  } finally {
    isSavingNote.value = false;
  }
};

const deleteNote = async note => {
  try {
    await crmDealsAPI.deleteNote(deal.value.id, note.id);
    notes.value = notes.value.filter(n => n.id !== note.id);
  } catch (error) {
    handleError(error);
  }
};

const taskPresets = computed(() => ({
  deal_id: deal.value?.id,
  deal_title: deal.value?.title,
  contact_id: deal.value?.contact?.id,
  contact_name: deal.value?.contact_name,
  assignee_id: deal.value?.assignee?.id,
}));

const onTaskSubmit = async ({ payload }) => {
  try {
    await store.dispatch('crm/tasks/create', payload);
    taskForm.value?.close();
    useAlert(t('CRM.TASKS.FORM.SAVED'));
    load();
  } catch (error) {
    handleError(error);
  }
};

const onTaskToggle = async task => {
  try {
    await store.dispatch(
      task.status === 'done' ? 'crm/tasks/reopen' : 'crm/tasks/complete',
      task.id
    );
    load();
  } catch (error) {
    handleError(error);
  }
};

const conversationRoute = computed(() =>
  deal.value?.conversation_display_id
    ? accountScopedRoute('inbox_conversation', {
        conversation_id: deal.value.conversation_display_id,
      })
    : null
);
const contactRoute = computed(() =>
  deal.value?.contact
    ? accountScopedRoute('contacts_edit', { contactId: deal.value.contact.id })
    : null
);
</script>

<template>
  <div class="flex flex-col h-full min-w-0 overflow-y-auto">
    <div
      v-if="isLoading && !deal"
      class="flex items-center justify-center flex-1"
    >
      <Spinner />
    </div>
    <CrmUnavailable
      v-else-if="isUnavailableState"
      :is-loading="isLoading"
      @retry="load"
    />

    <template v-else-if="deal">
      <div class="px-6 pt-5">
        <router-link
          :to="accountScopedRoute('crm_deals')"
          class="inline-flex items-center gap-1 text-sm text-n-slate-11 hover:text-n-slate-12"
        >
          <span class="i-lucide-arrow-left size-4 rtl:rotate-180" />
          {{ t('CRM.DEALS.DETAIL.BACK') }}
        </router-link>
      </div>

      <div
        v-if="isStaleState"
        class="flex flex-wrap items-center justify-between gap-3 px-4 py-3 mx-6 mt-4 rounded-xl bg-n-amber-2 border border-n-amber-6"
        role="alert"
      >
        <div>
          <p class="text-sm font-medium text-n-amber-12">
            {{ t('CRM.COMMON.STALE_TITLE') }}
          </p>
          <p class="text-sm text-n-amber-11">
            {{ t('CRM.COMMON.STALE_BODY') }}
          </p>
        </div>
        <Button
          :label="t('CRM.COMMON.RELOAD')"
          size="sm"
          icon="i-lucide-refresh-cw"
          @click="load"
        />
      </div>

      <header
        class="flex flex-wrap items-start justify-between gap-4 px-6 pt-4 pb-5 border-b border-n-weak"
      >
        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-2">
            <h1 class="text-heading-1 text-n-slate-12 break-words">
              {{ deal.title }}
            </h1>
            <StatusBadge :status="deal.status" />
          </div>
          <p
            class="mt-1 text-2xl font-semibold text-n-brand tabular-nums"
            dir="auto"
          >
            {{ money(deal.amount_cents, deal.currency) }}
          </p>
          <p class="mt-1 text-sm text-n-slate-11">
            <span class="inline-flex items-center gap-1.5">
              <span
                class="size-2 rounded-full"
                :style="{ backgroundColor: stage?.color }"
              />
              {{ pipeline?.name }} · {{ stage?.name }} ·
              {{ stage?.probability }}%
            </span>
          </p>
          <p v-if="deal.status === 'won'" class="mt-1 text-sm text-n-teal-11">
            {{ t('CRM.DEALS.DETAIL.WON_AT', { date: date(deal.won_at) }) }}
          </p>
          <p
            v-else-if="deal.status === 'lost'"
            class="mt-1 text-sm text-n-ruby-11"
          >
            {{
              t('CRM.DEALS.DETAIL.LOST_AT', {
                date: date(deal.lost_at),
                reason: deal.lost_reason,
              })
            }}
          </p>
          <p
            v-if="deal.status === 'lost' && deal.lost_note"
            class="mt-1 text-sm whitespace-pre-wrap text-n-slate-11"
          >
            {{ deal.lost_note }}
          </p>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <Select
            v-if="deal.status === 'open'"
            :model-value="deal.stage_id"
            :options="openStageOptions"
            :aria-label="t('CRM.PANEL.CHANGE_STAGE')"
            @update:model-value="onStagePick"
          />
          <Button
            v-if="deal.status === 'open'"
            :label="t('CRM.DEALS.DETAIL.MARK_WON')"
            size="sm"
            color="teal"
            icon="i-lucide-trophy"
            @click="markWon"
          />
          <Button
            v-if="deal.status === 'open'"
            :label="t('CRM.DEALS.DETAIL.MARK_LOST')"
            size="sm"
            color="ruby"
            variant="faded"
            icon="i-lucide-x-circle"
            @click="markLost"
          />
          <Button
            v-else
            :label="t('CRM.DEALS.DETAIL.REOPEN')"
            size="sm"
            variant="faded"
            icon="i-lucide-rotate-ccw"
            @click="reopen"
          />
          <Button
            :label="t('CRM.COMMON.EDIT')"
            size="sm"
            variant="faded"
            icon="i-lucide-pencil"
            @click="dealForm?.open()"
          />
          <Button
            v-if="canDelete"
            icon="i-lucide-trash-2"
            size="sm"
            variant="ghost"
            color="slate"
            :aria-label="t('CRM.COMMON.DELETE')"
            @click="deleteDialog?.open()"
          />
        </div>
      </header>

      <div
        class="grid grid-cols-1 gap-6 px-6 py-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]"
      >
        <div class="flex flex-col gap-6">
          <section class="p-4 rounded-2xl border border-n-weak bg-n-solid-1">
            <div class="flex items-center justify-between mb-3">
              <h2 class="text-heading-3 text-n-slate-12">
                {{ t('CRM.DEALS.DETAIL.TASKS') }}
              </h2>
              <Button
                :label="t('CRM.DEALS.DETAIL.ADD_TASK')"
                size="xs"
                variant="faded"
                icon="i-lucide-plus"
                @click="taskForm?.open()"
              />
            </div>
            <ul
              v-if="tasks.length"
              class="flex flex-col divide-y divide-n-weak"
            >
              <TaskRow
                v-for="task in tasks"
                :key="task.id"
                :task="task"
                compact
                @toggle="onTaskToggle"
              />
            </ul>
            <p v-else class="text-sm text-n-slate-11">
              {{ t('CRM.DEALS.DETAIL.NO_TASKS') }}
            </p>
          </section>

          <section class="p-4 rounded-2xl border border-n-weak bg-n-solid-1">
            <h2 class="mb-3 text-heading-3 text-n-slate-12">
              {{ t('CRM.DEALS.DETAIL.NOTES') }}
            </h2>
            <DealNotes
              :notes="notes"
              :is-saving="isSavingNote"
              :can-delete="n => isAdmin || n.user?.id === currentUser?.id"
              @add="addNote"
              @delete="deleteNote"
            />
          </section>
        </div>

        <div class="flex flex-col gap-6">
          <section class="p-4 rounded-2xl border border-n-weak bg-n-solid-1">
            <dl class="flex flex-col gap-3 text-sm">
              <div>
                <dt class="text-n-slate-11">
                  {{ t('CRM.DEALS.FORM.CONTACT') }}
                </dt>
                <dd class="text-n-slate-12">
                  <router-link
                    v-if="contactRoute"
                    :to="contactRoute"
                    class="text-n-blue-11 hover:underline"
                  >
                    {{ deal.contact_name }}
                  </router-link>
                  <span v-else>{{ deal.contact_name || '—' }}</span>
                </dd>
              </div>
              <div>
                <dt class="text-n-slate-11">
                  {{ t('CRM.DEALS.FORM.ASSIGNEE') }}
                </dt>
                <dd class="text-n-slate-12">
                  {{ deal.assignee?.name || t('CRM.COMMON.NO_ASSIGNEE') }}
                </dd>
              </div>
              <div>
                <dt class="text-n-slate-11">
                  {{ t('CRM.DEALS.FORM.CLOSE_DATE') }}
                </dt>
                <dd class="text-n-slate-12">
                  {{ deal.close_date ? date(deal.close_date) : '—' }}
                </dd>
              </div>
              <div>
                <dt class="text-n-slate-11">
                  {{ t('CRM.DEALS.DETAIL.SOURCE') }}
                </dt>
                <dd class="text-n-slate-12">
                  {{ t(`CRM.DEALS.DETAIL.SOURCES.${deal.source}`) }}
                  <router-link
                    v-if="conversationRoute"
                    :to="conversationRoute"
                    class="ms-1 text-n-blue-11 hover:underline"
                  >
                    {{ t('CRM.DEALS.DETAIL.OPEN_CONVERSATION') }}
                  </router-link>
                </dd>
              </div>
              <div v-if="deal.description">
                <dt class="text-n-slate-11">
                  {{ t('CRM.DEALS.FORM.DESCRIPTION') }}
                </dt>
                <dd class="whitespace-pre-wrap text-n-slate-12">
                  {{ deal.description }}
                </dd>
              </div>
              <div>
                <dt class="text-n-slate-11">
                  {{ t('CRM.DEALS.COLUMNS.UPDATED') }}
                </dt>
                <dd class="text-n-slate-12">{{ dateTime(deal.updated_at) }}</dd>
              </div>
            </dl>
          </section>

          <section class="p-4 rounded-2xl border border-n-weak bg-n-solid-1">
            <h2 class="mb-3 text-heading-3 text-n-slate-12">
              {{ t('CRM.DEALS.DETAIL.ACTIVITY') }}
            </h2>
            <DealActivityList
              :activities="activities"
              :stages-by-id="stagesById"
              :currency="deal.currency"
            />
          </section>
        </div>
      </div>

      <DealForm
        ref="dealForm"
        :pipelines="pipelines"
        :deal="deal"
        :is-saving="flags.isSaving"
        @submit="onEdit"
      />
      <LostReasonDialog ref="lostDialog" @confirm="onLostConfirm" />
      <TaskForm ref="taskForm" :presets="taskPresets" @submit="onTaskSubmit" />
      <Dialog
        ref="deleteDialog"
        type="alert"
        :title="t('CRM.DEALS.DELETE_CONFIRM_TITLE')"
        :description="t('CRM.DEALS.DELETE_CONFIRM_BODY')"
        :confirm-button-label="t('CRM.COMMON.DELETE')"
        :cancel-button-label="t('CRM.COMMON.CANCEL')"
        @confirm="confirmDelete"
      />
    </template>
  </div>
</template>
