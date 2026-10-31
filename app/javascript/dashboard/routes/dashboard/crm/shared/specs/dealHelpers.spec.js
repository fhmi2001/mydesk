// Custom (MyDesk)
import {
  validateDeal,
  buildDealPayload,
  validateStages,
  dealToForm,
} from '../dealHelpers';

describe('dealHelpers', () => {
  it('requires a title and a numeric amount', () => {
    expect(validateDeal({ title: '', amount: '' }).errors).toEqual({
      title: 'TITLE_REQUIRED',
    });
    expect(validateDeal({ title: 'x', amount: 'abc' }).errors).toEqual({
      amount: 'AMOUNT_INVALID',
    });
    expect(validateDeal({ title: 'x', amount: '٥٠٠' }).valid).toBe(true);
  });

  it('builds the payload with Arabic digits converted to a decimal string', () => {
    const payload = buildDealPayload({
      title: ' باقة ',
      amount: '٥٠٬٠٠٠',
      pipeline_id: 1,
      stage_id: 2,
      close_date: '',
    });
    expect(payload).toMatchObject({
      title: 'باقة',
      amount: '50000.00',
      pipeline_id: 1,
      stage_id: 2,
      close_date: null,
    });
  });

  it('validates pipeline stages', () => {
    const ok = [
      { name: 'a', probability: 10, kind: 'open' },
      { name: 'w', probability: 100, kind: 'won' },
      { name: 'l', probability: 0, kind: 'lost' },
    ];
    expect(validateStages(ok).valid).toBe(true);
    expect(validateStages(ok.slice(0, 2)).errors).toContain('NEED_WON_LOST');
    expect(validateStages(ok.slice(1)).errors).toContain('NEED_OPEN');
    expect(
      validateStages([...ok, { name: '', probability: 150, kind: 'open' }])
        .errors
    ).toEqual(['STAGE_NAME', 'PROBABILITY']);
  });

  it('maps a deal to the form', () => {
    const form = dealToForm({
      title: 't',
      amount: '12.00',
      pipeline_id: 1,
      stage_id: 2,
      contact: { id: 9 },
      contact_name: 'c',
      assignee: null,
      lock_version: 3,
    });
    expect(form).toMatchObject({
      title: 't',
      amount: '12.00',
      contact_id: 9,
      contact_name: 'c',
      assignee_id: null,
      lock_version: 3,
    });
  });

  it('carries the priority: medium for a new deal, the deal own one when editing', () => {
    expect(buildDealPayload({ title: 'x', amount: '1' }).priority).toBe(
      'medium'
    );
    expect(dealToForm({ title: 't', priority: 'high' }).priority).toBe('high');
    expect(
      buildDealPayload({ title: 'x', amount: '1', priority: 'low' }).priority
    ).toBe('low');
  });
});
