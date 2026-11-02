import { mount } from '@vue/test-utils';
import DealSuggestionCard from '../DealSuggestionCard.vue';

const mountCard = content =>
  mount(DealSuggestionCard, {
    props: { suggestion: { id: 7, kind: 'new_deal', content } },
  });

describe('DealSuggestionCard', () => {
  it('shows what the customer wants to buy, leaving out what is unknown', () => {
    const wrapper = mountCard({
      summary: 'يطلب سعر 500 كرتون',
      product: 'كراتين',
      quantity: '500',
      city: '',
    });
    expect(wrapper.text()).toContain('يطلب سعر 500 كرتون');
    expect(wrapper.find('[data-testid="suggestion-details"]').text()).toBe(
      'كراتين · 500'
    );
  });

  it("shows an automation rule's suggestion by its title, and says where it came from", () => {
    const wrapper = mount(DealSuggestionCard, {
      props: {
        suggestion: {
          id: 8,
          kind: 'new_deal',
          origin: 'automation',
          content: { title: 'طلب جملة — سارة' },
        },
      },
    });
    expect(wrapper.text()).toContain('طلب جملة — سارة');
    expect(wrapper.text()).toContain('CRM.PANEL.SUGGESTION.FROM_AUTOMATION');
  });

  it('asks to create the deal or to dismiss the suggestion', async () => {
    const wrapper = mountCard({ summary: 'x' });
    const [create, dismiss] = wrapper.findAll('button');
    await create.trigger('click');
    await dismiss.trigger('click');
    expect(wrapper.emitted('create')[0][0]).toMatchObject({ id: 7 });
    expect(wrapper.emitted('dismiss')[0][0]).toMatchObject({ id: 7 });
  });
});
