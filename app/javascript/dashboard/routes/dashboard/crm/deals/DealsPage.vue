<script setup>
// Custom (MyDesk): Sales > Deals: board or table, filters, forecast, new deal, lost-reason prompt
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { crmDealsAPI, crmReportsAPI } from 'dashboard/api/crm';
import { downloadCsvFile } from 'dashboard/helper/downloadHelper';
import CrmPageHeader from '../shared/CrmPageHeader.vue';
import CrmUnavailable from '../shared/CrmUnavailable.vue';
import AgentPicker from '../shared/AgentPicker.vue';
import { useCrmFormat } from '../shared/useCrmFormat';
import {
  apiErrorMessage,
  isStale,
  isUnavailable,
  DEAL_PRIORITIES,
} from '../shared/dealHelpers';
import DealsBoard from './DealsBoard.vue';
import DealsTable from './DealsTable.vue';
import DealForm from './DealForm.vue';
import LostReasonDialog from './LostReasonDialog.vue';

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const { accountScopedRoute } = useAccount();
const { money, plural } = useCrmFormat();

const pipelines = useMapGetter('crm/pipelines/all');
const dealsForStage = useMapGetter('crm/deals/dealsForStage');
const counts = useMapGetter('crm/deals/counts');
const forecast = useMapGetter('crm/deals/forecast');
const filters = useMapGetter('crm/deals/filters');
const flags = useMapGetter('crm/deals/getUIFlags');
const allLoaded = useMapGetter('crm/deals/allLoaded');
const isAdmin = useMapGetter('crm/status/isAdmin');
const crmSettings = useMapGetter('crm/status/settings');
// Team money is for administrators: an agent who sees the whole team's board gets the cards but no sums
// (the server leaves them out too). With "own deals only" on, the sums are the agent's own and stay.
const showMoney = computed(
  () => isAdmin.value || crmSettings.value?.agents_see_own_deals_only === true
);

const view = ref('board'); // board | table | discarded
const search = ref('');
const dealForm = ref(null);
const lostDialog = ref(null);
const presets = ref({});
const pendingLost = ref(null);
const isMoving = ref(false);
const discardedDeals = ref([]);
const tableDeals = ref([]);
const isTableLoading = ref(false);

const pipeline = computed(
  () =>
    pipelines.value.find(p => p.id === filters.value.pipelineId) ||
    pipelines.value[0]
);
const stagesById = computed(() =>
  Object.fromEntries((pipeline.value?.stages || []).map(s => [s.id, s]))
);
const pipelineOptions = computed(() =>
  pipelines.value.map(p => ({ value: p.id, label: p.name }))
);
const statusOptions = computed(() => [
  { value: '', label: t('CRM.COMMON.ALL') },
  { value: 'open', label: t('CRM.COMMON.OPEN') },
  { value: 'won', label: t('CRM.COMMON.WON') },
  { value: 'lost', label: t('CRM.COMMON.LOST') },
]);
const priorityOptions = computed(() => [
  { value: '', label: t('CRM.DEALS.ANY_PRIORITY') },
  ...DEAL_PRIORITIES.map(p => ({
    value: p,
    label: t(`CRM.DEALS.PRIORITIES.${p}`),
  })),
]);

const summary = computed(() => {
  if (!forecast.value) return '';
  const currency = forecast.value.currency || pipeline.value?.currency || 'SAR';
  return t('CRM.DEALS.SUMMARY', {
    open: plural('CRM.PLURALS.OPEN_DEALS', forecast.value.open_count),
    total: money(forecast.value.open_total_cents, currency),
    expected: money(forecast.value.expected_cents, currency),
  });
});

const load = () => store.dispatch('crm/deals/fetchBoard').catch(() => {});

const loadTable = async () => {
  if (!pipeline.value) return;
  isTableLoading.value = true;
  try {
    if (view.value === 'discarded') {
      const { data } = await crmDealsAPI.discarded({});
      discardedDeals.value = data.deals;
    } else {
      const { data } = await crmDealsAPI.get({
        pipeline_id: pipeline.value.id,
        assignee_id: filters.value.assigneeId || undefined,
        status: filters.value.status || undefined,
        q: filters.value.q || undefined,
        view: 'table',
      });
      tableDeals.value = data.deals;
    }
  } finally {
    isTableLoading.value = false;
  }
};

const refresh = () => (view.value === 'board' ? load() : loadTable());

onMounted(async () => {
  if (!pipelines.value.length)
    await store.dispatch('crm/pipelines/fetch').catch(() => {});
  if (!filters.value.pipelineId && pipelines.value[0]) {
    store.dispatch('crm/deals/setFilters', {
      pipelineId: pipelines.value[0].id,
    });
  }
  refresh();
});

watch(
  () => [
    filters.value.pipelineId,
    filters.value.assigneeId,
    filters.value.status,
    filters.value.priority,
    filters.value.q,
  ],
  refresh
);
watch(view, refresh);

let searchTimer = null;
watch(search, value => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(
    () => store.dispatch('crm/deals/setFilters', { q: value }),
    300
  );
});

const setPipeline = id =>
  store.dispatch('crm/deals/setFilters', { pipelineId: Number(id) });
const setAssignee = id =>
  store.dispatch('crm/deals/setFilters', { assigneeId: id ?? '' });
const setStatus = status => store.dispatch('crm/deals/setFilters', { status });
const setPriority = priority =>
  store.dispatch('crm/deals/setFilters', { priority });

const openDeal = deal =>
  router.push(accountScopedRoute('crm_deal', { dealId: deal.id }));

const openNew = (stage = null) => {
  presets.value = { pipeline_id: pipeline.value?.id, stage_id: stage?.id };
  dealForm.value?.open();
};

const onSubmit = async ({ payload }) => {
  try {
    const deal = await store.dispatch('crm/deals/create', payload);
    dealForm.value?.close();
    useAlert(t('CRM.DEALS.FORM.SAVED'));
    if (view.value !== 'board') loadTable();
    return deal;
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
    return null;
  }
};

const performMove = async ({
  dealId,
  stageId,
  position,
  lostReason,
  lostNote,
}) => {
  isMoving.value = true;
  try {
    await store.dispatch('crm/deals/move', {
      id: dealId,
      stageId,
      position,
      lostReason,
      lostNote,
    });
  } catch (error) {
    if (isStale(error)) {
      useAlert(t('CRM.COMMON.STALE_BODY'));
      load();
    } else if (isUnavailable(error)) {
      useAlert(t('CRM.COMMON.UNAVAILABLE_TITLE'));
    } else {
      useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
    }
  } finally {
    isMoving.value = false;
  }
};

// Landing on the lost stage asks for a reason first; everything else moves at once
const onMove = move => {
  if (move.stage.kind === 'lost') {
    pendingLost.value = move;
    lostDialog.value?.open();
    return;
  }
  performMove(move);
};

const onLostConfirm = async ({ reason, note }) => {
  const move = pendingLost.value;
  pendingLost.value = null;
  lostDialog.value?.close();
  if (move) await performMove({ ...move, lostReason: reason, lostNote: note });
};

const onLostCancel = () => {
  const move = pendingLost.value;
  pendingLost.value = null;
  if (move) load(); // the card was placed optimistically by the drag; reload restores it
};

const onRestore = async deal => {
  try {
    await store.dispatch('crm/deals/restore', deal.id);
    discardedDeals.value = discardedDeals.value.filter(d => d.id !== deal.id);
    useAlert(t('CRM.DEALS.RESTORED'));
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  }
};

const exportCsv = async () => {
  const today = new Date().toISOString().slice(0, 10);
  const from = new Date(Date.now() - 365 * 86400000).toISOString().slice(0, 10);
  try {
    const { data } = await crmReportsAPI.export({
      from,
      to: today,
      pipeline_id: pipeline.value?.id,
    });
    downloadCsvFile(`deals-${from}-${today}.csv`, data);
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  }
};

const viewOptions = computed(() => [
  { key: 'board', label: t('CRM.DEALS.VIEW_BOARD'), icon: 'i-lucide-kanban' },
  { key: 'table', label: t('CRM.DEALS.VIEW_TABLE'), icon: 'i-lucide-table' },
  ...(isAdmin.value
    ? [
        {
          key: 'discarded',
          label: t('CRM.DEALS.DISCARDED_TAB'),
          icon: 'i-lucide-trash-2',
        },
      ]
    : []),
]);

// "Show more" fills the same column with the stage's next deals
const loadingStageId = ref(null);
const onLoadMore = async stage => {
  loadingStageId.value = stage.id;
  try {
    await store.dispatch('crm/deals/loadMoreForStage', stage.id);
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  } finally {
    loadingStageId.value = null;
  }
};

const goToSettings = () =>
  router.push(accountScopedRoute('crm_settings', {}, { tab: 'pipelines' }));
</script>

<template>
  <div class="flex flex-col h-full min-w-0">
    <CrmPageHeader
      :title="t('CRM.DEALS.TITLE')"
      :subtitle="t('CRM.DEALS.SUBTITLE')"
    >
      <!-- On phones the two secondary actions show their icon only (label kept for screen readers),
           so the header holds one row -->
      <template #actions>
        <Button
          v-if="isAdmin"
          :label="t('CRM.DEALS.EDIT_PIPELINE')"
          :title="t('CRM.DEALS.EDIT_PIPELINE')"
          variant="faded"
          size="sm"
          icon="i-lucide-settings-2"
          class="max-sm:!px-2 max-sm:[&>span.truncate]:sr-only"
          @click="goToSettings"
        />
        <Button
          :label="t('CRM.DEALS.EXPORT')"
          :title="t('CRM.DEALS.EXPORT')"
          variant="faded"
          size="sm"
          icon="i-lucide-download"
          class="max-sm:!px-2 max-sm:[&>span.truncate]:sr-only"
          @click="exportCsv"
        />
        <Button
          :label="t('CRM.DEALS.NEW')"
          size="sm"
          icon="i-lucide-plus"
          @click="openNew()"
        />
      </template>
    </CrmPageHeader>

    <div class="flex flex-wrap items-center gap-3 px-6 pb-4">
      <Select
        v-if="pipelineOptions.length > 1"
        :model-value="pipeline?.id || ''"
        :options="pipelineOptions"
        :aria-label="t('CRM.DEALS.PIPELINE')"
        class="w-48"
        @update:model-value="setPipeline"
      />
      <div class="w-44">
        <AgentPicker
          :model-value="filters.assigneeId || ''"
          :none-label="t('CRM.COMMON.ANY_ASSIGNEE')"
          :aria-label="t('CRM.DEALS.ASSIGNEE')"
          @update:model-value="setAssignee"
        />
      </div>
      <Select
        :model-value="filters.status"
        :options="statusOptions"
        :aria-label="t('CRM.DEALS.STATUS')"
        class="w-36"
        @update:model-value="setStatus"
      />
      <Select
        :model-value="filters.priority || ''"
        :options="priorityOptions"
        :aria-label="t('CRM.DEALS.PRIORITY')"
        class="w-36"
        @update:model-value="setPriority"
      />
      <Input
        v-model="search"
        type="search"
        :placeholder="t('CRM.DEALS.SEARCH_PLACEHOLDER')"
        :aria-label="t('CRM.COMMON.SEARCH')"
        class="group w-full sm:w-56 [&>input]:!ps-8"
        size="sm"
      >
        <!-- The Input prefix slot is not positioned for us: sit the icon inside the field's start edge -->
        <template #prefix>
          <span
            class="absolute top-1/2 -translate-y-1/2 start-2.5 i-lucide-search size-3.5 text-n-slate-10 group-focus-within:text-n-brand pointer-events-none"
            aria-hidden="true"
          />
        </template>
      </Input>
      <div
        class="flex items-center gap-1 p-0.5 ms-auto rounded-lg bg-n-alpha-black2"
        role="group"
        :aria-label="t('CRM.DEALS.VIEW_LABEL')"
      >
        <Button
          v-for="option in viewOptions"
          :key="option.key"
          :label="option.label"
          :icon="option.icon"
          size="sm"
          :variant="view === option.key ? 'faded' : 'ghost'"
          :color="view === option.key ? 'blue' : 'slate'"
          :aria-pressed="view === option.key"
          @click="view = option.key"
        />
      </div>
    </div>

    <p
      v-if="showMoney && summary && view === 'board'"
      class="px-6 pb-3 text-body-main text-n-slate-11 tabular-nums"
      dir="auto"
    >
      {{ summary }}
    </p>

    <CrmUnavailable
      v-if="flags.isUnavailable"
      :is-loading="flags.isFetching"
      @retry="refresh"
    />

    <div
      v-else-if="
        (view === 'board' && !flags.hasFetched) ||
        (view !== 'board' && isTableLoading)
      "
      class="flex items-center justify-center flex-1"
    >
      <Spinner />
    </div>

    <template v-else-if="pipeline">
      <div
        v-if="view === 'board' && !allLoaded.length && !flags.isFetching"
        class="flex flex-col items-center justify-center gap-2 py-16 text-center"
      >
        <span class="i-lucide-briefcase size-8 text-n-slate-9" />
        <h2 class="text-heading-2 text-n-slate-12">
          {{ t('CRM.DEALS.EMPTY_TITLE') }}
        </h2>
        <p class="text-body-main text-n-slate-11">
          {{ t('CRM.DEALS.EMPTY_BODY') }}
        </p>
        <Button
          :label="t('CRM.DEALS.NEW')"
          size="sm"
          icon="i-lucide-plus"
          class="mt-2"
          @click="openNew()"
        />
      </div>
      <DealsBoard
        v-else-if="view === 'board'"
        :pipeline="pipeline"
        :deals-for-stage="dealsForStage"
        :counts="counts"
        :show-money="showMoney"
        :loading-stage-id="loadingStageId"
        @move="onMove"
        @open="openDeal"
        @add="openNew"
        @load-more="onLoadMore"
      />
      <DealsTable
        v-else
        :deals="view === 'discarded' ? discardedDeals : tableDeals"
        :stages-by-id="stagesById"
        :currency="pipeline.currency"
        :discarded="view === 'discarded'"
        @open="openDeal"
        @restore="onRestore"
      />
    </template>

    <DealForm
      ref="dealForm"
      :pipelines="pipelines"
      :presets="presets"
      :is-saving="flags.isSaving"
      @submit="onSubmit"
    />
    <LostReasonDialog
      ref="lostDialog"
      :is-loading="isMoving"
      @confirm="onLostConfirm"
      @cancel="onLostCancel"
    />
  </div>
</template>
