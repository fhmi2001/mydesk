import { mount } from '@vue/test-utils';
import DealMessageCard from '../DealMessageCard.vue';

const suggestion = (kind, content = {}) => ({
  id: 4,
  kind,
  deal_title: 'كراتين',
  content,
});
const mountCard = (props = {}) =>
  mount(DealMessageCard, {
    props: { suggestion: suggestion('follow_up'), ...props },
  });
const button = (wrapper, testid) =>
  wrapper.find(
    `[data-testid="${testid}"] button, button[data-testid="${testid}"]`
  );

describe('DealMessageCard', () => {
  it('names the kind and the deal, and asks for the draft only on request', async () => {
    const wrapper = mountCard();
    expect(wrapper.text()).toContain('CRM.PANEL.DEAL_MESSAGE.follow_up');
    expect(button(wrapper, 'copy-draft').exists()).toBe(false);
    await button(wrapper, 'write-draft').trigger('click');
    expect(wrapper.emitted('write')[0][0]).toMatchObject({ id: 4 });
  });

  it('shows a written draft the employee can edit, then copies the edited text', async () => {
    const wrapper = mountCard({
      suggestion: suggestion('won_message', { draft: 'شكراً لثقتك' }),
    });
    expect(wrapper.find('textarea').element.value).toBe('شكراً لثقتك');
    await wrapper.find('textarea').setValue('شكراً جزيلاً');
    await button(wrapper, 'copy-draft').trigger('click');
    expect(wrapper.emitted('copy')[0]).toEqual([
      expect.objectContaining({ id: 4 }),
      'شكراً جزيلاً',
    ]);
  });

  it('warns that WhatsApp takes only a template once its 24 hours are over', () => {
    const wrapper = mountCard({
      suggestion: suggestion('follow_up', { draft: 'x' }),
      canReply: false,
    });
    expect(wrapper.text()).toContain('CRM.PANEL.DEAL_MESSAGE.WINDOW_CLOSED');
  });

  it('reminds that resolving sends the satisfaction survey after a win', () => {
    const wrapper = mountCard({
      suggestion: suggestion('won_message'),
      csatSurveyEnabled: true,
    });
    expect(wrapper.text()).toContain('CRM.PANEL.DEAL_MESSAGE.CSAT_HINT');
  });

  it('can be dismissed', async () => {
    const wrapper = mountCard();
    await button(wrapper, 'dismiss').trigger('click');
    expect(wrapper.emitted('dismiss')).toHaveLength(1);
  });
});
