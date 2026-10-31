<script setup>
// Custom (MyDesk): Sales > Settings (administrators), one tab each: General (visibility, the Sales currency, the
// report thresholds), Lost reasons, Lists (lead source, product, competitor, region, industry), Targets, Pipelines.
// The tab is kept in ?tab= so links (e.g. "Edit pipeline") can open the right one.
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { crmSettingsAPI, crmDealsAPI } from 'dashboard/api/crm';
import CrmPageHeader from '../shared/CrmPageHeader.vue';
import { apiErrorMessage, DEAL_LISTS } from '../shared/dealHelpers';
import PipelineEditor from './PipelineEditor.vue';
import LostReasonsEditor from './LostReasonsEditor.vue';
import ListItemsEditor from './ListItemsEditor.vue';
import TargetsEditor from './TargetsEditor.vue';

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const TABS = ['general', 'lost_reasons', 'lists', 'targets', 'pipelines'];
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
  currency_locked: false,
  stale_days: 14,
  coverage_multiple: 3,
});
// The thresholds are typed, then saved when the field is left
const staleDays = ref('');
const coverageMultiple = ref('');
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
    staleDays.value = String(data.stale_days);
    coverageMultiple.value = String(data.coverage_multiple);
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
    store.dispatch('crm/pipelines/fetch');
    useAlert(t('CRM.COMMON.SAVED'));
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  } finally {
    staleDays.value = String(settings.value.stale_days);
    coverageMultiple.value = String(settings.value.coverage_multiple);
  }
};

const saveThreshold = (key, value) => {
  if (String(value).trim() === String(settings.value[key])) return;
  saveSetting({ [key]: value });
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

      <!-- The tab already names this panel, so its heading is for screen readers only -->
      <section
        v-if="activeTab === 'general'"
        class="p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
        aria-labelledby="crm-settings-general"
      >
        <h2 id="crm-settings-general" class="sr-only">
          {{ t('CRM.SETTINGS.TABS.general') }}
        </h2>
        <div class="flex items-start justify-between gap-4">
          <div>
            <p
              id="crm-settings-own-deals"
              class="text-body-main text-n-slate-12"
            >
              {{ t('CRM.SETTINGS.OWN_DEALS_ONLY') }}
            </p>
            <p
              id="crm-settings-own-deals-hint"
              class="text-label-small text-n-slate-11"
            >
              {{ t('CRM.SETTINGS.OWN_DEALS_ONLY_HINT') }}
            </p>
          </div>
          <Switch
            :model-value="settings.agents_see_own_deals_only"
            aria-labelledby="crm-settings-own-deals"
            aria-describedby="crm-settings-own-deals-hint"
            @change="
              saveSetting({
                agents_see_own_deals_only: !settings.agents_see_own_deals_only,
              })
            "
          />
        </div>
        <!-- One currency for the whole Sales section; amounts are never converted, so it locks once deals exist -->
        <div class="flex items-start justify-between gap-4 mt-4">
          <div>
            <p class="text-body-main text-n-slate-12" aria-hidden="true">
              {{ t('CRM.SETTINGS.CURRENCY') }}
            </p>
            <p
              id="crm-settings-currency-hint"
              class="text-label-small text-n-slate-11"
            >
              {{
                settings.currency_locked
                  ? t('CRM.SETTINGS.CURRENCY_LOCKED')
                  : t('CRM.SETTINGS.CURRENCY_HINT')
              }}
            </p>
          </div>
          <Select
            :model-value="settings.default_currency"
            :options="currencyOptions"
            :disabled="settings.currency_locked"
            :aria-label="t('CRM.SETTINGS.CURRENCY')"
            aria-describedby="crm-settings-currency-hint"
            class="w-32 shrink-0"
            @update:model-value="v => saveSetting({ default_currency: v })"
          />
        </div>

        <h3 class="mt-6 mb-1 text-heading-3 text-n-slate-12">
          {{ t('CRM.SETTINGS.REPORTS_HEADING') }}
        </h3>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <Input
            v-model="staleDays"
            inputmode="numeric"
            :label="t('CRM.SETTINGS.STALE_DAYS')"
            :message="t('CRM.SETTINGS.STALE_DAYS_HINT')"
            @blur="saveThreshold('stale_days', staleDays)"
          />
          <Input
            v-model="coverageMultiple"
            inputmode="decimal"
            :label="t('CRM.SETTINGS.COVERAGE')"
            :message="t('CRM.SETTINGS.COVERAGE_HINT')"
            @blur="saveThreshold('coverage_multiple', coverageMultiple)"
          />
        </div>
      </section>

      <LostReasonsEditor v-if="activeTab === 'lost_reasons'" />

      <template v-if="activeTab === 'lists'">
        <ListItemsEditor v-for="list in DEAL_LISTS" :key="list" :list="list" />
      </template>

      <TargetsEditor v-if="activeTab === 'targets'" />

      <template v-if="activeTab === 'pipelines'">
        <PipelineEditor
          v-for="pipeline in pipelines"
          :key="pipeline.id"
          :pipeline="pipeline"
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
