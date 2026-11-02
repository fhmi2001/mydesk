// Custom (MyDesk): a report's filters in the page address, so a reload or a shared link opens the
// same view. Only what is set is written; the dates only for a custom period (the others are worked out each day).
const IDS = [
  'pipeline_id',
  'assignee_id',
  'stage_id',
  'product_id',
  'lead_source_id',
];
const DATE = /^\d{4}-\d{2}-\d{2}$/;

export const toQuery = state => {
  const query = {};
  if (state.period) query.period = state.period;
  if (state.period === 'custom') {
    if (state.from) query.from = state.from;
    if (state.to) query.to = state.to;
  }
  IDS.forEach(key => {
    if (state[key] !== '' && state[key] != null)
      query[key] = String(state[key]);
  });
  if (state.days) query.days = String(state.days);
  if (state.group_by) query.group_by = state.group_by;
  return query;
};

// Whatever does not read as a value is left out, so a hand-edited address falls back to the defaults
export const fromQuery = query => {
  const state = {};
  if (typeof query.period === 'string') state.period = query.period;
  ['from', 'to'].forEach(key => {
    if (DATE.test(query[key] || '')) state[key] = query[key];
  });
  IDS.forEach(key => {
    if (/^\d+$/.test(query[key] || '')) state[key] = Number(query[key]);
  });
  if (/^\d+$/.test(query.days || '')) state.days = query.days;
  if (/^[a-z_]+$/.test(query.group_by || '')) state.group_by = query.group_by;
  return state;
};
