<script setup>
// Custom (MyDesk): one task in a list: done checkbox, title, due, links, assignee
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useCrmFormat } from '../shared/useCrmFormat';

const props = defineProps({
  task: { type: Object, required: true },
  compact: { type: Boolean, default: false },
  canDelete: { type: Boolean, default: false },
});
const emit = defineEmits(['toggle', 'edit', 'delete']);
const { t } = useI18n();
const { dateTime } = useCrmFormat();
const { accountScopedRoute } = useAccount();

const isDone = computed(() => props.task.status === 'done');
const overdueSuffix = computed(() =>
  props.task.overdue && !isDone.value ? ` · ${t('CRM.TASKS.OVERDUE')}` : ''
);
const dueLabel = computed(() =>
  props.task.due_at ? dateTime(props.task.due_at) : t('CRM.TASKS.NO_DUE')
);
const dealRoute = computed(() =>
  props.task.deal
    ? accountScopedRoute('crm_deal', { dealId: props.task.deal.id })
    : null
);
const contactRoute = computed(() =>
  props.task.contact
    ? accountScopedRoute('contacts_edit', { contactId: props.task.contact.id })
    : null
);
</script>

<template>
  <li class="flex items-start gap-3 py-3" :class="{ 'opacity-60': isDone }">
    <!-- The base button CSS drops the border style and adds side padding, hence border-solid and p-0;
         the ::before widens the tap area to 44px without growing the circle -->
    <button
      type="button"
      class="relative flex items-center justify-center p-0 mt-0.5 border-2 border-solid rounded-full size-5 shrink-0 transition-colors before:absolute before:-inset-3 before:content-[''] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
      :class="
        isDone
          ? 'bg-n-teal-3 border-n-teal-11 text-n-teal-11'
          : 'border-n-slate-8 hover:border-n-teal-11'
      "
      :aria-label="
        isDone
          ? t('CRM.TASKS.REOPEN_ARIA', { title: task.title })
          : t('CRM.TASKS.COMPLETE_ARIA', { title: task.title })
      "
      :aria-pressed="isDone"
      @click="emit('toggle', task)"
    >
      <span v-if="isDone" class="i-lucide-check size-3" aria-hidden="true" />
    </button>
    <div class="flex-1 min-w-0">
      <p
        class="text-body-main text-n-slate-12"
        :class="{ 'line-through': isDone }"
      >
        {{ task.title }}
      </p>
      <p
        v-if="task.description && !compact"
        class="mt-0.5 text-label-small text-n-slate-11 line-clamp-2"
      >
        {{ task.description }}
      </p>
      <div
        class="flex flex-wrap items-center gap-x-3 gap-y-1 mt-1 text-label-small"
      >
        <span
          class="inline-flex items-center gap-1"
          :class="
            task.overdue && !isDone
              ? 'text-n-ruby-11 font-medium'
              : 'text-n-slate-11'
          "
        >
          <span class="i-lucide-clock size-3" aria-hidden="true" />
          {{ dueLabel }}{{ overdueSuffix }}
        </span>
        <router-link
          v-if="dealRoute && !compact"
          :to="dealRoute"
          class="inline-flex items-center gap-1 text-n-blue-11 hover:underline"
        >
          <span class="i-lucide-briefcase size-3" aria-hidden="true" />
          {{ task.deal.title }}
        </router-link>
        <router-link
          v-if="contactRoute"
          :to="contactRoute"
          class="inline-flex items-center gap-1 text-n-blue-11 hover:underline"
        >
          <span class="i-lucide-user size-3" aria-hidden="true" />
          {{ task.contact.name }}
        </router-link>
      </div>
    </div>
    <div class="flex items-center gap-2 shrink-0">
      <Avatar
        v-if="task.assignee"
        :name="task.assignee.name"
        :src="task.assignee.avatar_url"
        :size="22"
        rounded-full
      />
      <Button
        v-if="!compact"
        icon="i-lucide-pencil"
        size="xs"
        variant="ghost"
        color="slate"
        :aria-label="t('CRM.TASKS.EDIT_ARIA', { title: task.title })"
        @click="emit('edit', task)"
      />
      <Button
        v-if="!compact && canDelete"
        icon="i-lucide-trash-2"
        size="xs"
        variant="ghost"
        color="slate"
        :aria-label="t('CRM.TASKS.DELETE_ARIA', { title: task.title })"
        @click="emit('delete', task)"
      />
    </div>
  </li>
</template>
