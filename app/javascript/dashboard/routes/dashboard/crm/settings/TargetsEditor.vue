<script setup>
// Custom (MyDesk): Sales settings > Targets (administrators): each employee's sales target for a month, in the
// Sales currency. The team target is the sum and is never entered. A blank amount clears that employee's month.
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { crmTargetsAPI } from 'dashboard/api/crm';
import { parseAmount } from 'dashboard/helper/crmFormat';
import { apiErrorMessage } from '../shared/dealHelpers';
import { useCrmFormat } from '../shared/useCrmFormat';

const { t } = useI18n();
const store = useStore();
const { money } = useCrmFormat();
const agents = useMapGetter('agents/getAgents');

const month = ref(new Date().toISOString().slice(0, 7));
const amounts = ref({}); // userId -> amount text as typed
const saved = ref({}); // userId -> amount text as stored
const currency = ref('SAR');
const isLoading = ref(true);
const isSaving = ref(false);

const centsToText = cents => (cents / 100).toFixed(2).replace(/\.00$/, '');

const load = async () => {
  isLoading.value = true;
  try {
    const { data } = await crmTargetsAPI.get(month.value);
    currency.value = data.currency;
    const byUser = Object.fromEntries(
      data.targets.map(row => [row.user_id, centsToText(row.amount_cents)])
    );
    amounts.value = { ...byUser };
    saved.value = byUser;
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  if (!agents.value?.length) store.dispatch('agents/get');
  load();
});
watch(month, value => {
  if (value) load();
});

const invalidIds = computed(() =>
  Object.entries(amounts.value)
    .filter(
      ([, text]) => String(text ?? '').trim() && parseAmount(text) === null
    )
    .map(([id]) => Number(id))
);
const teamCents = computed(() =>
  Object.values(amounts.value).reduce(
    (sum, text) => sum + (parseAmount(text) || 0),
    0
  )
);
const dirty = computed(
  () =>
    (agents.value || []).some(
      agent =>
        String(amounts.value[agent.id] ?? '').trim() !==
        String(saved.value[agent.id] ?? '')
    ) && !invalidIds.value.length
);

const save = async () => {
  isSaving.value = true;
  try {
    const payload = Object.fromEntries(
      (agents.value || []).map(agent => {
        const cents = parseAmount(amounts.value[agent.id]);
        return [agent.id, cents === null ? '' : (cents / 100).toFixed(2)];
      })
    );
    await crmTargetsAPI.update(month.value, payload);
    await load();
    useAlert(t('CRM.COMMON.SAVED'));
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <section
    class="p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
    aria-labelledby="crm-targets-title"
  >
    <div class="flex flex-wrap items-end justify-between gap-3">
      <div>
        <h2 id="crm-targets-title" class="text-heading-3 text-n-slate-12">
          {{ t('CRM.TARGETS.TITLE') }}
        </h2>
        <p class="mt-1 text-label-small text-n-slate-11">
          {{ t('CRM.TARGETS.HINT', { currency }) }}
        </p>
      </div>
      <div class="w-44">
        <Input
          v-model="month"
          type="month"
          size="sm"
          :label="t('CRM.TARGETS.MONTH')"
        />
      </div>
    </div>

    <div v-if="isLoading" class="flex justify-center py-6">
      <Spinner />
    </div>
    <template v-else>
      <table class="w-full mt-4 text-body-main">
        <thead>
          <tr class="text-label-small text-n-slate-11">
            <th scope="col" class="py-2 font-medium text-start">
              {{ t('CRM.TARGETS.EMPLOYEE') }}
            </th>
            <th scope="col" class="py-2 font-medium text-start w-48">
              {{ t('CRM.TARGETS.AMOUNT', { currency }) }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-n-weak">
          <tr v-for="agent in agents" :key="agent.id">
            <th scope="row" class="py-2 font-normal text-start text-n-slate-12">
              {{ agent.name }}
            </th>
            <td class="py-2">
              <Input
                v-model="amounts[agent.id]"
                size="sm"
                inputmode="decimal"
                placeholder="—"
                :aria-label="t('CRM.TARGETS.AMOUNT_FOR', { name: agent.name })"
                :message="
                  invalidIds.includes(agent.id)
                    ? t('CRM.DEALS.FORM.AMOUNT_INVALID')
                    : ''
                "
                :message-type="invalidIds.includes(agent.id) ? 'error' : 'info'"
              />
            </td>
          </tr>
        </tbody>
        <tfoot>
          <tr class="border-t border-n-weak">
            <th scope="row" class="pt-3 font-medium text-start text-n-slate-12">
              {{ t('CRM.TARGETS.TEAM') }}
            </th>
            <td
              class="pt-3 font-medium tabular-nums text-n-slate-12"
              dir="auto"
            >
              {{ money(teamCents, currency) }}
            </td>
          </tr>
        </tfoot>
      </table>
      <div class="flex justify-end mt-4">
        <Button
          :label="t('CRM.COMMON.SAVE')"
          size="sm"
          :variant="dirty ? 'solid' : 'faded'"
          :disabled="!dirty"
          :is-loading="isSaving"
          @click="save"
        />
      </div>
    </template>
  </section>
</template>
