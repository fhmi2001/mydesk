import { mount } from '@vue/test-utils';
import LinkConversationBar from '../LinkConversationBar.vue';

const deals = [
  { id: 1, title: 'كراتين — النخبة', active_conversation_display_id: 12 },
  { id: 2, title: 'أكياس — النخبة', active_conversation_display_id: null },
];

describe('LinkConversationBar', () => {
  it("names the customer's one deal and links it in one click", async () => {
    const wrapper = mount(LinkConversationBar, {
      props: { deals: [deals[0]] },
    });
    expect(wrapper.text()).toContain('CRM.PANEL.LINK.ONE');
    expect(wrapper.find('select').exists()).toBe(false);
    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('link')[0][0]).toEqual(deals[0]);
  });

  it('lets the user pick the deal when the customer has several', async () => {
    const wrapper = mount(LinkConversationBar, { props: { deals } });
    await wrapper.find('select').setValue('2');
    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('link')[0][0]).toEqual(deals[1]);
  });
});
