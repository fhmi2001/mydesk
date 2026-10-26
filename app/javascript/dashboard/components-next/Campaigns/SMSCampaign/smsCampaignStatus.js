// Custom (MyDesk): one status for an SMS campaign, from its campaign status and the result of its numbers
export const SMS_CAMPAIGN_STATUSES = {
  SCHEDULED: 'scheduled',
  STARTING: 'starting',
  SENDING: 'sending',
  COMPLETED: 'completed',
  PARTIAL: 'partial',
  FAILED: 'failed',
};

export const SMS_CAMPAIGN_STATUS_STYLES = {
  scheduled: 'bg-n-blue-3 text-n-blue-11',
  starting: 'bg-n-amber-3 text-n-amber-11',
  sending: 'bg-n-amber-3 text-n-amber-11',
  completed: 'bg-n-teal-3 text-n-teal-11',
  partial: 'bg-n-amber-3 text-n-amber-11',
  failed: 'bg-n-ruby-3 text-n-ruby-11',
};

export const smsCampaignStatus = (campaign, now = Date.now()) => {
  const stats = campaign.sms_stats;
  if (campaign.campaign_status === 'processing') {
    return SMS_CAMPAIGN_STATUSES.SENDING;
  }
  if (campaign.campaign_status === 'active') {
    return campaign.scheduled_at * 1000 > now
      ? SMS_CAMPAIGN_STATUSES.SCHEDULED
      : SMS_CAMPAIGN_STATUSES.STARTING;
  }
  if (stats?.total && stats.failed === stats.total) {
    return SMS_CAMPAIGN_STATUSES.FAILED;
  }
  if (stats?.failed) return SMS_CAMPAIGN_STATUSES.PARTIAL;
  return SMS_CAMPAIGN_STATUSES.COMPLETED;
};

// A campaign that is due or sending changes on its own, so pages showing it keep refreshing
export const isSmsCampaignInProgress = (campaign, now = Date.now()) =>
  campaign.campaign_status === 'processing' ||
  (campaign.campaign_status === 'active' &&
    campaign.scheduled_at * 1000 <= now);
