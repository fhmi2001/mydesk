// Custom (MyDesk): the account's time zone, sent with the CRM status, sets the day the report shortcuts count from
import { mutations, types, state as initial } from '../status';
import { salesToday } from 'dashboard/routes/dashboard/crm/reports/periods';

describe('crm/status mutations', () => {
  // 20:30 UTC on 31 October is 00:30 on 1 November in Dubai, still 31 October in Riyadh
  const instant = new Date(Date.UTC(2026, 9, 31, 20, 30));

  it("counts days in the account's time zone once the status arrives, and in Riyadh again after a reset", () => {
    const state = structuredClone(initial);
    mutations[types.SET](state, {
      enabled: true,
      settings: { timezone: 'Asia/Dubai' },
    });
    expect(state.settings.timezone).toBe('Asia/Dubai');
    expect(salesToday(instant).getDate()).toBe(1);

    mutations[types.RESET](state);
    expect(state.settings.timezone).toBe('Asia/Riyadh');
    expect(salesToday(instant).getDate()).toBe(31);
  });
});
