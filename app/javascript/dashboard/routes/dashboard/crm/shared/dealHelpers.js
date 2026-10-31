// Custom (MyDesk): pure helpers for the deal form, the pipeline editor and error handling
import { parseAmount, toWesternDigits } from 'dashboard/helper/crmFormat';

// The managed lists a deal takes a value from, and the deal field each fills
export const DEAL_LISTS = [
  'lead_source',
  'product',
  'competitor',
  'region',
  'industry',
];
export const listField = list => `${list}_id`;

// Set by the employee, or empty for the one derived from the probability
export const FORECAST_CATEGORIES = [
  'pipeline',
  'best_case',
  'commit',
  'omitted',
];

const emptyLists = () =>
  Object.fromEntries(DEAL_LISTS.map(list => [listField(list), '']));

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
  priority: 'medium',
  forecast_category: '',
  probability_override: '',
  ...emptyLists(),
  conversation_id: null,
  lock_version: undefined,
  ...overrides,
});

// Most important first, as the filter and the form list them
export const DEAL_PRIORITIES = ['high', 'medium', 'low'];

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
    priority: deal.priority || 'medium',
    forecast_category: deal.forecast_category || '',
    probability_override: deal.probability_override ?? '',
    ...Object.fromEntries(
      DEAL_LISTS.map(list => [listField(list), deal[listField(list)] ?? ''])
    ),
    conversation_id: deal.conversation_id,
    lock_version: deal.lock_version,
  });

// { errors: { title, amount, close_date }, valid }. An open deal needs an amount above zero and an expected close
// date (the server holds the same rule); a deal created straight into won or lost does not.
export const validateDeal = (form, { open = true } = {}) => {
  const errors = {};
  if (!String(form.title || '').trim()) errors.title = 'TITLE_REQUIRED';
  const amountText = String(form.amount ?? '').trim();
  const cents = parseAmount(form.amount);
  if (amountText !== '' && cents === null) errors.amount = 'AMOUNT_INVALID';
  else if (open && !(cents > 0)) errors.amount = 'AMOUNT_REQUIRED';
  if (open && !form.close_date) errors.close_date = 'CLOSE_DATE_REQUIRED';
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
    priority: form.priority || 'medium',
    // Empty puts the deal back on the category derived from the probability, and on the stage's probability
    forecast_category: form.forecast_category || null,
    probability_override:
      String(form.probability_override ?? '').trim() === ''
        ? null
        : toWesternDigits(String(form.probability_override).trim()),
    ...Object.fromEntries(
      DEAL_LISTS.map(list => [
        listField(list),
        form[listField(list)] ? Number(form[listField(list)]) : null,
      ])
    ),
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
