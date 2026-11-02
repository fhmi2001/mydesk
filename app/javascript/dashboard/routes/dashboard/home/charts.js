// Custom (MyDesk): the home screen's charts, from report payloads to what a chart draws. Raw values only: the cards
// format them.
const MAX_ROWS = 8;

// The v2 reports timeseries ([{ value, timestamp }], one per day) as [{ at, value }]
export const dailySeries = series =>
  (series || []).map(point => ({
    at: new Date(point.timestamp * 1000),
    value: Number(point.value) || 0,
  }));

// An SVG polyline's points: the values spread evenly across the width, 0 at the bottom and `max` at the top. It stops
// at the first null (the days still ahead in the month).
export const linePoints = (values, { width, height, max }) => {
  const firstMissing = values.indexOf(null);
  const known = firstMissing === -1 ? values : values.slice(0, firstMissing);
  const step = values.length > 1 ? width / (values.length - 1) : 0;
  const y = value => (max > 0 ? height - (value / max) * height : height);
  return known
    .map((value, i) => `${Math.round(step * i)},${Math.round(y(value))}`)
    .join(' ');
};

// The quota report's cumulative line (won so far against the target spread over the days) as two series
export const cumulativeSeries = cumulative => {
  const won = (cumulative || []).map(day => day.won_cents);
  const target = (cumulative || []).map(day => day.target_cents);
  return { won, target, max: Math.max(0, ...won, ...target) };
};

const ranked = rows =>
  rows
    .filter(row => row.value > 0)
    .sort((a, b) => b.value - a.value)
    .slice(0, MAX_ROWS);

// The inbox summary report, named from the account's inboxes
export const channelRows = (summary, inboxes) => {
  const names = Object.fromEntries((inboxes || []).map(i => [i.id, i.name]));
  return ranked(
    (summary || []).map(row => ({
      id: row.id,
      name: names[row.id] || '',
      value: Number(row.conversations_count) || 0,
    }))
  );
};

// Open conversations per agent (live reports grouped by assignee); the unassigned have their own line in the list
export const loadRows = (grouped, agents) => {
  const names = Object.fromEntries((agents || []).map(a => [a.id, a.name]));
  return ranked(
    (grouped || [])
      .filter(row => row.assignee_id)
      .map(row => ({
        id: row.assignee_id,
        name: names[row.assignee_id] || '',
        value: Number(row.open) || 0,
      }))
  );
};

// The open deals' value in each stage; with several pipelines, each row also names its pipeline (`sub`, shown under
// the stage, so two stages of the same name stay apart on a narrow screen)
export const stageRows = report => {
  const rows = report?.rows || [];
  const pipelines = new Set(rows.map(row => row.pipeline_name)).size;
  return rows
    .filter(row => row.count > 0)
    .map(row => ({
      id: row.stage_id,
      name: row.name,
      sub: pipelines > 1 ? row.pipeline_name : '',
      value: row.total_cents,
      count: row.count,
    }));
};

// Like linePoints, but a missing value (null) breaks the line into segments rather than ending it: a day with nothing
// to average leaves a gap instead of reading as zero
export const lineSegments = (values, { width, height, max }) => {
  const step = values.length > 1 ? width / (values.length - 1) : 0;
  const y = value => (max > 0 ? height - (value / max) * height : height);
  const segments = [[]];
  values.forEach((value, i) => {
    if (value === null) {
      if (segments.at(-1).length) segments.push([]);
      return;
    }
    segments.at(-1).push(`${Math.round(step * i)},${Math.round(y(value))}`);
  });
  return segments.filter(segment => segment.length).map(s => s.join(' '));
};

// An average per day (first response) is null on the days with no conversations
export const gapsWhereNone = (averages, counts) =>
  averages.map((value, i) => (counts[i] ? value : null));

// A bar chart's day: day/month, short enough for seven bars on a phone (a weekday name gets cut)
export const dayLabel = at => `${at.getDate()}/${at.getMonth() + 1}`;

// Whether an agent's open conversations are twice the team's average or more: only they get the warning colour
export const isOverloaded = rows => {
  const average = rows.reduce((sum, row) => sum + row.value, 0) / rows.length;
  return row => rows.length > 1 && row.value >= 2 * average;
};
