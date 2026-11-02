<script setup>
// Custom (MyDesk): pick one of the account's contacts (or none). Opening the list shows the most recently
// active contacts; typing two or more characters searches all of them by name or phone.
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import ContactAPI from 'dashboard/api/contacts';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  contactName: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['select']);
const model = defineModel({ type: [Number, String], default: null });
const { t } = useI18n();

const MIN_QUERY = 2;

const options = ref([]);
const recent = ref(null);
const query = ref('');
const isLoading = ref(false);
const label = ref(props.contactName);

watch(
  () => props.contactName,
  name => {
    label.value = name;
  }
);

const toOptions = contacts =>
  (contacts || []).map(contact => ({
    value: contact.id,
    label: [contact.name, contact.phone_number].filter(Boolean).join(' · '),
    contact,
  }));

// The combobox clears its search box each time it opens
const loadRecent = async () => {
  query.value = '';
  if (recent.value) {
    options.value = recent.value;
    return;
  }
  isLoading.value = true;
  try {
    const { data } = await ContactAPI.get(1, '-last_activity_at');
    recent.value = toOptions(data?.payload);
    if (query.value.length < MIN_QUERY) options.value = recent.value;
  } catch (e) {
    options.value = [];
  } finally {
    isLoading.value = false;
  }
};

const runSearch = useDebounceFn(async text => {
  try {
    const { data } = await ContactAPI.search(text, 1, 'name');
    // Ignore a reply for text the user has since changed
    if (text === query.value) options.value = toOptions(data?.payload);
  } catch (e) {
    if (text === query.value) options.value = [];
  } finally {
    if (text === query.value) isLoading.value = false;
  }
}, 300);

const onSearch = text => {
  query.value = (text || '').trim();
  if (query.value.length < MIN_QUERY) {
    // Too short to search the server: narrow the recent list instead
    const needle = query.value.toLowerCase();
    options.value = (recent.value || []).filter(o =>
      o.label.toLowerCase().includes(needle)
    );
    isLoading.value = false;
    return;
  }
  isLoading.value = true;
  runSearch(query.value);
};

const emptyState = computed(() => {
  if (isLoading.value) return t('CRM.COMMON.LOADING');
  if (query.value && query.value.length < MIN_QUERY)
    return t('CRM.CONTACT_PICKER.TYPE_MORE');
  if (query.value) return t('CRM.CONTACT_PICKER.NO_MATCH');
  return t('CRM.CONTACT_PICKER.NO_CONTACTS');
});

const onUpdate = value => {
  const option = options.value.find(o => o.value === value);
  model.value = value === '' ? null : value;
  label.value = option?.contact?.name || '';
  emit('select', option?.contact || null);
};
</script>

<template>
  <ComboBox
    :model-value="model ?? ''"
    :options="options"
    :display-label="label"
    :placeholder="t('CRM.DEALS.FORM.CONTACT_NONE')"
    :search-placeholder="t('CRM.DEALS.FORM.CONTACT_PLACEHOLDER')"
    :empty-state="emptyState"
    :disabled="disabled"
    use-api-results
    @open="loadRecent"
    @search="onSearch"
    @update:model-value="onUpdate"
  />
</template>
