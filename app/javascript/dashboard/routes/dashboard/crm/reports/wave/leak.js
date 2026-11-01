// Custom (MyDesk): the dashboard's leak alert reads the conversion report of the last 30 days, and names a stage only
// when enough deals reached the stage before it to make its rate mean something (a day or two of deals at the start
// of a month would otherwise report a 0% leak)
export const LEAK_MIN_DEALS = 10;

export const findLeak = (conversion, min = LEAK_MIN_DEALS) => {
  const row = conversion?.rows?.find(
    r => r.stage_id === conversion.leak_stage_id
  );
  if (!row || row.dropped == null) return null;
  return row.count + row.dropped >= min ? row : null;
};
