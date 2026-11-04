import { mount, flushPromises } from '@vue/test-utils';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { crmConversationsAPI, crmSuggestionsAPI } from 'dashboard/api/crm';
import DealSuggestionBar from '../DealSuggestionBar.vue';

const push = vi.fn();
vi.mock('vue-router', () => ({
  useRouter: () => ({ push, currentRoute: { value: { fullPath: '/c/14' } } }),
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountScopedRoute: (name, params, query) => ({ name, params, query }),
  }),
}));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({ value: true }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/crm', () => ({
  crmConversationsAPI: { show: vi.fn() },
  crmSuggestionsAPI: { dismiss: vi.fn() },
}));

const chat = {
  id: 14,
  meta: { sender: { id: 26, name: 'سارة' }, assignee: { id: 3 } },
};
const pending = {
  id: 7,
  kind: 'new_deal',
  origin: 'automation',
  content: { title: 'عميل عاجل — سارة' },
};
const otherKinds = { id: 8, kind: 'follow_up', deal_id: 1, content: {} };

const mountBar = async (suggestions = [pending, otherKinds]) => {
  crmConversationsAPI.show.mockResolvedValue({ data: { suggestions } });
  const wrapper = mount(DealSuggestionBar, { props: { chat } });
  await flushPromises();
  return wrapper;
};

describe('DealSuggestionBar', () => {
  beforeEach(() => {
    push.mockReset();
    crmConversationsAPI.show.mockReset();
    crmSuggestionsAPI.dismiss.mockReset().mockResolvedValue({});
  });

  it("shows the conversation's deal suggestion above the reply box, and nothing else", async () => {
    const wrapper = await mountBar();
    expect(crmConversationsAPI.show).toHaveBeenCalledWith(14);
    expect(wrapper.text()).toContain('عميل عاجل — سارة');
    expect(wrapper.findAll('section')).toHaveLength(1);
  });

  it('shows nothing when there is no deal suggestion', async () => {
    const wrapper = await mountBar([otherKinds]);
    expect(wrapper.find('section').exists()).toBe(false);
  });

  it('appears at once when a suggestion for this conversation arrives', async () => {
    const wrapper = await mountBar([]);
    crmConversationsAPI.show.mockResolvedValue({
      data: { suggestions: [pending] },
    });
    emitter.emit(BUS_EVENTS.CRM_SUGGESTION_CREATED, {
      conversation_display_id: 14,
    });
    await flushPromises();
    expect(wrapper.text()).toContain('عميل عاجل — سارة');
  });

  it('opens the new deal form filled from it', async () => {
    const wrapper = await mountBar();
    await wrapper.findAll('button')[0].trigger('click');
    expect(push).toHaveBeenCalledWith({
      name: 'crm_deal_new',
      params: {},
      query: expect.objectContaining({
        contact_id: 26,
        contact_name: 'سارة',
        assignee_id: 3,
        conversation_id: 14,
        title: 'عميل عاجل — سارة',
        suggestion_id: 7,
        return_to: '/c/14',
      }),
    });
  });

  it('dismisses it', async () => {
    const wrapper = await mountBar();
    await wrapper.findAll('button')[1].trigger('click');
    await flushPromises();
    expect(crmSuggestionsAPI.dismiss).toHaveBeenCalledWith(7);
    expect(wrapper.find('section').exists()).toBe(false);
  });
});
