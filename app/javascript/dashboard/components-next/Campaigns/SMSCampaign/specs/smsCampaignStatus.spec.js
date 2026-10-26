import {
  isSmsCampaignInProgress,
  smsCampaignStatus,
} from '../smsCampaignStatus';

const NOW = 1_800_000_000_000;
const build = (attrs = {}) => ({
  campaign_status: 'completed',
  scheduled_at: NOW / 1000 - 60,
  sms_stats: { total: 2, sent: 2, failed: 0, queued: 0 },
  ...attrs,
});

describe('smsCampaignStatus', () => {
  it('tells scheduled campaigns from due ones that have not started', () => {
    const future = build({
      campaign_status: 'active',
      scheduled_at: NOW / 1000 + 60,
    });
    const due = build({ campaign_status: 'active' });

    expect(smsCampaignStatus(future, NOW)).toBe('scheduled');
    expect(smsCampaignStatus(due, NOW)).toBe('starting');
  });

  it('uses the result of the numbers once the campaign has finished', () => {
    expect(smsCampaignStatus(build(), NOW)).toBe('completed');
    expect(
      smsCampaignStatus(
        build({ sms_stats: { total: 2, sent: 1, failed: 1 } }),
        NOW
      )
    ).toBe('partial');
    expect(
      smsCampaignStatus(
        build({ sms_stats: { total: 2, sent: 0, failed: 2 } }),
        NOW
      )
    ).toBe('failed');
  });

  it('marks due and sending campaigns as in progress', () => {
    expect(
      isSmsCampaignInProgress(build({ campaign_status: 'processing' }), NOW)
    ).toBe(true);
    expect(
      isSmsCampaignInProgress(build({ campaign_status: 'active' }), NOW)
    ).toBe(true);
    expect(isSmsCampaignInProgress(build(), NOW)).toBe(false);
  });
});
