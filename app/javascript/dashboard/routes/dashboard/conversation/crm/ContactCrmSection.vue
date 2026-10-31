<script setup>
// Custom (MyDesk): "Deals & tasks" for one contact, inside the conversation side panel and the contact page.
// New deals and tasks are pre-filled with the contact, the conversation and its assignee. Renders nothing
// when the CRM is off or unreachable, so the conversation never depends on it.
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import Button from 'dashboard/components-next/button/Button.vue';
import { crmContactSummaryAPI } from 'dashboard/api/crm';
import { useCrmFormat } from 'dashboard/routes/dashboard/crm/shared/useCrmFormat';
import StatusBadge from 'dashboard/routes/dashboard/crm/shared/StatusBadge.vue';
import { apiErrorMessage } from 'dashboard/routes/dashboard/crm/shared/dealHelpers';
import DealForm from 'dashboard/routes/dashboard/crm/deals/DealForm.vue';
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
const dealFlags = useMapGetter('crm/deals/getUIFlags');
const taskFlags = useMapGetter('crm/tasks/getUIFlags');

const deals = ref([]);
const tasks = ref([]);
const closedCount = ref(0);
const failed = ref(false);
const loaded = ref(false);
const dealForm = ref(null);
const taskForm = ref(null);

const stageName = deal =>
  pipelines.value
    .find(p => p.id === deal.pipeline_id)
    ?.stages.find(s => s.id === deal.stage_id)?.name || '';

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

const dealPresets = computed(() => ({
  contact_id: Number(props.contactId),
  contact_name: props.contactName,
  assignee_id: props.assigneeId ? Number(props.assigneeId) : null,
  conversation_id: props.conversationId,
}));
const taskPresets = computed(() => ({
  contact_id: Number(props.contactId),
  contact_name: props.contactName,
  assignee_id: props.assigneeId ? Number(props.assigneeId) : null,
  conversation_id: props.conversationId,
}));

const onDealSubmit = async ({ payload }) => {
  try {
    await store.dispatch('crm/deals/create', {
      ...payload,
      pipeline_id: payload.pipeline_id || pipelines.value[0]?.id,
    });
    dealForm.value?.close();
    useAlert(t('CRM.DEALS.FORM.SAVED'));
    load();
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  }
};

const onTaskSubmit = async ({ payload }) => {
  try {
    await store.dispatch('crm/tasks/create', payload);
    taskForm.value?.close();
    useAlert(t('CRM.TASKS.FORM.SAVED'));
    load();
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  }
};

const completeTask = async task => {
  try {
    await store.dispatch('crm/tasks/complete', task.id);
    tasks.value = tasks.value.filter(x => x.id !== task.id);
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  }
};

const openDeal = deal =>
  router.push(accountScopedRoute('crm_deal', { dealId: deal.id }));
const openTasks = () => router.push(accountScopedRoute('crm_tasks'));
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
        @click="dealForm?.open()"
      />
      <Button
        :label="t('CRM.PANEL.NEW_TASK')"
        size="xs"
        variant="faded"
        icon="i-lucide-list-plus"
        @click="taskForm?.open()"
      />
    </div>

    <p v-if="!deals.length && !tasks.length" class="text-xs text-n-slate-11">
      {{ t('CRM.PANEL.NONE') }}
    </p>

    <template v-if="deals.length">
      <p class="text-xs font-medium text-n-slate-11">
        {{ t('CRM.PANEL.OPEN_DEALS') }}
      </p>
      <ul class="flex flex-col gap-1.5">
        <li v-for="deal in deals" :key="deal.id">
          <button
            type="button"
            class="w-full p-2 text-start rounded-lg border border-n-weak bg-n-solid-1 hover:border-n-strong"
            @click="openDeal(deal)"
          >
            <div class="flex items-center justify-between gap-2">
              <span class="text-sm truncate text-n-slate-12">{{
                deal.title
              }}</span>
              <StatusBadge :status="deal.status" />
            </div>
            <p class="mt-0.5 text-xs text-n-slate-11 tabular-nums" dir="auto">
              {{ money(deal.amount_cents, deal.currency) }} ·
              {{ stageName(deal) }}
            </p>
          </button>
        </li>
      </ul>
    </template>

    <template v-if="tasks.length">
      <p class="text-xs font-medium text-n-slate-11">
        {{ t('CRM.PANEL.UPCOMING_TASKS') }}
      </p>
      <ul class="flex flex-col gap-1.5">
        <li
          v-for="task in tasks"
          :key="task.id"
          class="flex items-start gap-2 p-2 rounded-lg border border-n-weak bg-n-solid-1"
        >
          <button
            type="button"
            class="flex items-center justify-center mt-0.5 border-2 rounded-full size-4 shrink-0 border-n-slate-8 hover:border-n-teal-9"
            :aria-label="t('CRM.TASKS.COMPLETE')"
            @click="completeTask(task)"
          />
          <div class="min-w-0">
            <p class="text-sm truncate text-n-slate-12">{{ task.title }}</p>
            <p
              class="text-xs"
              :class="task.overdue ? 'text-n-ruby-11' : 'text-n-slate-11'"
            >
              {{ task.due_at ? dateTime(task.due_at) : t('CRM.TASKS.NO_DUE') }}
            </p>
          </div>
        </li>
      </ul>
    </template>

    <div class="flex items-center justify-between text-xs text-n-slate-11">
      <span v-if="closedCount">{{
        t('CRM.PANEL.CLOSED_COUNT', { count: closedCount })
      }}</span>
      <button
        type="button"
        class="ms-auto text-n-blue-11 hover:underline"
        @click="openTasks"
      >
        {{ t('CRM.PANEL.VIEW_ALL') }}
      </button>
    </div>

    <DealForm
      ref="dealForm"
      :pipelines="pipelines"
      :presets="dealPresets"
      :is-saving="dealFlags.isSaving"
      @submit="onDealSubmit"
    />
    <TaskForm
      ref="taskForm"
      :presets="taskPresets"
      :is-saving="taskFlags.isSaving"
      @submit="onTaskSubmit"
    />
  </div>
</template>
