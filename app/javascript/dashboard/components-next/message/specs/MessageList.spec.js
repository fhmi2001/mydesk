import { mount } from '@vue/test-utils';
import MessageList from '../MessageList.vue';
import { MESSAGE_TYPES } from '../constants';

vi.mock('dashboard/composables/store.js', () => ({
  useMapGetter: () => ({ value: null }),
}));
vi.mock('dashboard/api/inbox/message.js', () => ({ default: {} }));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => `${key}${params ? `:${params.count}` : ''}`,
    locale: { value: 'en' },
  }),
}));

const MessageStub = {
  props: ['id', 'content', 'messageType'],
  template: '<li data-test="message">{{ content }}</li>',
};

const message = (id, messageType, content = `message ${id}`) => ({
  id,
  content,
  message_type: messageType,
  created_at: 1793135000 + id,
  sender: { id: 1 },
});

const activity = (id, content) => message(id, MESSAGE_TYPES.ACTIVITY, content);

const mountList = messages =>
  mount(MessageList, {
    props: { currentUserId: 1, messages },
    global: { stubs: { Message: MessageStub, CampaignMessage: true } },
  });

const separators = wrapper =>
  wrapper.findAll('[role="separator"]').map(item => item.text());

const shown = wrapper =>
  wrapper.findAll('[data-test="message"]').map(item => item.text());

describe('MessageList activity folding', () => {
  const messages = [
    message(1, MESSAGE_TYPES.INCOMING, 'hello'),
    activity(2, 'assigned'),
    activity(3, 'priority high'),
    activity(4, 'resolved'),
    activity(5, 'reopened'),
    message(6, MESSAGE_TYPES.OUTGOING, 'reply'),
  ];

  it('folds a run of three or more events, keeping the latest one', () => {
    const wrapper = mountList(messages);

    expect(shown(wrapper)).toEqual(['hello', 'reopened', 'reply']);
    const toggle = wrapper.find('button[aria-expanded]');
    expect(toggle.text()).toContain('CONVERSATION.ACTIVITY_FOLD.SHOW:3');
    expect(toggle.attributes('aria-expanded')).toBe('false');
  });

  it('expands and collapses the run', async () => {
    const wrapper = mountList(messages);
    const toggle = wrapper.find('button[aria-expanded]');

    await toggle.trigger('click');
    expect(shown(wrapper)).toEqual([
      'hello',
      'assigned',
      'priority high',
      'resolved',
      'reopened',
      'reply',
    ]);
    expect(toggle.attributes('aria-expanded')).toBe('true');
    expect(toggle.text()).toContain('CONVERSATION.ACTIVITY_FOLD.HIDE');

    await toggle.trigger('click');
    expect(shown(wrapper)).toEqual(['hello', 'reopened', 'reply']);
  });

  it('leaves one or two events alone', () => {
    const wrapper = mountList([
      message(1, MESSAGE_TYPES.INCOMING, 'hello'),
      activity(2, 'assigned'),
      activity(3, 'resolved'),
    ]);

    expect(shown(wrapper)).toEqual(['hello', 'assigned', 'resolved']);
    expect(wrapper.find('button[aria-expanded]').exists()).toBe(false);
  });
});

describe('MessageList day separators', () => {
  const at = (day, hour, minute = 0) =>
    new Date(2026, 9, day, hour, minute).getTime() / 1000;
  const on = (id, time, messageType = MESSAGE_TYPES.INCOMING) => ({
    ...message(id, messageType, `message ${id}`),
    created_at: time,
  });

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 28, 12, 0));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('heads each day once, naming yesterday and today', () => {
    const wrapper = mountList([
      on(1, at(27, 9)),
      on(2, at(27, 10)),
      on(3, at(28, 8)),
    ]);

    expect(separators(wrapper)).toEqual([
      'CONVERSATION.DAY_SEPARATOR.YESTERDAY',
      'CONVERSATION.DAY_SEPARATOR.TODAY',
    ]);
  });

  it('does not fold events across midnight', () => {
    const wrapper = mountList([
      on(1, at(27, 23, 50), MESSAGE_TYPES.ACTIVITY),
      on(2, at(27, 23, 55), MESSAGE_TYPES.ACTIVITY),
      on(3, at(28, 0, 5), MESSAGE_TYPES.ACTIVITY),
      on(4, at(28, 0, 10), MESSAGE_TYPES.ACTIVITY),
    ]);

    // Two events each side of midnight: no run reaches three, nothing folds
    expect(wrapper.find('button[aria-expanded]').exists()).toBe(false);
    expect(shown(wrapper)).toHaveLength(4);
    expect(separators(wrapper)).toHaveLength(2);
  });
});
