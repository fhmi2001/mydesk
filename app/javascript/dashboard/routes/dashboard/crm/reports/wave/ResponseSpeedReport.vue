<script setup>
// Custom (MyDesk): التقرير 20, do deals answered faster close better? (SalesCrm::Reports::ResponseSpeed) The closed deals by
// the first reply in their conversation, five buckets: closed, win rate (none under 10 deals: a small sample) and
// average won. The deals left out are counted, and the page says it shows a link, not a cause.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../../shared/useCrmFormat';
import NumberTile from './NumberTile.vue';
import ReportSection from './ReportSection.vue';
import CellButton from './CellButton.vue';
import { COLORS } from './reportColors';

const props = defineProps({
  data: { type: Object, required: true },
  currency: { type: String, default: 'SAR' },
});
const emit = defineEmits(['drill']);

const { t } = useI18n();
const { money, number } = useCrmFormat();
const L = key => t(`CRM.REPORTS.WAVE.RESPONSE_SPEED.${key}`);
const BUCKET = {
  under_5m: () => L('BUCKETS.under_5m'),
  '5_30m': () => L('BUCKETS.5_30m'),
  '30m_2h': () => L('BUCKETS.30m_2h'),
  '2h_24h': () => L('BUCKETS.2h_24h'),
  over_24h: () => L('BUCKETS.over_24h'),
};
const label = bucket => BUCKET[bucket.key]?.() || bucket.key;
// No deal: nothing to say; under the minimum: a small sample
const rate = bucket => {
  if (!bucket.closed_count) return '—';
  return bucket.small_sample || bucket.win_rate === null
    ? L('SMALL_SAMPLE')
    : `${number(bucket.win_rate)}%`;
};
// The bar shows the rate where there is one; a small sample gets none
const width = bucket =>
  bucket.small_sample || bucket.win_rate === null
    ? '0%'
    : `${Math.min(bucket.win_rate, 100)}%`;
const buckets = computed(() => props.data.buckets || []);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3">
      <NumberTile
        :label="L('CLOSED')"
        :value="number(data.totals.closed_count)"
      />
      <NumberTile
        :label="L('EXCLUDED')"
        :value="number(data.totals.excluded_count)"
        :note="L('EXCLUDED_HINT')"
      />
    </div>

    <ReportSection :title="L('BY_BUCKET')" :note="L('CORRELATION')">
      <div class="overflow-x-auto">
        <table class="w-full text-body-main">
          <thead>
            <tr class="text-label-small text-n-slate-11">
              <th scope="col" class="py-2 pe-3 font-medium text-start">
                {{ L('FIRST_REPLY') }}
              </th>
              <th scope="col" class="py-2 ps-3 font-medium text-end">
                {{ L('CLOSED') }}
              </th>
              <th scope="col" class="py-2 ps-3 font-medium text-start w-2/5">
                {{ L('WIN_RATE') }}
              </th>
              <th scope="col" class="py-2 ps-3 font-medium text-end">
                {{ L('AVERAGE_WON') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak">
            <tr v-for="bucket in buckets" :key="bucket.key">
              <th
                scope="row"
                class="py-2.5 pe-3 font-normal text-start text-n-slate-12 whitespace-nowrap"
              >
                {{ label(bucket) }}
              </th>
              <td class="py-2.5 ps-3 text-end tabular-nums">
                <CellButton
                  :cell="bucket.cell"
                  :label="number(bucket.closed_count)"
                  :title="`${L('CLOSED')} · ${label(bucket)}`"
                  :empty="!bucket.closed_count"
                  @drill="(cell, title) => emit('drill', cell, title)"
                />
              </td>
              <td class="py-2.5 ps-3">
                <div class="flex items-center gap-2">
                  <div
                    class="flex-1 h-2 overflow-hidden rounded-full bg-n-alpha-2"
                    aria-hidden="true"
                  >
                    <div
                      class="h-full rounded-full"
                      :style="{
                        width: width(bucket),
                        background: COLORS.won.rgb,
                      }"
                    />
                  </div>
                  <span
                    class="tabular-nums shrink-0 text-label-small"
                    :class="
                      bucket.small_sample
                        ? 'text-n-slate-10'
                        : 'text-n-slate-12'
                    "
                  >
                    {{ rate(bucket) }}
                  </span>
                </div>
              </td>
              <td class="py-2.5 ps-3 text-end tabular-nums" dir="auto">
                {{
                  bucket.average_won_cents === null
                    ? '—'
                    : money(bucket.average_won_cents, currency)
                }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p class="mt-2 text-label-small text-n-slate-11">
        {{ L('SMALL_SAMPLE_HINT') }}
      </p>
    </ReportSection>
  </div>
</template>
