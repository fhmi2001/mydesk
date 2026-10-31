<script setup>
// Custom (MyDesk): search the account's contacts by name or phone and pick one (or none)
import { ref, watch } from 'vue';
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

const options = ref([]);
const label = ref(props.contactName);

watch(
  () => props.contactName,
  name => {
    label.value = name;
  }
);

const search = useDebounceFn(async query => {
  if (!query || query.length < 2) return;
  try {
    const { data } = await ContactAPI.search(query, 1, 'name');
    options.value = (data?.payload || []).map(contact => ({
      value: contact.id,
      label: [contact.name, contact.phone_number].filter(Boolean).join(' · '),
      contact,
    }));
  } catch (e) {
    options.value = [];
  }
}, 300);

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
    :empty-state="t('CRM.DEALS.EMPTY_SEARCH')"
    :disabled="disabled"
    use-api-results
    @search="search"
    @update:model-value="onUpdate"
  />
</template>
