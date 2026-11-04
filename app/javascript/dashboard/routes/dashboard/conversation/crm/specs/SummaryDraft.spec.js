import { mount } from '@vue/test-utils';
import SummaryDraft from '../SummaryDraft.vue';

const draft = {
  summary: 'يريد 500 كرتون',
  objections: 'السعر مرتفع',
  next_step: 'إرسال عرض سعر',
  suggested_amount: '12500',
  suggested_close_date: '2026-11-20',
};
const deals = [
  { id: 1, title: 'كراتين — النخبة', lock_version: 3 },
  { id: 2, title: 'أكياس — النخبة', lock_version: 0 },
];

vi.mock('dashboard/routes/dashboard/crm/shared/useCrmFormat', () => ({
  useCrmFormat: () => ({ date: value => String(value) }),
}));

const mountDraft = (props = {}) =>
  mount(SummaryDraft, { props: { draft, deals, ...props } });
const button = (wrapper, testid) =>
  wrapper.find(
    `[data-testid="${testid}"] button, button[data-testid="${testid}"]`
  );

describe('SummaryDraft', () => {
  it('puts the summary, objections and next step in one note the employee can edit', () => {
    const note = mountDraft().find('textarea').element.value;
    expect(note).toContain('يريد 500 كرتون');
    expect(note).toContain('السعر مرتفع');
    expect(note).toContain('إرسال عرض سعر');
  });

  it('saves the edited note on the chosen deal', async () => {
    const wrapper = mountDraft();
    await wrapper.find('select').setValue('2');
    await wrapper.find('textarea').setValue('ملاحظتي');
    await button(wrapper, 'save-note').trigger('click');
    expect(wrapper.emitted('saveNote')[0][0]).toEqual({
      deal: deals[1],
      content: 'ملاحظتي',
    });
  });

  it('applies the suggested amount and date only on its own button', async () => {
    const wrapper = mountDraft();
    expect(wrapper.emitted('apply')).toBeUndefined();
    await button(wrapper, 'apply-suggested').trigger('click');
    expect(wrapper.emitted('apply')[0][0]).toEqual({
      deal: deals[0],
      amount: '12500',
      close_date: '2026-11-20',
    });
  });

  it('offers no apply button when the conversation gave no amount or date', () => {
    const wrapper = mountDraft({
      draft: { ...draft, suggested_amount: null, suggested_close_date: null },
    });
    expect(button(wrapper, 'apply-suggested').exists()).toBe(false);
  });

  it('offers to create a deal from it when the customer has no open deal', async () => {
    const wrapper = mountDraft({ deals: [] });
    expect(wrapper.find('select').exists()).toBe(false);
    await button(wrapper, 'create-deal').trigger('click');
    expect(wrapper.emitted('createDeal')[0][0]).toMatchObject({
      amount: '12500',
      close_date: '2026-11-20',
    });
  });
});
