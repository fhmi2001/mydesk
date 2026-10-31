<script setup>
// Custom (MyDesk): Sales > Settings (administrators), one tab each: General (visibility, default currency),
// Lost reasons, Pipelines. The tab is kept in ?tab= so links (e.g. "Edit pipeline") can open the right one.
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { crmSettingsAPI, crmDealsAPI } from 'dashboard/api/crm';
import CrmPageHeader from '../shared/CrmPageHeader.vue';
import { apiErrorMessage } from '../shared/dealHelpers';
import PipelineEditor from './PipelineEditor.vue';
import LostReasonsEditor from './LostReasonsEditor.vue';

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const TABS = ['general', 'lost_reasons', 'pipelines'];
const activeTab = computed(() =>
  TABS.includes(route.query.tab) ? route.query.tab : 'general'
);
const tabs = computed(() =>
  TABS.map(key => ({ key, label: t(`CRM.SETTINGS.TABS.${key}`) }))
);
const activeTabIndex = computed(() => TABS.indexOf(activeTab.value));
const onTab = tab =>
  router.replace({ query: { ...route.query, tab: tab.key } });

const pipelines = useMapGetter('crm/pipelines/all');
const pipelineFlags = useMapGetter('crm/pipelines/getUIFlags');
const isAdmin = useMapGetter('crm/status/isAdmin');

const settings = ref({
  agents_see_own_deals_only: false,
  default_currency: 'SAR',
  currencies: [],
});
const stageDealCounts = ref({});
const isLoading = ref(true);
const deleteTarget = ref(null);
const deleteDialog = ref(null);

const currencyOptions = computed(() =>
  settings.value.currencies.map(c => ({ value: c, label: c }))
);

const loadCounts = async () => {
  const counts = {};
  await Promise.all(
    pipelines.value.map(async pipeline => {
      const { data } = await crmDealsAPI.get({
        pipeline_id: pipeline.id,
        view: 'board',
      });
      Object.entries(data.counts || {}).forEach(([stageId, c]) => {
        counts[stageId] = c.count;
      });
    })
  );
  stageDealCounts.value = counts;
};

onMounted(async () => {
  try {
    const [{ data }] = await Promise.all([
      crmSettingsAPI.get(),
      store.dispatch('crm/pipelines/fetch'),
    ]);
    settings.value = data;
    await loadCounts();
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  } finally {
    isLoading.value = false;
  }
});

const saveSetting = async patch => {
  try {
    const { data } = await crmSettingsAPI.update(patch);
    settings.value = { ...settings.value, ...data };
    store.dispatch('crm/status/fetch');
    useAlert(t('CRM.COMMON.SAVED'));
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  }
};

const onSave = async payload => {
  try {
    await store.dispatch('crm/pipelines/update', payload);
    await loadCounts();
    useAlert(t('CRM.SETTINGS.SAVED'));
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  }
};

const addPipeline = async () => {
  try {
    await store.dispatch('crm/pipelines/create', {
      name: `${t('CRM.SIDEBAR.GROUP')} ${pipelines.value.length + 1}`,
    });
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  }
};

const askDelete = pipeline => {
  deleteTarget.value = pipeline;
  deleteDialog.value?.open();
};
const confirmDelete = async () => {
  try {
    await store.dispatch('crm/pipelines/delete', deleteTarget.value.id);
    deleteDialog.value?.close();
    useAlert(t('CRM.SETTINGS.DELETED'));
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  }
};
</script>

<template>
  <div class="flex flex-col h-full min-w-0 overflow-y-auto">
    <CrmPageHeader
      :title="t('CRM.SETTINGS.TITLE')"
      :subtitle="t('CRM.SETTINGS.SUBTITLE')"
    >
      <template #actions>
        <Button
          v-if="isAdmin && activeTab === 'pipelines'"
          :label="t('CRM.SETTINGS.NEW_PIPELINE')"
          size="sm"
          variant="faded"
          icon="i-lucide-plus"
          @click="addPipeline"
        />
      </template>
    </CrmPageHeader>

    <p v-if="!isAdmin" class="px-6 text-body-main text-n-slate-11">
      {{ t('CRM.SETTINGS.ADMIN_ONLY') }}
    </p>
    <div v-else-if="isLoading" class="flex items-center justify-center flex-1">
      <Spinner />
    </div>

    <div v-else class="flex flex-col gap-6 px-6 pb-8">
      <TabBar
        :key="activeTab"
        :tabs="tabs"
        :initial-active-tab="activeTabIndex"
        class="self-start"
        @tab-changed="onTab"
      />

      <section
        v-if="activeTab === 'general'"
        class="p-5 rounded-2xl border border-n-weak bg-n-solid-1"
      >
        <h2 class="mb-4 text-heading-3 text-n-slate-12">
          {{ t('CRM.SETTINGS.TABS.general') }}
        </h2>
        <div class="flex items-start justify-between gap-4">
          <div>
            <p class="text-sm text-n-slate-12">
              {{ t('CRM.SETTINGS.OWN_DEALS_ONLY') }}
            </p>
            <p class="text-xs text-n-slate-11">
              {{ t('CRM.SETTINGS.OWN_DEALS_ONLY_HINT') }}
            </p>
          </div>
          <Switch
            :model-value="settings.agents_see_own_deals_only"
            @change="
              saveSetting({
                agents_see_own_deals_only: !settings.agents_see_own_deals_only,
              })
            "
          />
        </div>
        <div class="flex items-center justify-between gap-4 mt-4">
          <p class="text-sm text-n-slate-12">
            {{ t('CRM.SETTINGS.DEFAULT_CURRENCY') }}
          </p>
          <Select
            :model-value="settings.default_currency"
            :options="currencyOptions"
            class="w-32"
            @update:model-value="v => saveSetting({ default_currency: v })"
          />
        </div>
      </section>

      <LostReasonsEditor v-if="activeTab === 'lost_reasons'" />

      <template v-if="activeTab === 'pipelines'">
        <PipelineEditor
          v-for="pipeline in pipelines"
          :key="pipeline.id"
          :pipeline="pipeline"
          :currencies="settings.currencies"
          :stage-deal-counts="stageDealCounts"
          :is-saving="pipelineFlags.isSaving"
          :can-delete="pipelines.length > 1 && !pipeline.deals_count"
          @save="onSave"
          @delete="askDelete"
        />
      </template>
    </div>

    <Dialog
      ref="deleteDialog"
      type="alert"
      :title="t('CRM.SETTINGS.DELETE_PIPELINE')"
      :description="t('CRM.SETTINGS.DELETE_PIPELINE_CONFIRM')"
      :confirm-button-label="t('CRM.COMMON.DELETE')"
      :cancel-button-label="t('CRM.COMMON.CANCEL')"
      @confirm="confirmDelete"
    />
  </div>
</template>
