<script>
import PageHeader from '../../SettingsSubPageHeader.vue';
import BandwidthSms from './BandwidthSms.vue';
import DeewanSms from './DeewanSms.vue';
import Twilio from './Twilio.vue';

export default {
  components: {
    PageHeader,
    Twilio,
    BandwidthSms,
    DeewanSms,
  },
  data() {
    return {
      // Custom (MyDesk): Deewan is the default SMS gateway
      provider: 'deewan',
    };
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.SMS.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.SMS.DESC')"
    />
    <div class="flex-shrink-0 flex-grow-0">
      <label>
        {{ $t('INBOX_MGMT.ADD.SMS.PROVIDERS.LABEL') }}
        <select v-model="provider">
          <option value="deewan">
            {{ $t('INBOX_MGMT.ADD.SMS.PROVIDERS.DEEWAN') }}
          </option>
          <option value="twilio">
            {{ $t('INBOX_MGMT.ADD.SMS.PROVIDERS.TWILIO') }}
          </option>
          <option value="360dialog">
            {{ $t('INBOX_MGMT.ADD.SMS.PROVIDERS.BANDWIDTH') }}
          </option>
        </select>
      </label>
    </div>
    <DeewanSms v-if="provider === 'deewan'" />
    <Twilio v-else-if="provider === 'twilio'" type="sms" />
    <BandwidthSms v-else />
  </div>
</template>
