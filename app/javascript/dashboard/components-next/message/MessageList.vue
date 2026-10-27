<script setup>
import { computed, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import { useLocale } from 'shared/composables/useLocale';
import { dayKey, dayLabel } from 'dashboard/helper/localizedTime';
import Message from './Message.vue';
import CampaignMessage from './CampaignMessage.vue';
import { MESSAGE_TYPES } from './constants.js';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import { useMapGetter } from 'dashboard/composables/store.js';
import MessageApi from 'dashboard/api/inbox/message.js';

/**
 * Props definition for the component
 * @typedef {Object} Props
 * @property {Array} readMessages - Array of read messages
 * @property {Array} unReadMessages - Array of unread messages
 * @property {Number} currentUserId - ID of the current user
 * @property {Boolean} isAnEmailChannel - Whether this is an email channel
 * @property {Object} inboxSupportsReplyTo - Inbox reply support configuration
 * @property {Array} messages - Array of all messages [These are not in camelcase]
 */
const props = defineProps({
  currentUserId: {
    type: Number,
    required: true,
  },
  firstUnreadId: {
    type: Number,
    default: null,
  },
  isAnEmailChannel: {
    type: Boolean,
    default: false,
  },
  inboxSupportsReplyTo: {
    type: Object,
    default: () => ({ incoming: false, outgoing: false }),
  },
  messages: {
    type: Array,
    default: () => [],
  },
  campaignHistory: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['retry']);

const allMessages = computed(() => {
  return useCamelCase(props.messages, {
    deep: true,
    stopPaths: [
      'content_attributes.translations',
      'content_attributes.whatsapp_flow_response.response_json',
    ],
  });
});

const currentChat = useMapGetter('getSelectedChat');

const timeline = computed(() => {
  const messages = allMessages.value.map(message => ({
    key: `message-${message.id}`,
    createdAt: message.createdAt,
    message,
  }));
  if (!props.campaignHistory.length) return messages;

  return [
    ...messages,
    ...props.campaignHistory.map(recipient => ({
      key: `campaign-${recipient.id}`,
      createdAt: recipient.sent_at,
      recipient,
    })),
  ].sort((a, b) => a.createdAt - b.createdAt);
});

// Custom (MyDesk): a run of system events (assignment, priority, status, labels...) folds behind one
// toggle so the conversation itself stays in view. The latest event of the run stays visible, since it
// tells the current state.
const ACTIVITY_RUN_MIN = 3;
const expandedRuns = reactive(new Set());
const isActivity = entry =>
  entry.message?.messageType === MESSAGE_TYPES.ACTIVITY;

// Custom (MyDesk): a heading at each new day («اليوم», «أمس», «السبت، 25 أكتوبر»); a folded run
// never crosses midnight, so every day keeps its own events
const { t } = useI18n();
const { resolvedLocale } = useLocale();
const dayLabels = computed(() => ({
  today: t('CONVERSATION.DAY_SEPARATOR.TODAY'),
  yesterday: t('CONVERSATION.DAY_SEPARATOR.YESTERDAY'),
}));

const rows = computed(() => {
  const list = timeline.value.map((entry, index) => ({
    key: entry.key,
    entry,
    index,
    day: dayKey(entry.createdAt),
  }));
  const result = [];
  let currentDay = null;
  let start = 0;
  while (start < list.length) {
    const { day, entry } = list[start];
    if (day !== currentDay) {
      currentDay = day;
      result.push({
        key: `day-${day}`,
        separator: dayLabel(
          entry.createdAt,
          resolvedLocale.value,
          dayLabels.value
        ),
      });
    }

    let end = start;
    while (
      end < list.length &&
      list[end].day === day &&
      isActivity(list[end].entry)
    ) {
      end += 1;
    }

    if (end - start >= ACTIVITY_RUN_MIN) {
      const run = list.slice(start, end);
      const key = `activity-run-${run[0].key}`;
      const expanded = expandedRuns.has(key);
      result.push({ key, fold: { key, hidden: run.length - 1, expanded } });
      result.push(...(expanded ? run : run.slice(-1)));
    } else {
      result.push(...list.slice(start, Math.max(end, start + 1)));
    }
    start = Math.max(end, start + 1);
  }
  return result;
});

const toggleRun = key => {
  if (expandedRuns.has(key)) expandedRuns.delete(key);
  else expandedRuns.add(key);
};

// Cache for fetched reply messages to avoid duplicate API calls
const fetchedReplyMessages = reactive(new Map());

/**
 * Fetches a specific message from the API by trying to get messages around it
 * @param {number} messageId - The ID of the message to fetch
 * @param {number} conversationId - The ID of the conversation
 * @returns {Promise<Object|null>} - The fetched message or null if not found/error
 */
const fetchReplyMessage = async (messageId, conversationId) => {
  // Return cached result if already fetched
  if (fetchedReplyMessages.has(messageId)) {
    return fetchedReplyMessages.get(messageId);
  }

  try {
    const response = await MessageApi.getPreviousMessages({
      conversationId,
      before: messageId + 100,
      after: messageId - 100,
    });

    const messages = response.data?.payload || [];
    const targetMessage = messages.find(msg => msg.id === messageId);

    if (targetMessage) {
      const camelCaseMessage = useCamelCase(targetMessage);
      fetchedReplyMessages.set(messageId, camelCaseMessage);
      return camelCaseMessage;
    }

    // Cache null result to avoid repeated API calls
    fetchedReplyMessages.set(messageId, null);
    return null;
  } catch (error) {
    fetchedReplyMessages.set(messageId, null);
    return null;
  }
};

/**
 * Determines if a message should be grouped with the next message
 * @param {Object} current - Current message
 * @param {Object} next - Next message, absent at a campaign entry or the end
 * @returns {Boolean} - Whether the message should be grouped with next
 */
const shouldGroupWithNext = (current, next) => {
  if (!next || next.status === 'failed') return false;

  const nextSenderId = next.senderId ?? next.sender?.id;
  const currentSenderId = current.senderId ?? current.sender?.id;
  const hasSameSender = nextSenderId === currentSenderId;

  const nextMessageType = next.messageType;
  const currentMessageType = current.messageType;

  const areBothTemplates =
    nextMessageType === MESSAGE_TYPES.TEMPLATE &&
    currentMessageType === MESSAGE_TYPES.TEMPLATE;

  if (!hasSameSender || areBothTemplates) return false;

  if (currentMessageType !== nextMessageType) return false;

  // Check if messages are in the same minute by rounding down to nearest minute
  return Math.floor(next.createdAt / 60) === Math.floor(current.createdAt / 60);
};

/**
 * Gets the message that was replied to
 * @param {Object} parentMessage - The message containing the reply reference
 * @returns {Object|null} - The message being replied to, or null if not found
 */
const getInReplyToMessage = parentMessage => {
  if (!parentMessage) return null;

  const inReplyToMessageId =
    parentMessage.contentAttributes?.inReplyTo ??
    parentMessage.content_attributes?.in_reply_to;

  if (!inReplyToMessageId) return null;

  // Try to find in current messages first
  let replyMessage = props.messages?.find(msg => msg.id === inReplyToMessageId);

  // Then try store messages
  if (!replyMessage && currentChat.value?.messages) {
    replyMessage = currentChat.value.messages.find(
      msg => msg.id === inReplyToMessageId
    );
  }

  // Then check fetch cache
  if (!replyMessage && fetchedReplyMessages.has(inReplyToMessageId)) {
    replyMessage = fetchedReplyMessages.get(inReplyToMessageId);
  }

  // If still not found and we have conversation context, fetch it
  if (!replyMessage && currentChat.value?.id) {
    fetchReplyMessage(inReplyToMessageId, currentChat.value.id);
    return null; // Let UI handle loading state
  }

  return replyMessage ? useCamelCase(replyMessage) : null;
};
</script>

<template>
  <ul class="px-4 bg-n-surface-1">
    <slot name="beforeAll" />
    <template v-for="{ key, separator, fold, entry, index } in rows" :key="key">
      <li
        v-if="separator"
        class="flex justify-center pt-4 pb-2"
        role="separator"
        :aria-label="separator"
      >
        <span
          class="inline-flex items-center h-6 px-2.5 rounded-full text-label-small font-medium text-n-slate-11 bg-n-alpha-2"
        >
          {{ separator }}
        </span>
      </li>
      <li v-else-if="fold" class="flex justify-center py-1">
        <button
          type="button"
          class="inline-flex items-center h-6 gap-1 px-2 rounded-lg text-label-small text-n-slate-11 bg-n-alpha-2 hover:bg-n-alpha-3 hover:text-n-slate-12 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
          :aria-expanded="fold.expanded"
          @click="toggleRun(fold.key)"
        >
          <span class="i-lucide-history size-3.5" aria-hidden="true" />
          {{
            fold.expanded
              ? t('CONVERSATION.ACTIVITY_FOLD.HIDE')
              : t('CONVERSATION.ACTIVITY_FOLD.SHOW', { count: fold.hidden })
          }}
          <span
            class="size-3.5"
            :class="
              fold.expanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'
            "
            aria-hidden="true"
          />
        </button>
      </li>
      <template v-else>
        <slot
          v-if="firstUnreadId && entry.message?.id === firstUnreadId"
          name="unreadBadge"
        />
        <CampaignMessage v-if="entry.recipient" :recipient="entry.recipient" />
        <Message
          v-else
          v-bind="entry.message"
          :is-email-inbox="isAnEmailChannel"
          :in-reply-to="getInReplyToMessage(entry.message)"
          :group-with-next="
            shouldGroupWithNext(entry.message, timeline[index + 1]?.message)
          "
          :inbox-supports-reply-to="inboxSupportsReplyTo"
          :current-user-id="currentUserId"
          data-clarity-mask="True"
          @retry="emit('retry', entry.message)"
        />
      </template>
    </template>
    <slot name="after" />
  </ul>
</template>
