<script setup>
// Custom (MyDesk): the reply box's AI button and its menu, used by the classic top panel and by the
// one-row composer (in the row, or in the extra-tools tray on phones). Shown only with Captain tasks.
import { ref } from 'vue';
import { vOnClickOutside } from '@vueuse/components';
import { useCaptain } from 'dashboard/composables/useCaptain';
import { useTrack } from 'dashboard/composables';
import { CAPTAIN_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import NextButton from 'dashboard/components-next/button/Button.vue';
import CopilotMenuBar from './CopilotMenuBar.vue';

const props = defineProps({
  conversationId: { type: Number, default: null },
  disabled: { type: Boolean, default: false },
  editorContent: { type: String, default: undefined },
  hasContent: { type: Boolean, default: false },
  entryPoint: { type: String, default: 'top_panel' },
  // Where the menu opens from the button: up and toward the end, or up and toward the start
  menuAlign: { type: String, default: 'end' },
});

const emit = defineEmits(['executeCopilotAction']);

const { captainTasksEnabled } = useCaptain();
const showCopilotMenu = ref(false);
const copilotToggleRef = ref(null);

const toggleCopilotMenu = () => {
  const isOpening = !showCopilotMenu.value;
  if (isOpening) {
    useTrack(CAPTAIN_EVENTS.EDITOR_AI_MENU_OPENED, {
      conversationId: props.conversationId,
      entryPoint: props.entryPoint,
    });
  }
  showCopilotMenu.value = isOpening;
};

const handleCopilotAction = (actionKey, data) => {
  emit('executeCopilotAction', actionKey, data || props.editorContent);
  showCopilotMenu.value = false;
};
</script>

<template>
  <div v-if="captainTasksEnabled" class="relative">
    <NextButton
      ref="copilotToggleRef"
      v-tooltip.top="$t('CONVERSATION.REPLYBOX.AI_ASSIST')"
      ghost
      :disabled="disabled"
      :aria-label="$t('CONVERSATION.REPLYBOX.AI_ASSIST')"
      :aria-expanded="showCopilotMenu"
      :class="{
        'text-n-blue-11 hover:enabled:!bg-n-blue-3': !showCopilotMenu,
        'text-n-blue-11 bg-n-blue-3': showCopilotMenu,
      }"
      sm
      icon="i-ph-sparkle-fill"
      @click="toggleCopilotMenu"
    />
    <CopilotMenuBar
      v-if="showCopilotMenu"
      v-on-click-outside="[
        () => (showCopilotMenu = false),
        { ignore: [copilotToggleRef] },
      ]"
      :has-selection="false"
      :has-content="hasContent"
      :conversation-id="conversationId"
      class="bottom-full mb-2"
      :class="menuAlign === 'start' ? 'start-0' : 'end-0'"
      @execute-copilot-action="handleCopilotAction"
    />
  </div>
</template>
