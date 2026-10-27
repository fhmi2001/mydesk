<script>
import { ref } from 'vue';
import { useMediaQuery } from '@vueuse/core';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import FileUpload from 'vue-upload-component';
import * as ActiveStorage from 'activestorage';
import inboxMixin from 'shared/mixins/inboxMixin';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { getAllowedFileTypesByChannel } from '@chatwoot/utils';
import VideoCallButton from '../VideoCallButton.vue';
import RequestContactInfoButton from '../RequestContactInfoButton.vue';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import { mapGetters } from 'vuex';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  name: 'ReplyBottomPanel',
  components: {
    NextButton,
    FileUpload,
    VideoCallButton,
    RequestContactInfoButton,
  },
  mixins: [inboxMixin],
  props: {
    isNote: {
      type: Boolean,
      default: false,
    },
    onSend: {
      type: Function,
      default: () => {},
    },
    sendButtonText: {
      type: String,
      default: '',
    },
    recordingAudioDurationText: {
      type: String,
      default: '00:00',
    },
    // inbox prop is used in /mixins/inboxMixin,
    // remove this props when refactoring to composable if not needed
    // eslint-disable-next-line vue/no-unused-properties
    inbox: {
      type: Object,
      default: () => ({}),
    },
    showFileUpload: {
      type: Boolean,
      default: false,
    },
    showAudioRecorder: {
      type: Boolean,
      default: false,
    },
    onFileUpload: {
      type: Function,
      default: () => {},
    },
    toggleEmojiPicker: {
      type: Function,
      default: () => {},
    },
    toggleAudioRecorder: {
      type: Function,
      default: () => {},
    },
    toggleAudioRecorderPlayPause: {
      type: Function,
      default: () => {},
    },
    isRecordingAudio: {
      type: Boolean,
      default: false,
    },
    recordingAudioState: {
      type: String,
      default: '',
    },
    isSendDisabled: {
      type: Boolean,
      default: false,
    },
    isOnPrivateNote: {
      type: Boolean,
      default: false,
    },
    enableMultipleFileUpload: {
      type: Boolean,
      default: true,
    },
    enableWhatsAppTemplates: {
      type: Boolean,
      default: false,
    },
    enableContentTemplates: {
      type: Boolean,
      default: false,
    },
    conversationId: {
      type: Number,
      required: true,
    },
    // eslint-disable-next-line vue/no-unused-properties
    message: {
      type: String,
      default: '',
    },
    newConversationModalActive: {
      type: Boolean,
      default: false,
    },
    portalSlug: {
      type: String,
      required: true,
    },
    conversationType: {
      type: String,
      default: '',
    },
    isEditorDisabled: {
      type: Boolean,
      default: false,
    },
    // Custom (MyDesk): tools and Send of the one-row composer (see ReplyBox)
    chatBar: {
      type: Boolean,
      default: false,
    },
    // Only private notes are allowed here, so the note switch cannot turn back to reply
    isReplyRestricted: {
      type: Boolean,
      default: false,
    },
  },
  emits: [
    'toggleInsertArticle',
    'selectWhatsappTemplate',
    'selectContentTemplate',
    'requestContactInfoTemplate',
    'toggleNoteMode',
  ],
  setup(props) {
    const { setSignatureFlagForInbox, fetchSignatureFlagFromUISettings } =
      useUISettings();

    const uploadRef = ref(false);

    const keyboardEvents = {
      '$mod+Alt+KeyA': {
        action: () => {
          // Skip if editor is disabled (e.g., WhatsApp 24-hour window expired)
          if (props.isEditorDisabled) return;

          // TODO: This is really hacky, we need to replace the file picker component with
          // a custom one, where the logic and the component markup is isolated.
          // Once we have the custom component, we can remove the hacky logic below.

          const uploadTriggerButton = document.querySelector(
            '#conversationAttachment'
          );
          if (uploadTriggerButton) uploadTriggerButton.click();
        },
        allowOnFocusedInput: true,
      },
    };

    useKeyboardEvents(keyboardEvents);
    const isCompact = useMediaQuery('(max-width: 639px)');
    const isTrayOpen = ref(false);

    return {
      setSignatureFlagForInbox,
      fetchSignatureFlagFromUISettings,
      uploadRef,
      isCompact,
      isTrayOpen,
    };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      uiFlags: 'integrations/getUIFlags',
    }),
    wrapClass() {
      return {
        'is-note-mode': this.isNote,
      };
    },
    // Custom (MyDesk): plain icons in the one-row composer, soft buttons in the classic toolbar
    toolVariant() {
      return this.chatBar ? 'ghost' : 'faded';
    },
    sendAsIcon() {
      return this.chatBar || this.isCompact;
    },
    // Whether the "+" tray would hold anything
    hasExtraTools() {
      return (
        (this.isCompact && !this.isEditorDisabled) ||
        (!this.isRecordingAudio && this.showAudioRecorderButton) ||
        this.showMessageSignatureButton ||
        this.enableWhatsAppTemplates ||
        this.enableContentTemplates ||
        !!this.enableInsertArticleInReply ||
        !this.isOnPrivateNote
      );
    },
    showAttachButton() {
      if (this.isEditorDisabled) return false;
      return this.showFileUpload || this.isNote;
    },
    showAudioRecorderButton() {
      if (this.isEditorDisabled) return false;
      if (this.isALineChannel || this.isATiktokChannel) {
        return false;
      }
      // Disable audio recorder for safari browser as recording is not supported
      // const isSafari = /^((?!chrome|android|crios|fxios).)*safari/i.test(
      //   navigator.userAgent
      // );

      return (
        this.isFeatureEnabledonAccount(
          this.accountId,
          FEATURE_FLAGS.VOICE_RECORDER
        ) && this.showAudioRecorder
        // !isSafari
      );
    },
    showAudioPlayStopButton() {
      if (this.isEditorDisabled) return false;
      return this.showAudioRecorder && this.isRecordingAudio;
    },
    isInstagramDM() {
      return this.conversationType === 'instagram_direct_message';
    },
    allowedFileTypes() {
      if (this.isOnPrivateNote) {
        return getAllowedFileTypesByChannel();
      }

      let channelType = this.channelType || this.inbox?.channel_type;
      if (this.isAnInstagramChannel || this.isInstagramDM) {
        channelType = INBOX_TYPES.INSTAGRAM;
      }

      return getAllowedFileTypesByChannel({
        channelType,
        medium: this.inbox?.medium,
      });
    },
    enableDragAndDrop() {
      return !this.newConversationModalActive;
    },
    audioRecorderPlayStopIcon() {
      switch (this.recordingAudioState) {
        // playing paused recording stopped inactive destroyed
        case 'playing':
          return 'i-ph-pause';
        case 'paused':
          return 'i-ph-play';
        case 'stopped':
          return 'i-ph-play';
        default:
          return 'i-ph-stop';
      }
    },
    showMessageSignatureButton() {
      if (this.isEditorDisabled) return false;
      return !this.isOnPrivateNote;
    },
    sendWithSignature() {
      // channelType is sourced from inboxMixin
      return this.fetchSignatureFlagFromUISettings(this.channelType);
    },
    signatureToggleTooltip() {
      return this.sendWithSignature
        ? this.$t('CONVERSATION.FOOTER.DISABLE_SIGN_TOOLTIP')
        : this.$t('CONVERSATION.FOOTER.ENABLE_SIGN_TOOLTIP');
    },
    enableInsertArticleInReply() {
      return this.portalSlug;
    },
    isFetchingAppIntegrations() {
      return this.uiFlags.isFetching;
    },
  },
  mounted() {
    ActiveStorage.start();
  },
  methods: {
    toggleMessageSignature() {
      this.setSignatureFlagForInbox(this.channelType, !this.sendWithSignature);
    },
    // Custom (MyDesk): the "+" tray of the one-row composer
    closeTray() {
      this.isTrayOpen = false;
    },
    onTrayEmoji() {
      this.closeTray();
      this.toggleEmojiPicker();
    },
    toggleInsertArticle() {
      this.$emit('toggleInsertArticle');
    },
  },
};
</script>

<template>
  <!-- Custom (MyDesk): with `chatBar` the panel becomes the tools and Send of the one-row composer
       (ReplyBox lays them out around the text box): attach, private note, emoji and AI in the row, the
       other tools in a "+" tray. Without it (email), the classic toolbar below the editor. -->
  <div
    class="flex justify-between p-3"
    :class="[wrapClass, { 'composer-bar': chatBar }]"
  >
    <div class="left-wrap" :class="{ relative: chatBar }">
      <NextButton
        v-if="!isEditorDisabled && !(chatBar && isCompact)"
        v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_EMOJI_ICON')"
        :aria-label="$t('CONVERSATION.REPLYBOX.TIP_EMOJI_ICON')"
        icon="i-ph-smiley-sticker"
        color="slate"
        :variant="toolVariant"
        size="sm"
        :class="{ 'order-3': chatBar }"
        @click="toggleEmojiPicker"
      />
      <FileUpload
        v-if="showAttachButton"
        ref="uploadRef"
        v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_ATTACH_ICON')"
        input-id="conversationAttachment"
        :size="4096 * 4096"
        :accept="allowedFileTypes"
        :multiple="enableMultipleFileUpload"
        :drop="enableDragAndDrop"
        :drop-directory="false"
        :data="{
          direct_upload_url: '/rails/active_storage/direct_uploads',
          direct_upload: true,
        }"
        :class="{ 'order-1': chatBar }"
        @input-file="onFileUpload"
      >
        <NextButton
          v-if="showAttachButton"
          v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_ATTACH_ICON')"
          :aria-label="$t('CONVERSATION.REPLYBOX.TIP_ATTACH_ICON')"
          icon="i-ph-paperclip"
          color="slate"
          :variant="toolVariant"
          size="sm"
        />
      </FileUpload>
      <NextButton
        v-if="chatBar"
        v-tooltip.top-end="
          isOnPrivateNote
            ? $t('CONVERSATION.REPLYBOX.NOTE_TOGGLE.TO_REPLY')
            : $t('CONVERSATION.REPLYBOX.NOTE_TOGGLE.TO_NOTE')
        "
        :aria-label="$t('CONVERSATION.REPLYBOX.PRIVATE_NOTE')"
        :aria-pressed="isOnPrivateNote"
        icon="i-lucide-message-square-lock"
        :color="isOnPrivateNote ? 'amber' : 'slate'"
        :variant="isOnPrivateNote ? 'faded' : 'ghost'"
        size="sm"
        :disabled="isOnPrivateNote && isReplyRestricted"
        class="order-2"
        @click="$emit('toggleNoteMode')"
      />
      <template v-if="!chatBar || isRecordingAudio">
        <NextButton
          v-if="showAudioRecorderButton"
          v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_AUDIORECORDER_ICON')"
          :aria-label="$t('CONVERSATION.REPLYBOX.TIP_AUDIORECORDER_ICON')"
          :icon="
            !isRecordingAudio ? 'i-ph-microphone' : 'i-ph-microphone-slash'
          "
          color="slate"
          :variant="toolVariant"
          size="sm"
          :class="{ 'order-3': chatBar }"
          @click="toggleAudioRecorder"
        />
        <NextButton
          v-if="showAudioPlayStopButton"
          :icon="audioRecorderPlayStopIcon"
          color="slate"
          :variant="toolVariant"
          size="sm"
          :label="recordingAudioDurationText"
          :class="{ 'order-3': chatBar }"
          @click="toggleAudioRecorderPlayPause"
        />
      </template>
      <!-- "+" and its tray share one container, so clicking "+" again is not an outside click -->
      <div
        v-on-clickaway="closeTray"
        :class="chatBar ? 'relative order-4 flex' : 'contents'"
      >
        <NextButton
          v-if="chatBar && hasExtraTools"
          v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.MORE_TOOLS')"
          :aria-label="$t('CONVERSATION.REPLYBOX.MORE_TOOLS')"
          :aria-expanded="isTrayOpen"
          aria-controls="composer-extra-tools"
          icon="i-lucide-plus"
          color="slate"
          :variant="isTrayOpen ? 'faded' : 'ghost'"
          size="sm"
          class="[&_span]:transition-transform"
          :class="{ '[&_span]:rotate-45': isTrayOpen }"
          @click="isTrayOpen = !isTrayOpen"
        />
        <!-- Classic: these tools sit inline (display: contents). One-row: a tray above "+". -->
        <div
          v-show="!chatBar || isTrayOpen"
          id="composer-extra-tools"
          :class="
            chatBar
              ? 'absolute bottom-full start-0 z-30 mb-2 flex w-max max-w-[calc(100vw-2rem)] flex-wrap items-center gap-1 rounded-xl bg-n-solid-2 p-1.5 shadow-lg outline outline-1 -outline-offset-1 outline-n-weak'
              : 'contents'
          "
          @click="closeTray"
        >
          <NextButton
            v-if="chatBar && isCompact && !isEditorDisabled"
            v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_EMOJI_ICON')"
            :aria-label="$t('CONVERSATION.REPLYBOX.TIP_EMOJI_ICON')"
            icon="i-ph-smiley-sticker"
            color="slate"
            variant="ghost"
            size="sm"
            @click.stop="onTrayEmoji"
          />
          <slot v-if="chatBar && isCompact" name="ai" :in-tray="true" />
          <NextButton
            v-if="chatBar && !isRecordingAudio && showAudioRecorderButton"
            v-tooltip.top-end="
              $t('CONVERSATION.REPLYBOX.TIP_AUDIORECORDER_ICON')
            "
            :aria-label="$t('CONVERSATION.REPLYBOX.TIP_AUDIORECORDER_ICON')"
            icon="i-ph-microphone"
            color="slate"
            variant="ghost"
            size="sm"
            @click="toggleAudioRecorder"
          />
          <NextButton
            v-if="showMessageSignatureButton"
            v-tooltip.top-end="signatureToggleTooltip"
            :aria-label="signatureToggleTooltip"
            icon="i-ph-signature"
            color="slate"
            :variant="toolVariant"
            size="sm"
            @click="toggleMessageSignature"
          />
          <NextButton
            v-if="enableWhatsAppTemplates"
            v-tooltip.top-end="$t('CONVERSATION.FOOTER.WHATSAPP_TEMPLATES')"
            :aria-label="$t('CONVERSATION.FOOTER.WHATSAPP_TEMPLATES')"
            icon="i-ph-whatsapp-logo"
            color="slate"
            :variant="toolVariant"
            size="sm"
            @click="$emit('selectWhatsappTemplate')"
          />
          <RequestContactInfoButton
            v-if="!isOnPrivateNote"
            @request-template="$emit('requestContactInfoTemplate')"
          />
          <NextButton
            v-if="enableContentTemplates"
            v-tooltip.top-end="'Content Templates'"
            icon="i-ph-whatsapp-logo"
            color="slate"
            :variant="toolVariant"
            size="sm"
            @click="$emit('selectContentTemplate')"
          />
          <VideoCallButton
            v-if="
              (isAWebWidgetInbox || isAPIInbox) &&
              !isOnPrivateNote &&
              !isEditorDisabled
            "
            :conversation-id="conversationId"
          />
          <NextButton
            v-if="enableInsertArticleInReply"
            v-tooltip.top-end="
              $t('HELP_CENTER.ARTICLE_SEARCH.OPEN_ARTICLE_SEARCH')
            "
            :aria-label="$t('HELP_CENTER.ARTICLE_SEARCH.OPEN_ARTICLE_SEARCH')"
            icon="i-ph-article-ny-times"
            color="slate"
            :variant="toolVariant"
            size="sm"
            @click="toggleInsertArticle"
          />
        </div>
      </div>
      <div v-if="chatBar && !isCompact" class="order-5">
        <slot name="ai" :in-tray="false" />
      </div>
      <transition name="modal-fade">
        <div
          v-show="uploadRef && uploadRef.dropActive"
          class="flex fixed top-0 right-0 bottom-0 left-0 z-20 flex-col gap-2 justify-center items-center w-full h-full text-n-slate-12 bg-modal-backdrop-light dark:bg-modal-backdrop-dark"
        >
          <fluent-icon icon="cloud-backup" size="40" />
          <h4 class="text-2xl break-words text-n-slate-12">
            {{ $t('CONVERSATION.REPLYBOX.DRAG_DROP') }}
          </h4>
        </div>
      </transition>
    </div>
    <div class="right-wrap">
      <!-- Custom (MyDesk): Send is an icon in the one-row composer and on phones (it points the
           reading direction), a labelled button otherwise -->
      <NextButton
        v-tooltip.top-end="sendAsIcon ? sendButtonText : null"
        :label="sendAsIcon ? undefined : sendButtonText"
        :icon="sendAsIcon ? 'i-lucide-send-horizontal' : undefined"
        :aria-label="sendButtonText"
        type="submit"
        sm
        :color="isNote ? 'amber' : 'blue'"
        :disabled="isSendDisabled"
        class="flex-shrink-0 rtl:[&_span]:-scale-x-100"
        @click="onSend"
      />
    </div>
  </div>
</template>

<style lang="scss" scoped>
.left-wrap {
  @apply items-center flex gap-2;
}

.right-wrap {
  @apply flex;
}

// Custom (MyDesk): finger-sized tools and Send on touch screens (44px)
@media (pointer: coarse) {
  .left-wrap :deep(button),
  .right-wrap :deep(button) {
    @apply min-h-11 min-w-11;
  }
}

:deep(.file-uploads) {
  label {
    @apply cursor-pointer;
  }

  &:hover button {
    @apply enabled:bg-n-slate-9/20;
  }
}
</style>
