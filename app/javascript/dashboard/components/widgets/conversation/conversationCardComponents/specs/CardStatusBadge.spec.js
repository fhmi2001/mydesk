import { mount } from '@vue/test-utils';
import CardStatusBadge from '../CardStatusBadge.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const mountBadge = status =>
  mount(CardStatusBadge, {
    props: { status },
    global: {
      stubs: { Icon: { props: ['icon'], template: '<i :data-icon="icon" />' } },
    },
  });

describe('CardStatusBadge', () => {
  it.each([
    ['open', 'text-n-teal-11', 'i-lucide-circle-dot'],
    ['pending', 'text-n-amber-11', 'i-lucide-circle-pause'],
    ['snoozed', 'text-n-iris-11', 'i-lucide-alarm-clock'],
    ['resolved', 'text-n-slate-11', 'i-lucide-circle-check'],
  ])('names %s in its own colour and icon', (status, tone, icon) => {
    const wrapper = mountBadge(status);

    expect(wrapper.text()).toBe(`CHAT_LIST.QUICK_FILTERS.${status}`);
    expect(wrapper.classes()).toContain(tone);
    expect(wrapper.find('i').attributes('data-icon')).toBe(icon);
  });

  it('renders nothing for an unknown status', () => {
    expect(mountBadge('archived').html()).toBe('<!--v-if-->');
  });
});
