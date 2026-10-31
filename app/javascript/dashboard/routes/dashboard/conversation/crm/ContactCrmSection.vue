<script setup>
// Custom (MyDesk): "Deals & tasks" for one contact, inside the conversation side panel and the contact page.
// Each open deal can change stage here (won / lost included) and gets its own tasks; new deals and tasks are
// pre-filled with the contact, the conversation and its assignee. Renders nothing when the CRM is off or
// unreachable, so the conversation never depends on it.
import { ref, computed, nextTick, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import { crmContactSummaryAPI } from 'dashboard/api/crm';
import { useCrmFormat } from 'dashboard/routes/dashboard/crm/shared/useCrmFormat';
import {
  apiErrorMessage,
  isStale,
} from 'dashboard/routes/dashboard/crm/shared/dealHelpers';
import LostReasonDialog from 'dashboard/routes/dashboard/crm/deals/LostReasonDialog.vue';
import TaskForm from 'dashboard/routes/dashboard/crm/tasks/TaskForm.vue';

const props = defineProps({
  contactId: { type: [Number, String], required: true },
  contactName: { type: String, default: '' },
  conversationId: { type: [Number, String], default: null },
  assigneeId: { type: [Number, String], default: null },
});
const { t } = useI18n();
const store = useStore();
const router = useRouter();
const { accountScopedRoute } = useAccount();
const { money, dateTime } = useCrmFormat();

const enabled = useMapGetter('crm/status/isEnabled');
const pipelines = useMapGetter('crm/pipelines/all');
const taskFlags = useMapGetter('crm/tasks/getUIFlags');

const deals = ref([]);
const tasks = ref([]);
const closedCount = ref(0);
const failed = ref(false);
const loaded = ref(false);
const taskForm = ref(null);
const lostDialog = ref(null);
const taskDeal = ref(null);
const pendingLost = ref(null);
const movingId = ref(null);

const pipelineOf = deal => pipelines.value.find(p => p.id === deal.pipeline_id);
const stageOptions = deal =>
  (pipelineOf(deal)?.stages || []).map(s => ({ value: s.id, label: s.name }));
const tasksOf = deal => tasks.value.filter(task => task.deal?.id === deal.id);
const looseTasks = computed(() =>
  tasks.value.filter(task => !deals.value.some(d => d.id === task.deal?.id))
);

const load = async () => {
  if (!enabled.value || !props.contactId) return;
  try {
    if (!pipelines.value.length) await store.dispatch('crm/pipelines/fetch');
    const { data } = await crmContactSummaryAPI.get(props.contactId);
    deals.value = data.deals;
    tasks.value = data.tasks;
    closedCount.value = data.closed_count;
    failed.value = false;
  } catch (error) {
    failed.value = true;
  } finally {
    loaded.value = true;
  }
};

onMounted(load);
watch(() => [props.contactId, enabled.value], load);

const visible = computed(() => enabled.value && loaded.value && !failed.value);

const basePresets = computed(() => ({
  contact_id: Number(props.contactId),
  contact_name: props.contactName,
  assignee_id: props.assigneeId ? Number(props.assigneeId) : null,
  conversation_id: props.conversationId,
}));
const taskPresets = computed(() =>
  taskDeal.value
    ? {
        ...basePresets.value,
        deal_id: taskDeal.value.id,
        deal_title: taskDeal.value.title,
      }
    : basePresets.value
);

const handleError = error => {
  useAlert(
    isStale(error)
      ? t('CRM.COMMON.STALE_BODY')
      : apiErrorMessage(error, t('CRM.COMMON.ERROR'))
  );
  load();
};

const performMove = async (deal, stageId, lost = {}) => {
  movingId.value = deal.id;
  try {
    await store.dispatch('crm/deals/move', {
      id: deal.id,
      stageId,
      lostReason: lost.reason,
      lostNote: lost.note,
      lockVersion: deal.lock_version,
    });
    useAlert(t('CRM.PANEL.STAGE_CHANGED'));
    await load();
  } catch (error) {
    handleError(error);
  } finally {
    movingId.value = null;
  }
};

// Changing to the lost stage asks for the reason and notes first
const onStageChange = (deal, stageId) => {
  const id = Number(stageId);
  if (!id || id === deal.stage_id) return;
  const stage = pipelineOf(deal)?.stages.find(s => s.id === id);
  if (stage?.kind === 'lost') {
    pendingLost.value = { deal, stageId: id };
    lostDialog.value?.open();
    return;
  }
  performMove(deal, id);
};

const onLostConfirm = lost => {
  const pending = pendingLost.value;
  pendingLost.value = null;
  lostDialog.value?.close();
  if (pending) performMove(pending.deal, pending.stageId, lost);
};

// The select already shows the lost stage; reload puts it back
const onLostCancel = () => {
  pendingLost.value = null;
  load();
};

// The form reads its presets when it opens, so let the chosen deal reach it first
const openTaskFor = async (deal = null) => {
  taskDeal.value = deal;
  await nextTick();
  taskForm.value?.open();
};

// A new deal opens in its own page with this contact and conversation filled in, and comes back here once saved
const openNewDeal = () => {
  const { contact_id, contact_name, assignee_id, conversation_id } =
    basePresets.value;
  router.push(
    accountScopedRoute(
      'crm_deal_new',
      {},
      {
        contact_id,
        contact_name: contact_name || undefined,
        assignee_id: assignee_id || undefined,
        conversation_id: conversation_id || undefined,
        return_to: router.currentRoute.value.fullPath,
      }
    )
  );
};

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

const completeTask = async task => {
  try {
    await store.dispatch('crm/tasks/complete', task.id);
    tasks.value = tasks.value.filter(x => x.id !== task.id);
  } catch (error) {
    handleError(error);
  }
};

const dueText = task =>
  task.due_at ? dateTime(task.due_at) : t('CRM.TASKS.NO_DUE');
const dealAmount = deal => money(deal.amount_cents, deal.currency);

const openDeal = deal =>
  router.push(accountScopedRoute('crm_deal', { dealId: deal.id }));
const openTasks = () => router.push(accountScopedRoute('crm_tasks'));
const taskRoute = task => accountScopedRoute('crm_task', { taskId: task.id });

// The base button CSS drops the border style and pads buttons, hence border-solid and p-0; the ::before
// widens the tap area to 40px without growing the 20px circle
const TASK_CHECK_CLASS =
  "relative flex items-center justify-center p-0 mt-0.5 border-2 border-solid rounded-full size-5 shrink-0 border-n-slate-8 transition-colors hover:border-n-teal-11 before:absolute before:-inset-2.5 before:content-[''] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand";
</script>

<template>
  <div
    v-if="visible"
    class="flex flex-col gap-3"
    data-test-id="contact-crm-section"
  >
    <div class="flex items-center gap-2">
      <Button
        :label="t('CRM.PANEL.NEW_DEAL')"
        size="xs"
        variant="faded"
        icon="i-lucide-briefcase"
        @click="openNewDeal"
      />
      <Button
        :label="t('CRM.PANEL.NEW_TASK')"
        size="xs"
        variant="faded"
        icon="i-lucide-list-plus"
        @click="openTaskFor()"
      />
    </div>

    <p
      v-if="!deals.length && !tasks.length"
      class="text-label-small text-n-slate-11"
    >
      {{ t('CRM.PANEL.NONE') }}
    </p>

    <template v-if="deals.length">
      <h3 class="text-label-small font-medium text-n-slate-11">
        {{ t('CRM.PANEL.OPEN_DEALS') }}
      </h3>
      <ul class="flex flex-col gap-2">
        <li
          v-for="deal in deals"
          :key="deal.id"
          class="p-2 rounded-lg bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
          :data-deal-id="deal.id"
        >
          <button
            type="button"
            class="w-full p-0 text-start hover:underline focus-visible:outline-2 focus-visible:outline-n-brand rounded"
            @click="openDeal(deal)"
          >
            <span class="block truncate text-body-main text-n-slate-12">
              {{ deal.title }}
            </span>
            <span
              class="block mt-0.5 text-label-small text-n-slate-11 tabular-nums"
              dir="auto"
            >
              {{ dealAmount(deal) }}
            </span>
          </button>

          <div class="flex items-center gap-2 mt-2">
            <Select
              :model-value="deal.stage_id"
              :options="stageOptions(deal)"
              :disabled="movingId === deal.id"
              :aria-label="t('CRM.PANEL.CHANGE_STAGE')"
              class="flex-1 min-w-0"
              @update:model-value="value => onStageChange(deal, value)"
            />
            <Button
              :label="t('CRM.PANEL.ADD_TASK')"
              :aria-label="t('CRM.PANEL.ADD_TASK_FOR', { title: deal.title })"
              size="xs"
              variant="faded"
              icon="i-lucide-plus"
              @click="openTaskFor(deal)"
            />
          </div>

          <ul v-if="tasksOf(deal).length" class="flex flex-col gap-2 mt-2">
            <li
              v-for="task in tasksOf(deal)"
              :key="task.id"
              class="flex items-start gap-2 ps-1"
            >
              <button
                type="button"
                :class="TASK_CHECK_CLASS"
                :aria-label="
                  t('CRM.TASKS.COMPLETE_ARIA', { title: task.title })
                "
                @click="completeTask(task)"
              />
              <div class="min-w-0">
                <router-link
                  :to="taskRoute(task)"
                  class="block truncate text-label-small text-n-slate-12 hover:underline"
                >
                  {{ task.title }}
                </router-link>
                <p
                  class="text-label-small"
                  :class="task.overdue ? 'text-n-ruby-11' : 'text-n-slate-10'"
                >
                  {{ dueText(task) }}
                </p>
              </div>
            </li>
          </ul>
        </li>
      </ul>
    </template>

    <template v-if="looseTasks.length">
      <h3 class="text-label-small font-medium text-n-slate-11">
        {{ t('CRM.PANEL.UPCOMING_TASKS') }}
      </h3>
      <ul class="flex flex-col gap-1.5">
        <li
          v-for="task in looseTasks"
          :key="task.id"
          class="flex items-start gap-2 p-2 rounded-lg bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
        >
          <button
            type="button"
            :class="TASK_CHECK_CLASS"
            :aria-label="t('CRM.TASKS.COMPLETE_ARIA', { title: task.title })"
            @click="completeTask(task)"
          />
          <div class="min-w-0">
            <router-link
              :to="taskRoute(task)"
              class="block truncate text-body-main text-n-slate-12 hover:underline"
            >
              {{ task.title }}
            </router-link>
            <p
              class="text-label-small"
              :class="task.overdue ? 'text-n-ruby-11' : 'text-n-slate-11'"
            >
              {{ dueText(task) }}
            </p>
          </div>
        </li>
      </ul>
    </template>

    <div
      class="flex items-center justify-between text-label-small text-n-slate-11"
    >
      <span v-if="closedCount">
        {{ t('CRM.PANEL.CLOSED_COUNT', { count: closedCount }) }}
      </span>
      <button
        type="button"
        class="p-0 ms-auto text-n-blue-11 hover:underline"
        @click="openTasks"
      >
        {{ t('CRM.PANEL.VIEW_ALL') }}
      </button>
    </div>

    <TaskForm
      ref="taskForm"
      :presets="taskPresets"
      :is-saving="taskFlags.isSaving"
      @submit="onTaskSubmit"
    />
    <LostReasonDialog
      ref="lostDialog"
      :is-loading="Boolean(movingId)"
      @confirm="onLostConfirm"
      @cancel="onLostCancel"
    />
  </div>
</template>
