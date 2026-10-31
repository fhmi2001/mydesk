// Custom (MyDesk): the "▲ 12%" next to a summary number. `lowerIsBetter` flips the colour (lost deals, days)
export const deltaFor = (current, previous, lowerIsBetter = false) => {
  const cur = Number(current) || 0;
  const prev = Number(previous) || 0;
  if (!prev && !cur) return { label: '', tone: 'flat' };
  if (!prev) return { label: '▲ —', tone: lowerIsBetter ? 'down' : 'up' };
  const pct = Math.round(((cur - prev) / Math.abs(prev)) * 100);
  if (pct === 0) return { label: '0%', tone: 'flat' };
  const improved = lowerIsBetter ? pct < 0 : pct > 0;
  return {
    label: `${pct > 0 ? '▲' : '▼'} ${Math.abs(pct)}%`,
    tone: improved ? 'up' : 'down',
  };
};
