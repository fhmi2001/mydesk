// Custom (MyDesk): pure helpers for the deal form, the pipeline editor and error handling
import { parseAmount } from 'dashboard/helper/crmFormat';

export const emptyDealForm = (overrides = {}) => ({
  title: '',
  amount: '',
  pipeline_id: null,
  stage_id: null,
  contact_id: null,
  contact_name: '',
  assignee_id: null,
  close_date: '',
  description: '',
  conversation_id: null,
  lock_version: undefined,
  ...overrides,
});

export const dealToForm = deal =>
  emptyDealForm({
    title: deal.title,
    amount: deal.amount,
    pipeline_id: deal.pipeline_id,
    stage_id: deal.stage_id,
    contact_id: deal.contact?.id ?? null,
    contact_name: deal.contact_name || '',
    assignee_id: deal.assignee?.id ?? null,
    close_date: deal.close_date || '',
    description: deal.description || '',
    conversation_id: deal.conversation_id,
    lock_version: deal.lock_version,
  });

// { errors: { title, amount }, valid }
export const validateDeal = form => {
  const errors = {};
  if (!String(form.title || '').trim()) errors.title = 'TITLE_REQUIRED';
  if (
    String(form.amount ?? '').trim() !== '' &&
    parseAmount(form.amount) === null
  )
    errors.amount = 'AMOUNT_INVALID';
  return { errors, valid: Object.keys(errors).length === 0 };
};

export const isPastDate = value => {
  if (!value) return false;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return new Date(`${value}T00:00:00`) < today;
};

// What the API receives; the amount goes as a decimal string of cents / 100
export const buildDealPayload = form => {
  const cents = parseAmount(form.amount);
  return {
    title: String(form.title || '').trim(),
    amount: cents === null ? '0' : (cents / 100).toFixed(2),
    pipeline_id: form.pipeline_id,
    stage_id: form.stage_id || undefined,
    contact_id: form.contact_id || null,
    assignee_id: form.assignee_id || null,
    close_date: form.close_date || null,
    description: form.description || '',
    conversation_id: form.conversation_id || undefined,
    lock_version: form.lock_version,
  };
};

// Pipeline editor: one won, one lost, at least one open, names present, probability 0..100
export const validateStages = stages => {
  const kinds = stages.map(s => s.kind);
  const errors = [];
  if (
    kinds.filter(k => k === 'won').length !== 1 ||
    kinds.filter(k => k === 'lost').length !== 1
  )
    errors.push('NEED_WON_LOST');
  if (!kinds.includes('open')) errors.push('NEED_OPEN');
  if (stages.some(s => !String(s.name || '').trim())) errors.push('STAGE_NAME');
  if (
    stages.some(
      s => !(Number(s.probability) >= 0 && Number(s.probability) <= 100)
    )
  )
    errors.push('PROBABILITY');
  return { errors, valid: errors.length === 0 };
};

export const apiErrorMessage = (error, fallback) =>
  error?.response?.data?.message || error?.response?.data?.error || fallback;

export const isStale = error => error?.response?.status === 409;
export const isUnavailable = error =>
  !error?.response || error.response.status >= 500;
