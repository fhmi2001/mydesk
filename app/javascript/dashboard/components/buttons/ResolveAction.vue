<script setup>
import { ref, computed } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useMediaQuery } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useEmitter } from 'dashboard/composables/emitter';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useConversationRequiredAttributes } from 'dashboard/composables/useConversationRequiredAttributes';

import wootConstants from 'dashboard/constants/globals';
import {
  CMD_REOPEN_CONVERSATION,
  CMD_RESOLVE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

import Button from 'dashboard/components-next/button/Button.vue';
import ConversationResolveAttributesModal from 'dashboard/components-next/ConversationWorkflow/ConversationResolveAttributesModal.vue';

const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();
const { checkMissingAttributes } = useConversationRequiredAttributes();

const isLoading = ref(false);
const resolveAttributesModalRef = ref(null);

const currentChat = computed(() => getters.getSelectedChat.value);

// Custom (MyDesk): on phones the header is one row, so the status button keeps only its icon
// (the label stays as tooltip and accessible name)
const isCompact = useMediaQuery('(max-width: 639px)');
const compactProps = (label, icon) =>
  isCompact.value ? { icon, 'aria-label': label, title: label } : { label };

const isOpen = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.OPEN
);
const isPending = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.PENDING
);
const isResolved = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.RESOLVED
);
const isSnoozed = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.SNOOZED
);

const showOpenButton = computed(() => {
  return isPending.value || isSnoozed.value;
});

const getConversationParams = () => {
  const allConversations = document.querySelectorAll(
    '.conversations-list .conversation'
  );

  const activeConversation = document.querySelector(
    'div.conversations-list div.conversation.active'
  );
  const activeConversationIndex = [...allConversations].indexOf(
    activeConversation
  );
  const lastConversationIndex = allConversations.length - 1;

  return {
    all: allConversations,
    activeIndex: activeConversationIndex,
    lastIndex: lastConversationIndex,
  };
};

const toggleStatus = (status, snoozedUntil, customAttributes = null) => {
  isLoading.value = true;

  const payload = {
    conversationId: currentChat.value.id,
    status,
    snoozedUntil,
  };

  if (customAttributes) {
    payload.customAttributes = customAttributes;
  }

  store.dispatch('toggleStatus', payload).then(() => {
    useAlert(t('CONVERSATION.CHANGE_STATUS'));
    isLoading.value = false;
  });
};

const handleResolveWithAttributes = ({ attributes, context }) => {
  if (context) {
    const currentCustomAttributes = currentChat.value.custom_attributes || {};
    const mergedAttributes = { ...currentCustomAttributes, ...attributes };
    toggleStatus(
      wootConstants.STATUS_TYPE.RESOLVED,
      context.snoozedUntil,
      mergedAttributes
    );
  }
};

const onCmdOpenConversation = () => {
  toggleStatus(wootConstants.STATUS_TYPE.OPEN);
};

const onCmdResolveConversation = () => {
  const currentCustomAttributes = currentChat.value.custom_attributes || {};
  const { hasMissing, missing } = checkMissingAttributes(
    currentCustomAttributes
  );

  if (hasMissing) {
    const conversationContext = {
      id: currentChat.value.id,
      snoozedUntil: null,
    };
    resolveAttributesModalRef.value?.open(
      missing,
      currentCustomAttributes,
      conversationContext
    );
  } else {
    toggleStatus(wootConstants.STATUS_TYPE.RESOLVED);
  }
};

// Custom (MyDesk): Alt+M (status options) now opens «إجراءات أخرى», see MoreActions
const keyboardEvents = {
  'Alt+KeyE': {
    action: async event => {
      // Chrome on Windows treats Alt+E as a legacy shortcut for its own
      // menu (Alt+E / Alt+F both open "Customize and control Google
      // Chrome"). Without preventDefault, our resolve action still runs,
      // but Chrome's menu also opens on top of it.
      event.preventDefault();
      onCmdResolveConversation();
    },
  },
  '$mod+Alt+KeyE': {
    action: async event => {
      const { all, activeIndex, lastIndex } = getConversationParams();
      onCmdResolveConversation();

      if (activeIndex < lastIndex) {
        all[activeIndex + 1].click();
      } else if (all.length > 1) {
        all[0].click();
        document.querySelector('.conversations-list').scrollTop = 0;
      }
      event.preventDefault();
    },
  },
};

useKeyboardEvents(keyboardEvents);

useEmitter(CMD_REOPEN_CONVERSATION, onCmdOpenConversation);
useEmitter(CMD_RESOLVE_CONVERSATION, onCmdResolveConversation);
</script>

<template>
  <div class="flex relative justify-end items-center resolve-actions">
    <!-- Custom (MyDesk): one flat status button («✓ إغلاق», «إعادة فتح», «فتح»); snooze and
         "on hold" moved to the «إجراءات أخرى» menu (MoreActions) -->
    <Button
      v-if="isOpen"
      v-bind="
        compactProps(t('CONVERSATION.HEADER.RESOLVE_ACTION'), 'i-lucide-check')
      "
      icon="i-lucide-check"
      size="sm"
      color="slate"
      no-animation
      class="flex-shrink-0"
      :is-loading="isLoading"
      @click="onCmdResolveConversation"
    />
    <Button
      v-else-if="isResolved"
      v-bind="
        compactProps(
          t('CONVERSATION.HEADER.REOPEN_ACTION'),
          'i-lucide-rotate-ccw'
        )
      "
      size="sm"
      color="slate"
      no-animation
      class="flex-shrink-0"
      :is-loading="isLoading"
      @click="onCmdOpenConversation"
    />
    <Button
      v-else-if="showOpenButton"
      v-bind="
        compactProps(t('CONVERSATION.HEADER.OPEN_ACTION'), 'i-lucide-inbox')
      "
      size="sm"
      color="slate"
      no-animation
      class="flex-shrink-0"
      :is-loading="isLoading"
      @click="onCmdOpenConversation"
    />
    <ConversationResolveAttributesModal
      ref="resolveAttributesModalRef"
      @submit="handleResolveWithAttributes"
    />
  </div>
</template>
