<script>
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { REPLY_EDITOR_MODES, CHAR_LENGTH_WARNING } from './constants';
import NextButton from 'dashboard/components-next/button/Button.vue';
import EditorModeToggle from './EditorModeToggle.vue';
// Custom (MyDesk): the AI button lives in its own component, shared with the one-row composer
import ComposerAiButton from './ComposerAiButton.vue';

export default {
  name: 'ReplyTopPanel',
  components: {
    NextButton,
    EditorModeToggle,
    ComposerAiButton,
  },
  props: {
    mode: {
      type: String,
      default: REPLY_EDITOR_MODES.REPLY,
    },
    isReplyRestricted: {
      type: Boolean,
      default: false,
    },
    disabled: {
      type: Boolean,
      default: false,
    },
    isEditorDisabled: {
      type: Boolean,
      default: false,
    },
    conversationId: {
      type: Number,
      default: null,
    },
    isMessageLengthReachingThreshold: {
      type: Boolean,
      default: () => false,
    },
    charactersRemaining: {
      type: Number,
      default: () => 0,
    },
    editorContent: {
      type: String,
      default: undefined,
    },
    hasContent: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['setReplyMode', 'toggleEditorSize', 'executeCopilotAction'],
  setup(props, { emit }) {
    const setReplyMode = mode => {
      emit('setReplyMode', mode);
    };
    const handleReplyClick = () => {
      if (props.isReplyRestricted) return;
      setReplyMode(REPLY_EDITOR_MODES.REPLY);
    };
    const handleNoteClick = () => {
      setReplyMode(REPLY_EDITOR_MODES.NOTE);
    };
    const handleModeToggle = () => {
      const newMode =
        props.mode === REPLY_EDITOR_MODES.REPLY
          ? REPLY_EDITOR_MODES.NOTE
          : REPLY_EDITOR_MODES.REPLY;
      setReplyMode(newMode);
    };

    const keyboardEvents = {
      'Alt+KeyP': {
        action: () => handleNoteClick(),
        allowOnFocusedInput: false,
      },
      'Alt+KeyL': {
        action: () => handleReplyClick(),
        allowOnFocusedInput: false,
      },
    };
    useKeyboardEvents(keyboardEvents);

    return {
      handleModeToggle,
      handleReplyClick,
      handleNoteClick,
      REPLY_EDITOR_MODES,
    };
  },
  computed: {
    replyButtonClass() {
      return {
        'is-active': this.mode === REPLY_EDITOR_MODES.REPLY,
      };
    },
    noteButtonClass() {
      return {
        'is-active': this.mode === REPLY_EDITOR_MODES.NOTE,
      };
    },
    charLengthClass() {
      return this.charactersRemaining < 0 ? 'text-n-ruby-9' : 'text-n-slate-11';
    },
    characterLengthWarning() {
      return this.charactersRemaining < 0
        ? `${-this.charactersRemaining} ${CHAR_LENGTH_WARNING.NEGATIVE}`
        : `${this.charactersRemaining} ${CHAR_LENGTH_WARNING.UNDER_50}`;
    },
  },
};
</script>

<template>
  <div class="flex justify-between gap-2 h-[3.25rem] items-center ps-3 pe-2">
    <EditorModeToggle
      :mode="mode"
      :disabled="disabled"
      :is-reply-restricted="isReplyRestricted"
      @toggle-mode="handleModeToggle"
    />
    <div class="flex items-center mx-4 my-0">
      <div v-if="isMessageLengthReachingThreshold" class="text-xs">
        <span :class="charLengthClass">
          {{ characterLengthWarning }}
        </span>
      </div>
    </div>
    <!-- Custom (MyDesk): resizing works without AI too, so only the AI menu depends on Captain tasks;
         both buttons get a name, and the AI one the brand violet (One Violet Rule) -->
    <div
      class="flex items-center gap-2 touch:[&_button]:min-h-11 touch:[&_button]:min-w-11"
    >
      <ComposerAiButton
        :conversation-id="conversationId"
        :disabled="disabled || isEditorDisabled"
        :editor-content="editorContent"
        :has-content="hasContent"
        @execute-copilot-action="
          (actionKey, data) => $emit('executeCopilotAction', actionKey, data)
        "
      />
      <NextButton
        v-tooltip.top="$t('CONVERSATION.REPLYBOX.RESIZE_EDITOR')"
        ghost
        class="text-n-slate-11"
        sm
        icon="i-lucide-maximize-2"
        :aria-label="$t('CONVERSATION.REPLYBOX.RESIZE_EDITOR')"
        @click="$emit('toggleEditorSize')"
      />
    </div>
  </div>
</template>
