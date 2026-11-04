// Custom (MyDesk): the wide list row carries the customer's deal badge too (CONVERSATION_SALES_PLAN.md)
import { shallowMount } from '@vue/test-utils';
import ConversationCardExpanded from '../ConversationCardExpanded.vue';
import DealBadge from 'dashboard/routes/dashboard/conversation/crm/DealBadge.vue';

describe('ConversationCardExpanded', () => {
  it("shows the deal badge of the conversation's contact", () => {
    const wrapper = shallowMount(ConversationCardExpanded, {
      props: {
        chat: { id: 11, labels: [], messages: [], status: 'open' },
        currentContact: { id: 900, name: 'مجموعة الصفوة' },
      },
      global: { directives: { tooltip: {} } },
    });
    expect(wrapper.findComponent(DealBadge).props('contactId')).toBe(900);
  });
});
