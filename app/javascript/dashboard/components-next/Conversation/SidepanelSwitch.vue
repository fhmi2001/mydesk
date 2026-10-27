<script setup>
import Button from 'dashboard/components-next/button/Button.vue';
import ButtonGroup from 'dashboard/components-next/buttonGroup/ButtonGroup.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { computed } from 'vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useMapGetter } from 'dashboard/composables/store';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';

// Custom (MyDesk): `inline` renders the switch as header buttons next to «إغلاق» instead of a pill
// floating over the messages
defineProps({ inline: { type: Boolean, default: false } });

const { updateUISettings } = useUISettings();

const currentAccountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const showCopilotTab = computed(() =>
  isFeatureEnabledonAccount.value(currentAccountId.value, FEATURE_FLAGS.CAPTAIN)
);

const { uiSettings } = useUISettings();
const isContactSidebarOpen = computed(
  () => uiSettings.value.is_contact_sidebar_open
);
const isCopilotPanelOpen = computed(
  () => uiSettings.value.is_copilot_panel_open
);

const handleConversationSidebarToggle = () => {
  updateUISettings({
    is_contact_sidebar_open: !isContactSidebarOpen.value,
    is_copilot_panel_open: false,
  });
};

const handleCopilotSidebarToggle = () => {
  updateUISettings({
    is_contact_sidebar_open: false,
    is_copilot_panel_open: !isCopilotPanelOpen.value,
  });
};

const keyboardEvents = {
  'Alt+KeyO': {
    action: handleConversationSidebarToggle,
  },
};
useKeyboardEvents(keyboardEvents);
</script>

<template>
  <ButtonGroup
    :class="
      inline
        ? 'flex flex-row items-center gap-1'
        : 'flex flex-col justify-center items-center absolute top-36 xl:top-24 ltr:right-2 rtl:left-2 bg-n-solid-2/90 backdrop-blur-lg border border-n-weak/50 rounded-full gap-1.5 p-1.5 shadow-sm transition-shadow duration-200 hover:shadow !z-20'
    "
  >
    <Button
      v-tooltip.bottom="$t('CONVERSATION.SIDEBAR.CONTACT')"
      ghost
      slate
      sm
      class="transition-all duration-[250ms] ease-out active:!scale-95 active:!brightness-105 active:duration-75"
      :class="{
        '!rounded-full': !inline,
        'bg-n-alpha-2 active:shadow-sm': isContactSidebarOpen,
      }"
      icon="i-ph-user-bold"
      :aria-label="$t('CONVERSATION.SIDEBAR.CONTACT')"
      :aria-pressed="isContactSidebarOpen"
      @click="handleConversationSidebarToggle"
    />
    <Button
      v-if="showCopilotTab"
      v-tooltip.bottom="$t('CONVERSATION.SIDEBAR.COPILOT')"
      ghost
      slate
      sm
      :aria-label="$t('CONVERSATION.SIDEBAR.COPILOT')"
      :aria-pressed="isCopilotPanelOpen"
      class="transition-all duration-[250ms] ease-out active:!scale-95 active:duration-75"
      :class="{
        '!rounded-full': !inline,
        'bg-n-alpha-2 !text-n-iris-9 active:!brightness-105 active:shadow-sm':
          isCopilotPanelOpen,
      }"
      icon="i-woot-captain"
      @click="handleCopilotSidebarToggle"
    />
  </ButtonGroup>
</template>
