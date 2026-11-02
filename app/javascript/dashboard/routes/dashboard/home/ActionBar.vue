<script setup>
// Custom (MyDesk): the home screen's quick actions. Each opens the same dialog or page the app already uses for it.
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import Button from 'dashboard/components-next/button/Button.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import CreateNewContactDialog from 'dashboard/components-next/Contacts/ContactsForm/CreateNewContactDialog.vue';
import TaskForm from '../crm/tasks/TaskForm.vue';
import { apiErrorMessage } from '../crm/shared/dealHelpers';

defineProps({
  crmEnabled: { type: Boolean, default: false },
  isAdmin: { type: Boolean, default: false },
});

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const { accountScopedRoute } = useAccount();

const contactDialog = ref(null);
const taskForm = ref(null);
const isSavingTask = ref(false);

const onCreateContact = async contact => {
  try {
    await store.dispatch('contacts/create', contact);
    contactDialog.value?.onSuccess();
    useAlert(
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.SUCCESS_MESSAGE')
    );
  } catch (error) {
    useAlert(
      error?.data && typeof error.data === 'string'
        ? error.data
        : t('CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.ERROR_MESSAGE')
    );
  }
};

const onCreateTask = async ({ payload }) => {
  isSavingTask.value = true;
  try {
    await store.dispatch('crm/tasks/create', payload);
    taskForm.value?.close();
    useAlert(t('CRM.TASKS.FORM.SAVED'));
  } catch (error) {
    useAlert(apiErrorMessage(error, t('CRM.COMMON.ERROR')));
  } finally {
    isSavingTask.value = false;
  }
};

const go = name => router.push(accountScopedRoute(name));
</script>

<template>
  <!-- Below md the actions grow to a 44px touch target -->
  <div class="flex flex-wrap items-center gap-2">
    <ComposeConversation align="start">
      <template #trigger>
        <Button
          icon="i-lucide-message-circle-plus"
          size="sm"
          class="max-md:!h-11"
          :label="t('HOME.ACTIONS.CONVERSATION')"
        />
      </template>
    </ComposeConversation>
    <Button
      v-if="crmEnabled"
      icon="i-lucide-handshake"
      size="sm"
      class="max-md:!h-11"
      color="slate"
      variant="faded"
      :label="t('HOME.ACTIONS.DEAL')"
      @click="go('crm_deal_new')"
    />
    <Button
      v-if="crmEnabled"
      icon="i-lucide-list-plus"
      size="sm"
      class="max-md:!h-11"
      color="slate"
      variant="faded"
      :label="t('HOME.ACTIONS.TASK')"
      @click="taskForm?.open()"
    />
    <Button
      icon="i-lucide-user-round-plus"
      size="sm"
      class="max-md:!h-11"
      color="slate"
      variant="faded"
      :label="t('HOME.ACTIONS.CONTACT')"
      @click="contactDialog?.dialogRef.open()"
    />
    <Button
      v-if="isAdmin"
      icon="i-lucide-megaphone"
      size="sm"
      class="max-md:!h-11"
      color="slate"
      variant="faded"
      :label="t('HOME.ACTIONS.CAMPAIGN')"
      @click="go('campaigns_ongoing_index')"
    />

    <CreateNewContactDialog ref="contactDialog" @create="onCreateContact" />
    <TaskForm
      v-if="crmEnabled"
      ref="taskForm"
      :is-saving="isSavingTask"
      @submit="onCreateTask"
      @close="() => {}"
    />
  </div>
</template>
