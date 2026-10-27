<script setup>
import { computed, onUnmounted, ref } from 'vue';
import { useToggle } from '@vueuse/core';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { emitter } from 'shared/helpers/mitt';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useAgentsList } from 'dashboard/composables/useAgentsList';
import wootConstants from 'dashboard/constants/globals';
import EmailTranscriptModal from './EmailTranscriptModal.vue';
import ResolveAction from '../../buttons/ResolveAction.vue';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

import {
  CMD_MUTE_CONVERSATION,
  CMD_SEND_TRANSCRIPT,
  CMD_UNMUTE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

// No props needed as we're getting currentChat from the store directly
const store = useStore();
const { t } = useI18n();

const [showEmailActionsModal, toggleEmailModal] = useToggle(false);
const [showActionsDropdown, toggleDropdown] = useToggle(false);

const currentChat = computed(() => store.getters.getSelectedChat);

// Custom (MyDesk): «إجراءات أخرى» also holds assigning the conversation and putting it on hold or
// snoozing it (these used to sit in a menu on the status button). Assigning opens a searchable list.
const MENU_VIEWS = { MAIN: 'main', ASSIGN: 'assign' };
const menuView = ref(MENU_VIEWS.MAIN);
const { agentsList } = useAgentsList(true, { includeAIAssignees: true });

const { PENDING, OPEN } = wootConstants.STATUS_TYPE;

const closeMenu = () => {
  toggleDropdown(false);
  menuView.value = MENU_VIEWS.MAIN;
};

const conversationSection = computed(() => {
  const items = [
    {
      icon: 'i-lucide-user-round-plus',
      label: t('CONVERSATION.HEADER.ACTIONS.ASSIGN'),
      action: 'open_assign',
      value: 'open_assign',
    },
  ];
  if (currentChat.value.status !== PENDING) {
    items.push({
      icon: 'i-lucide-circle-pause',
      label: t('CONVERSATION.HEADER.ACTIONS.ON_HOLD'),
      action: 'on_hold',
      value: 'on_hold',
    });
  }
  if (currentChat.value.status === OPEN) {
    items.push({
      icon: 'i-lucide-alarm-clock-minus',
      label: t('CONVERSATION.HEADER.ACTIONS.SNOOZE'),
      action: 'snooze',
      value: 'snooze',
    });
  }
  return { items };
});

const contactSection = computed(() => ({
  items: [
    currentChat.value.muted
      ? {
          icon: 'i-lucide-volume-1',
          label: t('CONTACT_PANEL.UNMUTE_CONTACT'),
          action: 'unmute',
          value: 'unmute',
        }
      : {
          icon: 'i-lucide-volume-off',
          label: t('CONTACT_PANEL.MUTE_CONTACT'),
          action: 'mute',
          value: 'mute',
        },
    {
      icon: 'i-lucide-share',
      label: t('CONTACT_PANEL.SEND_TRANSCRIPT'),
      action: 'send_transcript',
      value: 'send_transcript',
    },
  ],
}));

const assigneeId = computed(() => currentChat.value.meta?.assignee?.id ?? 0);

const agentSection = computed(() => ({
  title: t('CONVERSATION.HEADER.ACTIONS.ASSIGN_TITLE'),
  items: agentsList.value.map(agent => ({
    label: agent.available_name || agent.name,
    value: `agent-${agent.assignee_type || 'User'}-${agent.id}`,
    action: 'assign',
    agent,
    isSelected: agent.id === assigneeId.value,
    ...(agent.id
      ? { thumbnail: { name: agent.name, src: agent.thumbnail } }
      : { icon: 'i-lucide-user-round-x' }),
  })),
}));

const menuSections = computed(() =>
  menuView.value === MENU_VIEWS.ASSIGN
    ? [agentSection.value]
    : [conversationSection.value, contactSection.value]
);

const assignAgent = agent => {
  const selected = agent?.id ? agent : null;
  const assigneeType = selected ? selected.assignee_type || 'User' : null;
  store.dispatch('setCurrentChatAssignee', {
    conversationId: currentChat.value.id,
    assignee: selected,
    assigneeType,
  });
  store
    .dispatch('assignAgent', {
      conversationId: currentChat.value.id,
      agentId: selected ? selected.id : null,
      assigneeType,
    })
    .then(() => useAlert(t('CONVERSATION.CHANGE_AGENT')));
};

const putOnHold = () => {
  store
    .dispatch('toggleStatus', {
      conversationId: currentChat.value.id,
      status: PENDING,
    })
    .then(() => useAlert(t('CONVERSATION.CHANGE_STATUS')));
};

const openSnooze = () => {
  document.querySelector('ninja-keys')?.open({ parent: 'snooze_conversation' });
};

const mute = () => {
  store.dispatch('muteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.MUTED_SUCCESS'));
};

const unmute = () => {
  store.dispatch('unmuteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.UNMUTED_SUCCESS'));
};

const handleActionClick = ({ action, agent }) => {
  if (action === 'open_assign') {
    menuView.value = MENU_VIEWS.ASSIGN;
    return;
  }
  closeMenu();
  const handlers = {
    assign: () => assignAgent(agent),
    on_hold: putOnHold,
    snooze: openSnooze,
    mute,
    unmute,
    send_transcript: toggleEmailModal,
  };
  handlers[action]?.();
};

const toggleMenu = () => {
  if (showActionsDropdown.value) closeMenu();
  else toggleDropdown(true);
};

useKeyboardEvents({
  'Alt+KeyM': { action: toggleMenu, allowOnFocusedInput: true },
});

emitter.on(CMD_MUTE_CONVERSATION, mute);
emitter.on(CMD_UNMUTE_CONVERSATION, unmute);
emitter.on(CMD_SEND_TRANSCRIPT, toggleEmailModal);

onUnmounted(() => {
  emitter.off(CMD_MUTE_CONVERSATION, mute);
  emitter.off(CMD_UNMUTE_CONVERSATION, unmute);
  emitter.off(CMD_SEND_TRANSCRIPT, toggleEmailModal);
});
</script>

<template>
  <div class="relative flex items-center gap-2 actions--container">
    <ResolveAction
      :conversation-id="currentChat.id"
      :status="currentChat.status"
    />
    <div v-on-clickaway="closeMenu" class="relative flex items-center group">
      <ButtonV4
        v-tooltip="$t('CONVERSATION.HEADER.MORE_ACTIONS')"
        :aria-label="$t('CONVERSATION.HEADER.MORE_ACTIONS')"
        aria-haspopup="menu"
        :aria-expanded="showActionsDropdown"
        size="sm"
        variant="ghost"
        color="slate"
        icon="i-lucide-more-vertical"
        class="rounded-md group-hover:bg-n-alpha-2"
        @click="toggleMenu"
      />
      <DropdownMenu
        v-if="showActionsDropdown"
        :key="menuView"
        :menu-sections="menuSections"
        :show-search="menuView === MENU_VIEWS.ASSIGN"
        :search-placeholder="t('CONVERSATION.HEADER.ACTIONS.SEARCH_AGENT')"
        class="mt-1 end-0 top-full w-60 max-h-80"
        @action="handleActionClick"
      />
    </div>
    <EmailTranscriptModal
      v-if="showEmailActionsModal"
      :show="showEmailActionsModal"
      :current-chat="currentChat"
      @cancel="toggleEmailModal"
    />
  </div>
</template>
