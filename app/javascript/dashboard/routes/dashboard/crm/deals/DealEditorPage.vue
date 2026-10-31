<script setup>
// Custom (MyDesk): a deal's full-page editor: new (crm_deal_new, /crm/deals/new) and edit (crm_deal_edit,
// /crm/deals/:dealId/edit). The main column is what every deal needs; the side column classifies it for reports.
// The save bar stays pinned at the top, so saving never depends on the page's length.
// A new deal takes presets from the query (pipeline_id, stage_id, contact_id, contact_name, assignee_id,
// conversation_id) and `return_to`, the in-app path to go back to (e.g. the conversation it was opened from).
import { ref, computed, onMounted, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { crmDealsAPI } from 'dashboard/api/crm';
import AgentPicker from '../shared/AgentPicker.vue';
import ContactPicker from '../shared/ContactPicker.vue';
import { useCrmLists } from '../shared/useCrmLists';
import {
  emptyDealForm,
  dealToForm,
  validateDeal,
  buildDealPayload,
  isPastDate,
  isStale,
  apiErrorMessage,
  DEAL_PRIORITIES,
  DEAL_LISTS,
  FORECAST_CATEGORIES,
  listField,
} from '../shared/dealHelpers';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const { accountScopedRoute } = useAccount();
const lists = useCrmLists();

const pipelines = useMapGetter('crm/pipelines/all');
const flags = useMapGetter('crm/deals/getUIFlags');
const crmSettings = useMapGetter('crm/status/settings');

const dealId = computed(() => route.params.dealId);
const isEdit = computed(() => Boolean(dealId.value));
const deal = ref(null);
const form = ref(emptyDealForm());
const errors = ref({});
const isLoading = ref(true);

const pipeline = computed(
  () =>
    pipelines.value.find(p => p.id === Number(form.value.pipeline_id)) ||
    pipelines.value[0]
);
const stage = computed(() =>
  (pipeline.value?.stages || []).find(s => s.id === Number(form.value.stage_id))
);
// An open deal needs an amount and an expected close date; one created straight into won or lost does not
const isOpenStage = computed(() => (stage.value?.kind || 'open') === 'open');
const currency = computed(
  () => crmSettings.value?.default_currency || pipeline.value?.currency || 'SAR'
);

const pipelineOptions = computed(() =>
  pipelines.value.map(p => ({ value: p.id, label: p.name }))
);
const stageOptions = computed(() =>
  (pipeline.value?.stages || []).map(s => ({ value: s.id, label: s.name }))
);
const priorityOptions = computed(() =>
  DEAL_PRIORITIES.map(p => ({
    value: p,
    label: t(`CRM.DEALS.PRIORITIES.${p}`),
  }))
);
const forecastOptions = computed(() => [
  { value: '', label: t('CRM.DEALS.FORM.FORECAST_AUTO') },
  ...FORECAST_CATEGORIES.map(c => ({
    value: c,
    label: t(`CRM.DEALS.FORECAST.${c}`),
  })),
]);

const errorText = key =>
  errors.value[key] ? t(`CRM.DEALS.FORM.${errors.value[key]}`) : '';
const closeDateMessage = computed(() => {
  if (errors.value.close_date) return errorText('close_date');
  return isPastDate(form.value.close_date)
    ? t('CRM.DEALS.FORM.CLOSE_DATE_PAST')
    : '';
});

// Where Cancel and Save lead: back to where the editor was opened from
const returnTo = computed(() => {
  const path = route.query.return_to;
  return typeof path === 'string' && path.startsWith('/') ? path : null;
});
const leave = savedId => {
  if (returnTo.value) return router.push(returnTo.value);
  const id = savedId || dealId.value;
  return router.push(
    id
      ? accountScopedRoute('crm_deal', { dealId: id })
      : accountScopedRoute('crm_deals')
  );
};

const queryNumber = key =>
  route.query[key] ? Number(route.query[key]) || null : null;

const presetForm = () => {
  const first =
    pipelines.value.find(p => p.id === queryNumber('pipeline_id')) ||
    pipelines.value[0];
  form.value = emptyDealForm({
    pipeline_id: first?.id || null,
    stage_id:
      queryNumber('stage_id') ||
      first?.stages?.find(s => s.kind === 'open')?.id ||
      null,
    contact_id: queryNumber('contact_id'),
    contact_name: route.query.contact_name || '',
    assignee_id: queryNumber('assignee_id'),
    conversation_id: queryNumber('conversation_id'),
  });
};

const load = async () => {
  isLoading.value = true;
  errors.value = {};
  try {
    if (!pipelines.value.length) await store.dispatch('crm/pipelines/fetch');
    lists.load();
    if (isEdit.value) {
      const { data } = await crmDealsAPI.show(dealId.value);
      deal.value = data;
      form.value = dealToForm(data);
    } else {
      deal.value = null;
      presetForm();
    }
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  } finally {
    isLoading.value = false;
  }
};
onMounted(load);
watch(() => route.fullPath, load);

watch(
  () => form.value.pipeline_id,
  () => {
    if (!pipeline.value?.stages.some(s => s.id === Number(form.value.stage_id)))
      form.value.stage_id =
        pipeline.value?.stages.find(s => s.kind === 'open')?.id || null;
  }
);

// After a refused save, take the person to the first field that needs them, in reading order
const FIELD_ORDER = ['title', 'amount', 'close_date'];
const focusFirstError = async () => {
  await nextTick();
  const first = FIELD_ORDER.find(key => errors.value[key]);
  document.getElementById(`crm-deal-${first}`)?.focus();
};

const save = async () => {
  const result = validateDeal(form.value, { open: isOpenStage.value });
  errors.value = result.errors;
  if (!result.valid) {
    focusFirstError();
    return;
  }
  const payload = buildDealPayload(form.value);
  try {
    const saved = isEdit.value
      ? await store.dispatch('crm/deals/update', {
          id: dealId.value,
          ...payload,
        })
      : await store.dispatch('crm/deals/create', {
          ...payload,
          pipeline_id: payload.pipeline_id || pipelines.value[0]?.id,
        });
    useAlert(t('CRM.DEALS.FORM.SAVED'));
    leave(saved?.id);
  } catch (error) {
    if (isStale(error)) {
      useAlert(t('CRM.COMMON.STALE_BODY'));
      load();
      return;
    }
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  }
};
</script>

<template>
  <div class="flex flex-col h-full min-w-0 overflow-y-auto">
    <!-- The save bar: pinned, so Save is always one click away however long the form grows -->
    <header
      class="sticky top-0 z-10 flex flex-wrap items-center justify-between gap-3 px-6 py-3 border-b border-n-weak bg-n-background"
    >
      <div class="flex items-center min-w-0 gap-3">
        <Button
          icon="i-lucide-arrow-right"
          size="sm"
          variant="ghost"
          color="slate"
          class="ltr:rotate-180"
          :aria-label="t('CRM.COMMON.BACK')"
          @click="leave()"
        />
        <h1 class="truncate text-heading-1 text-n-slate-12">
          {{
            isEdit
              ? t('CRM.DEALS.FORM.EDIT_TITLE')
              : t('CRM.DEALS.FORM.NEW_TITLE')
          }}
        </h1>
      </div>
      <div class="flex items-center gap-2">
        <Button
          :label="t('CRM.COMMON.CANCEL')"
          size="sm"
          variant="faded"
          color="slate"
          @click="leave()"
        />
        <Button
          :label="t('CRM.COMMON.SAVE')"
          size="sm"
          :is-loading="flags.isSaving"
          :disabled="isLoading"
          @click="save"
        />
      </div>
    </header>

    <div v-if="isLoading" class="flex items-center justify-center flex-1">
      <Spinner />
    </div>

    <form
      v-else
      class="grid w-full max-w-6xl grid-cols-1 gap-6 px-6 py-6 mx-auto lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)] lg:items-start"
      novalidate
      @submit.prevent="save"
    >
      <!-- Main column: what every deal needs, in the order a person thinks of it -->
      <div class="flex flex-col gap-6">
        <section
          class="flex flex-col gap-5 p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
          aria-labelledby="crm-deal-essentials"
        >
          <h2 id="crm-deal-essentials" class="text-heading-3 text-n-slate-12">
            {{ t('CRM.DEALS.FORM.ESSENTIALS') }}
          </h2>
          <Input
            id="crm-deal-title"
            v-model="form.title"
            :label="`${t('CRM.DEALS.FORM.TITLE')} *`"
            :placeholder="t('CRM.DEALS.FORM.TITLE_PLACEHOLDER')"
            :message="errorText('title')"
            :message-type="errors.title ? 'error' : 'info'"
            aria-required="true"
            :aria-invalid="Boolean(errors.title)"
            autofocus
          />
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <Input
              id="crm-deal-amount"
              v-model="form.amount"
              :label="
                t('CRM.DEALS.FORM.AMOUNT_IN', { currency }) +
                (isOpenStage ? ' *' : '')
              "
              inputmode="decimal"
              placeholder="0.00"
              :message="errorText('amount')"
              :message-type="errors.amount ? 'error' : 'info'"
              :aria-required="isOpenStage"
              :aria-invalid="Boolean(errors.amount)"
            />
            <Input
              id="crm-deal-close_date"
              v-model="form.close_date"
              type="date"
              :label="
                t('CRM.DEALS.FORM.CLOSE_DATE') + (isOpenStage ? ' *' : '')
              "
              :message="closeDateMessage"
              :message-type="errors.close_date ? 'error' : 'info'"
              :aria-required="isOpenStage"
              :aria-invalid="Boolean(errors.close_date)"
            />
          </div>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div v-if="pipelines.length > 1" class="flex flex-col gap-1">
              <span class="text-heading-3 text-n-slate-12" aria-hidden="true">
                {{ t('CRM.DEALS.PIPELINE') }}
              </span>
              <Select
                v-model="form.pipeline_id"
                class="w-full [&_select]:w-full"
                :options="pipelineOptions"
                :disabled="isEdit"
                :aria-label="t('CRM.DEALS.PIPELINE')"
              />
            </div>
            <div v-if="!isEdit" class="flex flex-col gap-1">
              <span class="text-heading-3 text-n-slate-12" aria-hidden="true">
                {{ t('CRM.DEALS.FORM.STAGE') }}
              </span>
              <Select
                v-model="form.stage_id"
                class="w-full [&_select]:w-full"
                :options="stageOptions"
                :aria-label="t('CRM.DEALS.FORM.STAGE')"
              />
            </div>
          </div>
          <p class="text-label-small text-n-slate-11">
            {{ t('CRM.DEALS.FORM.REQUIRED_NOTE') }}
          </p>
        </section>

        <section
          class="flex flex-col gap-5 p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
          aria-labelledby="crm-deal-people"
        >
          <h2 id="crm-deal-people" class="text-heading-3 text-n-slate-12">
            {{ t('CRM.DEALS.FORM.PEOPLE') }}
          </h2>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <!-- The pickers render buttons, not inputs, so each field is a labelled group -->
            <div
              class="flex flex-col gap-1"
              role="group"
              aria-labelledby="crm-deal-contact-label"
            >
              <span
                id="crm-deal-contact-label"
                class="text-heading-3 text-n-slate-12"
              >
                {{ t('CRM.DEALS.FORM.CONTACT') }}
              </span>
              <ContactPicker
                v-model="form.contact_id"
                :contact-name="form.contact_name"
                @select="c => (form.contact_name = c?.name || '')"
              />
            </div>
            <div class="flex flex-col gap-1">
              <span class="text-heading-3 text-n-slate-12" aria-hidden="true">
                {{ t('CRM.DEALS.FORM.ASSIGNEE') }}
              </span>
              <AgentPicker
                v-model="form.assignee_id"
                class="w-full [&_select]:w-full"
                :aria-label="t('CRM.DEALS.FORM.ASSIGNEE')"
              />
            </div>
          </div>
          <TextArea
            id="crm-deal-description"
            v-model="form.description"
            :label="t('CRM.DEALS.FORM.DESCRIPTION')"
            :max-length="5000"
            min-height="6rem"
            auto-height
          />
        </section>
      </div>

      <!-- Side column: classification. Optional, and it only feeds the reports and the forecast. -->
      <aside class="flex flex-col gap-6">
        <section
          class="flex flex-col gap-4 p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
          aria-labelledby="crm-deal-forecast"
        >
          <h2 id="crm-deal-forecast" class="text-heading-3 text-n-slate-12">
            {{ t('CRM.DEALS.FORM.FORECAST_HEADING') }}
          </h2>
          <div class="flex flex-col gap-1">
            <span class="text-heading-3 text-n-slate-12" aria-hidden="true">
              {{ t('CRM.DEALS.PRIORITY') }}
            </span>
            <Select
              v-model="form.priority"
              class="w-full [&_select]:w-full"
              :options="priorityOptions"
              :aria-label="t('CRM.DEALS.PRIORITY')"
            />
          </div>
          <Input
            id="crm-deal-probability"
            v-model="form.probability_override"
            inputmode="numeric"
            :label="t('CRM.DEALS.FORM.PROBABILITY')"
            :placeholder="
              t('CRM.DEALS.FORM.PROBABILITY_FROM_STAGE', {
                value: stage?.probability ?? 0,
              })
            "
            :message="t('CRM.DEALS.FORM.PROBABILITY_HINT')"
          />
          <div class="flex flex-col gap-1">
            <span class="text-heading-3 text-n-slate-12" aria-hidden="true">
              {{ t('CRM.DEALS.FORM.FORECAST_CATEGORY') }}
            </span>
            <Select
              v-model="form.forecast_category"
              class="w-full [&_select]:w-full"
              :options="forecastOptions"
              :aria-label="t('CRM.DEALS.FORM.FORECAST_CATEGORY')"
            />
          </div>
        </section>

        <section
          class="flex flex-col gap-4 p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
          aria-labelledby="crm-deal-report-fields"
        >
          <div>
            <h2
              id="crm-deal-report-fields"
              class="text-heading-3 text-n-slate-12"
            >
              {{ t('CRM.DEALS.FORM.REPORT_FIELDS') }}
            </h2>
            <p class="mt-1 text-label-small text-n-slate-11">
              {{ t('CRM.DEALS.FORM.REPORT_FIELDS_HINT') }}
            </p>
          </div>
          <div
            v-for="list in DEAL_LISTS"
            :key="list"
            class="flex flex-col gap-1"
          >
            <span class="text-heading-3 text-n-slate-12" aria-hidden="true">
              {{ t(`CRM.LISTS.${list}`) }}
            </span>
            <Select
              v-model="form[listField(list)]"
              class="w-full [&_select]:w-full"
              :options="lists.options(list, t('CRM.COMMON.NONE'))"
              :aria-label="t(`CRM.LISTS.${list}`)"
            />
          </div>
        </section>
      </aside>
    </form>
  </div>
</template>
