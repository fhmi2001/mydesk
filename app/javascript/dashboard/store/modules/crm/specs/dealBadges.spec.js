import { crmContactBadgesAPI } from 'dashboard/api/crm';
import {
  badges,
  requestBadge,
  refreshBadges,
  resetBadges,
} from '../dealBadges';

vi.mock('dashboard/api/crm', () => ({
  crmContactBadgesAPI: { get: vi.fn() },
}));

const flush = async () => {
  await vi.runAllTimersAsync();
};

describe('dealBadges', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    resetBadges();
    crmContactBadgesAPI.get.mockReset();
    crmContactBadgesAPI.get.mockResolvedValue({
      data: { badges: { 1: { count: 2 } } },
    });
  });

  afterEach(() => vi.useRealTimers());

  it('asks for the cards of one list page in a single request', async () => {
    requestBadge(1);
    requestBadge(2);
    requestBadge(1);
    await flush();
    expect(crmContactBadgesAPI.get).toHaveBeenCalledTimes(1);
    expect(crmContactBadgesAPI.get).toHaveBeenCalledWith([1, 2]);
    expect(badges['1']).toEqual({ count: 2 });
    expect(badges['2']).toBeNull();
  });

  it('does not ask again for a contact it already knows', async () => {
    requestBadge(1);
    await flush();
    requestBadge(1);
    await flush();
    expect(crmContactBadgesAPI.get).toHaveBeenCalledTimes(1);
  });

  it('asks again for every known contact when a deal changes', async () => {
    requestBadge(1);
    await flush();
    refreshBadges();
    await flush();
    expect(crmContactBadgesAPI.get).toHaveBeenCalledTimes(2);
    expect(crmContactBadgesAPI.get).toHaveBeenLastCalledWith([1]);
  });

  it('shows no badge when the request fails', async () => {
    crmContactBadgesAPI.get.mockRejectedValue(new Error('down'));
    requestBadge(3);
    await flush();
    expect(badges['3']).toBeNull();
  });
});
