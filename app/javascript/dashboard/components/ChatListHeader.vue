<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { formatNumber } from '@chatwoot/utils';
import wootConstants from 'dashboard/constants/globals';

import ConversationBasicFilter from './widgets/conversation/ConversationBasicFilter.vue';
import SwitchLayout from 'dashboard/routes/dashboard/conversation/search/SwitchLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';

const props = defineProps({
  pageTitle: { type: String, required: true },
  contactFilter: { type: Object, default: null },
  hasAppliedFilters: { type: Boolean, required: true },
  hasActiveFolders: { type: Boolean, required: true },
  isOnExpandedLayout: { type: Boolean, required: true },
  conversationStats: { type: Object, required: true },
  isListLoading: { type: Boolean, required: true },
  // Custom (MyDesk): the assignee views (mine / unassigned / all) switch from the title
  assigneeItems: { type: Array, default: () => [] },
  activeAssignee: { type: String, default: wootConstants.ASSIGNEE_TYPE.ME },
  // On the plain conversations page the view itself is the title
  isViewTitle: { type: Boolean, default: false },
  // null while the list is not fully loaded, so a partial count is never shown
  unreadCount: { type: Number, default: null },
});

const emit = defineEmits([
  'addFolders',
  'deleteFolders',
  'resetFilters',
  'basicFilterChange',
  'filtersModal',
  'assigneeChange',
]);

const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();

const onBasicFilterChange = (value, type) => {
  emit('basicFilterChange', value, type);
};

const hasAppliedFiltersOrActiveFolders = computed(() => {
  return props.hasAppliedFilters || props.hasActiveFolders;
});

// While filters narrow the list, the header names it and the back button exits.
const showFilterScope = computed(
  () => props.hasAppliedFilters && !props.hasActiveFolders
);

// The contact scope is set from the contact panel; it is exited, not edited.
const isContactScoped = computed(
  () => showFilterScope.value && !!props.contactFilter
);

const showViewMenu = computed(
  () =>
    !hasAppliedFiltersOrActiveFolders.value && props.assigneeItems.length > 1
);

const activeView = computed(() =>
  props.assigneeItems.find(item => item.key === props.activeAssignee)
);

const title = computed(() => {
  if (isContactScoped.value && props.contactFilter.name) {
    return props.contactFilter.name;
  }
  if (showViewMenu.value && props.isViewTitle && activeView.value) {
    return activeView.value.name;
  }
  return props.pageTitle;
});

const listCount = computed(() =>
  hasAppliedFiltersOrActiveFolders.value
    ? props.conversationStats?.allCount || 0
    : activeView.value?.count || 0
);

// «المسندة لي · 12 محادثة · 3 غير مقروءة»
const subtitle = computed(() => {
  if (props.isListLoading) return '';
  const parts = [];
  if (showViewMenu.value && !props.isViewTitle && activeView.value) {
    parts.push(activeView.value.name);
  }
  parts.push(
    t('CHAT_LIST.VIEWS.COUNT', { count: formatNumber(listCount.value) })
  );
  if (props.unreadCount) {
    parts.push(
      t('CHAT_LIST.VIEWS.UNREAD', { count: formatNumber(props.unreadCount) })
    );
  }
  return parts.join(' · ');
});

const isViewMenuOpen = ref(false);
const closeViewMenu = () => {
  isViewMenuOpen.value = false;
};

const selectView = key => {
  closeViewMenu();
  if (key !== props.activeAssignee) emit('assigneeChange', key);
};

// Alt+N cycles the views, as it cycled the tabs this menu replaced
useKeyboardEvents({
  'Alt+KeyN': {
    action: () => {
      if (!showViewMenu.value) return;
      const index = props.assigneeItems.findIndex(
        item => item.key === props.activeAssignee
      );
      const next =
        props.assigneeItems[(index + 1) % props.assigneeItems.length];
      selectView(next.key);
    },
  },
});

const toggleConversationLayout = () => {
  const { LAYOUT_TYPES } = wootConstants;
  const {
    conversation_display_type: conversationDisplayType = LAYOUT_TYPES.CONDENSED,
  } = uiSettings.value;
  const newViewType =
    conversationDisplayType === LAYOUT_TYPES.CONDENSED
      ? LAYOUT_TYPES.EXPANDED
      : LAYOUT_TYPES.CONDENSED;
  updateUISettings({
    conversation_display_type: newViewType,
    previously_used_conversation_display_type: newViewType,
  });
};
</script>

<template>
  <div
    class="flex items-center justify-between gap-2 px-3 h-14 flex-none"
    :class="{
      'border-b border-n-strong': hasAppliedFiltersOrActiveFolders,
    }"
  >
    <div class="flex items-center min-w-0 flex-1">
      <NextButton
        v-if="showFilterScope"
        v-tooltip.right="$t('FILTER.CLEAR_BUTTON_LABEL')"
        :aria-label="$t('FILTER.CLEAR_BUTTON_LABEL')"
        icon="i-lucide-chevron-left"
        class="shrink-0 -ms-2 !h-6 !w-6 me-1"
        slate
        sm
        ghost
        @click="emit('resetFilters')"
      />
      <!-- Custom (MyDesk): the title opens the view menu; the line under it counts the list -->
      <div
        v-on-click-outside="closeViewMenu"
        class="relative flex flex-col min-w-0 -ms-1"
      >
        <h1 class="flex min-w-0 text-heading-1 text-n-slate-12" :title="title">
          <button
            v-if="showViewMenu"
            v-tooltip.bottom="$t('CHAT_LIST.VIEWS.MENU_LABEL')"
            type="button"
            aria-haspopup="menu"
            :aria-expanded="isViewMenuOpen"
            class="flex items-center gap-1 min-w-0 max-w-full px-1 rounded-md text-start hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-blue-8 focus-visible:outline-none"
            @click="isViewMenuOpen = !isViewMenuOpen"
          >
            <span class="truncate">{{ title }}</span>
            <Icon
              icon="i-lucide-chevron-down"
              class="size-4 shrink-0 text-n-slate-11 transition-transform duration-150"
              :class="{ 'rotate-180': isViewMenuOpen }"
            />
          </button>
          <span v-else class="truncate px-1">{{ title }}</span>
        </h1>
        <p
          v-if="subtitle"
          class="mb-0 px-1 text-xs text-n-slate-11 truncate tabular-nums"
        >
          {{ subtitle }}
        </p>
        <ul
          v-if="isViewMenuOpen"
          role="menu"
          class="absolute z-40 top-full mt-1 start-0 w-60 p-1 m-0 list-none bg-n-alpha-3 backdrop-blur-[100px] border border-n-weak rounded-xl shadow-lg"
        >
          <li v-for="item in assigneeItems" :key="item.key" role="none">
            <button
              type="button"
              role="menuitemradio"
              :aria-checked="item.key === activeAssignee"
              class="flex items-center gap-2 w-full h-9 touch:h-11 px-2 rounded-lg text-sm text-start hover:bg-n-alpha-2 focus-visible:bg-n-alpha-2 focus-visible:outline-none"
              :class="
                item.key === activeAssignee
                  ? 'text-n-blue-11 font-medium'
                  : 'text-n-slate-12'
              "
              @click="selectView(item.key)"
            >
              <span class="flex-1 truncate">{{ item.name }}</span>
              <span class="text-xs tabular-nums text-n-slate-11">
                {{ formatNumber(item.count) }}
              </span>
              <Icon
                icon="i-lucide-check"
                class="size-4 shrink-0"
                :class="{ invisible: item.key !== activeAssignee }"
              />
            </button>
          </li>
        </ul>
      </div>
    </div>
    <!-- Custom (MyDesk): finger-sized (44px) on touch screens -->
    <div
      class="flex items-center gap-1 shrink-0 touch:[&_button]:min-h-11 touch:[&_button]:min-w-11"
    >
      <template v-if="hasAppliedFilters && !hasActiveFolders">
        <div class="relative">
          <NextButton
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.ADD.SAVE_BUTTON')"
            icon="i-lucide-save"
            slate
            xs
            faded
            @click="emit('addFolders')"
          />
          <div
            id="saveFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
      </template>
      <template v-if="hasActiveFolders">
        <div class="relative">
          <NextButton
            id="toggleConversationFilterButton"
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.EDIT.EDIT_BUTTON')"
            icon="i-lucide-pen-line"
            slate
            xs
            faded
            @click="emit('filtersModal')"
          />
          <div
            id="conversationFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
        <NextButton
          id="toggleConversationFilterButton"
          v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.DELETE.DELETE_BUTTON')"
          icon="i-lucide-trash-2"
          ruby
          xs
          faded
          @click="emit('deleteFolders')"
        />
      </template>
      <div v-else-if="!isContactScoped" class="relative">
        <NextButton
          id="toggleConversationFilterButton"
          v-tooltip.right="$t('FILTER.TOOLTIP_LABEL')"
          icon="i-lucide-list-filter"
          slate
          xs
          faded
          @click="emit('filtersModal')"
        />
        <div
          id="conversationFilterTeleportTarget"
          class="absolute z-50 mt-2"
          :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
        />
      </div>
      <!-- Custom (MyDesk): status now lives in the chips under the header; this keeps the sort -->
      <ConversationBasicFilter
        v-if="!isContactScoped"
        :is-on-expanded-layout="isOnExpandedLayout"
        :show-status-filter="false"
        @change-filter="onBasicFilterChange"
      />
      <SwitchLayout
        :is-on-expanded-layout="isOnExpandedLayout"
        @toggle="toggleConversationLayout"
      />
      <!-- Below md the search field sits under the header (ConversationListSearch) -->
      <NextButton
        v-tooltip.top="$t('CHAT_LIST.SEARCH_CONVERSATIONS')"
        :aria-label="$t('CHAT_LIST.SEARCH_CONVERSATIONS')"
        icon="i-lucide-search"
        class="max-md:hidden"
        slate
        xs
        faded
        @click="$router.push({ name: 'search' })"
      />
      <ComposeConversation align="start">
        <template #trigger>
          <NextButton
            v-tooltip.top-end="$t('CHAT_LIST.NEW_CONVERSATION')"
            :aria-label="$t('CHAT_LIST.NEW_CONVERSATION')"
            icon="i-lucide-plus"
            class="!rounded-full"
            xs
          />
        </template>
      </ComposeConversation>
    </div>
  </div>
</template>
