import { mount } from '@vue/test-utils';
import ResponseSpeedReport from '../ResponseSpeedReport.vue';
import CampaignsReport from '../CampaignsReport.vue';
import ConversationDealsReport from '../ConversationDealsReport.vue';

vi.mock('../../../shared/useCrmFormat', () => ({
  useCrmFormat: () => ({
    money: cents => `${cents / 100} ر.س`,
    number: value => String(value),
    date: value => String(value),
  }),
}));

const bucket = (key, extra = {}) => ({
  key,
  closed_count: 0,
  won_count: 0,
  won_cents: 0,
  small_sample: true,
  win_rate: null,
  average_won_cents: null,
  cell: { bucket: key },
  ...extra,
});

describe('ResponseSpeedReport', () => {
  const data = {
    buckets: [
      bucket('under_5m', {
        closed_count: 12,
        won_count: 9,
        win_rate: 75,
        small_sample: false,
        average_won_cents: 20000,
      }),
      bucket('5_30m', { closed_count: 3, won_count: 1 }),
      bucket('30m_2h'),
      bucket('2h_24h'),
      bucket('over_24h'),
    ],
    min_sample: 10,
    totals: { closed_count: 15, excluded_count: 4 },
  };

  it('gives each bucket its win rate, or says the sample is small', () => {
    const wrapper = mount(ResponseSpeedReport, { props: { data } });
    const rows = wrapper.findAll('tbody tr');
    expect(rows[0].text()).toContain('75%');
    expect(rows[1].text()).toContain(
      'CRM.REPORTS.WAVE.RESPONSE_SPEED.SMALL_SAMPLE'
    );
    // A bucket with no deal has nothing to sample
    expect(rows[2].text()).not.toContain('SMALL_SAMPLE');
    expect(rows[2].text()).toContain('—');
  });

  it('says how many deals were left out and that it shows a link, not a cause', () => {
    const text = mount(ResponseSpeedReport, { props: { data } }).text();
    expect(text).toContain('CRM.REPORTS.WAVE.RESPONSE_SPEED.EXCLUDED');
    expect(text).toContain('CRM.REPORTS.WAVE.RESPONSE_SPEED.CORRELATION');
  });

  it('opens the deals of a bucket', async () => {
    const wrapper = mount(ResponseSpeedReport, { props: { data } });
    await wrapper.find('tbody tr button').trigger('click');
    expect(wrapper.emitted('drill')[0][0]).toEqual({ bucket: 'under_5m' });
  });
});

describe('CampaignsReport', () => {
  const figures = (count, wonCount, cents, attribution) => ({
    count,
    won_count: wonCount,
    won_cents: cents,
    cell: { campaign_id: 3, attribution },
  });
  const data = {
    rows: [
      {
        campaign_id: 3,
        title: 'عرض نوفمبر',
        sms: true,
        direct: figures(0, 0, 0, 'direct'),
        influenced: figures(2, 1, 100000, 'influenced'),
        recipients: 4,
        conversion: 50,
        cost: 0.15,
        cost_known: false,
        return_per_riyal: 6666.7,
      },
    ],
    totals: {},
  };

  it('keeps direct and influenced apart, and marks an unknown cost', () => {
    const text = mount(CampaignsReport, { props: { data } }).text();
    expect(text).toContain('عرض نوفمبر');
    expect(text).toContain('CRM.REPORTS.WAVE.CAMPAIGNS.DIRECT');
    expect(text).toContain('CRM.REPORTS.WAVE.CAMPAIGNS.INFLUENCED');
    expect(text).toContain('CRM.REPORTS.WAVE.CAMPAIGNS.COST_PARTIAL');
  });
});

describe('ConversationDealsReport', () => {
  it('shows the conversations, those that became deals and the share, per channel', () => {
    const data = {
      totals: {
        conversation_count: 4,
        deal_count: 2,
        won_count: 1,
        won_cents: 80000,
        conversion: 50,
      },
      inboxes: [
        {
          inbox_id: 1,
          name: 'الموقع',
          conversation_count: 3,
          deal_count: 2,
          won_count: 1,
          won_cents: 80000,
          conversion: 66.7,
          cell: { inbox_id: 1 },
        },
      ],
      assignees: null,
    };
    const text = mount(ConversationDealsReport, { props: { data } }).text();
    expect(text).toContain('50%');
    expect(text).toContain('الموقع');
    expect(text).toContain('66.7%');
  });
});
