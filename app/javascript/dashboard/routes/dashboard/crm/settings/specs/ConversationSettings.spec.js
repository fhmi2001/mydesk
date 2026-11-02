import { mount } from '@vue/test-utils';
import ConversationSettings from '../ConversationSettings.vue';

const mountSettings = (settings = {}) =>
  mount(ConversationSettings, {
    props: {
      inboxes: [
        { id: 10, name: 'واتساب ويب' },
        { id: 6, name: 'bajaba store' },
      ],
      sources: [
        { id: 1, name: 'واتساب' },
        { id: 2, name: 'الموقع' },
      ],
      settings: {
        channel_sources: { 10: 1 },
        followup_days: 3,
        sms_attribution_days: 14,
        ...settings,
      },
    },
  });

describe('ConversationSettings', () => {
  it('lists every inbox with the lead source mapped to it, or none', () => {
    const wrapper = mountSettings();
    const selects = wrapper.findAll('select');
    expect(wrapper.text()).toContain('واتساب ويب');
    expect(wrapper.text()).toContain('bajaba store');
    expect(selects[0].element.value).toBe('1');
    expect(selects[1].element.value).toBe('');
  });

  it('saves the source picked for an inbox, and none as a cleared mapping', async () => {
    const wrapper = mountSettings();
    const selects = wrapper.findAll('select');
    await selects[1].setValue('2');
    await selects[0].setValue('');
    expect(wrapper.emitted('save')).toEqual([
      [{ channel_sources: { 6: 2 } }],
      [{ channel_sources: { 10: null } }],
    ]);
  });

  it('saves the silent days and the SMS window when the field is left with a new value', async () => {
    const wrapper = mountSettings();
    const [followup, window] = wrapper.findAll('input');
    await followup.setValue('5');
    await followup.trigger('blur');
    await window.trigger('blur');
    expect(wrapper.emitted('save')).toEqual([[{ followup_days: '5' }]]);
  });
});
