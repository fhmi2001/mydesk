import {
  dailySeries,
  linePoints,
  lineSegments,
  gapsWhereNone,
  cumulativeSeries,
  channelRows,
  loadRows,
  stageRows,
  dayLabel,
  isOverloaded,
} from '../charts';

describe('dailySeries', () => {
  it('turns the timeseries into days and numbers', () => {
    expect(
      dailySeries([
        { value: '3', timestamp: 1793480400 },
        { value: 5, timestamp: 1793566800 },
      ])
    ).toEqual([
      { at: new Date(1793480400 * 1000), value: 3 },
      { at: new Date(1793566800 * 1000), value: 5 },
    ]);
  });

  it('is empty without data', () => {
    expect(dailySeries(null)).toEqual([]);
  });
});

describe('linePoints', () => {
  it('spreads the values across the width and scales them to the height', () => {
    expect(linePoints([0, 5, 10], { width: 100, height: 50, max: 10 })).toBe(
      '0,50 50,25 100,0'
    );
  });

  it('stops at the first missing value (days still ahead)', () => {
    expect(
      linePoints([0, 10, null, null], { width: 90, height: 10, max: 10 })
    ).toBe('0,10 30,0');
  });

  it('draws a flat line when everything is zero', () => {
    expect(linePoints([0, 0], { width: 10, height: 10, max: 0 })).toBe(
      '0,10 10,10'
    );
  });
});

describe('cumulativeSeries', () => {
  it('splits the quota report line into won and target with a shared top', () => {
    expect(
      cumulativeSeries([
        { date: '2026-11-01', won_cents: 100, target_cents: 50 },
        { date: '2026-11-02', won_cents: null, target_cents: 300 },
      ])
    ).toEqual({ won: [100, null], target: [50, 300], max: 300 });
  });
});

describe('channelRows', () => {
  it('names each inbox and ranks by conversations', () => {
    expect(
      channelRows(
        [
          { id: 1, conversations_count: 4 },
          { id: 2, conversations_count: 9 },
          { id: 3, conversations_count: 0 },
        ],
        [
          { id: 1, name: 'Website' },
          { id: 2, name: 'WhatsApp' },
        ]
      )
    ).toEqual([
      { id: 2, name: 'WhatsApp', value: 9 },
      { id: 1, name: 'Website', value: 4 },
    ]);
  });
});

describe('loadRows', () => {
  it('names each agent, ranks by open conversations and leaves out the unassigned', () => {
    expect(
      loadRows(
        [
          { assignee_id: 7, open: 3 },
          { assignee_id: null, open: 12 },
          { assignee_id: 8, open: 16 },
        ],
        [
          { id: 7, name: 'Nora' },
          { id: 8, name: 'Sara' },
        ]
      )
    ).toEqual([
      { id: 8, name: 'Sara', value: 16 },
      { id: 7, name: 'Nora', value: 3 },
    ]);
  });
});

describe('stageRows', () => {
  it('keeps the stages holding deals, with the pipeline name when there are several', () => {
    expect(
      stageRows({
        rows: [
          {
            stage_id: 1,
            name: 'Lead',
            pipeline_name: 'B2B',
            count: 2,
            total_cents: 500,
          },
          {
            stage_id: 2,
            name: 'Offer',
            pipeline_name: 'B2B',
            count: 0,
            total_cents: 0,
          },
          {
            stage_id: 3,
            name: 'Lead',
            pipeline_name: 'Retail',
            count: 1,
            total_cents: 100,
          },
        ],
      })
    ).toEqual([
      { id: 1, name: 'Lead', sub: 'B2B', value: 500, count: 2 },
      { id: 3, name: 'Lead', sub: 'Retail', value: 100, count: 1 },
    ]);
  });

  it('counts only the pipelines holding deals', () => {
    expect(
      stageRows({
        rows: [
          {
            stage_id: 1,
            name: 'Lead',
            pipeline_name: 'B2B',
            count: 2,
            total_cents: 500,
          },
          {
            stage_id: 3,
            name: 'Lead',
            pipeline_name: 'Retail',
            count: 0,
            total_cents: 0,
          },
        ],
      })
    ).toEqual([{ id: 1, name: 'Lead', sub: '', value: 500, count: 2 }]);
  });

  it('uses the stage name alone for a single pipeline', () => {
    expect(
      stageRows({
        rows: [
          {
            stage_id: 1,
            name: 'Lead',
            pipeline_name: 'B2B',
            count: 2,
            total_cents: 500,
          },
        ],
      })
    ).toEqual([{ id: 1, name: 'Lead', sub: '', value: 500, count: 2 }]);
  });
});

describe('lineSegments', () => {
  it('breaks the line at a missing day instead of drawing it as zero', () => {
    expect(
      lineSegments([4, null, 8, 6], { width: 90, height: 10, max: 10 })
    ).toEqual(['0,6', '60,2 90,4']);
  });

  it('is one segment when nothing is missing', () => {
    expect(lineSegments([0, 10], { width: 10, height: 10, max: 10 })).toEqual([
      '0,10 10,0',
    ]);
  });
});

describe('gapsWhereNone', () => {
  it('leaves out a day with no conversations, whose average means nothing', () => {
    expect(gapsWhereNone([5, 0, 7], [3, 0, 2])).toEqual([5, null, 7]);
  });
});

describe('dayLabel', () => {
  it('is the day and month, short enough for seven bars on a phone', () => {
    expect(dayLabel(new Date(2026, 9, 27))).toBe('27/10');
    expect(dayLabel(new Date(2026, 10, 2))).toBe('2/11');
  });
});

describe('isOverloaded', () => {
  const rows = [
    { id: 1, value: 16 },
    { id: 2, value: 4 },
    { id: 3, value: 4 },
  ];

  it('flags an agent holding twice the team average or more', () => {
    // average 8: 16 is twice it
    expect(isOverloaded(rows)(rows[0])).toBe(true);
    expect(isOverloaded(rows)(rows[1])).toBe(false);
  });

  it('flags no one in a team of one', () => {
    expect(isOverloaded([{ id: 1, value: 9 }])({ id: 1, value: 9 })).toBe(
      false
    );
  });
});
