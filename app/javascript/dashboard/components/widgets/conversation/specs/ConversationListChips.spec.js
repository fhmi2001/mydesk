import { mount } from '@vue/test-utils';
import ConversationListChips from '../ConversationListChips.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const mountChips = props =>
  mount(ConversationListChips, { props: { modelValue: 'open', ...props } });

const labels = wrapper =>
  wrapper.findAll('button').map(button => button.text().split('.').pop());

describe('ConversationListChips', () => {
  it('offers every status and the two quick views, marking the active one', () => {
    const wrapper = mountChips();

    expect(labels(wrapper)).toEqual([
      'all',
      'open',
      'unread',
      'unattended',
      'pending',
      'snoozed',
      'resolved',
    ]);
    const pressed = wrapper.findAll('[aria-pressed="true"]');
    expect(pressed).toHaveLength(1);
    expect(pressed[0].text()).toContain('open');
  });

  it('hides the quick views where the route already sets a conversation type', () => {
    const wrapper = mountChips({ hideQuickFilters: true });

    expect(labels(wrapper)).not.toContain('unread');
    expect(labels(wrapper)).not.toContain('unattended');
  });

  it('emits the picked chip, and nothing for the active one', async () => {
    const wrapper = mountChips();
    const buttons = wrapper.findAll('button');

    await buttons[1].trigger('click');
    await buttons[2].trigger('click');

    expect(wrapper.emitted('update:modelValue')).toEqual([['unread']]);
  });
});
