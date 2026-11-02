import ConversationAPI from 'dashboard/api/inbox/conversation';
import ReportsAPI from 'dashboard/api/reports';
import CSATReportsAPI from 'dashboard/api/csatReports';
import SummaryReportsAPI from 'dashboard/api/summaryReports';
import LiveReportsAPI from 'dashboard/api/liveReports';
import HomeAPI from 'dashboard/api/home';
import { crmReportsAPI, crmTasksAPI } from 'dashboard/api/crm';
import { loadAgentHome, loadManagerHome } from '../homeData';

vi.mock('dashboard/api/inbox/conversation', () => ({
  default: { get: vi.fn(), meta: vi.fn() },
}));
vi.mock('dashboard/api/reports', () => ({
  default: { getSummary: vi.fn(), getReports: vi.fn() },
}));
vi.mock('dashboard/api/summaryReports', () => ({
  default: { getInboxReports: vi.fn() },
}));
vi.mock('dashboard/api/home', () => ({
  default: { waiting: vi.fn() },
}));
vi.mock('dashboard/api/liveReports', () => ({
  default: { getGroupedConversations: vi.fn() },
}));
vi.mock('dashboard/api/csatReports', () => ({
  default: { getMetrics: vi.fn() },
}));
vi.mock('dashboard/api/crm', () => ({
  crmReportsAPI: { report: vi.fn() },
  crmTasksAPI: { get: vi.fn() },
}));

const ok = data => Promise.resolve({ data });

beforeEach(() => {
  vi.clearAllMocks();
  ConversationAPI.get.mockImplementation(() => ok({ data: { payload: [] } }));
  ConversationAPI.meta.mockImplementation(() => ok({ meta: {} }));
  ReportsAPI.getSummary.mockImplementation(() =>
    ok({ conversations_count: 3 })
  );
  CSATReportsAPI.getMetrics.mockImplementation(() => ok({ total_count: 1 }));
  crmReportsAPI.report.mockImplementation(key => ok({ key }));
  crmTasksAPI.get.mockImplementation(() => ok({ tasks: [], total: 0 }));
  ReportsAPI.getReports.mockImplementation(() => ok([]));
  SummaryReportsAPI.getInboxReports.mockImplementation(() => ok([]));
  LiveReportsAPI.getGroupedConversations.mockImplementation(() => ok([]));
  HomeAPI.waiting.mockImplementation(() => ok({ late_count: 0 }));
});

describe('the charts', () => {
  afterEach(() => vi.useRealTimers());

  it('asks the manager for the last 7 days by day', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-11-01T09:00:00Z'));
    const data = await loadManagerHome({ crmEnabled: true });
    const week = { from: 1792962000, to: 1793566799, groupBy: 'day' };
    expect(ReportsAPI.getReports).toHaveBeenCalledWith({
      metric: 'conversations_count',
      ...week,
    });
    expect(ReportsAPI.getReports).toHaveBeenCalledWith({
      metric: 'avg_first_response_time',
      ...week,
    });
    expect(SummaryReportsAPI.getInboxReports).toHaveBeenCalledWith({
      since: 1792962000,
      until: 1793566799,
    });
    expect(LiveReportsAPI.getGroupedConversations).toHaveBeenCalledWith({
      groupBy: 'assignee_id',
    });
    expect(crmReportsAPI.report).toHaveBeenCalledWith('pipeline_by_stage', {});
    expect(Object.keys(data)).toEqual(
      expect.arrayContaining([
        'traffic',
        'responseTrend',
        'channels',
        'load',
        'pipeline',
      ])
    );
  });

  it("sends none of the manager's reports for an employee", async () => {
    await loadAgentHome({ crmEnabled: true });
    expect(ReportsAPI.getReports).not.toHaveBeenCalled();
    expect(ReportsAPI.getSummary).not.toHaveBeenCalled();
    expect(SummaryReportsAPI.getInboxReports).not.toHaveBeenCalled();
    expect(LiveReportsAPI.getGroupedConversations).not.toHaveBeenCalled();
    expect(crmReportsAPI.report).toHaveBeenCalledWith('pipeline_by_stage', {});
  });
});

describe('loadManagerHome', () => {
  it('keeps the rest when one source fails', async () => {
    CSATReportsAPI.getMetrics.mockImplementation(() =>
      Promise.reject(new Error('500'))
    );
    const data = await loadManagerHome({ crmEnabled: true });
    expect(data.csat).toBeNull();
    expect(data.meta).toEqual({ meta: {} });
    expect(data.summary).toEqual({ conversations_count: 3 });
    expect(data.quota).toEqual({ key: 'quota' });
  });

  it('counts the late conversations on the server, without loading them', async () => {
    const data = await loadManagerHome({ crmEnabled: false });
    expect(HomeAPI.waiting).toHaveBeenCalled();
    expect(ConversationAPI.get).not.toHaveBeenCalled();
    expect(data.waiting).toEqual({ late_count: 0 });
  });
});

describe('loadAgentHome', () => {
  it('sends no sales request when the CRM is off', async () => {
    const data = await loadAgentHome({ crmEnabled: false });
    expect(crmReportsAPI.report).not.toHaveBeenCalled();
    expect(crmTasksAPI.get).not.toHaveBeenCalled();
    expect(data.tasks).toBeNull();
    expect(data.deals).toBeNull();
    expect(data.quota).toBeNull();
  });

  it('asks for my open conversations by longest wait', async () => {
    await loadAgentHome({ crmEnabled: true });
    expect(ConversationAPI.get).toHaveBeenCalledWith(
      expect.objectContaining({
        status: 'open',
        assigneeType: 'me',
        sortBy: 'waiting_since_asc',
      })
    );
  });
});

describe('the deals closing soon', () => {
  afterEach(() => vi.useRealTimers());

  it('asks for the next 7 days, across the end of the month', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-28T09:00:00Z'));
    await loadAgentHome({ crmEnabled: true });
    expect(crmReportsAPI.report).toHaveBeenCalledWith('closing', {
      from: '2026-10-28',
      to: '2026-11-04',
    });
  });
});

describe('like-for-like comparisons', () => {
  afterEach(() => vi.useRealTimers());

  it('asks for yesterday up to this hour, and last month up to this day', async () => {
    vi.useFakeTimers();
    // 12:00 in Riyadh on 2 November
    vi.setSystemTime(new Date('2026-11-02T09:00:00Z'));
    const data = await loadManagerHome({ crmEnabled: true });
    expect(ReportsAPI.getSummary).toHaveBeenCalledWith(1793480400, 1793523600);
    expect(crmReportsAPI.report).toHaveBeenCalledWith('quota', {
      from: '2026-10-01',
      to: '2026-10-02',
    });
    expect(data).toHaveProperty('summarySoFar');
    expect(data).toHaveProperty('quotaSoFar');
  });

  it("asks the employee's own last month up to this day", async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-11-02T09:00:00Z'));
    await loadAgentHome({ crmEnabled: true });
    expect(crmReportsAPI.report).toHaveBeenCalledWith('quota', {
      from: '2026-10-01',
      to: '2026-10-02',
    });
  });
});
