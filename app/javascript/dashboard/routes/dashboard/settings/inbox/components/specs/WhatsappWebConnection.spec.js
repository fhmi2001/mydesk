import { flushPromises, mount } from '@vue/test-utils';
import WhatsappWebConnection from '../WhatsappWebConnection.vue';
import whatsappWebChannel from 'dashboard/api/channel/whatsappWebChannel';
import inboxMgmt from 'dashboard/i18n/locale/en/inboxMgmt.json';

const lookup = key =>
  key.split('.').reduce((node, part) => node?.[part], inboxMgmt);

// Resolve against the real English copy so a missing or renamed key fails the test.
vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => String(lookup(key) ?? key) }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/channel/whatsappWebChannel', () => ({
  default: { getConnection: vi.fn(), disconnect: vi.fn() },
}));

const ButtonStub = {
  props: ['label'],
  emits: ['click'],
  template:
    '<button data-test="button" @click="$emit(\'click\')">{{ label }}</button>',
};

const mountComponent = (props = {}) =>
  mount(WhatsappWebConnection, {
    props: { inboxId: 7, ...props },
    global: { stubs: { NextButton: ButtonStub, Spinner: true } },
  });

describe('WhatsappWebConnection', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('shows the QR code and the linking steps while waiting for the phone', async () => {
    whatsappWebChannel.getConnection.mockResolvedValue({
      data: { state: 'connecting', qr_code: 'data:image/png;base64,QR' },
    });

    const wrapper = mountComponent();
    await flushPromises();

    expect(wrapper.find('img').attributes('src')).toBe(
      'data:image/png;base64,QR'
    );
    expect(wrapper.text()).toContain('Waiting for the phone to scan the code');
    expect(wrapper.findAll('li')).toHaveLength(3);
  });

  it('keeps polling until the phone is linked, then reports it', async () => {
    whatsappWebChannel.getConnection
      .mockResolvedValueOnce({
        data: { state: 'connecting', qr_code: 'data:image/png;base64,QR' },
      })
      .mockResolvedValueOnce({ data: { state: 'open', qr_code: null } });

    const wrapper = mountComponent();
    await flushPromises();
    await vi.advanceTimersByTimeAsync(4000);
    await flushPromises();

    expect(whatsappWebChannel.getConnection).toHaveBeenCalledTimes(2);
    expect(wrapper.emitted('connected')).toHaveLength(1);
    expect(wrapper.text()).toContain('The number is linked');
    // No unlink button while setting up a new inbox
    expect(wrapper.find('[data-test="button"]').exists()).toBe(false);
  });

  it('offers to unlink a linked number on the settings page', async () => {
    whatsappWebChannel.getConnection.mockResolvedValue({
      data: { state: 'open', qr_code: null },
    });
    whatsappWebChannel.disconnect.mockResolvedValue({});

    const wrapper = mountComponent({ manage: true });
    await flushPromises();
    await wrapper.find('[data-test="button"]').trigger('click');
    await flushPromises();

    expect(whatsappWebChannel.disconnect).toHaveBeenCalledWith(7);
  });

  it('stops polling after a few minutes and offers a new code', async () => {
    whatsappWebChannel.getConnection.mockResolvedValue({
      data: { state: 'connecting', qr_code: 'data:image/png;base64,QR' },
    });

    const wrapper = mountComponent();
    await flushPromises();
    await vi.advanceTimersByTimeAsync(3 * 60 * 1000 + 8000);
    await flushPromises();

    expect(wrapper.text()).toContain('The code expired before it was scanned');
    expect(wrapper.find('img').exists()).toBe(false);
    const callsAtExpiry = whatsappWebChannel.getConnection.mock.calls.length;
    await vi.advanceTimersByTimeAsync(20000);
    expect(whatsappWebChannel.getConnection).toHaveBeenCalledTimes(
      callsAtExpiry
    );
  });
});
