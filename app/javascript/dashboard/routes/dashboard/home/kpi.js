// Custom (MyDesk): the "▲ 12%" beside a home screen number. The page compares like with like (today against
// yesterday up to the same hour, this month against last month up to the same day), and says nothing where there
// is nothing honest to say: no previous figure, or an average with nothing to average yet.
import { deltaFor } from '../crm/reports/summaryDelta';

export const compareKpi = (
  current,
  previous,
  { average = false, lowerIsBetter = false } = {}
) => {
  if (previous === null || previous === undefined) return null;
  if (average && !current) return null;
  const delta = deltaFor(current, previous, lowerIsBetter);
  return delta.label ? delta : null;
};
