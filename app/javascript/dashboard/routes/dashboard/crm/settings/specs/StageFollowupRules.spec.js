import { mount } from '@vue/test-utils';
import StageFollowupRules from '../StageFollowupRules.vue';

const mountRules = stage =>
  mount(StageFollowupRules, {
    props: {
      stage: {
        name: 'تم إرسال العرض',
        silence_followup: true,
        followup_task_days: null,
        followup_task_title: null,
        ...stage,
      },
    },
  });

describe('StageFollowupRules', () => {
  it('shows and switches the silence follow-up', async () => {
    const wrapper = mountRules();
    const checkbox = wrapper.find('input[type="checkbox"]');
    expect(checkbox.element.checked).toBe(true);
    await checkbox.setValue(false);
    expect(wrapper.emitted('update')[0][0]).toEqual({
      silence_followup: false,
    });
  });

  it('sets the task a deal gets on entering the stage', async () => {
    const wrapper = mountRules({
      followup_task_days: 2,
      followup_task_title: 'متابعة العرض',
    });
    const [days, title] = wrapper.findAll('input:not([type="checkbox"])');
    expect(days.element.value).toBe('2');
    expect(title.element.value).toBe('متابعة العرض');
    await days.setValue('3');
    await title.setValue('اتصل بالعميل');
    expect(wrapper.emitted('update')).toEqual([
      [{ followup_task_days: '3' }],
      [{ followup_task_title: 'اتصل بالعميل' }],
    ]);
  });
});
