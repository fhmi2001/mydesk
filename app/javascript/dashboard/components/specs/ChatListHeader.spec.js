import { shallowMount } from '@vue/test-utils';
import ChatListHeader from '../ChatListHeader.vue';

vi.mock('dashboard/composables/useUISettings', async () => {
  const { ref } = await import('vue');
  return {
    useUISettings: () => ({
      uiSettings: ref({}),
      updateUISettings: vi.fn(),
    }),
  };
});

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(),
}));

const mountHeader = props =>
  shallowMount(ChatListHeader, {
    props: {
      pageTitle: 'Conversations',
      hasAppliedFilters: false,
      hasActiveFolders: false,
      activeStatus: 'open',
      isOnExpandedLayout: false,
      conversationStats: { allCount: 12 },
      isListLoading: false,
      ...props,
    },
    global: {
      mocks: { $t: key => key },
    },
  });

const contactFilter = { id: 7, name: 'Jane Doe' };

describe('ChatListHeader', () => {
  it('renders the page title and the filter button without filters', () => {
    const wrapper = mountHeader();

    expect(wrapper.find('h1').text()).toBe('Conversations');
    expect(wrapper.find('#toggleConversationFilterButton').exists()).toBe(true);
    expect(wrapper.find('[icon="i-lucide-chevron-left"]').exists()).toBe(false);
  });

  it('keeps the page title and the filter button for non contact filters', () => {
    const wrapper = mountHeader({ hasAppliedFilters: true });

    expect(wrapper.find('h1').text()).toBe('Conversations');
    expect(wrapper.find('#toggleConversationFilterButton').exists()).toBe(true);
    expect(wrapper.find('[icon="i-lucide-chevron-left"]').exists()).toBe(true);
  });

  it('names the contact and hides the filter button when scoped to a contact', () => {
    const wrapper = mountHeader({ hasAppliedFilters: true, contactFilter });

    expect(wrapper.find('h1').text()).toBe('Jane Doe');
    expect(wrapper.find('#toggleConversationFilterButton').exists()).toBe(
      false
    );
    expect(wrapper.find('[icon="i-lucide-chevron-left"]').exists()).toBe(true);
  });

  it('falls back to the page title when the scoped contact has no name', () => {
    const wrapper = mountHeader({
      hasAppliedFilters: true,
      contactFilter: { id: 7, name: '' },
    });

    expect(wrapper.find('h1').text()).toBe('Conversations');
    expect(wrapper.find('#toggleConversationFilterButton').exists()).toBe(
      false
    );
  });

  const assigneeItems = [
    { key: 'me', name: 'Assigned to me', count: 4 },
    { key: 'unassigned', name: 'Unassigned', count: 2 },
    { key: 'all', name: 'All conversations', count: 12 },
  ];

  it('titles the plain list with its view and counts it underneath', () => {
    const wrapper = mountHeader({
      assigneeItems,
      activeAssignee: 'unassigned',
      isViewTitle: true,
      unreadCount: 1,
    });

    expect(wrapper.find('h1').text()).toBe('Unassigned');
    expect(wrapper.find('p').text()).toBe(
      'CHAT_LIST.VIEWS.COUNT · CHAT_LIST.VIEWS.UNREAD'
    );
  });

  it('keeps a scoped title and names the view in the count line', () => {
    const wrapper = mountHeader({
      pageTitle: 'WhatsApp',
      assigneeItems,
      activeAssignee: 'me',
    });

    expect(wrapper.find('h1').text()).toBe('WhatsApp');
    expect(wrapper.find('p').text()).toBe(
      'Assigned to me · CHAT_LIST.VIEWS.COUNT'
    );
  });

  it('switches the view from the title menu', async () => {
    const wrapper = mountHeader({ assigneeItems, activeAssignee: 'me' });

    await wrapper.find('button[aria-haspopup="menu"]').trigger('click');
    const items = wrapper.findAll('[role="menuitemradio"]');
    expect(items).toHaveLength(3);
    await items[2].trigger('click');

    expect(wrapper.emitted('assigneeChange')).toEqual([['all']]);
    expect(wrapper.find('[role="menu"]').exists()).toBe(false);
  });

  it('closes the view menu on Escape', async () => {
    const wrapper = mountHeader({ assigneeItems, activeAssignee: 'me' });

    await wrapper.find('button[aria-haspopup="menu"]').trigger('click');
    await wrapper.find('[role="menu"]').trigger('keydown', { key: 'Escape' });

    expect(wrapper.find('[role="menu"]').exists()).toBe(false);
    expect(wrapper.emitted('assigneeChange')).toBeUndefined();
  });

  it('has no view menu while filters narrow the list', () => {
    const wrapper = mountHeader({ assigneeItems, hasAppliedFilters: true });

    expect(wrapper.find('button[aria-haspopup="menu"]').exists()).toBe(false);
  });

  it('keeps the folder controls when a folder is active', () => {
    const wrapper = mountHeader({
      hasAppliedFilters: true,
      hasActiveFolders: true,
      contactFilter,
    });

    expect(wrapper.find('h1').text()).toBe('Conversations');
    expect(wrapper.find('[icon="i-lucide-pen-line"]').exists()).toBe(true);
    expect(wrapper.find('[icon="i-lucide-trash-2"]').exists()).toBe(true);
  });
});
