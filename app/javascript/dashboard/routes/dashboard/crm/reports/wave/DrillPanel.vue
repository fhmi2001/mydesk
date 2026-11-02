<script setup>
// Custom (MyDesk): the deals behind a number, beside the report (GET crm/reports/:key/deals). The server lists them
// from the same relation it counted, so the count and the total here always equal the number that was clicked.
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { crmReportsAPI } from 'dashboard/api/crm';
import { useCrmFormat } from '../../shared/useCrmFormat';
import DealLines from './DealLines.vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { saveFile } from './saveFile';

const props = defineProps({
  reportKey: { type: String, required: true },
  params: { type: Object, required: true },
  currency: { type: String, default: 'SAR' },
  columns: { type: Array, default: () => ['stage', 'close_date'] },
  showAssignee: { type: Boolean, default: false },
});

const { t } = useI18n();
const { money, number, dateTime } = useCrmFormat();

const panel = ref(null);
const title = ref('');
const cell = ref({});
const page = ref(1);
const items = ref([]);
const totalCount = ref(0);
const totalCents = ref(null);
const isLoading = ref(false);
const failed = ref(false);

// The server says what it listed: deals, or tasks (my tasks, the team's activity)
const resultType = ref('deals');
const isTasks = computed(() => resultType.value === 'tasks');
const hasMore = computed(() => items.value.length < totalCount.value);

const fetchPage = async () => {
  isLoading.value = true;
  failed.value = false;
  try {
    const { data } = await crmReportsAPI.drill(props.reportKey, {
      ...props.params,
      cell: cell.value,
      page: page.value,
    });
    items.value =
      page.value === 1 ? data.items : [...items.value, ...data.items];
    resultType.value = data.type || 'deals';
    totalCount.value = data.total_count;
    totalCents.value = data.total_cents ?? null;
  } catch {
    failed.value = true;
  } finally {
    isLoading.value = false;
  }
};

const open = (newCell, newTitle) => {
  cell.value = newCell;
  title.value = newTitle;
  page.value = 1;
  items.value = [];
  totalCount.value = 0;
  totalCents.value = null;
  panel.value?.open();
  fetchPage();
};

const more = () => {
  page.value += 1;
  fetchPage();
};

const summary = computed(() => {
  const count = t('CRM.REPORTS.WAVE.DRILL_COUNT', {
    count: number(totalCount.value),
  });
  if (totalCents.value === null) return count;
  return `${count} · ${money(totalCents.value, props.currency)}`;
});

// The manager can take these deals away as CSV (the server refuses anyone else)
const isAdmin = useMapGetter('crm/status/isAdmin');
const isExporting = ref(false);
const exportCsv = async () => {
  isExporting.value = true;
  try {
    const { data: blob } = await crmReportsAPI.download(props.reportKey, {
      ...props.params,
      cell: cell.value,
      file_format: 'csv',
    });
    saveFile(blob, `${props.reportKey}-deals.csv`);
  } catch {
    useAlert(t('CRM.COMMON.ERROR'));
  } finally {
    isExporting.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <SidePanel ref="panel" :title="title" :description="summary" width="3xl">
    <template v-if="isAdmin && items.length" #header-actions>
      <Button
        :label="t('CRM.REPORTS.WAVE.EXPORT.CSV')"
        variant="faded"
        size="sm"
        icon="i-lucide-download"
        :is-loading="isExporting"
        @click="exportCsv"
      />
    </template>
    <div v-if="isLoading && !items.length" class="flex justify-center py-10">
      <Spinner />
    </div>
    <div v-else-if="failed" class="flex flex-col items-start gap-3">
      <p class="text-body-main text-n-slate-11">{{ t('CRM.COMMON.ERROR') }}</p>
      <Button :label="t('CRM.COMMON.RETRY')" size="sm" @click="fetchPage" />
    </div>
    <p v-else-if="!items.length" class="text-body-main text-n-slate-11">
      {{ t('CRM.REPORTS.WAVE.DRILL_EMPTY') }}
    </p>
    <template v-else>
      <ul v-if="isTasks" class="divide-y divide-n-weak">
        <li v-for="task in items" :key="task.id" class="py-2.5 text-body-main">
          <router-link
            :to="{ name: 'crm_task', params: { taskId: task.id } }"
            class="text-n-slate-12 hover:text-n-brand hover:underline"
          >
            {{ task.title }}
          </router-link>
          <p class="text-label-small text-n-slate-11">
            {{ t(`CRM.TASKS.KINDS.${task.kind}`) }}
            <template v-if="task.due_at">
              · {{ dateTime(task.due_at) }}
            </template>
            <template v-if="task.deal"> · {{ task.deal.title }}</template>
          </p>
        </li>
      </ul>
      <DealLines
        v-else
        :deals="items"
        :columns="columns"
        :currency="currency"
        :show-assignee="showAssignee"
      />
      <div v-if="hasMore" class="flex justify-center mt-4">
        <Button
          :label="t('CRM.COMMON.SHOW_MORE')"
          variant="faded"
          size="sm"
          :is-loading="isLoading"
          @click="more"
        />
      </div>
    </template>
  </SidePanel>
</template>
