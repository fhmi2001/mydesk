import { mount } from '@vue/test-utils';
import DealActivityList from '../DealActivityList.vue';

vi.mock('../../shared/useCrmFormat', () => ({
  useCrmFormat: () => ({
    money: value => String(value),
    date: value => String(value),
    dateTime: value => String(value),
  }),
}));

describe('DealActivityList', () => {
  it('shows the system moving the follow-up to a new conversation', () => {
    const wrapper = mount(DealActivityList, {
      props: {
        activities: [
          {
            id: 1,
            kind: 'conversation_linked',
            user: null,
            data: { display_id: 42 },
            created_at: '2026-11-02T10:00:00Z',
          },
        ],
      },
    });
    expect(wrapper.text()).toContain('CRM.DEALS.ACTIVITY.SYSTEM');
    expect(wrapper.text()).toContain('CRM.DEALS.ACTIVITY.conversation_linked');
    expect(wrapper.find('.i-lucide-messages-square').exists()).toBe(true);
  });
});
